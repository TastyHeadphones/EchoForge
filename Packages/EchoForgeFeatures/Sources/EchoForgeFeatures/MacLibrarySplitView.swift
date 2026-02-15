#if os(macOS)
import SwiftUI
import EchoForgeCore

struct MacLibrarySplitView: View {
    @ObservedObject var viewModel: LibraryViewModel

    private enum EpisodeSelection: Hashable {
        case overview
        case episode(Episode.ID)
    }

    @State private var selectedProjectID: UUID?
    @State private var episodeSelection: EpisodeSelection = .overview
    @State private var hasSelectedEpisode: Bool = false

    @State private var projectIDPendingDelete: UUID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedProjectID) {
                Section("Podcasts") {
                    ForEach(viewModel.projects) { project in
                        MacLibraryProjectRow(project: project)
                            .tag(project.id)
                            .contextMenu {
                                Button("Export ZIP") {
                                    viewModel.exportProject(id: project.id)
                                }

                                Divider()

                                Button("Delete", role: .destructive) {
                                    projectIDPendingDelete = project.id
                                }
                            }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("EchoForge")
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } content: {
            episodesColumn
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar { toolbarContent }
        .sheet(isPresented: $viewModel.isShowingNewPodcast) {
            NewPodcastSheet(viewModel: viewModel) { newProjectID in
                selectedProjectID = newProjectID
                hasSelectedEpisode = false
                applyInitialEpisodeSelectionIfNeeded()
            }
        }
        .confirmationDialog(
            "Delete Podcast?",
            isPresented: isPresentingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let id = projectIDPendingDelete else { return }
                Task {
                    await viewModel.deleteProject(id: id)
                    if selectedProjectID == id {
                        selectedProjectID = viewModel.projects.first?.id
                        hasSelectedEpisode = false
                        applyInitialEpisodeSelectionIfNeeded()
                    }
                    projectIDPendingDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                projectIDPendingDelete = nil
            }
        } message: {
            Text("This will remove the podcast project from this device.")
        }
        .onAppear {
            applyInitialProjectSelectionIfNeeded()
            applyInitialEpisodeSelectionIfNeeded()
        }
        .onChange(of: viewModel.projects.map(\.id)) { _, _ in
            applyInitialProjectSelectionIfNeeded()
            applyInitialEpisodeSelectionIfNeeded()
        }
        .onChange(of: selectedProjectID) { _, _ in
            episodeSelection = .overview
            hasSelectedEpisode = false
            applyInitialEpisodeSelectionIfNeeded()
        }
        .onChange(of: episodeSelection) { _, newValue in
            if case .episode = newValue {
                hasSelectedEpisode = true
            }
        }
    }

    private var selectedProject: PodcastProject? {
        guard let id = selectedProjectID else { return nil }
        return viewModel.project(id: id)
    }

    private var sortedEpisodes: [Episode] {
        selectedProject?.episodes.sorted(by: { $0.number < $1.number }) ?? []
    }

    private var episodesColumn: some View {
        Group {
            if let project = selectedProject {
                List(selection: $episodeSelection) {
                    Section {
                        Label("Overview", systemImage: "sparkles")
                            .tag(EpisodeSelection.overview)
                    }

                    Section("Episodes") {
                        ForEach(sortedEpisodes) { episode in
                            MacLibraryEpisodeRow(episode: episode)
                                .tag(EpisodeSelection.episode(episode.id))
                        }
                    }
                }
                .listStyle(.inset)
                .navigationTitle(projectTitle(project))
                .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 420)
            } else {
                ContentUnavailableView(
                    "No Podcast Selected",
                    systemImage: "waveform",
                    description: Text("Create a new podcast or select one from the sidebar.")
                )
            }
        }
    }

    private var detailColumn: some View {
        Group {
            if let project = selectedProject {
                switch episodeSelection {
                case .overview:
                    MacLibraryProjectOverviewView(project: project)

                case let .episode(episodeID):
                    if let episode = sortedEpisodes.first(where: { $0.id == episodeID }) {
                        MacLibraryEpisodeDetailView(
                            project: project,
                            episode: episode,
                            viewModel: viewModel
                        )
                    } else {
                        MacLibraryProjectOverviewView(project: project)
                    }
                }
            } else {
                ContentUnavailableView(
                    "EchoForge",
                    systemImage: "waveform",
                    description: Text("Generate a podcast to start streaming episodes.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(detailID)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .animation(.easeInOut(duration: 0.18), value: detailID)
    }

    private var detailID: String {
        "\(selectedProjectID?.uuidString ?? "none")-\(String(describing: episodeSelection))"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                viewModel.isShowingNewPodcast = true
            } label: {
                Label("New Podcast", systemImage: "plus")
            }

            Button {
                viewModel.isShowingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            if let project = selectedProject {
                if project.status == .generating {
                    Button {
                        Task { await viewModel.cancelGeneration(for: project.id) }
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                }

                if project.status == .failed {
                    Button {
                        viewModel.retryGeneration(projectID: project.id)
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
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
                    projectIDPendingDelete = project.id
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var isPresentingDeleteConfirmation: Binding<Bool> {
        Binding(
            get: { projectIDPendingDelete != nil },
            set: { presented in
                if !presented {
                    projectIDPendingDelete = nil
                }
            }
        )
    }

    private func applyInitialProjectSelectionIfNeeded() {
        guard selectedProjectID == nil else { return }
        selectedProjectID = viewModel.projects.first?.id
    }

    private func applyInitialEpisodeSelectionIfNeeded() {
        guard !hasSelectedEpisode else { return }
        guard let first = sortedEpisodes.first else {
            episodeSelection = .overview
            return
        }

        episodeSelection = .episode(first.id)
        hasSelectedEpisode = true
    }

    private func projectTitle(_ project: PodcastProject) -> String {
        let trimmed = project.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed! : "Podcast"
    }
}
#endif
