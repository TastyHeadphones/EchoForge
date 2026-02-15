import Foundation
import SwiftUI
import EchoForgeCore
import UniformTypeIdentifiers

struct ProjectView: View {
    let project: PodcastProject
    @ObservedObject var viewModel: GenerateViewModel

    var body: some View {
#if os(macOS)
        macBody
#else
        iOSBody
#endif
    }

#if os(macOS)
    private var macBody: some View {
        MacProjectSplitView(project: project, isGenerating: viewModel.isGenerating, speakerName: speakerName(for:))
        .toolbar { toolbarContent }
        .fileExporter(
            isPresented: $viewModel.isShowingExportPicker,
            document: viewModel.exportDocument ?? ZipFileDocument(data: Data()),
            contentType: .zip,
            defaultFilename: viewModel.exportDefaultFilename
        ) { result in
            if case let .failure(error) = result {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
#endif

#if !os(macOS)
    private var iOSBody: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    let displayTitle = project.title.flatMap { $0.isEmpty ? nil : $0 } ?? project.topic
                    Text(displayTitle)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    if let description = project.description, !description.isEmpty {
                        Text(description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("Status: \(project.status.rawValue)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if viewModel.isGenerating {
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
                        Text("Waiting for dialogue...")
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
        .fileExporter(
            isPresented: $viewModel.isShowingExportPicker,
            document: viewModel.exportDocument ?? ZipFileDocument(data: Data()),
            contentType: .zip,
            defaultFilename: viewModel.exportDefaultFilename
        ) { result in
            if case let .failure(error) = result {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
#endif

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                viewModel.startNewProject()
            } label: {
                Label("New", systemImage: "plus")
            }

            if viewModel.isGenerating {
                Button {
                    viewModel.cancelGeneration()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                }
            }

            Button {
                viewModel.exportZip()
            } label: {
                if viewModel.isExporting {
                    ProgressView()
                } else {
                    Label("Export ZIP", systemImage: "square.and.arrow.up")
                }
            }
            .disabled(viewModel.isExporting || project.episodes.isEmpty)
        }
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
