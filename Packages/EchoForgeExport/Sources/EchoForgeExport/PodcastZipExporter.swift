import Foundation
import ZIPFoundation
import EchoForgeCore

public actor PodcastZipExporter: PodcastExporting {
    public init() {}

    public func export(project: PodcastProject) async throws -> URL {
        try await Task.detached(priority: .utility) {
            try Self.exportSync(project: project, fileManager: .default)
        }.value
    }

    nonisolated private static func exportSync(project: PodcastProject, fileManager: FileManager) throws -> URL {
        let exportDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("EchoForgeExport-\(project.id.uuidString)", isDirectory: true)

        if fileManager.fileExists(atPath: exportDirectory.path) {
            try fileManager.removeItem(at: exportDirectory)
        }
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        let zipURL = exportDirectory.appendingPathComponent("EchoForge-\(project.id.uuidString).zip")
        let archive = try Archive(url: zipURL, accessMode: .create)

        let encoder = EchoForgeJSON.encoder(prettyPrinted: true)

        let projectData = try encoder.encode(project)
        try addFile(to: archive, path: "project.json", data: projectData)

        for episode in project.episodes.sorted(by: { $0.number < $1.number }) {
            let number = String(format: "%03d", episode.number)

            let episodeJSON = try encoder.encode(episode)
            try addFile(to: archive, path: "episodes/episode-\(number).json", data: episodeJSON)

            let transcript = makeTranscript(project: project, episode: episode)
            let transcriptData = Data(transcript.utf8)
            try addFile(to: archive, path: "episodes/episode-\(number).txt", data: transcriptData)
        }

        return zipURL
    }

    nonisolated private static func addFile(to archive: Archive, path: String, data: Data) throws {
        let size = Int64(data.count)

        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: size,
            compressionMethod: .deflate
        ) { position, size in
            guard position >= 0, position <= Int64(Int.max) else {
                throw PodcastZipExporterError.invalidPosition
            }

            let start = Int(position)
            let end = start + size
            guard start >= 0, end <= data.count else {
                throw PodcastZipExporterError.invalidPosition
            }
            return data.subdata(in: start..<end)
        }
    }

    nonisolated private static func makeTranscript(project: PodcastProject, episode: Episode) -> String {
        let hostName: (Speaker) -> String = { speaker in
            project.hosts.first(where: { $0.id == speaker })?.displayName ?? speaker.rawValue
        }

        var lines: [String] = []
        lines.reserveCapacity(episode.lines.count)

        for line in episode.lines {
            lines.append("\(hostName(line.speaker)): \(line.text)")
        }

        return lines.joined(separator: "\n")
    }
}

public enum PodcastZipExporterError: LocalizedError, Sendable {
    case invalidPosition

    public var errorDescription: String? {
        switch self {
        case .invalidPosition:
            return "Internal ZIP export error."
        }
    }
}
