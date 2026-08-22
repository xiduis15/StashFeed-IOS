import SwiftUI

private enum SettingsFlow: Identifiable {
    case settingUpPin
    case confirmingDisablePin

    var id: Int {
        switch self {
        case .settingUpPin: return 0
        case .confirmingDisablePin: return 1
        }
    }
}

/// Mirrors FeedScreen.kt: grid <-> pager navigation, plus a persistent "..." menu (démarrage
/// aléatoire, PIN, verrouiller maintenant, déconnexion) drawn as an overlay so it stays visible
/// on both the wall and the full-screen player.
struct FeedRootScreen: View {
    @ObservedObject var viewModel: FeedViewModel
    let settingsStore: ServerSettingsStore
    let isLocked: Bool
    let resetSignal: Int
    let onLogout: () -> Void
    let onLockNow: () -> Void

    @State private var path = NavigationPath()
    @State private var settingsFlow: SettingsFlow?
    @State private var pinLockEnabled: Bool
    @State private var menuExpanded = false

    init(
        viewModel: FeedViewModel,
        settingsStore: ServerSettingsStore,
        isLocked: Bool,
        resetSignal: Int,
        onLogout: @escaping () -> Void,
        onLockNow: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.settingsStore = settingsStore
        self.isLocked = isLocked
        self.resetSignal = resetSignal
        self.onLogout = onLogout
        self.onLockNow = onLockNow
        _pinLockEnabled = State(initialValue: settingsStore.isPinLockEnabled)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationStack(path: $path) {
                VStack(spacing: 0) {
                    FeedFilterBar(
                        filter: viewModel.filter,
                        sortOption: viewModel.sortOption,
                        onFilterChange: { viewModel.updateFilter($0) },
                        onSortChange: { viewModel.updateSort($0) },
                        searchTags: { await viewModel.searchTags(query: $0) },
                        searchPerformers: { await viewModel.searchPerformers(query: $0) }
                    )
                    Group {
                        if viewModel.scenes.isEmpty {
                            loadingOrError
                        } else {
                            VideoGridScreen(
                                scenes: viewModel.scenes,
                                isLoadingMore: viewModel.isLoadingMore,
                                urlSession: viewModel.playerPool.urlSession,
                                onSceneTap: { index in path.append(index) },
                                onApproachingEnd: { index in viewModel.onApproachingEnd(index: index) }
                            )
                        }
                    }
                }
                .navigationDestination(for: Int.self) { startIndex in
                    FeedPagerScreen(
                        scenes: viewModel.scenes,
                        startIndex: startIndex,
                        playerPool: viewModel.playerPool,
                        urlSession: viewModel.playerPool.urlSession,
                        isMuted: viewModel.isMuted,
                        onLike: { viewModel.toggleLike(sceneId: $0) },
                        onDecrementLike: { viewModel.decrementLike(sceneId: $0) },
                        onToggleMute: { viewModel.toggleMute() },
                        onSaveActivity: { id, resume, duration in
                            viewModel.saveActivity(sceneId: id, resumeTimeSeconds: resume, playDurationSeconds: duration)
                        },
                        onPlayCounted: { viewModel.countPlay(sceneId: $0) },
                        onApproachingEnd: { index in viewModel.onApproachingEnd(index: index) }
                    )
                }
            }
            .tint(.white)

            settingsMenu
                .padding(.top, 8)
                .padding(.trailing, 8)
        }
        .fullScreenCover(item: $settingsFlow) { flow in
            switch flow {
            case .settingUpPin:
                PinSetupScreen(
                    onPinConfirmed: { hash in
                        settingsStore.setPin(hash: hash)
                        pinLockEnabled = true
                        settingsFlow = nil
                    },
                    onCancel: { settingsFlow = nil }
                )
            case .confirmingDisablePin:
                AppLockScreen(
                    expectedHash: settingsStore.pinHash ?? "",
                    onUnlocked: {
                        settingsStore.disablePinLock()
                        pinLockEnabled = false
                        settingsFlow = nil
                    },
                    onCancel: { settingsFlow = nil }
                )
            }
        }
        .onChange(of: resetSignal) { _, _ in
            path = NavigationPath()
            viewModel.playerPool.releaseAll()
        }
        .onChange(of: isLocked) { _, locked in
            if locked {
                settingsFlow = nil
            }
        }
    }

    private var loadingOrError: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.white)
                    .padding(24)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
    }

    private var appVersionText: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Version \(shortVersion) (\(buildNumber)) · \(BuildInfo.gitCommitHash)"
    }

    private var settingsMenu: some View {
        Menu {
            Text(appVersionText)

            Divider()

            Button {
                viewModel.toggleRandomStart()
            } label: {
                Label(
                    viewModel.randomStartEnabled ? "Démarrage aléatoire : activé" : "Démarrage aléatoire : désactivé",
                    systemImage: "shuffle"
                )
            }
            Button {
                settingsFlow = pinLockEnabled ? .confirmingDisablePin : .settingUpPin
            } label: {
                Label(
                    pinLockEnabled ? "Désactiver le code PIN" : "Activer le code PIN",
                    systemImage: pinLockEnabled ? "lock.open" : "lock"
                )
            }
            if pinLockEnabled {
                Button {
                    onLockNow()
                } label: {
                    Label("Verrouiller maintenant", systemImage: "lock")
                }
            }
            Button(role: .destructive) {
                onLogout()
            } label: {
                Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.title2)
                .foregroundColor(.white)
        }
    }
}
