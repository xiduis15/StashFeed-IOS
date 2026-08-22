import Foundation

/// UI/domain-level representation of a Stash scene shown in the vertical feed.
struct FeedScene: Identifiable, Equatable {
    let id: String
    let title: String
    let streamURL: URL
    let streamMimeType: String?
    let posterURL: URL?
    let durationSeconds: Double?
    let resumeTimeSeconds: Double?
    /// True when the video is taller than wide -> fill the screen (crop). Unknown -> false (fit).
    let isPortrait: Bool
    var organized: Bool
    var oCounter: Int
    var playCount: Int
}
