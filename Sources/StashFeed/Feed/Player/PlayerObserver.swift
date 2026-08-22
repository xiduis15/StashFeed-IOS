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
    /// Raw diagnostic string shown after a few seconds of stuck buffering with no formal error -
    /// there's no reliable "timed out" callback on AVPlayer/AVPlayerItem, so this is a manual
    /// watchdog to at least surface *something* actionable instead of a silent spinner forever.
    @Published var stuckDiagnostic: String?

    private weak var player: AVPlayer?
    private weak var item: AVPlayerItem?
    private var timeControlObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeObserverToken: Any?
    private var watchdogTask: Task<Void, Never>?

    func attach(to player: AVPlayer) {
        detach()
        self.player = player
        self.item = player.currentItem
        errorMessage = nil
        stuckDiagnostic = nil

        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] observedPlayer, _ in
            Task { @MainActor in
                self?.isBuffering = observedPlayer.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }

        itemStatusObservation = player.currentItem?.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                if item.status == .failed {
                    self?.errorMessage = item.error?.localizedDescription ?? "Erreur de lecture inconnue"
                } else if item.status == .readyToPlay {
                    self?.stuckDiagnostic = nil
                }
            }
        }

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let duration = player.currentItem?.duration.seconds,
                  duration.isFinite, duration > 0 else { return }
            self?.progressFraction = min(max(time.seconds / duration, 0), 1)
        }

        watchdogTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled else { return }
            self?.reportStuckState()
        }
    }

    private func reportStuckState() {
        guard errorMessage == nil else { return }
        guard let item else {
            stuckDiagnostic = "Aucun AVPlayerItem"
            return
        }
        let itemStatus: String
        switch item.status {
        case .unknown: itemStatus = "unknown"
        case .readyToPlay: itemStatus = "readyToPlay"
        case .failed: itemStatus = "failed"
        @unknown default: itemStatus = "?"
        }
        let lastErrorEvent = item.errorLog()?.events.last?.errorComment ?? "aucun"
        let loadedRanges = item.loadedTimeRanges.map { $0.timeRangeValue.duration.seconds }
        stuckDiagnostic = """
        Bloqué depuis 8s.
        item.status: \(itemStatus)
        dernier log d'erreur: \(lastErrorEvent)
        plages chargées: \(loadedRanges)
        """
    }

    func detach() {
        watchdogTask?.cancel()
        watchdogTask = nil
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
        timeObserverToken = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        player = nil
        item = nil
    }

    deinit {
        timeControlObservation?.invalidate()
        itemStatusObservation?.invalidate()
        watchdogTask?.cancel()
    }
}
