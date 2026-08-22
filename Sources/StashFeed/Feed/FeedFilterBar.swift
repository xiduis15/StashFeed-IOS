import SwiftUI

enum LibraryPickerKind: Identifiable, Equatable {
    case tag
    case performer

    var id: Int {
        switch self {
        case .tag: return 0
        case .performer: return 1
        }
    }

    var title: String {
        switch self {
        case .tag: return "Filtrer par tag"
        case .performer: return "Filtrer par performer"
        }
    }
}

/// Persistent filter/sort bar pinned above the video wall (see VideoGridScreen and
/// FeedRootScreen) - stays outside the wall's ScrollView so it never scrolls away, including
/// while a filter/sort change is reloading the grid.
struct FeedFilterBar: View {
    let filter: SceneFeedFilter
    let sortOption: SceneSortOption
    let onFilterChange: (SceneFeedFilter) -> Void
    let onSortChange: (SceneSortOption) -> Void
    let searchTags: (String) async -> [LibraryOption]
    let searchPerformers: (String) async -> [LibraryOption]

    @State private var titleText = ""
    @State private var pickerKind: LibraryPickerKind?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                TextField("Titre...", text: $titleText)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                if !titleText.isEmpty {
                    Button {
                        titleText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.12))
            .cornerRadius(10)

            HStack(spacing: 8) {
                FilterChip(
                    title: filter.tag?.name ?? "Tag",
                    isActive: filter.tag != nil,
                    onClear: filter.tag != nil ? { onFilterChange(updating(filter) { $0.tag = nil }) } : nil,
                    onTap: { pickerKind = .tag }
                )
                FilterChip(
                    title: filter.performer?.name ?? "Performer",
                    isActive: filter.performer != nil,
                    onClear: filter.performer != nil ? { onFilterChange(updating(filter) { $0.performer = nil }) } : nil,
                    onTap: { pickerKind = .performer }
                )

                Spacer()

                Menu {
                    ForEach(SceneSortOption.allCases, id: \.self) { option in
                        Button {
                            onSortChange(option)
                        } label: {
                            if option == sortOption {
                                Label(option.label, systemImage: "checkmark")
                            } else {
                                Text(option.label)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black)
        .task(id: titleText) {
            do {
                try await Task.sleep(nanoseconds: 400_000_000)
            } catch {
                return
            }
            onFilterChange(updating(filter) { $0.titleQuery = titleText })
        }
        .sheet(item: $pickerKind) { kind in
            TagPerformerPickerSheet(
                kind: kind,
                search: kind == .tag ? searchTags : searchPerformers
            ) { option in
                switch kind {
                case .tag: onFilterChange(updating(filter) { $0.tag = option })
                case .performer: onFilterChange(updating(filter) { $0.performer = option })
                }
                pickerKind = nil
            }
        }
    }

    private func updating(_ filter: SceneFeedFilter, _ mutate: (inout SceneFeedFilter) -> Void) -> SceneFeedFilter {
        var updated = filter
        mutate(&updated)
        return updated
    }
}

private struct FilterChip: View {
    let title: String
    let isActive: Bool
    let onClear: (() -> Void)?
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onTap) {
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.white)
            }
            if let onClear {
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color.white.opacity(0.3) : Color.white.opacity(0.12))
        .cornerRadius(14)
    }
}
