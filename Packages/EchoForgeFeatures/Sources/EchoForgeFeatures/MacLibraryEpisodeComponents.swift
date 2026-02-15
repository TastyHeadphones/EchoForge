#if os(macOS)
import SwiftUI
import EchoForgeCore

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

struct MacLibraryEpisodeDetailView: View {
    let project: PodcastProject
    let episode: Episode
    @ObservedObject var viewModel: LibraryViewModel

    @EnvironmentObject private var audioPlayer: AudioPlayerViewModel

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

            audioControls

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

    @ViewBuilder
    private var audioControls: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(audioTitle)
                        .font(.headline)

                    if let detail = audioDetailText {
                        Text(detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12)

                switch episode.audioStatus {
                case .none:
                    Button {
                        viewModel.generateAudio(projectID: project.id, episodeID: episode.id)
                    } label: {
                        Label("Generate Audio", systemImage: "waveform")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(project.status != .complete || episode.status != .complete || episode.lines.isEmpty)

                case .generating:
                    ProgressView()
                        .controlSize(.small)

                case .ready:
                    Button {
                        Task { @MainActor in
                            guard let url = await viewModel.audioFileURL(projectID: project.id, episode: episode) else {
                                return
                            }
                            audioPlayer.play(
                                projectID: project.id,
                                episodeID: episode.id,
                                title: episodeTitle,
                                url: url
                            )
                        }
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                case .failed:
                    Button {
                        viewModel.generateAudio(projectID: project.id, episodeID: episode.id)
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
        } label: {
            Label("Audio", systemImage: "speaker.wave.2")
        }
        .animation(.easeInOut(duration: 0.18), value: episode.audioStatus)
    }

    private var audioTitle: String {
        switch episode.audioStatus {
        case .none:
            return "Generate multi-speaker audio for this episode."
        case .generating:
            return "Generating audio…"
        case .ready:
            return "Audio ready."
        case .failed:
            return "Audio failed."
        }
    }

    private var audioDetailText: String? {
        if episode.audioStatus == .failed, let message = episode.audio?.errorMessage, !message.isEmpty {
            return message
        }
        if project.status != .complete {
            return "Audio can be generated after the podcast finishes generating."
        }
        if episode.status != .complete {
            return "Audio can be generated after the transcript is complete."
        }
        return nil
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
