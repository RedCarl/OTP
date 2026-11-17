import CryptoKit
import Foundation

enum BackupAutomation {
    static let fingerprintKey = "lastCloudBackupFingerprint"
    static let lastBackupKey = "lastBackupAt"

    static func fingerprint(for tokens: [OTPToken]) -> String {
        let source = tokens
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { token in
                "\(token.id.uuidString)|\(token.updatedAt.timeIntervalSince1970)|\(token.secret.base64EncodedString())"
            }
            .joined(separator: "\n")
        return SHA256.hash(data: Data(source.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// Called when the app goes to the background. Does nothing when auto
    /// backup is off, there are no tokens, or nothing changed since last time.
    static func backupIfNeeded(tokens: [OTPToken]) async {
        guard UserDefaults.standard.bool(forKey: "autoBackupEnabled", default: true),
              !tokens.isEmpty else {
            return
        }

        let fingerprint = fingerprint(for: tokens)
        guard UserDefaults.standard.string(forKey: fingerprintKey) != fingerprint else {
            return
        }

        do {
            let data = try await Task.detached(priority: .utility) {
                try BackupService().exportForICloud(tokens)
            }.value
            _ = try await BackupStore().save(data)
            UserDefaults.standard.set(fingerprint, forKey: fingerprintKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastBackupKey)
        } catch {
            // Best effort: automatic backups should never interrupt the app.
        }
    }
}

private extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        object(forKey: key) == nil ? defaultValue : bool(forKey: key)
    }
}
