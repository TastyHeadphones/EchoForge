import SwiftUI

struct GenerateView: View {
    @ObservedObject var viewModel: GenerateViewModel
    var openSettings: () -> Void

    var body: some View {
        Form {
            Section {
                TextField("Topic", text: $viewModel.topic, axis: .vertical)
                    .lineLimit(2...6)

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
            }
        }
        .navigationTitle("EchoForge")
    }

    private var isGenerateDisabled: Bool {
        let isTopicEmpty = viewModel.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return isTopicEmpty || viewModel.isGenerating || !viewModel.isGeminiConfigured
    }
}
