import Foundation
import Security

/// The passphrase used for automatic iCloud backups. It lives in the
/// iCloud-synchronizable keychain, so another device signed into the same
/// Apple ID can restore the backups without typing anything.
enum BackupKeyStore {
    private static let service = "cn.carljoy.otp.backupkey"
    private static let account = "backup-key"

    static func loadOrCreate() throws -> String {
        if let existing = try load() {
            return existing
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw BackupError.cryptoFailed
        }
        let value = Data(bytes).base64EncodedString()
        try save(value)
        return value
    }

    static func load() throws -> String? {
        var query = baseQuery
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            throw KeychainError.from(status)
        }
        return value
    }

    private static func save(_ value: String) throws {
        let data = Data(value.utf8)

        var update = baseQuery
        update[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        let changes = [kSecValueData as String: data]
        var status = SecItemUpdate(update as CFDictionary, changes as CFDictionary)

        if status == errSecItemNotFound {
            var attributes = baseQuery
            attributes[kSecAttrSynchronizable as String] = kCFBooleanTrue
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            attributes[kSecValueData as String] = data
            status = SecItemAdd(attributes as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw KeychainError.from(status)
        }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
