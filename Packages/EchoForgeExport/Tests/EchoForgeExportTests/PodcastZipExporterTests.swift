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

        let exporter = PodcastZipExporter()
        let zipURL = try await exporter.export(project: project)

        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path))
        let archive = try Archive(url: zipURL, accessMode: .read)

        let paths = Set(archive.map(\.path))
        XCTAssertTrue(paths.contains("project.json"))
        XCTAssertTrue(paths.contains("episodes/episode-001.json"))
        XCTAssertTrue(paths.contains("episodes/episode-001.txt"))
    }
}
