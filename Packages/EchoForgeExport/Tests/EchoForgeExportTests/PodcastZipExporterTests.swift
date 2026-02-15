import XCTest
import ZIPFoundation
import EchoForgeCore
@testable import EchoForgeExport

final class PodcastZipExporterTests: XCTestCase {
    func testExportCreatesZipWithExpectedEntries() async throws {
        var project = PodcastProject(topic: "Test", episodeCountRequested: 1)
        project.hosts = [
            PodcastHost(id: .hostA, displayName: "Ava"),
            PodcastHost(id: .hostB, displayName: "Noah")
        ]
        project.episodes = [
            Episode(
                number: 1,
                title: "Episode 1",
                summary: "Summary",
                lines: [
                    DialogueLine(speaker: .hostA, text: "Hello."),
                    DialogueLine(speaker: .hostB, text: "Hi there.")
                ],
                status: .complete
            )
        ]

        let exporter = PodcastZipExporter(episodeAudioURLProvider: nil)
        let zipURL = try await exporter.export(project: project)

        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path))
        let archive = try Archive(url: zipURL, accessMode: .read)

        let paths = Set(archive.map(\.path))
        XCTAssertTrue(paths.contains("project.json"))
        XCTAssertTrue(paths.contains("episodes/episode-001.json"))
        XCTAssertTrue(paths.contains("episodes/episode-001.txt"))
    }

    func testExportIncludesAudioWhenAvailable() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)

        let audioURL = temp.appendingPathComponent("episode.wav", isDirectory: false)
        FileManager.default.createFile(atPath: audioURL.path, contents: Data("RIFF".utf8))

        var project = PodcastProject(topic: "Test", episodeCountRequested: 1)
        let episodeID = UUID()
        project.episodes = [
            Episode(
                id: episodeID,
                number: 1,
                lines: [DialogueLine(speaker: .hostA, text: "Hello.")],
                status: .complete,
                audio: EpisodeAudio(status: .ready, fileName: audioURL.lastPathComponent, generatedAt: Date())
            )
        ]

        let exporter = PodcastZipExporter(episodeAudioURLProvider: { _, _ in audioURL })
        let zipURL = try await exporter.export(project: project)

        let archive = try Archive(url: zipURL, accessMode: .read)
        let paths = Set(archive.map(\.path))
        XCTAssertTrue(paths.contains("audio/episode-001.wav"))
    }
}
