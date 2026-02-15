import Foundation

public struct GeminiRuntimeConfiguration: Sendable, Equatable {
    public var apiKey: String
    public var model: String
    public var apiVersion: String
    public var baseURL: URL

    public init(
        apiKey: String,
        model: String,
        apiVersion: String = "v1beta",
        baseURL: URL = URL(string: "https://generativelanguage.googleapis.com")!
    ) {
        self.apiKey = apiKey
        self.model = model
        self.apiVersion = apiVersion
        self.baseURL = baseURL
    }

    public static func fromEnvironmentAndInfoPlist(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) throws -> GeminiRuntimeConfiguration {
        let apiKey = trimmedValue(for: "GEMINI_API_KEY", environment: environment, bundle: bundle)

        guard let apiKey, !apiKey.isEmpty, apiKey != "your_api_key_here" else {
            throw GeminiRuntimeConfigurationError.missingAPIKey
        }

        let model = trimmedValue(for: "GEMINI_MODEL", environment: environment, bundle: bundle)
            ?? "gemini-1.5-flash"

        return GeminiRuntimeConfiguration(apiKey: apiKey, model: model)
    }

    private static func trimmedValue(
        for key: String,
        environment: [String: String],
        bundle: Bundle
    ) -> String? {
        if let env = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }

        if let plist = bundle.object(forInfoDictionaryKey: key) as? String {
            let trimmed = plist.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return nil
    }
}

public enum GeminiRuntimeConfigurationError: LocalizedError, Sendable {
    case missingAPIKey

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing GEMINI_API_KEY. Set it via an environment variable or Info.plist build setting."
        }
    }
}
