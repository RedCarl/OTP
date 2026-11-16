import Foundation

struct TokenLoadResult: Sendable {
    var tokens: [OTPToken]
    var skippedCount: Int

    init(tokens: [OTPToken] = [], skippedCount: Int = 0) {
        self.tokens = tokens
        self.skippedCount = skippedCount
    }
}

protocol TokenRepository: Sendable {
    /// All tokens visible to the app, including entries synced through iCloud Keychain.
    func loadAll() throws -> TokenLoadResult
    func upsert(_ token: OTPToken) throws
    func delete(id: UUID) throws
    func deleteAll() throws
}
