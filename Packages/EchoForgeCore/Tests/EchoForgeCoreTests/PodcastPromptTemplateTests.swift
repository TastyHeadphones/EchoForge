import XCTest
@testable import EchoForgeCore

final class PodcastPromptTemplateTests: XCTestCase {
    func testPromptInterpolatesInputs() {
        let prompt = PodcastPromptTemplate.makeNDJSONPrompt(
            topic: "Space elevators",
            episodeCount: 3,
            hostAName: "Ava",
            hostBName: "Noah"
        )

        XCTAssertTrue(prompt.contains("Topic: Space elevators"))
        XCTAssertTrue(prompt.contains("Total episodes: 3"))
        XCTAssertTrue(prompt.contains("Host A name: Ava"))
        XCTAssertTrue(prompt.contains("Host B name: Noah"))
        XCTAssertTrue(prompt.contains("NDJSON"))
    }

    func testISO8601CodingRoundTrip() throws {
        let project = PodcastProject(topic: "Test", episodeCountRequested: 1)
        let data = try EchoForgeJSON.encoder().encode(project)
        let decoded = try EchoForgeJSON.decoder().decode(PodcastProject.self, from: data)
        XCTAssertEqual(project.topic, decoded.topic)
        XCTAssertEqual(project.episodeCountRequested, decoded.episodeCountRequested)
    }
}
