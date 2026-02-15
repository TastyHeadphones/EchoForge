import SwiftUI
import EchoForgeGemini
import EchoForgePersistence

@MainActor
public struct GeminiSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingTextModelPicker: Bool = false
    @State private var isShowingSpeechModelPicker: Bool = false

    @StateObject private var viewModel: GeminiSettingsViewModel

    public init(
        configurationStore: any GeminiConfigurationStoring,
        modelsClient: any GeminiModelsListing = GoogleGeminiModelsClient()
    ) {
        _viewModel = StateObject(
            wrappedValue: GeminiSettingsViewModel(
                configurationStore: configurationStore,
                modelsClient: modelsClient
            )
        )
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Settings")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .task { await viewModel.loadIfNeeded() }
                .alert("Error", isPresented: isPresentingError) {
                    Button("OK", role: .cancel) {
                        viewModel.errorMessage = nil
                    }
                } message: {
                    Text(viewModel.errorMessage ?? "")
                }
        }
        .sheet(isPresented: $isShowingTextModelPicker) {
            GeminiModelBrowserSheet(selectedModel: selectedTextModelBinding, models: viewModel.availableTextModels)
        }
        .sheet(isPresented: $isShowingSpeechModelPicker) {
            GeminiModelBrowserSheet(selectedModel: selectedSpeechModelBinding, models: viewModel.availableSpeechModels)
        }
#if os(macOS)
        .frame(minWidth: 720, minHeight: 620)
#endif
    }

    @ViewBuilder
    private var content: some View {
#if os(macOS)
        macContent
#else
        iosContent
#endif
    }

    private var macContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        SecureField("Gemini API Key", text: $viewModel.apiKeyDraft)
                            .textContentType(.password)
                            .textFieldStyle(.roundedBorder)

                        Text(keyStatusText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            Button("Clear Key", role: .destructive) {
                                Task { await viewModel.clearAPIKey() }
                            }
                            .disabled(!viewModel.isKeyPresent || viewModel.isSaving)

                            Spacer()

                            Button("Save API Key") {
                                Task { await viewModel.saveAPIKey() }
                            }
                            .disabled(viewModel.isSaving || isSaveDisabled)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 6)
                } label: {
                    Label("Gemini", systemImage: "key.fill")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        modelRow(
                            title: "Text (Streaming)",
                            selectedModel: viewModel.selectedTextModel,
                            chooseAction: { isShowingTextModelPicker = true }
                        )

                        Divider()

                        modelRow(
                            title: "Speech (TTS)",
                            selectedModel: viewModel.selectedSpeechModel,
                            chooseAction: { isShowingSpeechModelPicker = true }
                        )

                        Divider()

                        HStack(spacing: 12) {
                            Button {
                                Task { await viewModel.refreshModels() }
                            } label: {
                                Label("Refresh Models", systemImage: "arrow.clockwise")
                            }
                            .disabled(viewModel.isLoadingModels || !viewModel.isKeyPresent)

                            if viewModel.isLoadingModels {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            Spacer()
                        }

                        Text(modelHelpText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 6)
                } label: {
                    Label("Models", systemImage: "slider.horizontal.3")
                }

                Text("The API key is stored in UserDefaults on this device and never written to source control.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
    }

    private func modelRow(title: String, selectedModel: String, chooseAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.headline)

                Spacer()

                Text(selectedModel)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 460, alignment: .trailing)
                    .textSelection(.enabled)
            }

            HStack {
                Button("Choose…") {
                    chooseAction()
                }

                Spacer()
            }
        }
    }

    private var iosContent: some View {
        Form {
            Section {
                SecureField("Gemini API Key", text: $viewModel.apiKeyDraft)
                    .textContentType(.password)

                Text(keyStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button("Clear Key", role: .destructive) {
                        Task { await viewModel.clearAPIKey() }
                    }
                    .disabled(!viewModel.isKeyPresent || viewModel.isSaving)

                    Spacer()

                    Button("Save API Key") {
                        Task { await viewModel.saveAPIKey() }
                    }
                    .disabled(viewModel.isSaving || isSaveDisabled)
                    .buttonStyle(.borderedProminent)
                }
            } header: {
                Text("Gemini")
            } footer: {
                Text("The API key is stored in UserDefaults on this device and never written to source control.")
            }

            Section {
                LabeledContent("Text (Streaming)") {
                    Text(viewModel.selectedTextModel)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }

                Button("Choose Text Model…") {
                    isShowingTextModelPicker = true
                }

                LabeledContent("Speech (TTS)") {
                    Text(viewModel.selectedSpeechModel)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }

                Button("Choose Speech Model…") {
                    isShowingSpeechModelPicker = true
                }

                Button {
                    Task { await viewModel.refreshModels() }
                } label: {
                    Label("Refresh Models", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoadingModels || !viewModel.isKeyPresent)

                if viewModel.isLoadingModels {
                    ProgressView()
                }

                Text(modelHelpText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Models")
            }
        }
    }

    private var isSaveDisabled: Bool {
        viewModel.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isPresentingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { presenting in
                if !presenting {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}

extension GeminiSettingsView {
    private var keyStatusText: String {
        if viewModel.isKeyPresent {
            return "API key is saved. Enter a new value and Save to replace it."
        }
        return "No API key saved yet."
    }

    private var modelHelpText: String {
        if let message = viewModel.modelLoadErrorMessage, !message.isEmpty {
            return message
        }

        return "Text model is used for streaming transcripts. Speech model is used to generate multi-speaker audio."
    }

    private var selectedTextModelBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedTextModel },
            set: { newValue in viewModel.userSelectedTextModel(newValue) }
        )
    }

    private var selectedSpeechModelBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedSpeechModel },
            set: { newValue in viewModel.userSelectedSpeechModel(newValue) }
        )
    }
}
