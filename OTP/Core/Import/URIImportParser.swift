import Foundation

enum URIImportParser {
    static func parseText(_ text: String) -> [ImportCandidate] {
        var candidates: [ImportCandidate] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.lowercased().hasPrefix("otpauth-migration://") {
                do {
                    candidates.append(contentsOf: try GoogleAuthenticatorImport.parse(urlString: line))
                } catch {
                    candidates.append(ImportCandidate(error: error.localizedDescription))
                }
            } else if line.lowercased().hasPrefix("otpauth://") {
                do {
                    let token = try OTPAuthURI.parse(line).validated()
                    candidates.append(ImportCandidate(token: token))
                } catch {
                    candidates.append(ImportCandidate(error: error.localizedDescription))
                }
            } else {
                candidates.append(ImportCandidate(error: "无法识别的链接，应以 otpauth:// 开头"))
            }
        }
        return candidates
    }
}
