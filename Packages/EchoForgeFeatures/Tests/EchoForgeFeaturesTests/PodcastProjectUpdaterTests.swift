import XCTest
import EchoForgeCore
import EchoForgeGemini
@testable import EchoForgeFeatures

final class PodcastProjectUpdaterTests: XCTestCase {
    func testAppliesEventsToProject() {
        var project = PodcastProject(topic: "Test", episodeCountRequested: 2)
        project.status = .generating

        let header = PodcastStreamProjectHeader(
            topic: "Test",
            episodeCount: 2,
            title: "A Title",
            description: "A Description",
            hosts: [
                .init(id: .hostA, name: "Ava", persona: "Curious"),
                .init(id: .hostB, name: "Noah", persona: "Skeptical")
            ]
        )

        PodcastProjectUpdater.apply(.project(header), to: &project)
        XCTAssertEqual(project.title, "A Title")
        XCTAssertEqual(project.hosts.first?.displayName, "Ava")

        let episodeHeader = PodcastStreamEpisodeHeader(episodeNumber: 1, title: "Ep 1", summary: "Summary")
        PodcastProjectUpdater.apply(.episode(episodeHeader), to: &project)
        XCTAssertEqual(project.episodes.count, 1)
        XCTAssertEqual(project.episodes[0].number, 1)

        let line = PodcastStreamDialogueLineEvent(episodeNumber: 1, speaker: .hostA, text: "Hello")
        PodcastProjectUpdater.apply(.line(line), to: &project)
        XCTAssertEqual(project.episodes[0].lines.count, 1)

        PodcastProjectUpdater.apply(.done, to: &project)
        XCTAssertEqual(project.status, .complete)
    }
}
