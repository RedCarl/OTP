import Foundation

struct ImportService: Sendable {
    var backupService = BackupService()

    /// Pasted text: one or more otpauth:// links, or a Google migration link.
    func parseText(_ text: String) throws -> ImportOutcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ImportError.noRecognizableTokens }

        if trimmed.hasPrefix("{") {
            return try parseFile(Data(trimmed.utf8), passphrase: nil)
        }

        let candidates = URIImportParser.parseText(trimmed)
        guard candidates.contains(where: { $0.token != nil }) else {
            throw ImportError.noRecognizableTokens
        }
        return ImportOutcome(format: .otpAuthURI, candidates: candidates, warnings: [])
    }

    /// Sniffs JSON backups, 2FAS/Aegis exports and plain text link lists.
    func parseFile(_ data: Data, passphrase: String?) throws -> ImportOutcome {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if object["format"] as? String == BackupService.formatName {
                let tokens = try backupService.parse(data, passphrase: passphrase)
                return ImportOutcome(
                    format: .backup,
                    candidates: tokens.map { ImportCandidate(token: $0) },
                    warnings: []
                )
            }
            if object["db"] != nil || object["header"] != nil {
                return try AegisImport.parse(data)
            }
            if object["services"] != nil || object["servicesEncrypted"] != nil {
                return try TwoFASImport.parse(data)
            }
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw ImportError.unsupportedFile
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("{") else {
            throw ImportError.unsupportedFile
        }
        let candidates = URIImportParser.parseText(trimmed)
        guard candidates.contains(where: { $0.token != nil }) else {
            throw ImportError.unsupportedFile
        }
        return ImportOutcome(format: .text, candidates: candidates, warnings: [])
    }
}
