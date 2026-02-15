import Foundation
import EchoForgeGemini
import EchoForgePersistence

struct InAppGeminiClient: GeminiClient {
    let configurationStore: any GeminiConfigurationStoring
    let session: URLSession

    init(configurationStore: any GeminiConfigurationStoring, session: URLSession = .shared) {
        self.configurationStore = configurationStore
        self.session = session
    }

    func streamPodcastEvents(request: PodcastGenerationRequest) -> AsyncThrowingStream<PodcastStreamEvent, Error> {
        let configurationStore = configurationStore
        let session = session

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let apiKey = try await configurationStore.readAPIKey()
                    guard let apiKey, !apiKey.isEmpty else {
                        throw InAppGeminiClientError.missingAPIKey
                    }

                    let model = await configurationStore.readModel()
                    let configuration = GeminiRuntimeConfiguration(apiKey: apiKey, model: model)

                    let client = GoogleGeminiClient(configuration: configuration, session: session)
                    for try await event in client.streamPodcastEvents(request: request) {
                        continuation.yield(event)
                    }

                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

enum InAppGeminiClientError: LocalizedError, Sendable {
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is not configured. Open Settings to add it."
        }
    }
}
