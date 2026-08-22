import AVFoundation

/// Keeps a handful of AVPlayer instances alive at once (current feed position plus its
/// neighbours) so the next/previous video is already buffering by the time the user swipes,
/// instead of starting cold on every page change. Mirrors FeedPlayerPool.kt.
final class FeedPlayerPool {
    let urlSession: URLSession
    var randomStartEnabled = false

    private var players: [Int: AVPlayer] = [:]
    private var loopObservers: [Int: NSObjectProtocol] = [:]
    private var readyObservers: [Int: NSKeyValueObservation] = [:]

    init(urlSession: URLSession) {
        self.urlSession = urlSession
    }

    func player(for index: Int, scene: FeedScene) -> AVPlayer {
        if let existing = players[index] { return existing }
        let player = makePlayer(for: index, scene: scene)
        players[index] = player
        return player
    }

    /// Releases players away from `currentIndex` to free decoders and network connections.
    func trimAround(currentIndex: Int, keepRadius: Int = 1) {
        let stale = players.keys.filter { abs($0 - currentIndex) > keepRadius }
        for index in stale {
            release(index: index)
        }
    }

    func releaseAll() {
        for index in Array(players.keys) {
            release(index: index)
        }
    }

    private func release(index: Int) {
        players[index]?.pause()
        if let observer = loopObservers[index] {
            NotificationCenter.default.removeObserver(observer)
        }
        readyObservers[index]?.invalidate()
        players.removeValue(forKey: index)
        loopObservers.removeValue(forKey: index)
        readyObservers.removeValue(forKey: index)
    }

    private func makePlayer(for index: Int, scene: FeedScene) -> AVPlayer {
        // No custom "ApiKey" header here: Stash's stream URLs are self-authenticating (either a
        // "?apikey=" query param, or a signed URL with its own cid/expires/sig params when the
        // server has username/password credentials configured - see StashHttpClient.kt for the
        // Android-side equivalent finding). Injecting a header via AVURLAssetHTTPHeaderFieldsKey
        // is unreliable for HLS segment sub-requests on some iOS versions and isn't needed here.
        let asset = AVURLAsset(url: scene.streamURL)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .none

        // Loop the video like Reels instead of stopping at the end (equivalent of ExoPlayer's
        // REPEAT_MODE_ONE).
        loopObservers[index] = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        // Uses Stash's own known file duration (from the GraphQL scene metadata) rather than
        // AVPlayerItem.duration: a direct/progressive stream's duration isn't always populated
        // by the time the item becomes ready (can report an indefinite/NaN duration until more
        // of the file has been probed), which silently skipped this seek entirely.
        if randomStartEnabled, let knownDuration = scene.durationSeconds, knownDuration > 0 {
            readyObservers[index] = player.observe(\.status, options: [.new]) { [weak self] observedPlayer, _ in
                guard observedPlayer.status == .readyToPlay else { return }
                let fraction = Double.random(in: 0.15...0.60)
                let target = CMTime(seconds: knownDuration * fraction, preferredTimescale: 600)
                observedPlayer.seek(to: target)
                // Only randomize the very first time this player becomes ready, not on every
                // rebuffer-then-ready cycle.
                self?.readyObservers[index]?.invalidate()
                self?.readyObservers.removeValue(forKey: index)
            }
        }

        return player
    }
}
