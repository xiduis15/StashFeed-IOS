import SwiftUI

/// Instagram-Explore-style scrollable thumbnail wall; tapping a cell opens the full-screen feed.
/// Mirrors VideoGridScreen.kt.
struct VideoGridScreen: View {
    let scenes: [FeedScene]
    let isLoadingMore: Bool
    let urlSession: URLSession
    let onSceneTap: (Int) -> Void
    let onApproachingEnd: (Int) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(scenes.enumerated()), id: \.element.id) { index, scene in
                    GridThumbnail(scene: scene, urlSession: urlSession)
                        .onTapGesture { onSceneTap(index) }
                        .onAppear {
                            if index >= scenes.count - 6 {
                                onApproachingEnd(index)
                            }
                        }
                }
            }

            if isLoadingMore {
                ProgressView()
                    .tint(.white)
                    .padding()
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

private struct GridThumbnail: View {
    let scene: FeedScene
    let urlSession: URLSession

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.gray.opacity(0.3)
            AuthenticatedAsyncImage(url: scene.posterURL, urlSession: urlSession, contentMode: .fill)
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            Text(scene.title)
                .font(.caption2)
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(4)
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
    }
}
