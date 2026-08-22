import Foundation

/// A tag or performer picked from Stash's library via `findTags`/`findPerformers`.
struct LibraryOption: Identifiable, Equatable {
    let id: String
    let name: String
}

/// Content filter applied to the video wall - all set fields are combined with AND by
/// Stash's `SceneFilterType` (see FeedRepository.loadPage). One tag and one performer at a
/// time, deliberately - not a multi-select.
struct SceneFeedFilter: Equatable {
    var titleQuery: String = ""
    var tag: LibraryOption?
    var performer: LibraryOption?

    var isEmpty: Bool {
        titleQuery.isEmpty && tag == nil && performer == nil
    }
}
