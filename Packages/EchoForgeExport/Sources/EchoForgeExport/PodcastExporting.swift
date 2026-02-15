import Foundation
import EchoForgeCore

public protocol PodcastExporting: Sendable {
    func export(project: PodcastProject) async throws -> URL
}
