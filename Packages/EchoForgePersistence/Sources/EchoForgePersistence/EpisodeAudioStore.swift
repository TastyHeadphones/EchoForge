import Foundation

public struct WAVFormat: Sendable, Hashable {
    public var sampleRateHz: Int
    public var channels: Int
    public var bitsPerSample: Int

    public init(sampleRateHz: Int, channels: Int, bitsPerSample: Int) {
        self.sampleRateHz = sampleRateHz
        self.channels = channels
        self.bitsPerSample = bitsPerSample
    }

    public static let geminiTTS: WAVFormat = WAVFormat(sampleRateHz: 24_000, channels: 1, bitsPerSample: 16)
}

public protocol EpisodeAudioStoring: Sendable {
    func fileURL(projectID: UUID, episodeID: UUID, fileName: String?) async throws -> URL
    func fileExists(projectID: UUID, episodeID: UUID, fileName: String?) async -> Bool

    func writeWAV(
        pcmData: Data,
        projectID: UUID,
        episodeID: UUID,
        fileName: String?,
        format: WAVFormat
    ) async throws -> URL

    func deleteAudio(projectID: UUID, episodeID: UUID, fileName: String?) async throws
    func deleteAllAudio(projectID: UUID) async throws
}

public actor EpisodeAudioStore: EpisodeAudioStoring {
    private let fileManager: FileManager
    private let rootURL: URL

    public init(fileManager: FileManager = .default, rootURL: URL? = nil) {
        self.fileManager = fileManager
        self.rootURL = rootURL ?? Self.defaultRootURL(fileManager: fileManager)
    }

    public func fileURL(projectID: UUID, episodeID: UUID, fileName: String?) async throws -> URL {
        try ensureDirectories(projectID: projectID)
        let actualFileName = fileName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = actualFileName?.isEmpty == false ? actualFileName! : defaultFileName(episodeID: episodeID)
        return projectDirectoryURL(projectID: projectID).appendingPathComponent(resolved, isDirectory: false)
    }

    public func fileExists(projectID: UUID, episodeID: UUID, fileName: String?) async -> Bool {
        let url = try? await fileURL(projectID: projectID, episodeID: episodeID, fileName: fileName)
        guard let url else { return false }
        return fileManager.fileExists(atPath: url.path)
    }

    public func writeWAV(
        pcmData: Data,
        projectID: UUID,
        episodeID: UUID,
        fileName: String?,
        format: WAVFormat = .geminiTTS
    ) async throws -> URL {
        let url = try await fileURL(projectID: projectID, episodeID: episodeID, fileName: fileName)
        let wav = try WAVEncoder.encode(pcmData: pcmData, format: format)
        try wav.write(to: url, options: [.atomic])
        return url
    }

    public func deleteAudio(projectID: UUID, episodeID: UUID, fileName: String?) async throws {
        let url = try await fileURL(projectID: projectID, episodeID: episodeID, fileName: fileName)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    public func deleteAllAudio(projectID: UUID) async throws {
        let projectURL = projectDirectoryURL(projectID: projectID)
        if fileManager.fileExists(atPath: projectURL.path) {
            try fileManager.removeItem(at: projectURL)
        }
    }

    private func ensureDirectories(projectID: UUID) throws {
        if !fileManager.fileExists(atPath: audioDirectoryURL.path) {
            try fileManager.createDirectory(at: audioDirectoryURL, withIntermediateDirectories: true)
        }

        let projectURL = projectDirectoryURL(projectID: projectID)
        if !fileManager.fileExists(atPath: projectURL.path) {
            try fileManager.createDirectory(at: projectURL, withIntermediateDirectories: true)
        }
    }

    private var audioDirectoryURL: URL {
        rootURL.appendingPathComponent("audio", isDirectory: true)
    }

    private func projectDirectoryURL(projectID: UUID) -> URL {
        audioDirectoryURL.appendingPathComponent(projectID.uuidString, isDirectory: true)
    }

    private func defaultFileName(episodeID: UUID) -> String {
        "\(episodeID.uuidString).wav"
    }

    private static func defaultRootURL(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("EchoForge", isDirectory: true)
    }
}

enum WAVEncoder {
    static func encode(pcmData: Data, format: WAVFormat) throws -> Data {
        let sampleRateHz = format.sampleRateHz
        let channels = format.channels
        let bitsPerSample = format.bitsPerSample

        guard sampleRateHz > 0, channels > 0, bitsPerSample > 0 else {
            throw WAVEncoderError.invalidFormat
        }

        guard bitsPerSample % 8 == 0 else {
            throw WAVEncoderError.invalidFormat
        }

        let subchunk2Size = pcmData.count
        let chunkSize = 36 + subchunk2Size

        guard chunkSize <= Int(UInt32.max) else {
            throw WAVEncoderError.tooLarge
        }

        var data = Data()
        data.reserveCapacity(44 + subchunk2Size)

        data.append(contentsOf: "RIFF".utf8)
        data.append(littleEndian: UInt32(chunkSize))
        data.append(contentsOf: "WAVE".utf8)

        data.append(contentsOf: "fmt ".utf8)
        data.append(littleEndian: UInt32(16)) // PCM fmt chunk size
        data.append(littleEndian: UInt16(1)) // Audio format 1 = PCM
        data.append(littleEndian: UInt16(channels))
        data.append(littleEndian: UInt32(sampleRateHz))

        let byteRate = UInt32(sampleRateHz * channels * (bitsPerSample / 8))
        let blockAlign = UInt16(channels * (bitsPerSample / 8))
        data.append(littleEndian: byteRate)
        data.append(littleEndian: blockAlign)
        data.append(littleEndian: UInt16(bitsPerSample))

        data.append(contentsOf: "data".utf8)
        data.append(littleEndian: UInt32(subchunk2Size))
        data.append(pcmData)

        return data
    }
}

enum WAVEncoderError: LocalizedError, Sendable {
    case invalidFormat
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid audio format for WAV encoding."
        case .tooLarge:
            return "Audio is too large to encode as WAV."
        }
    }
}

private extension Data {
    mutating func append(littleEndian value: UInt16) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { buffer in
            append(contentsOf: buffer.bindMemory(to: UInt8.self))
        }
    }

    mutating func append(littleEndian value: UInt32) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { buffer in
            append(contentsOf: buffer.bindMemory(to: UInt8.self))
        }
    }
}
