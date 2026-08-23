import Foundation

/// Mirrors FeedViewModel.kt: owns the scenes list, pagination (incl. the active filter/sort),
/// the player pool, and every like/view-count action (with optimistic UI + rollback on failure
/// where it matters).
@MainActor
final class FeedViewModel: ObservableObject {
    @Published private(set) var scenes: [FeedScene] = []
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var randomStartEnabled: Bool
    @Published var isMuted: Bool
    @Published private(set) var filter = SceneFeedFilter()
    @Published private(set) var sortOption: SceneSortOption = .random

    let playerPool: FeedPlayerPool

    private let session: StashSession
    private let settingsStore: ServerSettingsStore
    private var nextPage = 1
    private var endReached = false

    init(session: StashSession, settingsStore: ServerSettingsStore) {
        self.session = session
        self.settingsStore = settingsStore
        self.playerPool = FeedPlayerPool(urlSession: session.urlSession)
        self.randomStartEnabled = settingsStore.randomStartEnabled
        self.playerPool.randomStartEnabled = settingsStore.randomStartEnabled
        self.isMuted = settingsStore.isMuted
        self.playerPool.isMuted = settingsStore.isMuted
        loadNextPage()
    }

    func toggleRandomStart() {
        let newValue = !randomStartEnabled
        randomStartEnabled = newValue
        playerPool.randomStartEnabled = newValue
        settingsStore.setRandomStartEnabled(newValue)
    }

    func toggleMute() {
        let newValue = !isMuted
        isMuted = newValue
        playerPool.isMuted = newValue
        settingsStore.setMuted(newValue)
    }

    func updateFilter(_ newFilter: SceneFeedFilter) {
        guard newFilter != filter else { return }
        filter = newFilter
        restartFeed()
    }

    func updateSort(_ newSort: SceneSortOption) {
        // `.random` is special-cased: re-picking it while it's already the active sort is how
        // the user asks for a fresh shuffle (the seed otherwise stays fixed for the whole
        // session - see FeedRepository.resetSeed, only called from restartFeed below). Every
        // other sort is deterministic, so re-picking an unchanged one would be a no-op reload.
        guard newSort != sortOption || newSort == .random else { return }
        sortOption = newSort
        restartFeed()
    }

    func searchTags(query: String) async -> [LibraryOption] {
        (try? await session.feedRepository.searchTags(query: query)) ?? []
    }

    func searchPerformers(query: String) async -> [LibraryOption] {
        (try? await session.feedRepository.searchPerformers(query: query)) ?? []
    }

    /// Clears the current page/scene list and starts loading fresh - used whenever the filter
    /// or sort changes, so the wall doesn't show a mix of scenes matching two different
    /// filters/sorts.
    private func restartFeed() {
        scenes = []
        nextPage = 1
        endReached = false
        session.feedRepository.resetSeed()
        loadNextPage()
    }

    func loadNextPage() {
        guard !endReached, !isLoadingMore else { return }
        isLoadingMore = true
        errorMessage = nil
        Task {
            do {
                let newScenes = try await session.feedRepository.loadPage(
                    page: nextPage,
                    sort: sortOption,
                    filter: filter
                )
                if newScenes.isEmpty {
                    endReached = true
                } else {
                    nextPage += 1
                    scenes.append(contentsOf: newScenes)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingMore = false
        }
    }

    func onApproachingEnd(index: Int) {
        if index >= scenes.count - 3 {
            loadNextPage()
        }
    }

    /// Double-tap "like" -> increments Stash's O-counter for the scene.
    func toggleLike(sceneId: String) {
        updateScene(sceneId) { $0.oCounter += 1 }
        Task {
            _ = try? await session.actionsRepository.addO(sceneId: sceneId)
        }
    }

    /// Undo/error tap on the drop icon -> decrements the O-counter (never below 0).
    func decrementLike(sceneId: String) {
        guard let scene = scenes.first(where: { $0.id == sceneId }), scene.oCounter > 0 else { return }
        updateScene(sceneId) { $0.oCounter -= 1 }
        Task {
            do {
                _ = try await session.actionsRepository.deleteO(sceneId: sceneId)
            } catch {
                updateScene(sceneId) { $0.oCounter += 1 }
            }
        }
    }

    /// Called once a scene has been on screen for more than 10 seconds -> counts as a view.
    func countPlay(sceneId: String) {
        updateScene(sceneId) { $0.playCount += 1 }
        Task {
            _ = try? await session.actionsRepository.addPlay(sceneId: sceneId)
        }
    }

    func saveActivity(sceneId: String, resumeTimeSeconds: Double, playDurationSeconds: Double) {
        Task {
            try? await session.actionsRepository.saveActivity(
                sceneId: sceneId,
                resumeTimeSeconds: resumeTimeSeconds,
                playDurationSeconds: playDurationSeconds
            )
        }
    }

    private func updateScene(_ sceneId: String, _ mutate: (inout FeedScene) -> Void) {
        guard let index = scenes.firstIndex(where: { $0.id == sceneId }) else { return }
        mutate(&scenes[index])
    }
}
