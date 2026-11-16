import Foundation

struct OTPToken: Identifiable, Hashable, Sendable {
    static let currentVersion = 1

    var id: UUID
    var issuer: String
    var accountName: String
    var secret: Data
    var kind: OTPKind
    var algorithm: OTPAlgorithm
    var digits: Int
    var period: Int
    var counter: UInt64
    var pinned: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        issuer: String,
        accountName: String,
        secret: Data,
        kind: OTPKind = .totp,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        counter: UInt64 = 0,
        pinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.issuer = issuer
        self.accountName = accountName
        self.secret = secret
        self.kind = kind
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
        self.counter = counter
        self.pinned = pinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Human readable issuer shown in lists; falls back to the account name.
    var displayIssuer: String {
        let trimmedIssuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedIssuer.isEmpty { return trimmedIssuer }
        let trimmedAccount = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedAccount.isEmpty ? "未命名" : trimmedAccount
    }

    var displayAccount: String {
        let trimmedIssuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedIssuer.isEmpty ? "" : accountName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var title: String { displayIssuer }
    var subtitle: String { displayAccount }

    var searchText: String {
        [issuer, accountName].joined(separator: " ").lowercased()
    }

    var uri: String { OTPAuthURI.string(from: self) }

    func validated() throws -> OTPToken {
        guard !secret.isEmpty else { throw OTPError.missingSecret }
        guard (6...8).contains(digits) else { throw OTPError.invalidDigits(digits) }
        if kind == .totp {
            guard (1...3600).contains(period) else { throw OTPError.invalidPeriod(period) }
        }
        return self
    }

    func updatedCopy(_ mutate: (inout OTPToken) -> Void) -> OTPToken {
        var copy = self
        mutate(&copy)
        copy.updatedAt = Date()
        return copy
    }
}

extension OTPToken: Codable {
    private enum CodingKeys: String, CodingKey {
        case v, id, issuer, account, kind, algo, digits, period, counter, secret, pinned, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .v) ?? 1
        guard version <= Self.currentVersion else { throw OTPError.unsupportedVersion(version) }

        id = try container.decode(UUID.self, forKey: .id)
        issuer = try container.decodeIfPresent(String.self, forKey: .issuer) ?? ""
        accountName = try container.decodeIfPresent(String.self, forKey: .account) ?? ""
        kind = try container.decodeIfPresent(OTPKind.self, forKey: .kind) ?? .totp
        algorithm = try container.decodeIfPresent(OTPAlgorithm.self, forKey: .algo) ?? .sha1
        digits = try container.decodeIfPresent(Int.self, forKey: .digits) ?? 6
        period = try container.decodeIfPresent(Int.self, forKey: .period) ?? 30
        counter = try container.decodeIfPresent(UInt64.self, forKey: .counter) ?? 0
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false

        let secretString = try container.decode(String.self, forKey: .secret)
        guard let decoded = Base32.decode(secretString), !decoded.isEmpty else {
            throw OTPError.invalidSecret
        }
        secret = decoded

        let createdString = try container.decodeIfPresent(String.self, forKey: .createdAt)
        let updatedString = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        let now = Date()
        createdAt = createdString.flatMap(ISO8601Value.date(from:)) ?? now
        updatedAt = updatedString.flatMap(ISO8601Value.date(from:)) ?? createdAt
        _ = try validated()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentVersion, forKey: .v)
        try container.encode(id, forKey: .id)
        try container.encode(issuer, forKey: .issuer)
        try container.encode(accountName, forKey: .account)
        try container.encode(kind, forKey: .kind)
        try container.encode(algorithm, forKey: .algo)
        try container.encode(digits, forKey: .digits)
        try container.encode(period, forKey: .period)
        try container.encode(counter, forKey: .counter)
        try container.encode(Base32.encode(secret), forKey: .secret)
        try container.encode(pinned, forKey: .pinned)
        try container.encode(ISO8601Value.string(from: createdAt), forKey: .createdAt)
        try container.encode(ISO8601Value.string(from: updatedAt), forKey: .updatedAt)
    }
}
