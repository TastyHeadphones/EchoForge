import Foundation
import OSLog

public struct GeminiSpeechSpeaker: Sendable, Hashable {
    public var name: String
    public var voiceName: String

    public init(name: String, voiceName: String) {
        self.name = name
        self.voiceName = voiceName
    }
}

public struct GeminiSpeechRequest: Sendable, Hashable {
    public var script: String
    public var speakers: [GeminiSpeechSpeaker]

    public init(script: String, speakers: [GeminiSpeechSpeaker]) {
        self.script = script
        self.speakers = speakers
    }
}

public struct GeminiSpeechResult: Sendable, Hashable {
    public var pcmData: Data
    public var mimeType: String?
    public var sampleRateHz: Int
    public var channels: Int
    public var bitsPerSample: Int

    public init(
        pcmData: Data,
        mimeType: String? = nil,
        sampleRateHz: Int = 24_000,
        channels: Int = 1,
        bitsPerSample: Int = 16
    ) {
        self.pcmData = pcmData
        self.mimeType = mimeType
        self.sampleRateHz = sampleRateHz
        self.channels = channels
        self.bitsPerSample = bitsPerSample
    }
}

public protocol GeminiSpeechGenerating: Sendable {
    func generateSpeech(request: GeminiSpeechRequest) async throws -> GeminiSpeechResult
}

public struct GoogleGeminiSpeechClient: GeminiSpeechGenerating {
    private let configuration: GeminiRuntimeConfiguration
    private let session: URLSession
    private let logger: Logger

    public init(configuration: GeminiRuntimeConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
        self.logger = Logger(subsystem: "EchoForge", category: "GoogleGeminiSpeechClient")
    }

    public func generateSpeech(request: GeminiSpeechRequest) async throws -> GeminiSpeechResult {
        let urlRequest = try makeURLRequest(request: request, configuration: configuration)
        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw GeminiSpeechClientError.invalidHTTPResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8)
            GeminiWireLogger.logHTTPError(statusCode: http.statusCode, body: bodyString)
            throw GeminiSpeechClientError.httpError(statusCode: http.statusCode, body: bodyString)
        }

        let decoded = try JSONDecoder().decode(GeminiStreamGenerateContentResponse.self, from: data)
        guard
            let part = decoded.candidates?.first?.content?.parts?.first,
            let inline = part.inlineData,
            let encoded = inline.data,
            let pcm = Data(base64Encoded: encoded)
        else {
            logger.error("Gemini speech response missing inlineData payload.")
            throw GeminiSpeechClientError.missingAudioPayload
        }

        return GeminiSpeechResult(
            pcmData: pcm,
            mimeType: inline.mimeType,
            sampleRateHz: 24_000,
            channels: 1,
            bitsPerSample: 16
        )
    }
}

private func makeURLRequest(
    request: GeminiSpeechRequest,
    configuration: GeminiRuntimeConfiguration
) throws -> URLRequest {
    var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false)
    components?.path = "/\(configuration.apiVersion)/models/\(configuration.model):generateContent"

    guard let url = components?.url else {
        throw GeminiSpeechClientError.invalidURL
    }

    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue(configuration.apiKey, forHTTPHeaderField: "x-goog-api-key")

    let speakerConfigs = request.speakers.map { speaker in
        GeminiSpeakerVoiceConfig(
            speaker: speaker.name,
            voiceConfig: GeminiVoiceConfig(
                prebuiltVoiceConfig: GeminiPrebuiltVoiceConfig(voiceName: speaker.voiceName)
            )
        )
    }

    let body = GeminiGenerateContentRequest(
        contents: [
            GeminiContentRequest(role: "user", parts: [GeminiPartRequest(text: request.script)])
        ],
        generationConfig: GeminiGenerationConfig(
            temperature: 0.3,
            topP: 0.95,
            maxOutputTokens: 8_192,
            responseModalities: ["AUDIO"],
            speechConfig: GeminiSpeechConfig(
                voiceConfig: nil,
                multiSpeakerVoiceConfig: GeminiMultiSpeakerVoiceConfig(speakerVoiceConfigs: speakerConfigs)
            )
        )
    )

    urlRequest.httpBody = try JSONEncoder().encode(body)
    return urlRequest
}

public enum GeminiSpeechClientError: LocalizedError, Sendable, Equatable {
    case invalidURL
    case invalidHTTPResponse
    case httpError(statusCode: Int, body: String?)
    case missingAudioPayload

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Gemini speech endpoint URL."
        case .invalidHTTPResponse:
            return "Invalid HTTP response from Gemini."
        case let .httpError(statusCode, body):
            if let body, !body.isEmpty {
                return "Gemini speech request failed (HTTP \(statusCode)): \(body)"
            }
            return "Gemini speech request failed (HTTP \(statusCode))."
        case .missingAudioPayload:
            return "Gemini speech response did not contain an audio payload."
        }
    }
}
