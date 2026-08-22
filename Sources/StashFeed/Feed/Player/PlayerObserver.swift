import AVFoundation
import Combine

/// Watches one AVPlayer's buffering state, playback progress and failures, publishing them for
/// a SwiftUI view to bind to. Kept as its own object (rather than raw KVO in a View's @State) so
/// observer tokens have a stable owner independent of View re-renders.
@MainActor
final class PlayerObserver: ObservableObject {
    @Published var isBuffering = true
    @Published var progressFraction: Double = 0
    @Published var errorMessage: String?

    private weak var player: AVPlayer?
    private var timeControlObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeObserverToken: Any?

    func attach(to player: AVPlayer, knownDuration: Double? = nil) {
        detach()
        self.player = player
        errorMessage = nil

        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] observedPlayer, _ in
            Task { @MainActor in
                self?.isBuffering = observedPlayer.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }

        itemStatusObservation = player.currentItem?.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                if item.status == .failed {
                    self?.errorMessage = item.error?.localizedDescription ?? "Erreur de lecture inconnue"
                }
            }
        }

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let duration = knownDuration ?? player.currentItem?.duration.seconds,
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
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        player = nil
    }

    deinit {
        timeControlObservation?.invalidate()
        itemStatusObservation?.invalidate()
    }
}
