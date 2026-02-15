import Foundation
import EchoForgeCore

public protocol ProjectStoring: Sendable {
    func loadAll() async throws -> [PodcastProject]
    func load(id: UUID) async throws -> PodcastProject
    func save(_ project: PodcastProject) async throws
    func delete(id: UUID) async throws
}
