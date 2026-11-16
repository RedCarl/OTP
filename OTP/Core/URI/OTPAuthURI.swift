import Foundation

/// https://github.com/google/google-authenticator/wiki/Key-Uri-Format
enum OTPAuthURI {
    private static let pathAllowed: CharacterSet = {
        CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:")
    }()

    static func parse(_ string: String) throws -> OTPToken {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "otpauth" else {
            throw OTPError.notOTPAuthURL
        }

        let rawKind = components.host?.lowercased() ?? ""
        guard let kind = OTPKind(rawValue: rawKind) else {
            throw OTPError.unsupportedKind(rawKind)
        }

        let label = (components.path.removingPercentEncoding ?? components.path)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let queryItems = components.queryItems ?? []
        func query(_ name: String) -> String? {
            queryItems.first { $0.name.lowercased() == name }?.value
        }

        var labelIssuer = ""
        var labelAccount = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if let separator = labelAccount.firstIndex(of: ":") {
            labelIssuer = String(labelAccount[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            labelAccount = String(labelAccount[labelAccount.index(after: separator)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let issuerParameter = (query("issuer") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let issuer = issuerParameter.isEmpty ? labelIssuer : issuerParameter

        guard let secretValue = query("secret")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !secretValue.isEmpty else {
            throw OTPError.missingSecret
        }
        guard let secret = Base32.decode(secretValue), !secret.isEmpty else {
            throw OTPError.invalidSecret
        }

        let digitsValue = (query("digits") ?? "6").trimmingCharacters(in: .whitespaces)
        guard let digits = Int(digitsValue), (6...8).contains(digits) else {
            throw OTPError.invalidDigits(Int(digitsValue) ?? -1)
        }

        let periodValue = (query("period") ?? "30").trimmingCharacters(in: .whitespaces)
        guard let period = Int(periodValue), (1...3600).contains(period) else {
            throw OTPError.invalidPeriod(Int(periodValue) ?? -1)
        }

        var counter: UInt64 = 0
        if kind == .hotp {
            let counterValue = (query("counter") ?? "0").trimmingCharacters(in: .whitespaces)
            guard let parsedCounter = UInt64(counterValue) else {
                throw OTPError.invalidCounter(counterValue)
            }
            counter = parsedCounter
        }

        let algorithmValue = (query("algorithm") ?? "SHA1").uppercased()
        guard let algorithm = OTPAlgorithm(rawValue: algorithmValue.lowercased()) else {
            throw OTPError.invalidAlgorithm(algorithmValue)
        }

        return OTPToken(
            issuer: issuer,
            accountName: labelAccount,
            secret: secret,
            kind: kind,
            algorithm: algorithm,
            digits: digits,
            period: period,
            counter: counter
        )
    }

    static func string(from token: OTPToken) -> String {
        var components = URLComponents()
        components.scheme = "otpauth"
        components.host = token.kind.rawValue

        let label: String
        if token.issuer.isEmpty {
            label = token.accountName
        } else {
            label = "\(token.issuer):\(token.accountName)"
        }
        components.percentEncodedPath = "/" + (label.addingPercentEncoding(withAllowedCharacters: pathAllowed) ?? label)

        var items: [URLQueryItem] = [URLQueryItem(name: "secret", value: Base32.encode(token.secret))]
        if !token.issuer.isEmpty {
            items.append(URLQueryItem(name: "issuer", value: token.issuer))
        }
        if token.algorithm != .sha1 {
            items.append(URLQueryItem(name: "algorithm", value: token.algorithm.rawValue.uppercased()))
        }
        if token.digits != 6 {
            items.append(URLQueryItem(name: "digits", value: String(token.digits)))
        }
        if token.kind == .totp && token.period != 30 {
            items.append(URLQueryItem(name: "period", value: String(token.period)))
        }
        if token.kind == .hotp {
            items.append(URLQueryItem(name: "counter", value: String(token.counter)))
        }
        components.queryItems = items
        return components.string ?? ""
    }
}
