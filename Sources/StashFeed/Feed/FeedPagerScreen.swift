import SwiftUI

/// Full-screen vertical paging feed, starting at `startIndex` (the scene tapped in the grid).
/// Uses iOS 17's native ScrollView paging - equivalent of Compose's VerticalPager. Mirrors the
/// pager portion of FeedScreen.kt. The native navigation bar is hidden (native back button would
/// clash with our own full-screen overlay chrome) but pushing through NavigationStack still
/// gives us the system edge-swipe-to-go-back gesture for free.
struct FeedPagerScreen: View {
    let scenes: [FeedScene]
    let startIndex: Int
    let playerPool: FeedPlayerPool
    let urlSession: URLSession
    let isMuted: Bool
    let onLike: (String) -> Void
    let onDecrementLike: (String) -> Void
    let onToggleMute: () -> Void
    let onSaveActivity: (String, Double, Double) -> Void
    let onPlayCounted: (String) -> Void
    let onApproachingEnd: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scrollPosition: Int?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(scenes.enumerated()), id: \.element.id) { index, scene in
                        FeedVideoPage(
                            scene: scene,
                            isActive: scrollPosition == index,
                            pageIndex: index,
                            playerPool: playerPool,
                            urlSession: urlSession,
                            isMuted: isMuted,
                            onLike: { onLike(scene.id) },
                            onDecrementLike: { onDecrementLike(scene.id) },
                            onToggleMute: onToggleMute,
                            onSaveActivity: { resume, duration in onSaveActivity(scene.id, resume, duration) },
                            onPlayCounted: { onPlayCounted(scene.id) }
                        )
                        .containerRelativeFrame(.vertical)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollPosition)
            .scrollTargetBehavior(.paging)
            .ignoresSafeArea()

            Button {
                playerPool.releaseAll()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
            }
            .padding(.top, 8)
            .padding(.leading, 4)
        }
        .onAppear {
            scrollPosition = startIndex
        }
        .onDisappear {
            playerPool.releaseAll()
        }
        .onChange(of: scrollPosition) { _, newValue in
            guard let newValue else { return }
            playerPool.trimAround(currentIndex: newValue)
            if newValue >= scenes.count - 3 {
                onApproachingEnd(newValue)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}
