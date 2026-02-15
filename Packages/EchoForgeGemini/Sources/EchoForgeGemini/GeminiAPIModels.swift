import Foundation

struct GeminiGenerateContentRequest: Encodable {
    var contents: [GeminiContentRequest]
    var generationConfig: GeminiGenerationConfig?
}

struct GeminiContentRequest: Encodable {
    var role: String?
    var parts: [GeminiPartRequest]
}

struct GeminiPartRequest: Encodable {
    var text: String
}

struct GeminiGenerationConfig: Encodable {
    var temperature: Double?
    var topP: Double?
    var maxOutputTokens: Int?
    var responseModalities: [String]?
    var speechConfig: GeminiSpeechConfig?
}

struct GeminiSpeechConfig: Encodable {
    var voiceConfig: GeminiVoiceConfig?
    var multiSpeakerVoiceConfig: GeminiMultiSpeakerVoiceConfig?
}

struct GeminiVoiceConfig: Encodable {
    var prebuiltVoiceConfig: GeminiPrebuiltVoiceConfig
}

struct GeminiPrebuiltVoiceConfig: Encodable {
    var voiceName: String
}

struct GeminiMultiSpeakerVoiceConfig: Encodable {
    var speakerVoiceConfigs: [GeminiSpeakerVoiceConfig]
}

struct GeminiSpeakerVoiceConfig: Encodable {
    var speaker: String
    var voiceConfig: GeminiVoiceConfig
}

struct GeminiStreamGenerateContentResponse: Decodable {
    var candidates: [GeminiCandidateResponse]?
}

struct GeminiCandidateResponse: Decodable {
    var content: GeminiContentResponse?
}

struct GeminiContentResponse: Decodable {
    var parts: [GeminiPartResponse]?
}

struct GeminiInlineDataResponse: Decodable {
    var mimeType: String?
    var data: String?
}

struct GeminiPartResponse: Decodable {
    var text: String?
    var inlineData: GeminiInlineDataResponse?
}
