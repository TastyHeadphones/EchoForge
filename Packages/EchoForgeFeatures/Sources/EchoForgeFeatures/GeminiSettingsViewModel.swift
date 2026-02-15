import Foundation
import EchoForgeGemini
import EchoForgePersistence

@MainActor
final class GeminiSettingsViewModel: ObservableObject {
    @Published var apiKeyDraft: String = ""
    @Published private(set) var isKeyPresent: Bool = false

    @Published var selectedTextModel: String = GeminiModelFallback.defaultTextModelID
    @Published var selectedSpeechModel: String = GeminiModelFallback.defaultSpeechModelID

    @Published private(set) var availableTextModels: [GeminiModelDescriptor] = GeminiModelFallback.textFallback
    @Published private(set) var availableSpeechModels: [GeminiModelDescriptor] = GeminiModelFallback.speechFallback

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
                    applyFallbackModels(reason: "Save an API key to fetch the full model list.")
                    continue
                }

                let remote = try await modelsClient.listModels(
                    apiKey: apiKey,
                    apiVersion: "v1beta",
                    baseURL: GeminiModelFallback.baseURL
                )

                let textModels = remote.filter { $0.supportedGenerationMethods.contains("streamGenerateContent") }
                let speechModels = remote.filter { model in
                    model.supportedGenerationMethods.contains("generateContent")
                        && model.id.localizedCaseInsensitiveContains("tts")
                }

                availableTextModels = GeminiModelFallback.merge(
                    remoteModels: textModels,
                    fallbackModels: GeminiModelFallback.textFallback,
                    selectedModelID: selectedTextModel
                )

                availableSpeechModels = GeminiModelFallback.merge(
                    remoteModels: speechModels,
                    fallbackModels: GeminiModelFallback.speechFallback,
                    selectedModelID: selectedSpeechModel
                )
            } catch {
                applyFallbackModels(reason: error.localizedDescription)
            }
        } while shouldRefreshModelsAgain
    }

    func userSelectedTextModel(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        selectedTextModel = trimmed
        availableTextModels = GeminiModelFallback.fallbackEnsuringSelected(
            modelID: trimmed,
            models: availableTextModels
        )

        Task { [configurationStore] in
            await configurationStore.setTextModel(trimmed)
        }
    }

    func userSelectedSpeechModel(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        selectedSpeechModel = trimmed
        availableSpeechModels = GeminiModelFallback.fallbackEnsuringSelected(
            modelID: trimmed,
            models: availableSpeechModels
        )

        Task { [configurationStore] in
            await configurationStore.setSpeechModel(trimmed)
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

        let storedTextModel = await configurationStore.readTextModel()
        selectedTextModel = storedTextModel
        availableTextModels = GeminiModelFallback.fallbackEnsuringSelected(
            modelID: storedTextModel,
            models: availableTextModels
        )

        let storedSpeechModel = await configurationStore.readSpeechModel()
        selectedSpeechModel = storedSpeechModel
        availableSpeechModels = GeminiModelFallback.fallbackEnsuringSelected(
            modelID: storedSpeechModel,
            models: availableSpeechModels
        )

        // Best-effort: populate a reasonably current list of models.
        await refreshModels()
    }

    private func applyFallbackModels(reason: String) {
        availableTextModels = GeminiModelFallback.merge(
            remoteModels: [],
            fallbackModels: GeminiModelFallback.textFallback,
            selectedModelID: selectedTextModel
        )
        availableSpeechModels = GeminiModelFallback.merge(
            remoteModels: [],
            fallbackModels: GeminiModelFallback.speechFallback,
            selectedModelID: selectedSpeechModel
        )
        modelLoadErrorMessage = reason
    }
}

private enum GeminiModelFallback {
    static let baseURL: URL = URL(string: "https://generativelanguage.googleapis.com")!

    static let defaultTextModelID: String = "gemini-2.5-flash"
    static let defaultSpeechModelID: String = "gemini-2.5-flash-preview-tts"

    // Curated from Google Gemini API docs. This list is only a fallback; refresh pulls the authoritative list.
    static let textFallback: [GeminiModelDescriptor] = [
        GeminiModelDescriptor(id: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash"),
        GeminiModelDescriptor(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro"),
        GeminiModelDescriptor(id: "gemini-2.5-flash-lite", displayName: "Gemini 2.5 Flash-Lite"),
        GeminiModelDescriptor(id: "gemini-2.0-flash", displayName: "Gemini 2.0 Flash"),
        GeminiModelDescriptor(id: "gemini-2.0-flash-lite", displayName: "Gemini 2.0 Flash-Lite")
    ]

    static let speechFallback: [GeminiModelDescriptor] = [
        GeminiModelDescriptor(id: "gemini-2.5-flash-preview-tts", displayName: "Gemini 2.5 Flash (Preview TTS)")
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
