import Foundation

/// Imports Google Authenticator's "export accounts" QR payloads.
/// Format: otpauth-migration://offline?data=<base64 protobuf>
enum GoogleAuthenticatorImport {
    static func parse(urlString: String) throws -> [ImportCandidate] {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "otpauth-migration" else {
            throw ImportError.malformed("这不是 Google Authenticator 迁移链接")
        }
        guard let encoded = components.queryItems?.first(where: { $0.name == "data" })?.value,
              let payload = decodeBase64(encoded), !payload.isEmpty else {
            throw ImportError.malformed("迁移链接缺少有效的 data 参数")
        }
        return try parse(payload: payload)
    }

    static func parse(payload: Data) throws -> [ImportCandidate] {
        var reader = ProtobufReader(payload)
        var candidates: [ImportCandidate] = []

        while !reader.isAtEnd {
            let (field, wireType) = try reader.readTag()
            if field == 1 && wireType == 2 {
                let message = try reader.readBytes()
                candidates.append(parseParameters(message))
            } else {
                try reader.skip(wireType: wireType)
            }
        }

        guard !candidates.isEmpty else {
            throw ImportError.malformed("迁移数据里没有令牌")
        }
        return candidates
    }

    // MARK: - Protobuf messages

    private struct Parameters {
        var secret = Data()
        var name = ""
        var issuer = ""
        var algorithm = 0
        var digits = 0
        var type = 0
        var counter: UInt64 = 0
    }

    private static func parseParameters(_ message: Data) -> ImportCandidate {
        var parameters = Parameters()
        var reader = ProtobufReader(message)
        do {
            while !reader.isAtEnd {
                let (field, wireType) = try reader.readTag()
                switch (field, wireType) {
                case (1, 2):
                    parameters.secret = try reader.readBytes()
                case (2, 2):
                    parameters.name = try reader.readString()
                case (3, 2):
                    parameters.issuer = try reader.readString()
                case (4, 0):
                    parameters.algorithm = Int(try reader.readVarint())
                case (5, 0):
                    parameters.digits = Int(try reader.readVarint())
                case (6, 0):
                    parameters.type = Int(try reader.readVarint())
                case (7, 0):
                    parameters.counter = try reader.readVarint()
                default:
                    try reader.skip(wireType: wireType)
                }
            }
        } catch {
            return ImportCandidate(error: error.localizedDescription)
        }
        return makeCandidate(from: parameters)
    }

    private static func makeCandidate(from parameters: Parameters) -> ImportCandidate {
        guard !parameters.secret.isEmpty else {
            return ImportCandidate(error: "条目缺少密钥")
        }
        guard parameters.algorithm != 4 else {
            return ImportCandidate(error: "Google Authenticator 中的 MD5 条目暂不支持")
        }

        let algorithm: OTPAlgorithm
        switch parameters.algorithm {
        case 2: algorithm = .sha256
        case 3: algorithm = .sha512
        default: algorithm = .sha1
        }

        let digits = parameters.digits == 2 ? 8 : 6
        let kind: OTPKind = parameters.type == 1 ? .hotp : .totp

        var issuer = parameters.issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        var account = parameters.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let separator = account.firstIndex(of: ":") {
            let prefix = String(account[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = String(account[account.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if issuer.isEmpty && !prefix.isEmpty {
                issuer = prefix
            }
            if !suffix.isEmpty {
                account = suffix
            }
        }

        let token = OTPToken(
            issuer: issuer,
            accountName: account,
            secret: parameters.secret,
            kind: kind,
            algorithm: algorithm,
            digits: digits,
            period: 30,
            counter: kind == .hotp ? parameters.counter : 0
        )
        do {
            return ImportCandidate(token: try token.validated())
        } catch {
            return ImportCandidate(error: error.localizedDescription)
        }
    }

    static func decodeBase64(_ value: String) -> Data? {
        var normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while normalized.count % 4 != 0 {
            normalized += "="
        }
        return Data(base64Encoded: normalized)
    }
}
