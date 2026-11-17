import Foundation
import Security
import os

/// Stores every token as an iCloud-Keychain-synchronizable generic password.
/// No local database, no plaintext on disk: the keychain is the single source
/// of truth and iCloud Keychain performs end-to-end encrypted sync.
struct KeychainTokenRepository: TokenRepository {
    static let defaultService = "cn.carljoy.otp.token"

    let service: String
    private let logger = Logger(subsystem: "cn.carljoy.otp", category: "Keychain")

    init(service: String = KeychainTokenRepository.defaultService) {
        self.service = service
    }

    // MARK: - Reads

    func loadAll() throws -> TokenLoadResult {
        let items = try fetchRawItems()
        let decoder = JSONDecoder()
        var tokens: [OTPToken] = []
        var skipped = 0

        for item in items {
            guard let data = item.data else {
                skipped += 1
                continue
            }
            do {
                let token = try decoder.decode(OTPToken.self, from: data)
                guard token.id.uuidString == item.account else {
                    logger.error("Discarding token whose account/identifier disagree")
                    skipped += 1
                    continue
                }
                tokens.append(token)
            } catch {
                logger.error("Discarding unreadable token: \(String(describing: error), privacy: .public)")
                skipped += 1
            }
        }
        return TokenLoadResult(tokens: tokens, skippedCount: skipped)
    }

    private struct RawItem {
        var account: String
        var data: Data?
    }

    private func fetchRawItems() throws -> [RawItem] {
        var query = baseQuery
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        query[kSecReturnAttributes as String] = true
        query[kSecReturnData as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess else {
            throw KeychainError.from(status)
        }
        guard let rawItems = result as? [[String: Any]] else {
            return []
        }
        return rawItems.compactMap { item in
            guard let account = item[kSecAttrAccount as String] as? String else { return nil }
            return RawItem(account: account, data: item[kSecValueData as String] as? Data)
        }
    }

    // MARK: - Writes

    func upsert(_ token: OTPToken) throws {
        _ = try token.validated()
        let data: Data
        do {
            data = try JSONEncoder().encode(token)
        } catch {
            throw KeychainError.encodingFailed
        }

        let account = token.id.uuidString
        let changes: [String: Any] = [kSecValueData as String: data]

        var status = SecItemUpdate(query(account: account, synchronizable: kSecAttrSynchronizableAny) as CFDictionary, changes as CFDictionary)
        if status == errSecParam || status == errSecItemNotFound {
            status = SecItemUpdate(query(account: account, synchronizable: kCFBooleanTrue) as CFDictionary, changes as CFDictionary)
        }
        if status == errSecItemNotFound {
            var attributes = baseQuery
            attributes[kSecAttrAccount as String] = account
            attributes[kSecAttrSynchronizable as String] = kCFBooleanTrue
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            attributes[kSecValueData as String] = data
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw KeychainError.from(status)
        }
    }

    func delete(id: UUID) throws {
        let status = SecItemDelete(query(account: id.uuidString, synchronizable: kSecAttrSynchronizableAny) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.from(status)
        }
    }

    func deleteAll() throws {
        let accounts = try fetchRawItems().map(\.account)
        for account in accounts {
            let status = SecItemDelete(query(account: account, synchronizable: kSecAttrSynchronizableAny) as CFDictionary)
            if status != errSecSuccess && status != errSecItemNotFound {
                throw KeychainError.from(status)
            }
        }
    }

    // MARK: - Queries

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
    }

    private func query(account: String, synchronizable: Any) -> [String: Any] {
        var query = baseQuery
        query[kSecAttrAccount as String] = account
        query[kSecAttrSynchronizable as String] = synchronizable
        return query
    }
}