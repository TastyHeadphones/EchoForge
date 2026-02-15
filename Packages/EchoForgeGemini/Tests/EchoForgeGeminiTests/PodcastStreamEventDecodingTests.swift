import XCTest
@testable import EchoForgeGemini

final class PodcastStreamEventDecodingTests: XCTestCase {
    func testDecodesProjectEvent() throws {
        let json = """
{
  "type":"project",
  "topic":"AI safety",
  "episode_count":2,
  "title":"AI Safety 101",
  "description":"A beginner series.",
  "hosts":[
    {"id":"HOST_A","name":"Ava","persona":"Curious and upbeat"},
    {"id":"HOST_B","name":"Noah","persona":"Skeptical and precise"}
  ]
}
"""
        let event = try JSONDecoder().decode(PodcastStreamEvent.self, from: Data(json.utf8))

        switch event {
        case let .project(header):
            XCTAssertEqual(header.topic, "AI safety")
            XCTAssertEqual(header.episodeCount, 2)
            XCTAssertEqual(header.hosts.count, 2)
        default:
            XCTFail("Expected .project")
        }
    }

    func testDecodesLineEvent() throws {
        let json = """
{"type":"line","episode_number":1,"speaker":"HOST_A","text":"Welcome back."}
"""
        let event = try JSONDecoder().decode(PodcastStreamEvent.self, from: Data(json.utf8))

        switch event {
        case let .line(line):
            XCTAssertEqual(line.episodeNumber, 1)
            XCTAssertEqual(line.speaker.rawValue, "HOST_A")
            XCTAssertEqual(line.text, "Welcome back.")
        default:
            XCTFail("Expected .line")
        }
    }

    func testNDJSONDecoderHandlesChunkedInput() throws {
        var decoder = PodcastNDJSONStreamDecoder()

        let part1 = "{\"type\":\"done\"}"
        XCTAssertEqual(try decoder.append(part1).count, 0)

        let part2 = "\n"
        let events = try decoder.append(part2)
        XCTAssertEqual(events, [.done])
    }
}
