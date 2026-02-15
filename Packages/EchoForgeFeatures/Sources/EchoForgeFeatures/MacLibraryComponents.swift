#if os(macOS)
import SwiftUI
import EchoForgeCore

struct MacLibraryProjectRow: View {
    let project: PodcastProject

    var body: some View {
        HStack(spacing: 10) {
            if project.status == .generating {
                ProgressView()
                    .controlSize(.small)
            } else {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .lineLimit(1)

                Text(secondaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var title: String {
        let trimmed = project.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed! : "Untitled Podcast"
    }

    private var secondaryText: String {
        let completed = project.episodes.filter { $0.status == .complete }.count
        return "Episodes: \(completed)/\(project.episodeCountRequested)  •  \(project.status.rawValue)"
    }

    private var indicatorColor: Color {
        switch project.status {
        case .draft:
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

struct MacLibraryEpisodeRow: View {
    let episode: Episode

    var body: some View {
        HStack(spacing: 10) {
            if episode.status == .generating {
                ProgressView()
                    .controlSize(.small)
            } else {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 8, height: 8)
            }

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

struct MacLibraryProjectOverviewView: View {
    let project: PodcastProject

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

                if project.status == .generating {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Generating episodes…")
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }

                if project.status == .failed, let error = project.errorMessage, !error.isEmpty {
                    ContentUnavailableView(
                        "Generation Failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    .padding(.top, 12)
                }

                if project.episodes.isEmpty, project.status == .generating {
                    ContentUnavailableView(
                        "Waiting for Episodes",
                        systemImage: "waveform.path.ecg",
                        description: Text("As Gemini streams NDJSON, episodes will appear in the Episodes column.")
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

struct MacLibraryEpisodeDetailView: View {
    let project: PodcastProject
    let episode: Episode

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header

                    Divider()

                    if episode.lines.isEmpty {
                        ContentUnavailableView(
                            episode.status == .generating ? "Generating Dialogue" : "Waiting for Dialogue",
                            systemImage: "text.quote",
                            description: Text("This episode will fill in as Gemini streams lines.")
                        )
                        .padding(.top, 24)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(episode.lines) { line in
                                MacLibraryTranscriptLineRow(
                                    speakerLabel: speakerName(line.speaker),
                                    text: line.text,
                                    accent: accentColor(for: line.speaker)
                                )
                                .id(line.id)
                                .transition(.opacity)
                            }
                        }
                        .animation(.easeInOut(duration: 0.15), value: episode.lines.count)
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

                    if project.status == .generating, episode.status == .generating {
                        ProgressView()
                            .controlSize(.small)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.18), value: episode.status)
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

    private func speakerName(_ speaker: Speaker) -> String {
        project.hosts.first(where: { $0.id == speaker })?.displayName ?? speaker.rawValue
    }

    private func accentColor(for speaker: Speaker) -> Color {
        switch speaker {
        case .hostA:
            return .accentColor
        case .hostB:
            return .secondary
        }
    }
}

struct MacLibraryTranscriptLineRow: View {
    let speakerLabel: String
    let text: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(speakerLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
                .fixedSize(horizontal: true, vertical: true)

            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(alignment: .leading) {
            Rectangle()
                .fill(accent.opacity(0.25))
                .frame(width: 3)
        }
    }
}
#endif
