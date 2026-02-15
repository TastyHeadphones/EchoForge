import Foundation
import OSLog
import EchoForgeCore

public struct GoogleGeminiClient: GeminiClient {
    private let configuration: GeminiRuntimeConfiguration
    private let session: URLSession
    private let logger: Logger

    private struct EpisodeRecap: Sendable {
        var number: Int
        var title: String
        var summary: String
    }

    private struct StreamState {
        var hasYieldedProjectHeader: Bool = false
        var recaps: [EpisodeRecap] = []
    }

    private struct BatchContext {
        var allowingProjectHeader: Bool
        var episodeRange: ClosedRange<Int>
    }

    public init(configuration: GeminiRuntimeConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
        self.logger = Logger(subsystem: "EchoForge", category: "GoogleGeminiClient")
    }

    public func streamPodcastEvents(
        request: PodcastGenerationRequest
    ) -> AsyncThrowingStream<PodcastStreamEvent, Error> {
        let configuration = configuration
        let session = session
        let logger = logger

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await Self.stream(
                        request: request,
                        configuration: configuration,
                        session: session,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    logger.error("Gemini stream failed: \(String(describing: error), privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private static func stream(
        request: PodcastGenerationRequest,
        configuration: GeminiRuntimeConfiguration,
        session: URLSession,
        continuation: AsyncThrowingStream<PodcastStreamEvent, Error>.Continuation
    ) async throws {
        let totalEpisodes = max(1, request.episodeCount)
        let batchSize = min(2, totalEpisodes)

        var state = StreamState()

        for range in makeEpisodeRanges(totalEpisodes: totalEpisodes, batchSize: batchSize) {
            try Task.checkCancellation()

            let context = BatchContext(
                allowingProjectHeader: !state.hasYieldedProjectHeader,
                episodeRange: range
            )

            let prompt = PodcastPromptTemplate.makeNDJSONPrompt(
                topic: request.topic,
                episodes: PodcastPromptTemplate.Episodes(total: totalEpisodes, range: range),
                hosts: PodcastPromptTemplate.Hosts(hostAName: request.hostAName, hostBName: request.hostBName),
                options: PodcastPromptTemplate.Options(
                    includeProjectHeader: context.allowingProjectHeader,
                    includeDoneMarker: false,
                    priorEpisodesRecap: makePriorEpisodesRecap(recaps: state.recaps, before: range.lowerBound),
                    projectTitle: request.projectTitle
                )
            )

            let bytes = try await fetchSSEBytes(prompt: prompt, configuration: configuration, session: session)
            try await decode(bytes: bytes) { event in
                handle(event, context: context, state: &state, continuation: continuation)
            }
        }

        continuation.yield(.done)
    }

    private static func fetchSSEBytes(
        prompt: String,
        configuration: GeminiRuntimeConfiguration,
        session: URLSession
    ) async throws -> URLSession.AsyncBytes {
        let urlRequest = try makeURLRequest(prompt: prompt, configuration: configuration)
        let (bytes, response) = try await session.bytes(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw GeminiClientError.invalidHTTPResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = try await readAll(bytes)
            let bodyString = String(data: body, encoding: .utf8)
            throw GeminiClientError.httpError(statusCode: http.statusCode, body: bodyString)
        }

        return bytes
    }

    private static func decode(
        bytes: URLSession.AsyncBytes,
        onEvent: (PodcastStreamEvent) -> Void
    ) async throws {
        var accumulator = SSEDataAccumulator()
        var ndjsonDecoder = PodcastNDJSONStreamDecoder()

        for try await line in bytes.lines {
            try Task.checkCancellation()

            guard let payload = accumulator.ingest(line: line) else {
                continue
            }

            if payload == "[DONE]" {
                break
            }

            try yieldEvents(fromSSEPayload: payload, ndjsonDecoder: &ndjsonDecoder, onEvent: onEvent)
        }

        if let payload = accumulator.flush(), payload != "[DONE]" {
            try yieldEvents(fromSSEPayload: payload, ndjsonDecoder: &ndjsonDecoder, onEvent: onEvent)
        }

        for event in try ndjsonDecoder.finish() {
            onEvent(event)
        }
    }

    private static func yieldEvents(
        fromSSEPayload payload: String,
        ndjsonDecoder: inout PodcastNDJSONStreamDecoder,
        onEvent: (PodcastStreamEvent) -> Void
    ) throws {
        guard let modelText = try extractModelText(fromSSEJSON: payload) else {
            return
        }

        let events = try ndjsonDecoder.append(modelText)
        for event in events {
            onEvent(event)
        }
    }

    private static func makeURLRequest(prompt: String, configuration: GeminiRuntimeConfiguration) throws -> URLRequest {
        let endpoint = try makeStreamGenerateContentURL(configuration: configuration)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let body = GeminiGenerateContentRequest(
            contents: [
                GeminiContentRequest(role: "user", parts: [GeminiPartRequest(text: prompt)])
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.7,
                topP: 0.95,
                maxOutputTokens: 8192
            )
        )

        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private static func makeStreamGenerateContentURL(configuration: GeminiRuntimeConfiguration) throws -> URL {
        var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/\(configuration.apiVersion)/models/\(configuration.model):streamGenerateContent"
        components?.queryItems = [
            URLQueryItem(name: "alt", value: "sse"),
            URLQueryItem(name: "key", value: configuration.apiKey)
        ]

        guard let url = components?.url else {
            throw GeminiClientError.invalidURL
        }

        return url
    }

    private static func readAll(_ bytes: URLSession.AsyncBytes) async throws -> Data {
        try await bytes.reduce(into: Data()) { partialResult, byte in
            partialResult.append(byte)
        }
    }

    private static func extractModelText(fromSSEJSON sseJSON: String) throws -> String? {
        let data = Data(sseJSON.utf8)
        let response = try JSONDecoder().decode(GeminiStreamGenerateContentResponse.self, from: data)

        return response
            .candidates?
            .first?
            .content?
            .parts?
            .compactMap(\.text)
            .joined()
    }

    private static func makeEpisodeRanges(totalEpisodes: Int, batchSize: Int) -> [ClosedRange<Int>] {
        let total = max(1, totalEpisodes)
        let clampedBatchSize = max(1, batchSize)

        var ranges: [ClosedRange<Int>] = []
        var current = 1
        while current <= total {
            let end = min(total, current + clampedBatchSize - 1)
            ranges.append(current...end)
            current = end + 1
        }

        return ranges
    }

    private static func makePriorEpisodesRecap(recaps: [EpisodeRecap], before episodeNumber: Int) -> String? {
        let candidates = recaps
            .filter { $0.number < episodeNumber }
            .sorted(by: { $0.number < $1.number })
            .suffix(6)

        guard !candidates.isEmpty else { return nil }

        let lines = candidates.map { recap in
            "Episode \(recap.number): \(asciiSanitized(recap.title)) - \(asciiSanitized(recap.summary))"
        }
        return lines.joined(separator: "\n")
    }

    private static func handle(
        _ event: PodcastStreamEvent,
        context: BatchContext,
        state: inout StreamState,
        continuation: AsyncThrowingStream<PodcastStreamEvent, Error>.Continuation
    ) {
        switch event {
        case let .project(header):
            guard context.allowingProjectHeader, !state.hasYieldedProjectHeader else { return }
            state.hasYieldedProjectHeader = true
            continuation.yield(.project(header))

        case .done:
            // The app will emit its own done marker after all batches complete.
            return

        case let .episode(header):
            guard context.episodeRange.contains(header.episodeNumber) else { return }
            upsertRecap(
                number: header.episodeNumber,
                title: header.title,
                summary: header.summary,
                recaps: &state.recaps
            )
            continuation.yield(.episode(header))

        case let .line(line):
            guard context.episodeRange.contains(line.episodeNumber) else { return }
            continuation.yield(.line(line))

        case let .episodeEnd(end):
            guard context.episodeRange.contains(end.episodeNumber) else { return }
            continuation.yield(.episodeEnd(end))
        }
    }

    private static func upsertRecap(number: Int, title: String, summary: String, recaps: inout [EpisodeRecap]) {
        let recap = EpisodeRecap(number: number, title: title, summary: summary)
        if let index = recaps.firstIndex(where: { $0.number == number }) {
            recaps[index] = recap
        } else {
            recaps.append(recap)
        }
    }

}

private func asciiSanitized(_ value: String) -> String {
    let scalars = value.unicodeScalars.map { scalar -> Unicode.Scalar in
        if scalar.value < 0x80 {
            return scalar
        }
        return "?"
    }
    return String(String.UnicodeScalarView(scalars))
}

public enum GeminiClientError: LocalizedError, Sendable {
    case invalidURL
    case invalidHTTPResponse
    case httpError(statusCode: Int, body: String?)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Gemini endpoint URL."
        case .invalidHTTPResponse:
            return "Invalid HTTP response from Gemini."
        case let .httpError(statusCode, body):
            if let body, !body.isEmpty {
                return "Gemini request failed (HTTP \(statusCode)): \(body)"
            }
            return "Gemini request failed (HTTP \(statusCode))."
        }
    }
}

private struct SSEDataAccumulator {
    private var dataLines: [String] = []

    mutating func ingest(line: String) -> String? {
        if line.hasPrefix("data:") {
            let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            dataLines.append(payload)
            return nil
        }

        // Blank line indicates end of SSE event.
        if line.isEmpty {
            return flush()
        }

        // Ignore other SSE fields (event:, id:, retry:, comments, etc.).
        return nil
    }

    mutating func flush() -> String? {
        guard !dataLines.isEmpty else {
            return nil
        }

        let payload = dataLines.joined(separator: "\n")
        dataLines.removeAll(keepingCapacity: true)
        return payload
    }
}
