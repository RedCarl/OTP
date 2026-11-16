import Foundation

/// Test / preview double for the keychain repository.
final class InMemoryTokenRepository: TokenRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UUID: OTPToken]
    private var skipped: Int

    init(tokens: [OTPToken] = [], skippedCount: Int = 0) {
        storage = Dictionary(uniqueKeysWithValues: tokens.map { ($0.id, $0) })
        skipped = skippedCount
    }

    func loadAll() throws -> TokenLoadResult {
        lock.lock()
        defer { lock.unlock() }
        let tokens = storage.values.sorted {
            if $0.pinned != $1.pinned { return $0.pinned }
            return $0.displayIssuer.localizedStandardCompare($1.displayIssuer) == .orderedAscending
        }
        return TokenLoadResult(tokens: tokens, skippedCount: skipped)
    }

    func upsert(_ token: OTPToken) throws {
        _ = try token.validated()
        lock.lock()
        defer { lock.unlock() }
        storage[token.id] = token
    }

    func delete(id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[id] = nil
    }

    func deleteAll() throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}
