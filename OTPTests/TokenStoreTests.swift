import Foundation
import Testing
@testable import OTP

struct TokenStoreTests {
    private func token(issuer: String, account: String, secret: String = "JBSWY3DPEHPK3PXP") -> OTPToken {
        OTPToken(
            issuer: issuer,
            accountName: account,
            secret: Base32.decode(secret) ?? Data()
        )
    }

    @Test func savesLoadsAndDeletes() async throws {
        let repository = InMemoryTokenRepository()
        let store = TokenStore(repository: repository)

        let github = token(issuer: "GitHub", account: "alice")
        try await store.save(github)

        var result = try await store.load()
        #expect(result.tokens.count == 1)
        #expect(result.tokens.first?.id == github.id)

        var updated = github
        updated.issuer = "GitHub Enterprise"
        try await store.save(updated)
        result = try await store.load()
        #expect(result.tokens.first?.issuer == "GitHub Enterprise")

        try await store.delete(id: github.id)
        result = try await store.load()
        #expect(result.tokens.isEmpty)
    }

    @Test func replaceAllClearsFirst() async throws {
        let repository = InMemoryTokenRepository(tokens: [token(issuer: "Old", account: "a")])
        let store = TokenStore(repository: repository)

        let fresh = [token(issuer: "New", account: "b"), token(issuer: "New2", account: "c")]
        try await store.replaceAll(with: fresh)

        let result = try await store.load()
        #expect(result.tokens.count == 2)
        #expect(Set(result.tokens.map(\.issuer)) == ["New", "New2"])
    }

    @Test func inMemorySortsPinnedFirst() async throws {
        let pinned = OTPToken(issuer: "Zed", accountName: "z", secret: Data([1, 2, 3]), pinned: true)
        let alpha = OTPToken(issuer: "Alpha", accountName: "a", secret: Data([4, 5, 6]))
        let repository = InMemoryTokenRepository(tokens: [alpha, pinned])
        let store = TokenStore(repository: repository)
        let result = try await store.load()
        #expect(result.tokens.first?.id == pinned.id)
        #expect(result.tokens.last?.id == alpha.id)
    }
}
