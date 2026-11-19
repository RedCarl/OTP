import Foundation

/// Imports unencrypted Aegis Authenticator JSON exports.
enum AegisImport {
    static func parse(_ data: Data) throws -> ImportOutcome {
        let document: Document
        do {
            document = try JSONDecoder().decode(Document.self, from: data)
        } catch {
            throw ImportError.malformed(L10n.t("Aegis 备份格式无法解析"))
        }

        if let slots = document.header?.slots, !slots.isEmpty, document.db?.entries == nil {
            throw ImportError.encryptedAegis
        }
        guard let entries = document.db?.entries, !entries.isEmpty else {
            throw ImportError.noRecognizableTokens
        }

        var candidates: [ImportCandidate] = []
        var skipped = 0
        for entry in entries {
            if let candidate = candidate(from: entry) {
                candidates.append(candidate)
            } else {
                skipped += 1
            }
        }

        var warnings: [String] = []
        if skipped > 0 {
            warnings.append(L10n.format("已跳过 %lld 个无法识别的 Aegis 条目", skipped))
        }
        return ImportOutcome(format: .aegis, candidates: candidates, warnings: warnings)
    }

    private static func candidate(from entry: Document.DB.Entry) -> ImportCandidate? {
        guard let info = entry.info else { return ImportCandidate(error: L10n.t("条目缺少信息")) }
        guard let secretText = info.secret, let secret = Base32.decode(secretText), !secret.isEmpty else {
            return ImportCandidate(error: L10n.t("条目缺少合法密钥"))
        }

        let type = (entry.type ?? "totp").lowercased()
        guard type == "totp" || type == "hotp" else {
            return ImportCandidate(error: L10n.format("不支持的条目类型：%@", type))
        }
        let algorithmName = (info.algo ?? "SHA1").uppercased()
        let algorithm: OTPAlgorithm
        switch algorithmName {
        case "SHA1": algorithm = .sha1
        case "SHA256": algorithm = .sha256
        case "SHA512": algorithm = .sha512
        default: return ImportCandidate(error: L10n.format("不支持的算法：%@", algorithmName))
        }

        let token = OTPToken(
            issuer: entry.issuer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            accountName: entry.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            secret: secret,
            kind: type == "hotp" ? .hotp : .totp,
            algorithm: algorithm,
            digits: info.digits ?? 6,
            period: info.period ?? 30,
            counter: UInt64(max(0, info.counter ?? 0)),
            pinned: entry.favorite ?? false
        )
        do {
            return ImportCandidate(token: try token.validated())
        } catch {
            return ImportCandidate(error: error.localizedDescription)
        }
    }

    // MARK: - JSON schema

    private struct Document: Decodable {
        struct Header: Decodable {
            struct Slot: Decodable {}
            var slots: [Slot]?
        }

        struct DB: Decodable {
            struct Entry: Decodable {
                struct Info: Decodable {
                    var secret: String?
                    var algo: String?
                    var digits: Int?
                    var period: Int?
                    var counter: Int?
                }
                var type: String?
                var name: String?
                var issuer: String?
                var favorite: Bool?
                var info: Info?
            }
            var entries: [Entry]?
        }

        var version: Int?
        var header: Header?
        var db: DB?
    }
}
