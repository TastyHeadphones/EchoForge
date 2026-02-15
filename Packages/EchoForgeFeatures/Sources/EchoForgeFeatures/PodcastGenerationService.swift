import Foundation
import EchoForgeCore
import EchoForgeGemini
import EchoForgePersistence

public actor PodcastGenerationService {
    private let geminiClient: any GeminiClient
    private let projectStore: any ProjectStoring
    private let autosaver: ProjectAutosaver

    public init(geminiClient: any GeminiClient, projectStore: any ProjectStoring) {
        self.geminiClient = geminiClient
        self.projectStore = projectStore
        self.autosaver = ProjectAutosaver(store: projectStore)
    }

    public func streamProject(
        initialProject: PodcastProject,
        request: PodcastGenerationRequest
    ) -> AsyncThrowingStream<PodcastProject, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var working = initialProject

                do {
                    try await projectStore.save(working)
                    continuation.yield(working)

                    for try await event in geminiClient.streamPodcastEvents(request: request) {
                        PodcastProjectUpdater.apply(event, to: &working)
                        await autosaver.scheduleSave(working)
                        continuation.yield(working)

                        if working.status == .complete {
                            break
                        }
                    }

                    await autosaver.flush()
                    try await projectStore.save(working)
                    continuation.finish()
                } catch is CancellationError {
                    await autosaver.flush()
                    continuation.finish(throwing: CancellationError())
                } catch {
                    working.status = .failed
                    working.errorMessage = error.localizedDescription

                    await autosaver.flush()
                    try? await projectStore.save(working)

                    continuation.yield(working)
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
