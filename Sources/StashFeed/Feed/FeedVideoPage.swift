import AVFoundation
import SwiftUI

/// One full-screen item of the feed: video player + poster + like/bookmark + progress bar.
/// Mirrors FeedVideoPage.kt.
struct FeedVideoPage: View {
    let scene: FeedScene
    let isActive: Bool
    let pageIndex: Int
    let playerPool: FeedPlayerPool
    let urlSession: URLSession
    let onLike: () -> Void
    let onDecrementLike: () -> Void
    let onBookmark: () -> Void
    let onSaveActivity: (Double, Double) -> Void
    let onPlayCounted: () -> Void

    @StateObject private var observer = PlayerObserver()
    @State private var showLikeBurst = false

    private var player: AVPlayer {
        playerPool.player(for: pageIndex, scene: scene)
    }

    var body: some View {
        ZStack {
            Color.black

            if let posterURL = scene.posterURL {
                AuthenticatedAsyncImage(
                    url: posterURL,
                    urlSession: urlSession,
                    contentMode: scene.isPortrait ? .fill : .fit
                )
                .clipped()
            }

            PlayerLayerView(
                player: player,
                videoGravity: scene.isPortrait ? .resizeAspectFill : .resizeAspect
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

            actionColumn
            titleLabel

            VStack {
                Spacer()
                SeekBar(progressFraction: observer.progressFraction) { fraction in
                    seek(toFraction: fraction)
                }
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onLike()
            showLikeBurst = true
            Task {
                try? await Task.sleep(nanoseconds: 700_000_000)
                showLikeBurst = false
            }
        }
        .onTapGesture(count: 1) {
            if player.rate > 0 {
                player.pause()
            } else {
                player.play()
            }
        }
        .onAppear {
            observer.attach(to: player)
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
                let durationSeconds = player.currentItem?.duration.seconds ?? 0
                if positionSeconds.isFinite, positionSeconds > 0 {
                    onSaveActivity(positionSeconds, durationSeconds.isFinite ? durationSeconds : 0)
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
    }

    private var actionColumn: some View {
        VStack(spacing: 8) {
            Spacer()
            Button(action: onDecrementLike) {
                Image(systemName: "drop.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            Text("\(scene.oCounter)")
                .foregroundColor(.white)

            Image(systemName: "eye.fill")
                .font(.title3)
                .foregroundColor(.white)
                .padding(.top, 12)
            Text("\(scene.playCount)")
                .foregroundColor(.white)

            Button(action: onBookmark) {
                Image(systemName: scene.organized ? "bookmark.fill" : "bookmark")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(.top, 12)
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

    private func seek(toFraction fraction: Double) {
        guard let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 else { return }
        let target = CMTime(seconds: duration * fraction, preferredTimescale: 600)
        player.seek(to: target)
        observer.progressFraction = fraction
    }
}
