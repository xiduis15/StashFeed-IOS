import AVFoundation
import SwiftUI

private enum PauseIndicatorPhase: Equatable {
    case hidden
    case centered
    case corner
}

/// One full-screen item of the feed: video player + poster + O-count/mute controls + progress
/// bar. Mirrors FeedVideoPage.kt (minus the tap-zone/O-count-buttons rework, iOS-only so far).
struct FeedVideoPage: View {
    let scene: FeedScene
    let isActive: Bool
    let pageIndex: Int
    let playerPool: FeedPlayerPool
    let urlSession: URLSession
    let isMuted: Bool
    let onLike: () -> Void
    let onDecrementLike: () -> Void
    let onToggleMute: () -> Void
    let onSaveActivity: (Double, Double) -> Void
    let onPlayCounted: () -> Void

    @StateObject private var observer = PlayerObserver()
    @State private var showLikeBurst = false
    @State private var showSeekBackward = false
    @State private var showSeekForward = false
    @State private var showCropToggleBurst = false
    @State private var isCroppedToFill: Bool
    @State private var pauseIndicatorPhase: PauseIndicatorPhase = .hidden

    init(
        scene: FeedScene,
        isActive: Bool,
        pageIndex: Int,
        playerPool: FeedPlayerPool,
        urlSession: URLSession,
        isMuted: Bool,
        onLike: @escaping () -> Void,
        onDecrementLike: @escaping () -> Void,
        onToggleMute: @escaping () -> Void,
        onSaveActivity: @escaping (Double, Double) -> Void,
        onPlayCounted: @escaping () -> Void
    ) {
        self.scene = scene
        self.isActive = isActive
        self.pageIndex = pageIndex
        self.playerPool = playerPool
        self.urlSession = urlSession
        self.isMuted = isMuted
        self.onLike = onLike
        self.onDecrementLike = onDecrementLike
        self.onToggleMute = onToggleMute
        self.onSaveActivity = onSaveActivity
        self.onPlayCounted = onPlayCounted
        // Portrait videos start filling the screen (crop), landscape ones start fitted -
        // matches the previous fixed behaviour; the center double-tap (see `handleDoubleTap`)
        // now lets the viewer flip this per video.
        _isCroppedToFill = State(initialValue: scene.isPortrait)
    }

    private var player: AVPlayer {
        playerPool.player(for: pageIndex, scene: scene)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                if let posterURL = scene.posterURL {
                    AuthenticatedAsyncImage(
                        url: posterURL,
                        urlSession: urlSession,
                        contentMode: isCroppedToFill ? .fill : .fit
                    )
                    .clipped()
                }

                PlayerLayerView(
                    player: player,
                    videoGravity: isCroppedToFill ? .resizeAspectFill : .resizeAspect
                )

                if let errorMessage = observer.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(24)
                } else if observer.isBuffering {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.4)
                }

                if showLikeBurst {
                    Image(systemName: "drop.fill")
                        .resizable()
                        .frame(width: 96, height: 96)
                        .foregroundColor(.white)
                }
                if showSeekBackward {
                    seekBurst(systemName: "gobackward.10", alignment: .leading)
                }
                if showSeekForward {
                    seekBurst(systemName: "goforward.10", alignment: .trailing)
                }
                if showCropToggleBurst {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .foregroundColor(.white)
                }
                pauseIndicator
                    .animation(.easeInOut(duration: 0.25), value: pauseIndicatorPhase)

                actionColumn
                titleLabel

                VStack {
                    Spacer()
                    SeekBar(
                        progressFraction: observer.progressFraction,
                        durationSeconds: scene.durationSeconds
                    ) { fraction in
                        seek(toFraction: fraction)
                    }
                    // The page ignores safe areas (full-bleed video), so without this the bar's
                    // touch target sits right in the home-indicator swipe zone - pulled well
                    // clear of it (closer to where Instagram Reels sits its own bar), on top of
                    // `.defersSystemGestures(on: .bottom)` below as a second line of defence.
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 28)
                }
            }
            .clipped()
            .contentShape(Rectangle())
            // Deliberately `.onTapGesture` (not a hand-composed `.gesture(SpatialTapGesture...)`)
            // - the composed form captures every tap across its whole contentShape to
            // disambiguate single/double tap, which silently ate taps meant for the actionColumn
            // buttons underneath. `.onTapGesture` doesn't have that problem (children win as
            // before) and still exposes the location via this overload.
            .onTapGesture(count: 2) { location in
                handleDoubleTap(at: location.x, width: geometry.size.width)
            }
            .onTapGesture(count: 1) {
                togglePlayPause()
            }
        }
        .onAppear {
            observer.attach(to: player, knownDuration: scene.durationSeconds)
            // .onChange(of: isActive) below only fires on a *change* - the very first page
            // (already active the moment it appears) would otherwise never get an initial
            // play() call, requiring a manual tap to start.
            if isActive {
                player.play()
            }
        }
        .onDisappear {
            observer.detach()
        }
        .onChange(of: isActive) { _, active in
            if active {
                player.play()
            } else {
                player.pause()
                let positionSeconds = player.currentTime().seconds
                if positionSeconds.isFinite, positionSeconds > 0 {
                    onSaveActivity(positionSeconds, scene.durationSeconds ?? 0)
                }
            }
        }
        .task(id: isActive) {
            guard isActive else { return }
            do {
                try await Task.sleep(nanoseconds: 10_000_000_000)
            } catch {
                return
            }
            onPlayCounted()
        }
        // Auto-cancels (and never reaches the `.corner` transition) if pauseIndicatorPhase
        // changes before the 5s elapse - e.g. the viewer resumes playback, which resets it to
        // `.hidden` and invalidates this task since its id changed.
        .task(id: pauseIndicatorPhase) {
            guard pauseIndicatorPhase == .centered else { return }
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                return
            }
            pauseIndicatorPhase = .corner
        }
    }

    private var actionColumn: some View {
        VStack(spacing: 8) {
            Spacer()

            Button(action: onToggleMute) {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(.bottom, 12)

            Button {
                onLike()
                triggerBurst($showLikeBurst, durationNanoseconds: 700_000_000)
            } label: {
                Image(systemName: "drop.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            Text("\(scene.oCounter)")
                .foregroundColor(.white)

            Button(action: onDecrementLike) {
                Image(systemName: "drop")
                    .font(.title2)
                    .foregroundColor(.white)
            }

            Image(systemName: "eye.fill")
                .font(.title3)
                .foregroundColor(.white)
                .padding(.top, 12)
            Text("\(scene.playCount)")
                .foregroundColor(.white)
                .padding(.bottom, 64)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .padding(.trailing, 16)
    }

    private var titleLabel: some View {
        VStack {
            Spacer()
            HStack {
                Text(scene.title)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.leading, 16)
            .padding(.trailing, 80)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private func seekBurst(systemName: String, alignment: HorizontalAlignment) -> some View {
        HStack {
            if alignment == .trailing { Spacer() }
            Image(systemName: systemName)
                .resizable()
                .frame(width: 64, height: 64)
                .foregroundColor(.white)
                .padding(.horizontal, 48)
            if alignment == .leading { Spacer() }
        }
    }

    /// Left third = -10s, right third = +10s, center third = flip crop/fit (see `init`).
    /// The O-count +1 that used to live on the center double-tap is now the dedicated button
    /// in `actionColumn`.
    private func handleDoubleTap(at x: CGFloat, width: CGFloat) {
        if x < width / 3 {
            seek(by: -10)
            triggerBurst($showSeekBackward)
        } else if x > width * 2 / 3 {
            seek(by: 10)
            triggerBurst($showSeekForward)
        } else {
            isCroppedToFill.toggle()
            triggerBurst($showCropToggleBurst)
        }
    }

    private func togglePlayPause() {
        if player.rate > 0 {
            player.pause()
            pauseIndicatorPhase = .centered
        } else {
            player.play()
            pauseIndicatorPhase = .hidden
        }
    }

    @ViewBuilder
    private var pauseIndicator: some View {
        switch pauseIndicatorPhase {
        case .hidden:
            EmptyView()
        case .centered:
            Image(systemName: "pause.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
                .padding(28)
                .background(Circle().fill(Color.black.opacity(0.35)))
                .transition(.opacity)
        case .corner:
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "pause.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(8)
                        .background(Circle().fill(Color.black.opacity(0.3)))
                }
                .padding(.top, 12)
                .padding(.trailing, 12)
                Spacer()
            }
            .transition(.opacity)
        }
    }

    private func triggerBurst(_ flag: Binding<Bool>, durationNanoseconds: UInt64 = 500_000_000) {
        flag.wrappedValue = true
        Task {
            try? await Task.sleep(nanoseconds: durationNanoseconds)
            flag.wrappedValue = false
        }
    }

    private func seek(toFraction fraction: Double) {
        guard let duration = scene.durationSeconds ?? player.currentItem?.duration.seconds,
              duration.isFinite, duration > 0 else { return }
        let target = CMTime(seconds: duration * fraction, preferredTimescale: 600)
        player.seek(to: target)
        observer.progressFraction = fraction
    }

    private func seek(by deltaSeconds: Double) {
        guard let duration = scene.durationSeconds ?? player.currentItem?.duration.seconds,
              duration.isFinite, duration > 0 else { return }
        let currentSeconds = player.currentTime().seconds
        let baseSeconds = currentSeconds.isFinite ? currentSeconds : 0
        let targetSeconds = min(max(baseSeconds + deltaSeconds, 0), duration)
        player.seek(to: CMTime(seconds: targetSeconds, preferredTimescale: 600))
        observer.progressFraction = targetSeconds / duration
    }
}
