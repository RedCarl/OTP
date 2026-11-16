import Foundation
import Testing
@testable import OTP

@MainActor
struct TokenListModelTests {
    private func token(
        issuer: String,
        account: String = "alice",
        secret: String = "JBSWY3DPEHPK3PXP",
        pinned: Bool = false,
        kind: OTPKind = .totp,
        counter: UInt64 = 0
    ) -> OTPToken {
        OTPToken(
            issuer: issuer,
            accountName: account,
            secret: Base32.decode(secret) ?? Data(),
            kind: kind,
            counter: counter,
            pinned: pinned
        )
    }

    @Test func refreshSortsPinnedThenAlphabetical() async {
        let zulu = token(issuer: "Zulu")
        let alpha = token(issuer: "Alpha")
        let pinned = token(issuer: "Bravo", pinned: true)
        let repository = InMemoryTokenRepository(tokens: [zulu, alpha, pinned])
        let model = TokenListModel(store: TokenStore(repository: repository))

        await model.refresh()

        #expect(model.tokens.map(\.issuer) == ["Bravo", "Alpha", "Zulu"])
        #expect(model.lastRefreshedAt != nil)
    }

    @Test func detectsDuplicatesByIssuerAccountAndSecret() async {
        let existing = token(issuer: "GitHub")
        let repository = InMemoryTokenRepository(tokens: [existing])
        let model = TokenListModel(store: TokenStore(repository: repository))
        await model.refresh()

        #expect(model.isDuplicate(existing))
        #expect(!model.isDuplicate(token(issuer: "GitHub", secret: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ")))
        #expect(!model.isDuplicate(token(issuer: "GitLab")))
    }

    @Test func importWritesAllSelectedTokens() async {
        let repository = InMemoryTokenRepository()
        let model = TokenListModel(store: TokenStore(repository: repository))
        await model.refresh()

        let imported = [token(issuer: "One"), token(issuer: "Two")]
        let count = await model.importTokens(imported)

        #expect(count == 2)
        #expect(model.tokens.count == 2)
        let stored = try? await repository.loadAll()
        #expect(stored?.tokens.count == 2)
    }

    @Test func hotpCopyAdvancesStoredCounter() async {
        let hotp = token(issuer: "AWS", kind: .hotp, counter: 0)
        let repository = InMemoryTokenRepository(tokens: [hotp])
        let model = TokenListModel(store: TokenStore(repository: repository))
        await model.refresh()

        await model.copyCode(for: hotp)

        #expect(model.code(for: hotp) != nil)
        let stored = try? await repository.loadAll()
        #expect(stored?.tokens.first?.counter == 1)
    }

    @Test func deletingRemovesFromStore() async {
        let token = token(issuer: "GitHub")
        let repository = InMemoryTokenRepository(tokens: [token])
        let model = TokenListModel(store: TokenStore(repository: repository))
        await model.refresh()

        await model.delete(token)

        #expect(model.tokens.isEmpty)
        let stored = try? await repository.loadAll()
        #expect(stored?.tokens.isEmpty == true)
    }
}
