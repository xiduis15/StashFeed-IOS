import SwiftUI

private enum RootState {
    case loading
    case needsLogin
    case connected
}

/// Mirrors StashFeedRoot in MainActivity.kt: NeedsLogin <-> Connected, with the app-wide PIN
/// lock overlay drawn on top of whatever is showing.
struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var state: RootState = .loading
    @State private var session: StashSession?
    @State private var viewModel: FeedViewModel?

    var body: some View {
        ZStack {
            switch state {
            case .loading:
                Color.black.ignoresSafeArea()
            case .needsLogin:
                ServerSettingsScreen(settingsStore: appState.settingsStore) { newSession in
                    connect(newSession)
                }
            case .connected:
                if let viewModel {
                    FeedRootScreen(
                        viewModel: viewModel,
                        settingsStore: appState.settingsStore,
                        isLocked: appState.isLocked,
                        resetSignal: appState.resetSignal,
                        onLogout: { logout() },
                        onLockNow: { appState.isLocked = true }
                    )
                }
            }

            if appState.isLocked, case .connected = state {
                AppLockScreen(expectedHash: appState.settingsStore.pinHash ?? "") {
                    appState.isLocked = false
                }
            }
        }
        .task {
            if let credentials = appState.settingsStore.getCredentials(),
               let restoredSession = StashSession.create(credentials: credentials) {
                connect(restoredSession)
                // A fresh process (app was killed, not just backgrounded) starts with
                // AppState.isLocked = false - without this check, restoring an existing
                // session at cold start would skip the PIN entirely even when it's enabled.
                if appState.settingsStore.isPinLockEnabled {
                    appState.isLocked = true
                }
            } else {
                state = .needsLogin
            }
        }
    }

    private func connect(_ newSession: StashSession) {
        session = newSession
        viewModel = FeedViewModel(session: newSession, settingsStore: appState.settingsStore)
        state = .connected
        appState.hasActiveSession = true
    }

    private func logout() {
        viewModel?.playerPool.releaseAll()
        appState.settingsStore.clear()
        appState.isLocked = false
        appState.hasActiveSession = false
        viewModel = nil
        session = nil
        state = .needsLogin
    }
}
