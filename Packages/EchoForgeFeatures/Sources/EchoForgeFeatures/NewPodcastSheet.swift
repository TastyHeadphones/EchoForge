import SwiftUI

struct NewPodcastSheet: View {
    @ObservedObject var viewModel: LibraryViewModel
    var onCreated: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var topic: String = ""
    @State private var episodeCount: Int = 3
    @State private var isCreating: Bool = false

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
                header

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title (Optional)")
                                .font(.headline)

                            TextField("Podcast title", text: $title)
                                .textFieldStyle(.roundedBorder)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Topic")
                                .font(.headline)

                            TopicTextEditor(text: $topic)
                        }

                        Divider()

                        Stepper(value: $episodeCount, in: 1...Int.max, step: 1) {
                            Text("Episodes: \(episodeCount)")
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
                                dismiss()
                                viewModel.isShowingSettings = true
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
                                create()
                            } label: {
                                if isCreating {
                                    ProgressView()
                                } else {
                                    Label("Generate Podcast", systemImage: "sparkles")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(!canGenerate)
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
        .frame(minWidth: 680, minHeight: 640)
        .navigationTitle("New Podcast")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("New Podcast")
                .font(.largeTitle.weight(.semibold))

            Text("Generate a multi-episode, two-host dialogue podcast from a title and topic.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
#endif
#if !os(macOS)
    private var iosBody: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title (Optional)", text: $title)

                    TextField("Topic", text: $topic, axis: .vertical)
                        .lineLimit(2...6)

                    Stepper(value: $episodeCount, in: 1...Int.max, step: 1) {
                        Text("Episodes: \(episodeCount)")
                    }
                } header: {
                    Text("Prompt")
                }

                Section {
                    if !viewModel.isGeminiConfigured {
                        Text("Gemini is not configured.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Open Settings") {
                            dismiss()
                            viewModel.isShowingSettings = true
                        }
                    }

                    Button {
                        create()
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Generate Podcast")
                        }
                    }
                    .disabled(!canGenerate)

                    Text("Your Gemini API key is stored in UserDefaults on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text("Generate")
                }
            }
            .navigationTitle("New Podcast")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
#endif

    private var canGenerate: Bool {
        let isTopicEmpty = topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !isTopicEmpty && viewModel.isGeminiConfigured && !isCreating
    }

    private func create() {
        guard !isCreating else { return }
        isCreating = true

        Task {
            defer { isCreating = false }

            guard let projectID = await viewModel.createPodcast(
                title: title,
                topic: topic,
                episodeCount: episodeCount
            ) else {
                return
            }

            onCreated(projectID)
            dismiss()
        }
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
