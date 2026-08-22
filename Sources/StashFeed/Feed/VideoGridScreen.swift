import SwiftUI

/// Instagram-Explore-style scrollable thumbnail wall; tapping a cell opens the full-screen feed.
/// Mirrors VideoGridScreen.kt.
///
/// Cell size is computed once from the available width and applied as an explicit fixed frame
/// (`GridItem(.fixed(...))`), rather than letting each cell size itself via `.aspectRatio` -
/// with async-loaded poster images, per-cell aspect-ratio layout renegotiates at a different
/// moment for every cell as its image finishes loading, which is what produced the
/// differently-sized/overlapping thumbnails.
struct VideoGridScreen: View {
    let scenes: [FeedScene]
    let isLoadingMore: Bool
    let urlSession: URLSession
    let onSceneTap: (Int) -> Void
    let onApproachingEnd: (Int) -> Void

    private let columnCount = 3
    private let spacing: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            let itemSize = (geometry.size.width - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
            let columns = Array(repeating: GridItem(.fixed(itemSize), spacing: spacing), count: columnCount)

            ScrollView {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(Array(scenes.enumerated()), id: \.element.id) { index, scene in
                        GridThumbnail(scene: scene, urlSession: urlSession, size: itemSize)
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
        }
        .background(Color.black.ignoresSafeArea())
    }
}

private struct GridThumbnail: View {
    let scene: FeedScene
    let urlSession: URLSession
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.gray.opacity(0.3)
            AuthenticatedAsyncImage(url: scene.posterURL, urlSession: urlSession, contentMode: .fill)
                .frame(width: size, height: size)
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            Text(scene.title)
                .font(.caption2)
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(4)
        }
        .frame(width: size, height: size)
        .clipped()
    }
}
