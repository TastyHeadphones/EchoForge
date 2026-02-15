import SwiftUI
import EchoForgeCore

struct LibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel

    var body: some View {
#if os(macOS)
        MacLibrarySplitView(viewModel: viewModel)
#else
        IOSLibraryView(viewModel: viewModel)
#endif
    }
}

#if !os(macOS)
private struct IOSLibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel

    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if viewModel.projects.isEmpty {
                    ContentUnavailableView(
                        "No Podcasts Yet",
                        systemImage: "waveform",
                        description: Text("Create a new podcast to start generating episodes.")
                    )
                    .listRowBackground(Color.clear)
                }

                ForEach(viewModel.projects) { project in
                    NavigationLink(value: project.id) {
                        IOSProjectRow(project: project)
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("EchoForge")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.isShowingNewPodcast = true
                    } label: {
                        Label("New Podcast", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        viewModel.isShowingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { projectID in
                if let project = viewModel.project(id: projectID) {
                    ProjectDetailView(project: project, viewModel: viewModel) {
                        path.removeAll()
                    }
                } else {
                    ContentUnavailableView(
                        "Podcast Not Found",
                        systemImage: "questionmark.folder",
                        description: Text("This podcast may have been deleted.")
                    )
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingNewPodcast) {
            NewPodcastSheet(viewModel: viewModel) { projectID in
                path = [projectID]
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let ids: [UUID] = offsets
            .filter(viewModel.projects.indices.contains)
            .map { viewModel.projects[$0].id }

        Task {
            for id in ids {
                await viewModel.deleteProject(id: id)
            }
        }
    }
}

private struct IOSProjectRow: View {
    let project: PodcastProject

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            Text(project.topic)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(episodeProgressText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                if project.status == .generating {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var title: String {
        let trimmed = project.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed! : "Untitled Podcast"
    }

    private var statusText: String {
        "Status: \(project.status.rawValue)"
    }

    private var episodeProgressText: String {
        let completed = project.episodes.filter { $0.status == .complete }.count
        return "Episodes: \(completed)/\(project.episodeCountRequested)"
    }
}
#endif
