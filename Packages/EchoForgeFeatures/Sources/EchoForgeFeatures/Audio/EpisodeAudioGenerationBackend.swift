import Foundation
import EchoForgeCore

actor EpisodeAudioGenerationBackend {
    private struct Key: Hashable, Sendable {
        var projectID: UUID
        var episodeID: UUID
    }

    private let service: EpisodeAudioGenerationService
    private var tasks: [Key: Task<Void, Never>] = [:]

    private let updatesContinuation: AsyncStream<PodcastProject>.Continuation
    nonisolated let updates: AsyncStream<PodcastProject>

    init(service: EpisodeAudioGenerationService) {
        let stream = AsyncStream.makeStream(
            of: PodcastProject.self,
            bufferingPolicy: .bufferingNewest(50)
        )
        self.updates = stream.stream
        self.updatesContinuation = stream.continuation
        self.service = service
    }

    func start(projectID: UUID, episodeID: UUID) {
        let key = Key(projectID: projectID, episodeID: episodeID)
        guard tasks[key] == nil else { return }

        tasks[key] = Task { [service, updatesContinuation] in
            do {
                let stream = await service.streamEpisodeAudio(projectID: projectID, episodeID: episodeID)
                for try await updated in stream {
                    updatesContinuation.yield(updated)
                }
            } catch {
                // Service persists failures into the project.
            }

            finish(key: key)
        }
    }

    func cancel(projectID: UUID, episodeID: UUID) {
        let key = Key(projectID: projectID, episodeID: episodeID)
        tasks[key]?.cancel()
        tasks.removeValue(forKey: key)
    }

    func cancelAll(projectID: UUID) {
        let keys = tasks.keys.filter { $0.projectID == projectID }
        for key in keys {
            tasks[key]?.cancel()
            tasks.removeValue(forKey: key)
        }
    }

    private func finish(key: Key) {
        tasks.removeValue(forKey: key)
    }
}
