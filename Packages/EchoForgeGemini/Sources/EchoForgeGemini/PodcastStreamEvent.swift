import Foundation
import EchoForgeCore

public struct PodcastStreamProjectHeader: Sendable, Equatable, Decodable {
    public struct Host: Sendable, Equatable, Decodable {
        public var id: Speaker
        public var name: String
        public var persona: String

        public init(id: Speaker, name: String, persona: String) {
            self.id = id
            self.name = name
            self.persona = persona
        }
    }

    public var topic: String
    public var episodeCount: Int
    public var title: String
    public var description: String
    public var hosts: [Host]

    public init(topic: String, episodeCount: Int, title: String, description: String, hosts: [Host]) {
        self.topic = topic
        self.episodeCount = episodeCount
        self.title = title
        self.description = description
        self.hosts = hosts
    }

    private enum CodingKeys: String, CodingKey {
        case topic
        case episodeCount = "episode_count"
        case title
        case description
        case hosts
    }
}

public struct PodcastStreamEpisodeHeader: Sendable, Equatable, Decodable {
    public var episodeNumber: Int
    public var title: String
    public var summary: String

    public init(episodeNumber: Int, title: String, summary: String) {
        self.episodeNumber = episodeNumber
        self.title = title
        self.summary = summary
    }

    private enum CodingKeys: String, CodingKey {
        case episodeNumber = "episode_number"
        case title
        case summary
    }
}

public struct PodcastStreamDialogueLineEvent: Sendable, Equatable, Decodable {
    public var episodeNumber: Int
    public var speaker: Speaker
    public var text: String

    public init(episodeNumber: Int, speaker: Speaker, text: String) {
        self.episodeNumber = episodeNumber
        self.speaker = speaker
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case episodeNumber = "episode_number"
        case speaker
        case text
    }
}

public struct PodcastStreamEpisodeEnd: Sendable, Equatable, Decodable {
    public var episodeNumber: Int

    public init(episodeNumber: Int) {
        self.episodeNumber = episodeNumber
    }

    private enum CodingKeys: String, CodingKey {
        case episodeNumber = "episode_number"
    }
}

public enum PodcastStreamEvent: Sendable, Equatable, Decodable {
    case project(PodcastStreamProjectHeader)
    case episode(PodcastStreamEpisodeHeader)
    case line(PodcastStreamDialogueLineEvent)
    case episodeEnd(PodcastStreamEpisodeEnd)
    case done

    private enum CodingKeys: String, CodingKey {
        case type
    }

    private enum EventType: String, Decodable {
        case project
        case episode
        case line
        case episodeEnd = "episode_end"
        case done
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EventType.self, forKey: .type)

        switch type {
        case .project:
            self = try .project(PodcastStreamProjectHeader(from: decoder))
        case .episode:
            self = try .episode(PodcastStreamEpisodeHeader(from: decoder))
        case .line:
            self = try .line(PodcastStreamDialogueLineEvent(from: decoder))
        case .episodeEnd:
            self = try .episodeEnd(PodcastStreamEpisodeEnd(from: decoder))
        case .done:
            self = .done
        }
    }
}
