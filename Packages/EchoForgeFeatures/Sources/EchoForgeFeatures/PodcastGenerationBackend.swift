import Foundation
import EchoForgeCore
import EchoForgeGemini

actor PodcastGenerationBackend {
    private let generationService: PodcastGenerationService

    private var tasks: [UUID: Task<Void, Never>] = [:]

    private let updatesContinuation: AsyncStream<PodcastProject>.Continuation
    nonisolated let updates: AsyncStream<PodcastProject>

    init(generationService: PodcastGenerationService) {
        var continuation: AsyncStream<PodcastProject>.Continuation!
        self.updates = AsyncStream { streamContinuation in
            continuation = streamContinuation
        }
        self.updatesContinuation = continuation
        self.generationService = generationService
    }

    func startGeneration(initialProject: PodcastProject, request: PodcastGenerationRequest) {
        guard tasks[initialProject.id] == nil else { return }

        tasks[initialProject.id] = Task { [generationService, updatesContinuation] in
            do {
                let stream = await generationService.streamProject(initialProject: initialProject, request: request)
                for try await updated in stream {
                    updatesContinuation.yield(updated)
                }
            } catch {
                // GenerationService already persists failures into the project.
            }

            finish(projectID: initialProject.id)
        }
    }

    func cancel(projectID: UUID) {
        tasks[projectID]?.cancel()
        tasks.removeValue(forKey: projectID)
    }

    private func finish(projectID: UUID) {
        tasks.removeValue(forKey: projectID)
    }
}
