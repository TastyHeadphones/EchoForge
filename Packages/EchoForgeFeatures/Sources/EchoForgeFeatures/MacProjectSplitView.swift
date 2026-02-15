#if os(macOS)
import SwiftUI
import EchoForgeCore

struct MacProjectSplitView: View {
    let project: PodcastProject
    let isGenerating: Bool
    let speakerName: (Speaker) -> String

    private enum Selection: Hashable {
        case overview
        case episode(Episode.ID)
    }

    @State private var selection: Selection = .overview
    @State private var hasSelectedEpisode: Bool = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    Label("Overview", systemImage: "sparkles")
                        .tag(Selection.overview)
                }

                Section("Episodes") {
                    ForEach(sortedEpisodes) { episode in
                        MacEpisodeRow(episode: episode)
                            .tag(Selection.episode(episode.id))
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("EchoForge")
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            Group {
                switch selection {
                case .overview:
                    MacProjectOverviewView(project: project, isGenerating: isGenerating)

                case let .episode(id):
                    if let episode = sortedEpisodes.first(where: { $0.id == id }) {
                        MacEpisodeDetailView(
                            project: project,
                            episode: episode,
                            isGenerating: isGenerating,
                            speakerName: speakerName
                        )
                    } else {
                        MacProjectOverviewView(project: project, isGenerating: isGenerating)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            applyInitialSelectionIfNeeded()
        }
        .onChange(of: project.episodes.map(\.id)) { _, _ in
            applyInitialSelectionIfNeeded()
        }
        .onChange(of: selection) { _, newValue in
            if case .episode = newValue {
                hasSelectedEpisode = true
            }
        }
    }

    private var sortedEpisodes: [Episode] {
        project.episodes.sorted(by: { $0.number < $1.number })
    }

    private func applyInitialSelectionIfNeeded() {
        guard !hasSelectedEpisode else { return }
        guard let first = sortedEpisodes.first else {
            selection = .overview
            return
        }

        selection = .episode(first.id)
        hasSelectedEpisode = true
    }
}

private struct MacEpisodeRow: View {
    let episode: Episode

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(primaryTitle)
                    .font(.body)
                    .lineLimit(1)

                Text(secondaryTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var primaryTitle: String {
        if let title = episode.title, !title.isEmpty {
            return "Episode \(episode.number): \(title)"
        }
        return "Episode \(episode.number)"
    }

    private var secondaryTitle: String {
        switch episode.status {
        case .pending:
            return "Pending"
        case .generating:
            return "Generating"
        case .complete:
            return "\(episode.lines.count) lines"
        case .failed:
            return "Failed"
        }
    }

    private var indicatorColor: Color {
        switch episode.status {
        case .pending:
            return .secondary.opacity(0.5)
        case .generating:
            return .orange
        case .complete:
            return .green
        case .failed:
            return .red
        }
    }
}

private struct MacProjectOverviewView: View {
    let project: PodcastProject
    let isGenerating: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Topic") {
                            Text(project.topic)
                                .multilineTextAlignment(.trailing)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }

                        Divider()

                        LabeledContent("Episodes") {
                            Text("\(project.episodeCountRequested)")
                        }

                        LabeledContent("Hosts") {
                            Text(project.hosts.map(\.displayName).joined(separator: ", "))
                                .multilineTextAlignment(.trailing)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } label: {
                    Label("Project", systemImage: "doc.text")
                }

                if isGenerating {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Generating episodes…")
                            .foregroundStyle(.secondary)
                    }
                }

                if project.episodes.isEmpty {
                    ContentUnavailableView(
                        "Waiting for Episodes",
                        systemImage: "waveform.path.ecg",
                        description: Text("As Gemini streams NDJSON, episodes will appear in the sidebar.")
                    )
                    .padding(.top, 12)
                }
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            let displayTitle = project.title.flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled Podcast"
            Text(displayTitle)
                .font(.largeTitle.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if let description = project.description, !description.isEmpty {
                Text(description)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct MacEpisodeDetailView: View {
    enum BubbleAlignment: Sendable {
        case leading
        case trailing
    }

    let project: PodcastProject
    let episode: Episode
    let isGenerating: Bool
    let speakerName: (Speaker) -> String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header

                    Divider()

                    if episode.lines.isEmpty {
                        ContentUnavailableView(
                            "Waiting for Dialogue",
                            systemImage: "text.bubble",
                            description: Text("This episode will fill in as Gemini streams lines.")
                        )
                        .padding(.top, 24)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(episode.lines) { line in
                                let config = bubbleConfig(for: line.speaker)
                                MacDialogueBubble(
                                    speakerLabel: speakerName(line.speaker),
                                    text: line.text,
                                    alignment: config.alignment,
                                    tint: config.tint
                                )
                                .id(line.id)
                            }
                        }
                        .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: 980, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }
            .onChange(of: episode.lines.last?.id) { _, newID in
                guard let newID else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(newID, anchor: .bottom)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(episodeTitle)
                    .font(.title.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Text(statusText)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if isGenerating, episode.status == .generating {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }

            if let summary = episode.summary, !summary.isEmpty {
                GroupBox {
                    Text(summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                } label: {
                    Label("Summary", systemImage: "text.alignleft")
                }
            }
        }
    }

    private var episodeTitle: String {
        if let title = episode.title, !title.isEmpty {
            return "Episode \(episode.number): \(title)"
        }
        return "Episode \(episode.number)"
    }

    private var statusText: String {
        switch episode.status {
        case .pending:
            return "Pending"
        case .generating:
            return "Generating"
        case .complete:
            return "Complete"
        case .failed:
            return "Failed"
        }
    }

    private func bubbleConfig(for speaker: Speaker) -> (alignment: BubbleAlignment, tint: Color) {
        switch speaker {
        case .hostA:
            return (alignment: .leading, tint: .accentColor.opacity(0.14))
        case .hostB:
            return (alignment: .trailing, tint: .secondary.opacity(0.12))
        }
    }
}

private struct MacDialogueBubble: View {
    let speakerLabel: String
    let text: String
    let alignment: MacEpisodeDetailView.BubbleAlignment
    let tint: Color

    var body: some View {
        HStack {
            if alignment == .trailing {
                Spacer(minLength: 32)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(speakerLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
            }
            .frame(maxWidth: 620, alignment: .leading)

            if alignment == .leading {
                Spacer(minLength: 32)
            }
        }
    }
}
#endif
