import Foundation

/// Imports unencrypted 2FAS (.2fas) JSON exports.
enum TwoFASImport {
    static func parse(_ data: Data) throws -> ImportOutcome {
        let document: Document
        do {
            document = try JSONDecoder().decode(Document.self, from: data)
        } catch {
            throw ImportError.malformed(L10n.t("2FAS 备份格式无法解析"))
        }

        if let encrypted = document.servicesEncrypted, !encrypted.isEmpty,
           (document.services ?? []).isEmpty {
            throw ImportError.encryptedTwoFAS
        }
        guard let services = document.services, !services.isEmpty else {
            throw ImportError.noRecognizableTokens
        }

        var candidates: [ImportCandidate] = []
        var skipped = 0
        for service in services {
            if let candidate = candidate(from: service) {
                candidates.append(candidate)
            } else {
                skipped += 1
            }
        }

        var warnings: [String] = []
        if skipped > 0 {
            warnings.append(L10n.format("已跳过 %lld 个无法识别的 2FAS 条目", skipped))
        }
        return ImportOutcome(format: .twoFAS, candidates: candidates, warnings: warnings)
    }

    private static func candidate(from service: Document.Service) -> ImportCandidate? {
        guard let secretText = service.secret, let secret = Base32.decode(secretText), !secret.isEmpty else {
            return ImportCandidate(error: L10n.t("条目缺少合法密钥"))
        }
        let otp = service.otp
        let type = (otp?.tokenType ?? "TOTP").uppercased()
        guard type == "TOTP" || type == "HOTP" else {
            return ImportCandidate(error: L10n.format("不支持的条目类型：%@", type))
        }
        let algorithmName = (otp?.algorithm ?? "SHA1").uppercased()
        let algorithm: OTPAlgorithm
        switch algorithmName {
        case "SHA1": algorithm = .sha1
        case "SHA256": algorithm = .sha256
        case "SHA512": algorithm = .sha512
        default: return ImportCandidate(error: L10n.format("不支持的算法：%@", algorithmName))
        }

        let issuer = (otp?.issuer ?? service.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let account = (otp?.account ?? otp?.label ?? service.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let token = OTPToken(
            issuer: issuer,
            accountName: account,
            secret: secret,
            kind: type == "HOTP" ? .hotp : .totp,
            algorithm: algorithm,
            digits: otp?.digits ?? 6,
            period: otp?.period ?? 30,
            counter: UInt64(max(0, otp?.counter ?? 0))
        )
        do {
            return ImportCandidate(token: try token.validated())
        } catch {
            return ImportCandidate(error: error.localizedDescription)
        }
    }

    // MARK: - JSON schema

    private struct Document: Decodable {
        struct Service: Decodable {
            struct OTP: Decodable {
                var label: String?
                var account: String?
                var issuer: String?
                var digits: Int?
                var period: Int?
                var algorithm: String?
                var tokenType: String?
                var counter: Int?
            }
            var name: String?
            var secret: String?
            var otp: OTP?
        }
        var services: [Service]?
        var servicesEncrypted: String?
    }
}
