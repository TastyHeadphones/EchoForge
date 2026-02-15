#if !os(macOS)
import SwiftUI
import EchoForgeCore

struct ProjectDetailView: View {
    let project: PodcastProject
    @ObservedObject var viewModel: LibraryViewModel
    var onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isShowingDeleteConfirmation: Bool = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(project.topic)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Status: \(project.status.rawValue)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if project.status == .generating {
                        ProgressView()
                            .padding(.top, 6)
                    }
                }
                .padding(.vertical, 4)
            }

            ForEach(project.episodes.sorted(by: { $0.number < $1.number })) { episode in
                Section {
                    if let summary = episode.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(episode.lines) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text(speakerName(for: line.speaker))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .leading)
                                .fixedSize(horizontal: true, vertical: true)

                            Text(line.text)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 2)
                    }

                    if episode.lines.isEmpty {
                        Text(episode.status == .generating ? "Generating dialogue..." : "Waiting for dialogue...")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    Text(episodeTitle(episode))
                } footer: {
                    Text("Episode status: \(episode.status.rawValue)")
                }
            }
        }
        .navigationTitle("Podcast")
        .toolbar { toolbarContent }
        .confirmationDialog(
            "Delete Podcast?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteProject(id: project.id)
                    onDeleted()
                    dismiss()
                }
            }
        } message: {
            Text("This will remove the podcast project from this device.")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                viewModel.isShowingNewPodcast = true
            } label: {
                Label("New", systemImage: "plus")
            }

            if project.status == .generating {
                Button {
                    Task { await viewModel.cancelGeneration(for: project.id) }
                } label: {
                    Label("Cancel", systemImage: "xmark")
                }
            }

            Button {
                viewModel.exportProject(id: project.id)
            } label: {
                if viewModel.isExporting {
                    ProgressView()
                } else {
                    Label("Export ZIP", systemImage: "square.and.arrow.up")
                }
            }
            .disabled(viewModel.isExporting || project.episodes.isEmpty)

            Button(role: .destructive) {
                isShowingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var title: String {
        let trimmed = project.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed! : "Untitled Podcast"
    }

    private func speakerName(for speaker: Speaker) -> String {
        project.hosts.first(where: { $0.id == speaker })?.displayName ?? speaker.rawValue
    }

    private func episodeTitle(_ episode: Episode) -> String {
        if let title = episode.title, !title.isEmpty {
            return "Episode \(episode.number): \(title)"
        }
        return "Episode \(episode.number)"
    }
}
#endif
