import Foundation

public protocol GeminiClient: Sendable {
    func streamPodcastEvents(request: PodcastGenerationRequest) -> AsyncThrowingStream<PodcastStreamEvent, Error>
}
