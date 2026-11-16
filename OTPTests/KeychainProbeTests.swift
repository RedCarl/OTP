import Foundation
import Security
import Testing
@testable import OTP

struct KeychainProbeTests {
    @Test func probeSynchronizableSupport() {
        let service = "com.redcarl.otp.probe.\(UUID().uuidString)"
        let account = UUID().uuidString
        var base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: Data("value".utf8),
        ]
        let plainStatus = SecItemAdd(base as CFDictionary, nil)

        var sync = base
        sync[kSecAttrSynchronizable as String] = kCFBooleanTrue
        let syncStatus = SecItemAdd(sync as CFDictionary, nil)

        print("PROBE plain=\(plainStatus) sync=\(syncStatus)")

        // Cleanup
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrService as String: service] as CFDictionary)
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrService as String: service,
                       kSecAttrSynchronizable as String: kSecAttrSynchronizableAny] as CFDictionary)

        #expect(plainStatus != errSecMissingEntitlement, "plain keychain unavailable: \(plainStatus)")
    }
}
