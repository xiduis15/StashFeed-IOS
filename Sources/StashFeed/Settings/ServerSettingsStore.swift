import Foundation

/// Stores the Stash server URL and the "random start" preference in UserDefaults (not
/// sensitive), and the API key + PIN lock state in the Keychain (sensitive: full read/write
/// access to the library, or bypasses the privacy lock). Mirrors ServerSettingsStore.kt.
@MainActor
final class ServerSettingsStore: ObservableObject {
    private let baseURLKey = "base_url"
    private let randomStartKey = "random_start_enabled"
    private let apiKeyKeychainKey = "api_key"
    private let pinHashKeychainKey = "pin_hash"
    private let pinEnabledKeychainKey = "pin_lock_enabled"

    private let defaults = UserDefaults.standard

    @Published var randomStartEnabled: Bool

    init() {
        randomStartEnabled = UserDefaults.standard.bool(forKey: "random_start_enabled")
    }

    func getCredentials() -> ServerCredentials? {
        guard let baseURL = defaults.string(forKey: baseURLKey),
              let apiKey = KeychainStore.get(forKey: apiKeyKeychainKey) else {
            return nil
        }
        return ServerCredentials(baseURL: baseURL, apiKey: apiKey)
    }

    func saveCredentials(baseURL: String, apiKey: String) {
        let normalized = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        defaults.set(normalized, forKey: baseURLKey)
        KeychainStore.set(apiKey, forKey: apiKeyKeychainKey)
    }

    /// PIN lock state deliberately survives `clear` (logout) - it's a device/app-level privacy
    /// preference, independent of which Stash server is currently logged in.
    func clear() {
        defaults.removeObject(forKey: baseURLKey)
        KeychainStore.remove(forKey: apiKeyKeychainKey)
    }

    func setRandomStartEnabled(_ enabled: Bool) {
        randomStartEnabled = enabled
        defaults.set(enabled, forKey: randomStartKey)
    }

    var isPinLockEnabled: Bool {
        KeychainStore.getBool(forKey: pinEnabledKeychainKey)
    }

    var pinHash: String? {
        KeychainStore.get(forKey: pinHashKeychainKey)
    }

    func setPin(hash: String) {
        KeychainStore.set(hash, forKey: pinHashKeychainKey)
        KeychainStore.setBool(true, forKey: pinEnabledKeychainKey)
    }

    func disablePinLock() {
        KeychainStore.remove(forKey: pinHashKeychainKey)
        KeychainStore.setBool(false, forKey: pinEnabledKeychainKey)
    }
}
