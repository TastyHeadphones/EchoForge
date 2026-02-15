import Foundation

public struct PodcastGenerationRequest: Sendable, Equatable {
    public var topic: String
    public var episodeCount: Int
    public var hostAName: String
    public var hostBName: String

    public init(topic: String, episodeCount: Int, hostAName: String, hostBName: String) {
        self.topic = topic
        self.episodeCount = episodeCount
        self.hostAName = hostAName
        self.hostBName = hostBName
    }
}
