import SwiftUI

struct GenerateView: View {
    @ObservedObject var viewModel: GenerateViewModel
    var openSettings: () -> Void

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iosBody
        #endif
    }

    #if os(macOS)
    private var macBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("New Podcast")
                        .font(.largeTitle.weight(.semibold))

                    Text("Generate a multi-episode, two-host dialogue podcast from a single topic.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Topic")
                                .font(.headline)

                            TopicTextEditor(text: $viewModel.topic)
                        }

                        Divider()

                        Stepper(value: $viewModel.episodeCount, in: 1...Int.max, step: 1) {
                            Text("Episodes: \(viewModel.episodeCount)")
                                .monospacedDigit()
                        }
                        .controlSize(.large)
                    }
                    .padding(.vertical, 6)
                } label: {
                    Label("Prompt", systemImage: "square.and.pencil")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.isGeminiConfigured ? "Gemini configured" : "Gemini not configured")
                                    .font(.headline)

                                Text("Your API key is stored in UserDefaults on this device.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            Button("Settings…") {
                                openSettings()
                            }
                        }

                        if !viewModel.isGeminiConfigured {
                            Text("Add an API key in Settings to enable generation.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack {
                            Spacer()

                            Button {
                                viewModel.startGeneration()
                            } label: {
                                Label("Generate Podcast", systemImage: "sparkles")
                                    .frame(maxWidth: 320)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(isGenerateDisabled)
                            .keyboardShortcut(.defaultAction)

                            Spacer()
                        }
                    }
                    .padding(.vertical, 6)
                } label: {
                    Label("Generate", systemImage: "waveform")
                }
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .navigationTitle("EchoForge")
    }
    #endif

    #if !os(macOS)
    private var iosBody: some View {
        Form {
            Section {
                topicInput

                Stepper(value: $viewModel.episodeCount, in: 1...Int.max, step: 1) {
                    Text("Episodes: \(viewModel.episodeCount)")
                }
            } header: {
                Text("Generate")
            }

            Section {
                if !viewModel.isGeminiConfigured {
                    Text("Gemini is not configured.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Configure Gemini") {
                        openSettings()
                    }
                }

                Button {
                    viewModel.startGeneration()
                } label: {
                    Text("Generate Podcast")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isGenerateDisabled)

                Text("Your Gemini API key is stored in UserDefaults on this device. Configure it from Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle("EchoForge")
    }
    #endif

    @ViewBuilder
    private var topicInput: some View {
#if os(macOS)
        TopicTextEditor(text: $viewModel.topic)
#else
        TextField("Topic", text: $viewModel.topic, axis: .vertical)
            .lineLimit(2...6)
#endif
    }

    private var isGenerateDisabled: Bool {
        let isTopicEmpty = viewModel.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return isTopicEmpty || viewModel.isGenerating || !viewModel.isGeminiConfigured
    }
}

#if os(macOS)
private struct TopicTextEditor: View {
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 120)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.quaternary.opacity(0.35))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                }

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Topic")
                    .foregroundStyle(.secondary)
                    .padding(.top, 14)
                    .padding(.leading, 16)
                    .allowsHitTesting(false)
            }
        }
    }
}
#endif
