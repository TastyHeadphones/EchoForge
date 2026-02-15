import SwiftUI

struct AudioPlayerBar: View {
    @EnvironmentObject private var player: AudioPlayerViewModel

    var body: some View {
        if let nowPlaying = player.nowPlaying {
            VStack(spacing: 0) {
                Divider()
                content(nowPlaying: nowPlaying)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
            .background(.regularMaterial)
        }
    }

    private func content(nowPlaying: AudioPlayerViewModel.NowPlaying) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)

                VStack(alignment: .leading, spacing: 2) {
                    Text(nowPlaying.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(timeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer(minLength: 12)

                Button {
                    player.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
            }

            Slider(value: timeBinding, in: 0...max(0.1, player.duration))
                .disabled(player.duration <= 0.1)
        }
    }

    private var timeBinding: Binding<Double> {
        Binding(
            get: { player.currentTime },
            set: { newValue in player.seek(to: newValue) }
        )
    }

    private var timeText: String {
        "\(format(player.currentTime)) / \(format(player.duration))"
    }

    private func format(_ time: TimeInterval) -> String {
        guard time.isFinite, time > 0 else { return "0:00" }
        let totalSeconds = Int(time.rounded(.down))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
