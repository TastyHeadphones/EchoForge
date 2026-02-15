import Foundation
import EchoForgeCore
import EchoForgeGemini

enum PodcastProjectUpdater {
    static func apply(_ event: PodcastStreamEvent, to project: inout PodcastProject) {
        project.lastUpdatedAt = Date()

        switch event {
        case let .project(header):
            project.status = .generating
            if project.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                project.title = header.title
            }
            project.description = header.description
            project.hosts = header.hosts.map {
                PodcastHost(id: $0.id, displayName: $0.name, roleDescription: $0.persona)
            }

        case let .episode(header):
            let index = upsertEpisode(number: header.episodeNumber, in: &project)
            project.episodes[index].title = header.title
            project.episodes[index].summary = header.summary
            project.episodes[index].status = .generating

        case let .line(line):
            let index = upsertEpisode(number: line.episodeNumber, in: &project)
            project.episodes[index].status = .generating
            project.episodes[index].lines.append(
                DialogueLine(speaker: line.speaker, text: line.text)
            )

        case let .episodeEnd(end):
            let index = upsertEpisode(number: end.episodeNumber, in: &project)
            project.episodes[index].status = .complete

        case .done:
            project.status = .complete
            project.episodes = project.episodes.map { episode in
                var updated = episode
                if updated.status == .generating {
                    updated.status = .complete
                }
                return updated
            }
        }
    }

    private static func upsertEpisode(number: Int, in project: inout PodcastProject) -> Int {
        if let existingIndex = project.episodes.firstIndex(where: { $0.number == number }) {
            return existingIndex
        }

        let episode = Episode(number: number, status: .generating)
        project.episodes.append(episode)
        project.episodes.sort { $0.number < $1.number }

        return project.episodes.firstIndex(where: { $0.number == number }) ?? 0
    }
}
