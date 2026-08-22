import CryptoKit
import Foundation

/// Never store the raw PIN - only its hash, so a leaked Keychain item doesn't reveal it directly.
enum PinHashing {
    static func hash(_ pin: String) -> String {
        let digest = SHA256.hash(data: Data(pin.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
