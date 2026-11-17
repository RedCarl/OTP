import Foundation

struct KDFParameters: Codable, Equatable, Sendable {
    var algorithm: String
    var iterations: Int
    var salt: String
}

struct CipherParameters: Codable, Equatable, Sendable {
    var algorithm: String
    var nonce: String
}

/// Versioned JSON envelope for portable backups.
struct BackupFile: Codable, Sendable {
    var format: String
    var version: Int
    var createdAt: String
    var encrypted: Bool
    var tokens: [OTPToken]?
    var kdf: KDFParameters?
    var cipher: CipherParameters?
    var ciphertext: String?
    var tag: String?
}

private struct BackupTokenBody: Codable {
    var tokens: [OTPToken]
}

struct BackupService: Sendable {
    static let formatName = "otp-backup"
    static let currentVersion = 1
    static let minimumPassphraseLength = 8

    var iterations: Int = BackupCrypto.defaultIterations

    func export(_ tokens: [OTPToken], passphrase: String?) throws -> Data {
        guard !tokens.isEmpty else { throw BackupError.noTokens }
        let createdAt = ISO8601Value.string(from: Date())
        let trimmed = passphrase?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if trimmed.isEmpty {
            let file = BackupFile(
                format: Self.formatName,
                version: Self.currentVersion,
                createdAt: createdAt,
                encrypted: false,
                tokens: tokens,
                kdf: nil,
                cipher: nil,
                ciphertext: nil,
                tag: nil
            )
            return try encoder.encode(file)
        }

        guard trimmed.count >= Self.minimumPassphraseLength else {
            throw BackupError.passphraseTooShort(Self.minimumPassphraseLength)
        }

        let body = try JSONEncoder().encode(BackupTokenBody(tokens: tokens))
        let sealed = try BackupCrypto.seal(payload: body, passphrase: trimmed, iterations: iterations)
        let file = BackupFile(
            format: Self.formatName,
            version: Self.currentVersion,
            createdAt: createdAt,
            encrypted: true,
            tokens: nil,
            kdf: KDFParameters(
                algorithm: "pbkdf2-hmac-sha256",
                iterations: iterations,
                salt: sealed.salt.base64EncodedString()
            ),
            cipher: CipherParameters(
                algorithm: "aes-256-gcm",
                nonce: sealed.nonce.base64EncodedString()
            ),
            ciphertext: sealed.ciphertext.base64EncodedString(),
            tag: sealed.tag.base64EncodedString()
        )
        return try encoder.encode(file)
    }

    func parse(_ data: Data, passphrase: String?) throws -> [OTPToken] {
        let file: BackupFile
        do {
            file = try JSONDecoder().decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.notBackupFile
        }
        guard file.format == Self.formatName else { throw BackupError.notBackupFile }
        guard file.version <= Self.currentVersion else { throw BackupError.unsupportedVersion(file.version) }

        if !file.encrypted {
            guard let tokens = file.tokens, !tokens.isEmpty else { throw BackupError.noTokens }
            return tokens
        }

        guard let passphrase = passphrase?.trimmingCharacters(in: .whitespacesAndNewlines), !passphrase.isEmpty else {
            throw BackupError.missingPassphrase
        }
        guard let kdf = file.kdf,
              let cipher = file.cipher,
              let ciphertext = file.ciphertext.flatMap({ Data(base64Encoded: $0) }),
              let tag = file.tag.flatMap({ Data(base64Encoded: $0) }),
              let salt = Data(base64Encoded: kdf.salt),
              let nonce = Data(base64Encoded: cipher.nonce) else {
            throw BackupError.wrongPassphraseOrCorrupted
        }
        guard kdf.iterations > 0, kdf.iterations <= 2_000_000 else {
            throw BackupError.cryptoFailed
        }

        let payload = try BackupCrypto.open(
            ciphertext: ciphertext,
            tag: tag,
            nonce: nonce,
            salt: salt,
            iterations: kdf.iterations,
            passphrase: passphrase
        )
        do {
            let body = try JSONDecoder().decode(BackupTokenBody.self, from: payload)
            guard !body.tokens.isEmpty else { throw BackupError.noTokens }
            return body.tokens
        } catch {
            throw BackupError.wrongPassphraseOrCorrupted
        }
    }

    /// Automatic iCloud backups use a key stored in iCloud Keychain, so the
    /// user can restore them with one tap on any device.
    func exportForICloud(_ tokens: [OTPToken]) throws -> Data {
        let key = try BackupKeyStore.loadOrCreate()
        return try export(tokens, passphrase: key)
    }

    func parseFromICloud(_ data: Data) throws -> [OTPToken] {
        let key = try BackupKeyStore.loadOrCreate()
        return try parse(data, passphrase: key)
    }

    func suggestedFileName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "OTP-备份-\(formatter.string(from: date))"
    }
}