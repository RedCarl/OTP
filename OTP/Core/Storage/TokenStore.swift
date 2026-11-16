import Foundation

/// Serializes all mutations to the token repository and keeps keychain I/O off
/// the main actor.
actor TokenStore {
    private let repository: any TokenRepository

    init(repository: any TokenRepository = KeychainTokenRepository()) {
        self.repository = repository
    }

    func load() throws -> TokenLoadResult {
        try repository.loadAll()
    }

    func save(_ token: OTPToken) throws {
        try repository.upsert(token)
    }

    func delete(id: UUID) throws {
        try repository.delete(id: id)
    }

    func delete(ids: [UUID]) throws {
        for id in ids {
            try repository.delete(id: id)
        }
    }

    func deleteAll() throws {
        try repository.deleteAll()
    }

    func replaceAll(with tokens: [OTPToken]) throws {
        try repository.deleteAll()
        for token in tokens {
            try repository.upsert(token)
        }
    }
}
