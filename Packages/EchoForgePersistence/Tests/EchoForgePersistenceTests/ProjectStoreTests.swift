import XCTest
@testable import EchoForgePersistence
import EchoForgeCore

final class ProjectStoreTests: XCTestCase {
    func testSaveAndLoadRoundTrip() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ProjectStore(rootURL: root)

        let project = PodcastProject(topic: "Test Topic", episodeCountRequested: 2)
        try await store.save(project)

        let loaded = try await store.load(id: project.id)
        XCTAssertEqual(loaded.id, project.id)
        XCTAssertEqual(loaded.topic, "Test Topic")
    }

    func testLoadAllReturnsSavedProjects() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ProjectStore(rootURL: root)

        let projectOne = PodcastProject(topic: "One", episodeCountRequested: 1)
        let projectTwo = PodcastProject(topic: "Two", episodeCountRequested: 1)

        try await store.save(projectOne)
        try await store.save(projectTwo)

        let all = try await store.loadAll()
        XCTAssertEqual(Set(all.map(\.id)), Set([projectOne.id, projectTwo.id]))
    }
}
