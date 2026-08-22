import AVFoundation
import Combine

/// Watches one AVPlayer's buffering state and playback progress, publishing them for a SwiftUI
/// view to bind to. Kept as its own object (rather than raw KVO in a View's @State) so observer
/// tokens have a stable owner independent of View re-renders.
@MainActor
final class PlayerObserver: ObservableObject {
    @Published var isBuffering = true
    @Published var progressFraction: Double = 0

    private weak var player: AVPlayer?
    private var timeControlObservation: NSKeyValueObservation?
    private var timeObserverToken: Any?

    func attach(to player: AVPlayer) {
        detach()
        self.player = player

        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] observedPlayer, _ in
            Task { @MainActor in
                self?.isBuffering = observedPlayer.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let duration = player.currentItem?.duration.seconds,
                  duration.isFinite, duration > 0 else { return }
            self?.progressFraction = min(max(time.seconds / duration, 0), 1)
        }
    }

    func detach() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
        timeObserverToken = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        player = nil
    }

    deinit {
        timeControlObservation?.invalidate()
    }
}
