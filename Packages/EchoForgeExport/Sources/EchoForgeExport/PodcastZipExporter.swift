import Foundation
import ZIPFoundation
import EchoForgeCore

public actor PodcastZipExporter: PodcastExporting {
    public typealias EpisodeAudioURLProvider = @Sendable (_ project: PodcastProject, _ episode: Episode) -> URL?

    private let episodeAudioURLProvider: EpisodeAudioURLProvider?

    public init() {
        self.episodeAudioURLProvider = PodcastZipExporter.defaultEpisodeAudioURLProvider()
    }

    public init(episodeAudioURLProvider: EpisodeAudioURLProvider?) {
        self.episodeAudioURLProvider = episodeAudioURLProvider
    }

    public func export(project: PodcastProject) async throws -> URL {
        let episodeAudioURLProvider = episodeAudioURLProvider
        return try await Task.detached(priority: .utility) {
            try Self.exportSync(
                project: project,
                fileManager: .default,
                episodeAudioURLProvider: episodeAudioURLProvider
            )
        }.value
    }

    nonisolated private static func exportSync(
        project: PodcastProject,
        fileManager: FileManager,
        episodeAudioURLProvider: EpisodeAudioURLProvider?
    ) throws -> URL {
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

            if
                episode.audioStatus == .ready,
                let episodeAudioURLProvider,
                let audioURL = episodeAudioURLProvider(project, episode),
                fileManager.fileExists(atPath: audioURL.path) {
                do {
                    let audioData = try Data(contentsOf: audioURL)
                    let ext = audioURL.pathExtension.isEmpty ? "wav" : audioURL.pathExtension
                    try addFile(to: archive, path: "audio/episode-\(number).\(ext)", data: audioData)
                } catch {
                    // If audio can't be read, keep exporting transcripts + metadata.
                }
            }
        }

        return zipURL
    }

    nonisolated private static func defaultEpisodeAudioURLProvider() -> EpisodeAudioURLProvider {
        { project, episode in
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let root = base.appendingPathComponent("EchoForge", isDirectory: true)
            let projectAudioDir = root
                .appendingPathComponent("audio", isDirectory: true)
                .appendingPathComponent(project.id.uuidString, isDirectory: true)

            let fileName = episode.audio?.fileName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolved = fileName?.isEmpty == false ? fileName! : "\(episode.id.uuidString).wav"
            return projectAudioDir.appendingPathComponent(resolved, isDirectory: false)
        }
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
