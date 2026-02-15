import SwiftUI
import EchoForgeGemini
import EchoForgePersistence

public struct GeminiSettingsView: View {
    private let configurationStore: any GeminiConfigurationStoring
    private let modelsClient: any GeminiModelsListing

    @Environment(\.dismiss) private var dismiss

    @State private var isKeyPresent: Bool = false
    @State private var apiKeyDraft: String = ""
    @State private var selectedModel: String = ""
    @State private var availableModels: [GeminiModelDescriptor] = GeminiModelFallback.fallback
    @State private var isLoadingModels: Bool = false
    @State private var modelLoadErrorMessage: String?

    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    public init(
        configurationStore: any GeminiConfigurationStoring,
        modelsClient: any GeminiModelsListing = GoogleGeminiModelsClient()
    ) {
        self.configurationStore = configurationStore
        self.modelsClient = modelsClient
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Gemini API Key", text: $apiKeyDraft)
                        .textContentType(.password)

                    Text(keyStatusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Clear Key", role: .destructive) {
                            Task { await clearKey() }
                        }
                        .disabled(!isKeyPresent || isSaving)

                        Spacer()

                        Button("Save") {
                            Task { await save() }
                        }
                        .disabled(isSaving || isSaveDisabled)
                    }
                } header: {
                    Text("Gemini")
                } footer: {
                    Text("The API key is stored in your Keychain and never written to source control.")
                }

                Section {
                    HStack {
                        Text("Selected")
                        Spacer()
                        Text(selectedModel)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .multilineTextAlignment(.trailing)
                    }

                    NavigationLink("Choose Model") {
                        GeminiModelPickerView(
                            selectedModel: $selectedModel,
                            models: $availableModels,
                            isRefreshing: $isLoadingModels
                        ) {
                            await refreshModels()
                        }
                    }
                    .disabled(isLoadingModels)

                    if let message = modelLoadErrorMessage, !message.isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Models list can be refreshed after you save an API key.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    Text("Model")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await load()
            }
            .onChange(of: selectedModel) { _, newValue in
                Task { await configurationStore.setModel(newValue) }
            }
            .alert("Error", isPresented: isPresentingError) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var keyStatusText: String {
        if isKeyPresent {
            return "API key is saved. Enter a new value and Save to replace it."
        }
        return "No API key saved yet."
    }

    private var isSaveDisabled: Bool {
        apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isPresentingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { presenting in
                if !presenting {
                    errorMessage = nil
                }
            }
        )
    }

    private func load() async {
        do {
            let apiKey = try await configurationStore.readAPIKey()
            isKeyPresent = apiKey?.isEmpty == false
        } catch {
            errorMessage = error.localizedDescription
            isKeyPresent = false
        }

        selectedModel = await configurationStore.readModel()

        // Best-effort: populate a reasonably current list of models.
        await refreshModels()
    }

    private func save() async {
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

    private func clearKey() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await configurationStore.clearAPIKey()
            isKeyPresent = false
            apiKeyDraft = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshModels() async {
        if isLoadingModels {
            return
        }

        isLoadingModels = true
        defer { isLoadingModels = false }

        modelLoadErrorMessage = nil

        do {
            let apiKey = try await configurationStore.readAPIKey()
            guard let apiKey, !apiKey.isEmpty else {
                availableModels = GeminiModelFallback.fallbackEnsuringSelected(
                    modelID: selectedModel,
                    models: GeminiModelFallback.fallback
                )
                modelLoadErrorMessage = "Save an API key to fetch the full model list."
                return
            }

            let remote = try await modelsClient.listTextGenerationModels(
                apiKey: apiKey,
                apiVersion: "v1beta",
                baseURL: GeminiModelFallback.baseURL
            )
            let merged = GeminiModelFallback.merge(
                remoteModels: remote,
                fallbackModels: GeminiModelFallback.fallback,
                selectedModelID: selectedModel
            )
            availableModels = merged
        } catch {
            availableModels = GeminiModelFallback.fallbackEnsuringSelected(
                modelID: selectedModel,
                models: GeminiModelFallback.fallback
            )
            modelLoadErrorMessage = error.localizedDescription
        }
    }
}

private enum GeminiModelFallback {
    static let baseURL: URL = URL(string: "https://generativelanguage.googleapis.com")!

    // Curated from Google Gemini API docs. This list is only a fallback; refresh pulls the authoritative list.
    static let fallback: [GeminiModelDescriptor] = [
        GeminiModelDescriptor(id: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash"),
        GeminiModelDescriptor(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro"),
        GeminiModelDescriptor(id: "gemini-2.5-flash-lite", displayName: "Gemini 2.5 Flash-Lite"),
        GeminiModelDescriptor(id: "gemini-3-flash-preview", displayName: "Gemini 3 Flash (Preview)"),
        GeminiModelDescriptor(id: "gemini-3-pro-preview", displayName: "Gemini 3 Pro (Preview)"),
        GeminiModelDescriptor(id: "gemini-1.5-flash", displayName: "Gemini 1.5 Flash"),
        GeminiModelDescriptor(id: "gemini-1.5-pro", displayName: "Gemini 1.5 Pro")
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
