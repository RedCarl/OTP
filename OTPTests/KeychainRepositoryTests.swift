import Foundation
import Security
import Testing
@testable import OTP

/// Exercises real keychain access from the hosted app process. The service name
/// is unique per test so repeated runs never collide.
struct KeychainRepositoryTests {
    private func makeRepository() -> KeychainTokenRepository {
        KeychainTokenRepository(service: "com.redcarl.otp.tests.\(UUID().uuidString)")
    }

    private func makeToken(issuer: String = "GitHub", account: String = "alice") -> OTPToken {
        OTPToken(
            issuer: issuer,
            accountName: account,
            secret: Base32.decode("JBSWY3DPEHPK3PXP") ?? Data()
        )
    }

    @Test func addsLoadsUpdatesAndDeletesSynchronizableItems() throws {
        let repository = makeRepository()
        defer { try? repository.deleteAll() }

        let token = makeToken()
        try repository.upsert(token)

        var loaded = try repository.loadAll()
        #expect(loaded.tokens.count == 1)
        #expect(loaded.tokens.first?.id == token.id)
        #expect(loaded.skippedCount == 0)

        var renamed = token
        renamed.issuer = "GitHub Enterprise"
        renamed.updatedAt = Date()
        try repository.upsert(renamed)

        loaded = try repository.loadAll()
        #expect(loaded.tokens.count == 1)
        #expect(loaded.tokens.first?.issuer == "GitHub Enterprise")

        try repository.delete(id: token.id)
        loaded = try repository.loadAll()
        #expect(loaded.tokens.isEmpty)
    }

    @Test func keepsTokensIsolatedPerService() throws {
        let first = makeRepository()
        let second = makeRepository()
        defer {
            try? first.deleteAll()
            try? second.deleteAll()
        }

        try first.upsert(makeToken(issuer: "First"))
        try second.upsert(makeToken(issuer: "Second"))

        #expect(try first.loadAll().tokens.map(\.issuer) == ["First"])
        #expect(try second.loadAll().tokens.map(\.issuer) == ["Second"])
    }

    @Test func storesCustomIconPayload() throws {
        let repository = makeRepository()
        defer { try? repository.deleteAll() }

        var token = makeToken()
        token.iconData = Data((0..<6000).map { UInt8($0 % 251) })
        try repository.upsert(token)

        let loaded = try repository.loadAll()
        #expect(loaded.tokens.count == 1)
        #expect(loaded.tokens.first?.iconData == token.iconData)
    }

    @Test func skipsCorruptPayloads() throws {
        let repository = makeRepository()
        defer { try? repository.deleteAll() }

        let token = makeToken()
        try repository.upsert(token)

        // Insert a malformed payload with the same service but a different account.
        let corruptAccount = UUID().uuidString
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: repository.service,
            kSecAttrAccount as String: corruptAccount,
            kSecAttrSynchronizable as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: Data("not json".utf8),
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        #expect(status == errSecSuccess, "SecItemAdd failed: \(status)")

        let loaded = try repository.loadAll()
        #expect(loaded.tokens.count == 1)
        #expect(loaded.skippedCount == 1)
    }
}