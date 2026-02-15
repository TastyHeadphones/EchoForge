import SwiftUI
import EchoForgeGemini
import EchoForgePersistence

@MainActor
public struct GeminiSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingModelPicker: Bool = false
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
                .task {
                    await viewModel.loadIfNeeded()
                }
                .alert("Error", isPresented: isPresentingError) {
                    Button("OK", role: .cancel) {
                        viewModel.errorMessage = nil
                    }
                } message: {
                    Text(viewModel.errorMessage ?? "")
                }
                .navigationDestination(isPresented: $isShowingModelPicker) {
                    GeminiModelPickerView(
                        selectedModel: selectedModelBinding,
                        models: viewModel.availableModels
                    )
                }
        }
#if os(macOS)
        .frame(minWidth: 640, minHeight: 560)
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
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Selected Model") {
                            Text(viewModel.selectedModel)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 420, alignment: .trailing)
                        }

                        HStack(spacing: 12) {
                            Button("Choose Model…") {
                                isShowingModelPicker = true
                            }

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
                    Label("Model", systemImage: "slider.horizontal.3")
                }
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
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
                Text("The API key is stored in your Keychain and never written to source control.")
            }

            Section {
                LabeledContent("Selected") {
                    Text(viewModel.selectedModel)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }

                Button("Choose Model…") {
                    isShowingModelPicker = true
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
                Text("Model")
            }
        }
    }

    private var isSaveDisabled: Bool {
        viewModel.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

        return "Choose a Gemini model for generation. "
            + "Refresh fetches models from the Gemini API and requires a saved API key."
    }

    private var selectedModelBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedModel },
            set: { newValue in
                viewModel.userSelectedModel(newValue)
            }
        )
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
