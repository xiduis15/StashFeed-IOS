import Foundation

/// App-wide state that must survive independently of which screen is showing: the settings
/// store, the PIN-lock flag, and the "jump back to the wall" reset signal. Mirrors the
/// ProcessLifecycleOwner-driven state kept in MainActivity.kt's StashFeedRoot.
@MainActor
final class AppState: ObservableObject {
    let settingsStore = ServerSettingsStore()

    @Published var isLocked = false
    @Published var resetSignal = 0

    /// Only lock/reset when there's actually a session to protect (not on the login screen).
    var hasActiveSession = false

    /// Called when the app enters the background: bumps the reset signal so the feed jumps back
    /// to the thumbnail wall and stops playback instead of resuming mid-video, and additionally
    /// locks the app immediately (not on return) if PIN lock is enabled, so nothing is ever
    /// visible for even a frame when the user comes back to it.
    func handleDidEnterBackground() {
        guard hasActiveSession else { return }
        resetSignal += 1
        if settingsStore.isPinLockEnabled {
            isLocked = true
        }
    }
}
