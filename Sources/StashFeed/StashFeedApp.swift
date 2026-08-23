import AVFoundation
import SwiftUI

@main
struct StashFeedApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()

    init() {
        // Default category (.soloAmbient) respects the physical silent switch, which is wrong
        // for a video app - .playback matches TikTok/Instagram/YouTube and plays regardless of
        // the switch's position, same as the in-app mute toggle already controls independently.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        appState.handleDidEnterBackground()
                    }
                }
        }
    }
}
