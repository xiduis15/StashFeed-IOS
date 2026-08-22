import Foundation

/// Loads the infinite video feed from Stash using a stable random order: the same
/// "random_<seed>" sort value is reused across pages so scrolling never repeats or skips a
/// scene (see stash/pkg/sqlite/sql.go randomSeedPrefix). Mirrors FeedRepository.kt.
final class FeedRepository {
    private let client: GraphQLClient
    private var seed: Int

    init(client: GraphQLClient) {
        self.client = client
        self.seed = Int.random(in: 0...99_999_999)
    }

    /// Regenerates the random-sort seed. Called whenever the filter or sort option changes so
    /// a new filtered set (or a switch back to `.random`) starts on a fresh stable order,
    /// rather than reusing whatever order the previous filter happened to settle on.
    func resetSeed() {
        seed = Int.random(in: 0...99_999_999)
    }

    func loadPage(
        page: Int,
        perPage: Int = 10,
        sort: SceneSortOption,
        filter: SceneFeedFilter
    ) async throws -> [FeedScene] {
        var variables: [String: Any] = [
            "page": page,
            "perPage": perPage,
            "sort": sort.field ?? "random_\(seed)",
            "direction": sort.direction,
        ]
        if let sceneFilter = Self.sceneFilterDict(filter) {
            variables["sceneFilter"] = sceneFilter
        }

        let data = try await client.execute(
            query: GraphQLQueries.findScenesFeed,
            variables: variables,
            as: FindScenesData.self
        )

        return data.findScenes.scenes.compactMap(Self.toFeedScene)
    }

    func searchTags(query: String, perPage: Int = 20) async throws -> [LibraryOption] {
        let data = try await client.execute(
            query: GraphQLQueries.findTags,
            variables: ["q": query, "perPage": perPage],
            as: FindTagsData.self
        )
        return data.findTags.tags.map { LibraryOption(id: $0.id, name: $0.name) }
    }

    func searchPerformers(query: String, perPage: Int = 20) async throws -> [LibraryOption] {
        let data = try await client.execute(
            query: GraphQLQueries.findPerformers,
            variables: ["q": query, "perPage": perPage],
            as: FindPerformersData.self
        )
        return data.findPerformers.performers.map { LibraryOption(id: $0.id, name: $0.name) }
    }

    /// Builds Stash's `SceneFilterType` dict, only including the fields actually set - `nil`
    /// when the filter is empty, so the `$sceneFilter` GraphQL variable is omitted entirely
    /// rather than sent as an all-null object.
    private static func sceneFilterDict(_ filter: SceneFeedFilter) -> [String: Any]? {
        guard !filter.isEmpty else { return nil }
        var dict: [String: Any] = [:]
        if !filter.titleQuery.isEmpty {
            dict["title"] = ["value": filter.titleQuery, "modifier": "INCLUDES"]
        }
        if let tag = filter.tag {
            dict["tags"] = ["value": [tag.id], "modifier": "INCLUDES"]
        }
        if let performer = filter.performer {
            dict["performers"] = ["value": [performer.id], "modifier": "INCLUDES"]
        }
        return dict
    }

    private static func toFeedScene(_ dto: SceneDTO) -> FeedScene? {
        guard let stream = bestStream(dto) else { return nil }
        let primaryFile = dto.files.first
        let isPortrait = primaryFile.map { $0.height > $0.width } ?? false

        let title: String
        if let dtoTitle = dto.title, !dtoTitle.isEmpty {
            title = dtoTitle
        } else {
            title = "Scène #\(dto.id)"
        }

        return FeedScene(
            id: dto.id,
            title: title,
            streamURL: stream.url,
            streamMimeType: stream.mimeType,
            posterURL: dto.paths?.screenshot.flatMap(URL.init(string:)),
            durationSeconds: primaryFile?.duration,
            resumeTimeSeconds: dto.resume_time,
            isPortrait: isPortrait,
            oCounter: dto.o_counter ?? 0,
            playCount: dto.play_count ?? 0
        )
    }

    private struct PickedStream {
        let url: URL
        let mimeType: String?
    }

    /// Prefers the direct/progressive stream over HLS on iOS: AVFoundation's native HLS parser
    /// has long-standing, inconsistent behaviour around re-applying a manifest URL's query
    /// string (our auth) to the *relative* segment URLs listed inside the .m3u8 playlist -
    /// unlike Android's ExoPlayer, which resolves that correctly (see FeedRepository.kt, which
    /// prefers HLS/DASH). A direct single-file URL has no such relative-resolution step, so it
    /// sidesteps the whole class of bug. Home-LAN bandwidth makes the ABR benefit of HLS less
    /// valuable here anyway.
    private static func bestStream(_ dto: SceneDTO) -> PickedStream? {
        if let streamPath = dto.paths?.stream, let url = URL(string: streamPath) {
            return PickedStream(url: url, mimeType: nil)
        }
        let hls = dto.sceneStreams.first {
            $0.mime_type?.localizedCaseInsensitiveContains("mpegurl") == true
        }
        let dash = dto.sceneStreams.first {
            $0.mime_type?.localizedCaseInsensitiveContains("dash+xml") == true
        }
        if let adaptive = hls ?? dash, let url = URL(string: adaptive.url) {
            return PickedStream(url: url, mimeType: adaptive.mime_type)
        }
        if let first = dto.sceneStreams.first, let url = URL(string: first.url) {
            return PickedStream(url: url, mimeType: first.mime_type)
        }
        return nil
    }
}
