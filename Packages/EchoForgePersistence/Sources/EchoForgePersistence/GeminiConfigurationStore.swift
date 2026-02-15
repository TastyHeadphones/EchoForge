import Foundation

public protocol GeminiConfigurationStoring: Sendable {
    func readAPIKey() async throws -> String?
    func setAPIKey(_ key: String) async throws
    func clearAPIKey() async throws

    func readTextModel() async -> String
    func setTextModel(_ model: String) async

    func readSpeechModel() async -> String
    func setSpeechModel(_ model: String) async
}

public actor GeminiConfigurationStore: GeminiConfigurationStoring {
    private let defaults: UserDefaults
    private let apiKeyDefaultsKey: String
    private let textModelDefaultsKey: String
    private let speechModelDefaultsKey: String
    private let legacyModelDefaultsKey: String = "EchoForge.gemini.model"

    public init(
        defaults: UserDefaults = .standard,
        apiKeyDefaultsKey: String = "EchoForge.gemini.apiKey",
        textModelDefaultsKey: String = "EchoForge.gemini.textModel",
        speechModelDefaultsKey: String = "EchoForge.gemini.speechModel"
    ) {
        self.defaults = defaults
        self.apiKeyDefaultsKey = apiKeyDefaultsKey
        self.textModelDefaultsKey = textModelDefaultsKey
        self.speechModelDefaultsKey = speechModelDefaultsKey
    }

    public func readAPIKey() async throws -> String? {
        let stored = defaults.string(forKey: apiKeyDefaultsKey)
        let trimmed = stored?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    public func setAPIKey(_ key: String) async throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        defaults.set(trimmed, forKey: apiKeyDefaultsKey)
    }

    public func clearAPIKey() async throws {
        defaults.removeObject(forKey: apiKeyDefaultsKey)
    }

    public func readTextModel() async -> String {
        let stored = defaults.string(forKey: textModelDefaultsKey)
            ?? defaults.string(forKey: legacyModelDefaultsKey)
        let trimmed = stored?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed! : defaultTextModel
    }

    public func setTextModel(_ model: String) async {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: textModelDefaultsKey)
        } else {
            defaults.set(trimmed, forKey: textModelDefaultsKey)
        }
    }

    public func readSpeechModel() async -> String {
        let stored = defaults.string(forKey: speechModelDefaultsKey)
        let trimmed = stored?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed! : defaultSpeechModel
    }

    public func setSpeechModel(_ model: String) async {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: speechModelDefaultsKey)
        } else {
            defaults.set(trimmed, forKey: speechModelDefaultsKey)
        }
    }

    private var defaultTextModel: String {
        "gemini-2.5-flash"
    }

    private var defaultSpeechModel: String {
        "gemini-2.5-flash-preview-tts"
    }
}
