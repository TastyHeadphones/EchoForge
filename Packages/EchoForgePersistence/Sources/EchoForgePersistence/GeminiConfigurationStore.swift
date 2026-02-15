import Foundation

public protocol GeminiConfigurationStoring: Sendable {
    func readAPIKey() async throws -> String?
    func setAPIKey(_ key: String) async throws
    func clearAPIKey() async throws

    func readModel() async -> String
    func setModel(_ model: String) async
}

public actor GeminiConfigurationStore: GeminiConfigurationStoring {
    private let keychain: KeychainGenericPasswordStore
    private let keychainItem: KeychainGenericPasswordItem
    private let defaults: UserDefaults
    private let modelDefaultsKey: String

    public init(
        keychain: KeychainGenericPasswordStore = .init(),
        defaults: UserDefaults = .standard,
        service: String? = Bundle.main.bundleIdentifier,
        keychainAccount: String = "gemini_api_key",
        modelDefaultsKey: String = "EchoForge.gemini.model"
    ) {
        let resolvedService = (service?.isEmpty == false) ? service! : "EchoForge"

        self.keychain = keychain
        self.defaults = defaults
        self.keychainItem = KeychainGenericPasswordItem(service: resolvedService, account: keychainAccount)
        self.modelDefaultsKey = modelDefaultsKey
    }

    public func readAPIKey() async throws -> String? {
        guard let data = try keychain.read(item: keychainItem) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func setAPIKey(_ key: String) async throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let data = Data(trimmed.utf8)
        try keychain.upsert(data, item: keychainItem)
    }

    public func clearAPIKey() async throws {
        try keychain.delete(item: keychainItem)
    }

    public func readModel() async -> String {
        let stored = defaults.string(forKey: modelDefaultsKey)
        let trimmed = stored?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed! : defaultModel
    }

    public func setModel(_ model: String) async {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: modelDefaultsKey)
        } else {
            defaults.set(trimmed, forKey: modelDefaultsKey)
        }
    }

    private var defaultModel: String {
        "gemini-2.5-flash"
    }
}
