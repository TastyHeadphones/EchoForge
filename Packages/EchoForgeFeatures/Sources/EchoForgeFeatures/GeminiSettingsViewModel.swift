import Foundation
import Combine
import EchoForgeGemini
import EchoForgePersistence

@MainActor
final class GeminiSettingsViewModel: ObservableObject {
    @Published var apiKeyDraft: String = ""
    @Published private(set) var isKeyPresent: Bool = false

    @Published var selectedModel: String = GeminiModelFallback.defaultModelID
    @Published private(set) var availableModels: [GeminiModelDescriptor] = GeminiModelFallback.fallback
    @Published private(set) var isLoadingModels: Bool = false
    @Published private(set) var modelLoadErrorMessage: String?

    @Published private(set) var isSaving: Bool = false
    @Published var errorMessage: String?

    private let configurationStore: any GeminiConfigurationStoring
    private let modelsClient: any GeminiModelsListing

    private var hasLoaded: Bool = false
    private var shouldRefreshModelsAgain: Bool = false

    init(
        configurationStore: any GeminiConfigurationStoring,
        modelsClient: any GeminiModelsListing = GoogleGeminiModelsClient()
    ) {
        self.configurationStore = configurationStore
        self.modelsClient = modelsClient
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await load()
    }

    func saveAPIKey() async {
        isSaving = true
        defer { isSaving = false }

        let trimmedKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if !trimmedKey.isEmpty {
                try await configurationStore.setAPIKey(trimmedKey)
                apiKeyDraft = ""
                isKeyPresent = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        await refreshModels()
    }

    func clearAPIKey() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await configurationStore.clearAPIKey()
            isKeyPresent = false
            apiKeyDraft = ""
        } catch {
            errorMessage = error.localizedDescription
        }

        await refreshModels()
    }

    func refreshModels() async {
        if isLoadingModels {
            shouldRefreshModelsAgain = true
            return
        }

        isLoadingModels = true
        defer { isLoadingModels = false }

        repeat {
            shouldRefreshModelsAgain = false
            modelLoadErrorMessage = nil

            do {
                let apiKey = try await configurationStore.readAPIKey()
                guard let apiKey, !apiKey.isEmpty else {
                    availableModels = GeminiModelFallback.fallbackEnsuringSelected(
                        modelID: selectedModel,
                        models: GeminiModelFallback.fallback
                    )
                    modelLoadErrorMessage = "Save an API key to fetch the full model list."
                    continue
                }

                let remote = try await modelsClient.listTextGenerationModels(
                    apiKey: apiKey,
                    apiVersion: "v1beta",
                    baseURL: GeminiModelFallback.baseURL
                )
                availableModels = GeminiModelFallback.merge(
                    remoteModels: remote,
                    fallbackModels: GeminiModelFallback.fallback,
                    selectedModelID: selectedModel
                )
            } catch {
                availableModels = GeminiModelFallback.fallbackEnsuringSelected(
                    modelID: selectedModel,
                    models: GeminiModelFallback.fallback
                )
                modelLoadErrorMessage = error.localizedDescription
            }
        } while shouldRefreshModelsAgain
    }

    func userSelectedModel(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        selectedModel = trimmed

        if !availableModels.contains(where: { $0.id == trimmed }) {
            availableModels = GeminiModelFallback.fallbackEnsuringSelected(
                modelID: trimmed,
                models: availableModels
            )
        }

        Task { [configurationStore] in
            await configurationStore.setModel(trimmed)
        }
    }

    private func load() async {
        do {
            let apiKey = try await configurationStore.readAPIKey()
            isKeyPresent = apiKey?.isEmpty == false
        } catch {
            errorMessage = error.localizedDescription
            isKeyPresent = false
        }

        let storedModel = await configurationStore.readModel()
        selectedModel = storedModel
        availableModels = GeminiModelFallback.fallbackEnsuringSelected(
            modelID: storedModel,
            models: availableModels
        )

        // Best-effort: populate a reasonably current list of models.
        await refreshModels()
    }
}

private enum GeminiModelFallback {
    static let baseURL: URL = URL(string: "https://generativelanguage.googleapis.com")!
    static let defaultModelID: String = "gemini-2.5-flash"

    // Curated from Google Gemini API docs. This list is only a fallback; refresh pulls the authoritative list.
    static let fallback: [GeminiModelDescriptor] = [
        GeminiModelDescriptor(id: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash"),
        GeminiModelDescriptor(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro"),
        GeminiModelDescriptor(id: "gemini-2.5-flash-lite", displayName: "Gemini 2.5 Flash-Lite"),
        GeminiModelDescriptor(id: "gemini-2.0-flash", displayName: "Gemini 2.0 Flash"),
        GeminiModelDescriptor(id: "gemini-2.0-flash-lite", displayName: "Gemini 2.0 Flash-Lite"),
        GeminiModelDescriptor(id: "gemini-3-flash-preview", displayName: "Gemini 3 Flash (Preview)"),
        GeminiModelDescriptor(id: "gemini-3-pro-preview", displayName: "Gemini 3 Pro (Preview)")
    ]

    static func merge(
        remoteModels: [GeminiModelDescriptor],
        fallbackModels: [GeminiModelDescriptor],
        selectedModelID: String
    ) -> [GeminiModelDescriptor] {
        // Prefer remote data; keep fallback entries if remote doesn't include them.
        var byID: [String: GeminiModelDescriptor] = Dictionary(uniqueKeysWithValues: remoteModels.map { ($0.id, $0) })
        for model in fallbackModels where byID[model.id] == nil {
            byID[model.id] = model
        }

        if !selectedModelID.isEmpty, byID[selectedModelID] == nil {
            byID[selectedModelID] = GeminiModelDescriptor(id: selectedModelID)
        }

        return byID.values.sorted(by: { $0.id < $1.id })
    }

    static func fallbackEnsuringSelected(modelID: String, models: [GeminiModelDescriptor]) -> [GeminiModelDescriptor] {
        guard !modelID.isEmpty else { return models }
        guard !models.contains(where: { $0.id == modelID }) else { return models }
        return (models + [GeminiModelDescriptor(id: modelID)]).sorted(by: { $0.id < $1.id })
    }
}
