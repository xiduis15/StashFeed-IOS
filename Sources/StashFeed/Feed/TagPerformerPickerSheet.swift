import SwiftUI

/// Search-with-autocomplete sheet reused for both tag and performer filtering - queries
/// Stash's findTags/findPerformers (via the closure passed in) as the user types, debounced
/// the same way as the title field in FeedFilterBar.
struct TagPerformerPickerSheet: View {
    let kind: LibraryPickerKind
    let search: (String) async -> [LibraryOption]
    let onPick: (LibraryOption) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [LibraryOption] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            List(results) { option in
                Button(option.name) {
                    onPick(option)
                }
                .foregroundColor(.white)
                .listRowBackground(Color.black)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .overlay {
                if !query.isEmpty, !isSearching, results.isEmpty {
                    Text("Aucun résultat")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task(id: query) {
            guard !query.isEmpty else {
                results = []
                return
            }
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
            } catch {
                return
            }
            isSearching = true
            results = await search(query)
            isSearching = false
        }
    }
}
