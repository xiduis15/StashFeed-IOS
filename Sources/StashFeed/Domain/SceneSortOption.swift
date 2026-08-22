import Foundation

/// Sort applied to the video wall. `.random` is handled separately by FeedRepository
/// (stable `random_<seed>` sort, reused across pages); every other case maps directly to a
/// Stash `sort` field + `direction`, both verified against `pkg/sqlite/scene.go`.
enum SceneSortOption: CaseIterable, Hashable {
    case random
    case dateAddedDesc
    case dateAddedAsc
    case titleAsc
    case titleDesc
    case oCounterDesc
    case oCounterAsc
    case playCountDesc
    case playCountAsc

    var label: String {
        switch self {
        case .random: return "Aléatoire"
        case .dateAddedDesc: return "Date d'ajout (plus récent)"
        case .dateAddedAsc: return "Date d'ajout (plus ancien)"
        case .titleAsc: return "Titre (A→Z)"
        case .titleDesc: return "Titre (Z→A)"
        case .oCounterDesc: return "O-counter (plus)"
        case .oCounterAsc: return "O-counter (moins)"
        case .playCountDesc: return "Vues (plus)"
        case .playCountAsc: return "Vues (moins)"
        }
    }

    /// `nil` for `.random`, which FeedRepository handles via its own `random_<seed>` string.
    var field: String? {
        switch self {
        case .random: return nil
        case .dateAddedDesc, .dateAddedAsc: return "created_at"
        case .titleAsc, .titleDesc: return "title"
        case .oCounterDesc, .oCounterAsc: return "o_counter"
        case .playCountDesc, .playCountAsc: return "play_count"
        }
    }

    var direction: String {
        switch self {
        // Matches the direction the app already used for random pagination.
        case .random: return "ASC"
        case .dateAddedDesc, .oCounterDesc, .playCountDesc, .titleDesc: return "DESC"
        case .dateAddedAsc, .titleAsc, .oCounterAsc, .playCountAsc: return "ASC"
        }
    }
}
