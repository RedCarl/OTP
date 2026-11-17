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

    func restore(_ incoming: [OTPToken], mode: RestoreMode) throws -> RestoreSummary {
        let tokens = incoming.compactMap { try? $0.validated() }
        guard !tokens.isEmpty else {
            throw BackupError.noTokens
        }

        if mode == .replace {
            try repository.deleteAll()
            for token in tokens {
                try repository.upsert(token)
            }
            return RestoreSummary(added: tokens.count)
        }

        let existing = try repository.loadAll().tokens
        var byID: [UUID: OTPToken] = [:]
        var byFingerprint: [String: OTPToken] = [:]
        for token in existing {
            byID[token.id] = token
            byFingerprint[Self.fingerprint(token)] = token
        }

        var summary = RestoreSummary()
        for token in tokens {
            let key = Self.fingerprint(token)
            if let match = byID[token.id] ?? byFingerprint[key] {
                if mode == .update {
                    var updated = token
                    updated.id = match.id
                    updated.pinned = match.pinned
                    updated.createdAt = match.createdAt
                    updated.updatedAt = Date()
                    try repository.upsert(updated)
                    byID[updated.id] = updated
                    byFingerprint[key] = updated
                    summary.updated += 1
                } else {
                    summary.skipped += 1
                }
            } else {
                try repository.upsert(token)
                byID[token.id] = token
                byFingerprint[key] = token
                summary.added += 1
            }
        }
        return summary
    }

    private static func fingerprint(_ token: OTPToken) -> String {
        let issuer = token.issuer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let account = token.accountName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(token.secret.base64EncodedString())|\(issuer)|\(account)"
    }
}