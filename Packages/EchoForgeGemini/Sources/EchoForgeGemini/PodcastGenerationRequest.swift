import Foundation

public struct PodcastGenerationRequest: Sendable, Equatable {
    public var projectTitle: String?
    public var topic: String
    public var episodeCount: Int
    public var hostAName: String
    public var hostBName: String

    public init(
        projectTitle: String? = nil,
        topic: String,
        episodeCount: Int,
        hostAName: String,
        hostBName: String
    ) {
        self.projectTitle = projectTitle
        self.topic = topic
        self.episodeCount = episodeCount
        self.hostAName = hostAName
        self.hostBName = hostBName
    }
}
