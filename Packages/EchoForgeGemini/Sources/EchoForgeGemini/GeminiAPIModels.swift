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

struct GeminiPartResponse: Decodable {
    var text: String?
}
