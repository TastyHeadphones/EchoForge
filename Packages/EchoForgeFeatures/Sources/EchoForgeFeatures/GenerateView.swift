import SwiftUI

struct GenerateView: View {
    @ObservedObject var viewModel: GenerateViewModel
    var openSettings: () -> Void

    var body: some View {
        Form {
            Section {
                topicInput

                Stepper(value: $viewModel.episodeCount, in: 1...10) {
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

                Text(
                    "Your Gemini API key is stored in the system Keychain. "
                        + "Configure it from Settings."
                )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle("EchoForge")
    }

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
                .frame(minHeight: 90)

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Topic")
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.leading, 6)
                    .allowsHitTesting(false)
            }
        }
    }
}
#endif
