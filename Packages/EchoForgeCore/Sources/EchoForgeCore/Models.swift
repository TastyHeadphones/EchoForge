import Foundation

public enum Speaker: String, Codable, Sendable, CaseIterable, Identifiable {
    case hostA = "HOST_A"
    case hostB = "HOST_B"

    public var id: String { rawValue }
}

public struct PodcastHost: Identifiable, Codable, Sendable, Equatable {
    public let id: Speaker
    public var displayName: String
    public var roleDescription: String?

    public init(id: Speaker, displayName: String, roleDescription: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.roleDescription = roleDescription
    }
}

public struct DialogueLine: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var speaker: Speaker
    public var text: String

    public init(id: UUID = UUID(), speaker: Speaker, text: String) {
        self.id = id
        self.speaker = speaker
        self.text = text
    }
}

public struct Episode: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var number: Int
    public var title: String?
    public var summary: String?
    public var lines: [DialogueLine]
    public var status: Status
    public var audio: EpisodeAudio?

    public init(
        id: UUID = UUID(),
        number: Int,
        title: String? = nil,
        summary: String? = nil,
        lines: [DialogueLine] = [],
        status: Status = .pending,
        audio: EpisodeAudio? = nil
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.summary = summary
        self.lines = lines
        self.status = status
        self.audio = audio
    }

    public enum Status: String, Codable, Sendable, Equatable {
        case pending
        case generating
        case complete
        case failed
    }
}

public struct EpisodeAudio: Codable, Sendable, Equatable {
    public var status: Status
    public var fileName: String?
    public var generatedAt: Date?
    public var errorMessage: String?

    public init(
        status: Status,
        fileName: String? = nil,
        generatedAt: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.status = status
        self.fileName = fileName
        self.generatedAt = generatedAt
        self.errorMessage = errorMessage
    }

    public enum Status: String, Codable, Sendable, Equatable {
        case none
        case generating
        case ready
        case failed
    }
}

public struct PodcastProject: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var createdAt: Date
    public var lastUpdatedAt: Date
    public var topic: String
    public var episodeCountRequested: Int
    public var title: String?
    public var description: String?
    public var hosts: [PodcastHost]
    public var episodes: [Episode]
    public var status: Status
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        lastUpdatedAt: Date = Date(),
        topic: String,
        episodeCountRequested: Int,
        title: String? = nil,
        description: String? = nil,
        hosts: [PodcastHost] = [
            PodcastHost(id: .hostA, displayName: "Host A"),
            PodcastHost(id: .hostB, displayName: "Host B")
        ],
        episodes: [Episode] = [],
        status: Status = .draft,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.topic = topic
        self.episodeCountRequested = episodeCountRequested
        self.title = title
        self.description = description
        self.hosts = hosts
        self.episodes = episodes
        self.status = status
        self.errorMessage = errorMessage
    }

    public enum Status: String, Codable, Sendable, Equatable {
        case draft
        case generating
        case complete
        case failed
    }
}

public extension Episode {
    var transcriptText: String {
        lines
            .map { "\($0.speaker.rawValue): \($0.text)" }
            .joined(separator: "\n")
    }

    var audioStatus: EpisodeAudio.Status {
        audio?.status ?? .none
    }
}
