import SwiftUI
import EchoForgePersistence

public struct GeminiSettingsView: View {
    private let configurationStore: any GeminiConfigurationStoring

    @Environment(\.dismiss) private var dismiss

    @State private var isKeyPresent: Bool = false
    @State private var apiKeyDraft: String = ""
    @State private var modelDraft: String = ""

    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    public init(configurationStore: any GeminiConfigurationStoring) {
        self.configurationStore = configurationStore
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
                    TextField("Model", text: $modelDraft)
                        .autocorrectionDisabled()

                    Text("Example: gemini-1.5-flash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
            && modelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

        modelDraft = await configurationStore.readModel()
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let trimmedKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = modelDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if !trimmedKey.isEmpty {
                try await configurationStore.setAPIKey(trimmedKey)
                apiKeyDraft = ""
                isKeyPresent = true
            }

            if !trimmedModel.isEmpty {
                await configurationStore.setModel(trimmedModel)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
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
}
