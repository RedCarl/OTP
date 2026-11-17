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

    @Test func restoreMergeKeepsExistingAndAddsMissing() async throws {
        let existing = token(issuer: "GitHub", account: "alice")
        let repository = InMemoryTokenRepository(tokens: [existing])
        let store = TokenStore(repository: repository)

        var changed = existing
        changed.issuer = "GitHub Enterprise"
        let added = token(issuer: "AWS", account: "root", secret: "MFRGGZDFMZTWQ2LKNNWG23TP")

        let summary = try await store.restore([changed, added], mode: .merge)
        #expect(summary.added == 1)
        #expect(summary.updated == 0)
        #expect(summary.skipped == 1)

        let result = try await store.load()
        #expect(result.tokens.count == 2)
        #expect(result.tokens.first(where: { $0.id == existing.id })?.issuer == "GitHub")
    }

    @Test func restoreUpdateOverwritesMatchingToken() async throws {
        let existing = token(issuer: "GitHub", account: "alice")
        let repository = InMemoryTokenRepository(tokens: [existing])
        let store = TokenStore(repository: repository)

        var changed = existing
        changed.issuer = "GitHub Enterprise"
        changed.accountName = "alice@company.com"

        let summary = try await store.restore([changed], mode: .update)
        #expect(summary.added == 0)
        #expect(summary.updated == 1)
        #expect(summary.skipped == 0)

        let result = try await store.load()
        #expect(result.tokens.count == 1)
        #expect(result.tokens.first?.id == existing.id)
        #expect(result.tokens.first?.issuer == "GitHub Enterprise")
        #expect(result.tokens.first?.accountName == "alice@company.com")
    }

    @Test func restoreReplaceDeletesEverythingFirst() async throws {
        let old = token(issuer: "Old", account: "a")
        let repository = InMemoryTokenRepository(tokens: [old, token(issuer: "Old2", account: "b")])
        let store = TokenStore(repository: repository)

        let fresh = token(issuer: "Fresh", account: "c", secret: "GEZDGNBVGY3TQOJQ")
        let summary = try await store.restore([fresh], mode: .replace)
        #expect(summary.added == 1)

        let result = try await store.load()
        #expect(result.tokens.count == 1)
        #expect(result.tokens.first?.id == fresh.id)
    }

    @Test func restoreMatchesLogicalDuplicatesWithDifferentIDs() async throws {
        let existing = token(issuer: "GitHub", account: "alice")
        var copy = existing
        copy.id = UUID()

        let mergeRepository = InMemoryTokenRepository(tokens: [existing])
        let mergeStore = TokenStore(repository: mergeRepository)
        let mergeSummary = try await mergeStore.restore([copy], mode: .merge)
        #expect(mergeSummary.skipped == 1)
        #expect(try await mergeStore.load().tokens.count == 1)

        let updateRepository = InMemoryTokenRepository(tokens: [existing])
        let updateStore = TokenStore(repository: updateRepository)
        let updateSummary = try await updateStore.restore([copy], mode: .update)
        #expect(updateSummary.updated == 1)
        let updated = try await updateStore.load().tokens
        #expect(updated.count == 1)
        #expect(updated.first?.id == existing.id)
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