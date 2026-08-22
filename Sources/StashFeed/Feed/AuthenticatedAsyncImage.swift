import SwiftUI

/// SwiftUI's built-in AsyncImage can't attach custom headers, but Stash's poster paths only
/// accept the "ApiKey" header (see StashURLSessionFactory) - this loads through the shared
/// authenticated URLSession instead. Equivalent role to Coil + LocalImageLoader on Android.
struct AuthenticatedAsyncImage: View {
    let url: URL?
    let urlSession: URLSession
    var contentMode: ContentMode = .fill

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color.clear
            }
        }
        .task(id: url) {
            uiImage = nil
            guard let url else { return }
            do {
                let (data, _) = try await urlSession.data(from: url)
                uiImage = UIImage(data: data)
            } catch {
                // Best-effort: leave the placeholder empty on failure.
            }
        }
    }
}
