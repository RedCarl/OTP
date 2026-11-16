import Foundation
import Testing
@testable import OTP

struct BackupTests {
    private func sampleTokens() -> [OTPToken] {
        [
            OTPToken(
                id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
                issuer: "GitHub",
                accountName: "alice",
                secret: Base32.decode("JBSWY3DPEHPK3PXP") ?? Data(),
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_500)
            ),
            OTPToken(
                issuer: "AWS",
                accountName: "admin",
                secret: Base32.decode("MFRGGZDFMZTWQ2LKNNWG23TP") ?? Data(),
                kind: .hotp,
                algorithm: .sha256,
                digits: 8,
                counter: 7
            ),
        ]
    }

    @Test func exportsPlainJSONBackup() throws {
        let service = BackupService()
        let data = try service.export(sampleTokens(), passphrase: nil)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["format"] as? String == "otp-backup")
        #expect(json["version"] as? Int == 1)
        #expect(json["encrypted"] as? Bool == false)
        let tokens = try #require(json["tokens"] as? [[String: Any]])
        #expect(tokens.count == 2)
        #expect(tokens[0]["secret"] as? String != nil)
    }

    @Test func roundTripsPlainBackup() throws {
        let service = BackupService()
        let original = sampleTokens()
        let data = try service.export(original, passphrase: nil)
        let restored = try service.parse(data, passphrase: nil)
        #expect(restored.map(\.id) == original.map(\.id))
        #expect(restored.map(\.issuer) == original.map(\.issuer))
        #expect(restored.map(\.secret) == original.map(\.secret))
        #expect(restored[1].counter == 7)
        #expect(restored[1].algorithm == .sha256)
    }

    @Test func roundTripsEncryptedBackup() throws {
        let service = BackupService(iterations: 1_000)
        let original = sampleTokens()
        let data = try service.export(original, passphrase: "correct horse battery")
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["encrypted"] as? Bool == true)
        #expect(json["ciphertext"] != nil)
        #expect(json["tokens"] == nil)

        let restored = try service.parse(data, passphrase: "correct horse battery")
        #expect(restored.map(\.id) == original.map(\.id))
        #expect(restored.map(\.secret) == original.map(\.secret))
    }

    @Test func rejectsWrongPassphrase() throws {
        let service = BackupService(iterations: 1_000)
        let data = try service.export(sampleTokens(), passphrase: "correct horse battery")
        #expect(throws: BackupError.wrongPassphraseOrCorrupted) {
            try service.parse(data, passphrase: "wrong horse battery")
        }
    }

    @Test func rejectsTamperedCiphertext() throws {
        let service = BackupService(iterations: 1_000)
        let original = try service.export(sampleTokens(), passphrase: "correct horse battery")
        var json = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
        let ciphertext = try #require(json["ciphertext"] as? String)
        var bytes = Array(Data(base64Encoded: ciphertext) ?? Data())
        bytes[0] ^= 0xFF
        json["ciphertext"] = Data(bytes).base64EncodedString()
        let tampered = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: BackupError.wrongPassphraseOrCorrupted) {
            try service.parse(tampered, passphrase: "correct horse battery")
        }
    }

    @Test func rejectsMissingPassphrase() throws {
        let service = BackupService(iterations: 1_000)
        let data = try service.export(sampleTokens(), passphrase: "correct horse battery")
        #expect(throws: BackupError.missingPassphrase) {
            try service.parse(data, passphrase: nil)
        }
    }

    @Test func rejectsNonBackupFile() {
        #expect(throws: BackupError.notBackupFile) {
            try BackupService().parse(Data("{\"hello\":1}".utf8), passphrase: nil)
        }
        #expect(throws: BackupError.notBackupFile) {
            try BackupService().parse(Data("garbage".utf8), passphrase: nil)
        }
    }

    @Test func rejectsNewerVersion() throws {
        let json = """
        {"format":"otp-backup","version":2,"createdAt":"2026-01-01T00:00:00.000Z","encrypted":false,"tokens":[]}
        """
        #expect(throws: BackupError.unsupportedVersion(2)) {
            try BackupService().parse(Data(json.utf8), passphrase: nil)
        }
    }

    @Test func rejectsShortPassphraseOnExport() {
        #expect(throws: BackupError.passphraseTooShort(8)) {
            try BackupService().export(sampleTokens(), passphrase: "short")
        }
    }

    @Test func pbkdf2MatchesKnownVectors() throws {
        // PBKDF2-HMAC-SHA256 test vectors.
        let salt = Data("salt".utf8)
        let key1 = try BackupCrypto.deriveKey(passphrase: "password", salt: salt, iterations: 1)
        #expect(key1.hexString == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")

        let key4096 = try BackupCrypto.deriveKey(passphrase: "password", salt: salt, iterations: 4096)
        #expect(key4096.hexString == "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a")
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
