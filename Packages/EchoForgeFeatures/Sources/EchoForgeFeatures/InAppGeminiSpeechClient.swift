import Foundation
import EchoForgeGemini
import EchoForgePersistence

struct InAppGeminiSpeechClient: GeminiSpeechGenerating {
    let configurationStore: any GeminiConfigurationStoring
    let session: URLSession

    init(configurationStore: any GeminiConfigurationStoring, session: URLSession = .shared) {
        self.configurationStore = configurationStore
        self.session = session
    }

    func generateSpeech(request: GeminiSpeechRequest) async throws -> GeminiSpeechResult {
        let apiKey = try await configurationStore.readAPIKey()
        guard let apiKey, !apiKey.isEmpty else {
            throw InAppGeminiSpeechClientError.missingAPIKey
        }

        let model = await configurationStore.readSpeechModel()
        let configuration = GeminiRuntimeConfiguration(apiKey: apiKey, model: model)

        let client = GoogleGeminiSpeechClient(configuration: configuration, session: session)
        return try await client.generateSpeech(request: request)
    }
}

enum InAppGeminiSpeechClientError: LocalizedError, Sendable {
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is not configured. Open Settings to add it."
        }
    }
}
