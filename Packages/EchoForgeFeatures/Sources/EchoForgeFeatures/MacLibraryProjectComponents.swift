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
#endif
