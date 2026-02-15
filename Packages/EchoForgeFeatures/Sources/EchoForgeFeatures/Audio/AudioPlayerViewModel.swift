import Foundation
import AVFoundation
import OSLog

@MainActor
final class AudioPlayerViewModel: ObservableObject {
    struct NowPlaying: Sendable, Equatable {
        var projectID: UUID
        var episodeID: UUID
        var title: String
        var url: URL
    }

    @Published private(set) var nowPlaying: NowPlaying?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    private let player: AVPlayer
    private let logger = Logger(subsystem: "EchoForge", category: "AudioPlayer")

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init(player: AVPlayer = AVPlayer()) {
        self.player = player
        configureTimeObserver()
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func play(projectID: UUID, episodeID: UUID, title: String, url: URL) {
        let item = NowPlaying(projectID: projectID, episodeID: episodeID, title: title, url: url)
        if nowPlaying?.url == url {
            togglePlayPause()
            return
        }

        nowPlaying = item
        currentTime = 0
        duration = 0

        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        observeEnd(of: playerItem)

        player.play()
        isPlaying = true
    }

    func togglePlayPause() {
        guard player.currentItem != nil else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        nowPlaying = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    func seek(to time: TimeInterval) {
        guard player.currentItem != nil else { return }
        let clamped = max(0, min(time, duration))
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
    }

    private func configureTimeObserver() {
        let interval = CMTime(seconds: 0.35, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTime = time.seconds.isFinite ? time.seconds : 0

                if let item = self.player.currentItem {
                    let itemDuration = item.duration.seconds
                    self.duration = itemDuration.isFinite ? itemDuration : 0
                }
            }
        }
    }

    private func observeEnd(of item: AVPlayerItem) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.logger.info("Playback ended.")
                self.isPlaying = false
            }
        }
    }
}
