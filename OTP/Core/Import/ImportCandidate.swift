import Foundation

enum ImportFormat: String, Sendable {
    case otpAuthURI
    case googleMigration
    case backup
    case aegis
    case twoFAS
    case text

    var displayName: String {
        switch self {
        case .otpAuthURI: "otpauth 链接"
        case .googleMigration: "Google Authenticator 迁移码"
        case .backup: "OTP 备份文件"
        case .aegis: "Aegis 备份"
        case .twoFAS: "2FAS 备份"
        case .text: "文本"
        }
    }
}

struct ImportCandidate: Identifiable, Sendable {
    let id: UUID
    var token: OTPToken?
    var errorMessage: String?

    init(token: OTPToken) {
        self.id = UUID()
        self.token = token
        self.errorMessage = nil
    }

    init(error: String) {
        self.id = UUID()
        self.token = nil
        self.errorMessage = error
    }

    var isError: Bool { token == nil }

    var title: String {
        if let token { return token.displayIssuer }
        return "无法识别的条目"
    }

    var subtitle: String {
        if let token { return token.displayAccount }
        return errorMessage ?? ""
    }
}

struct ImportOutcome: Sendable {
    var format: ImportFormat
    var candidates: [ImportCandidate]
    var warnings: [String]

    var validTokens: [OTPToken] {
        candidates.compactMap(\.token)
    }

    var errorCount: Int {
        candidates.filter(\.isError).count
    }
}

enum ImportError: LocalizedError, Equatable {
    case noRecognizableTokens
    case unsupportedFile
    case encryptedAegis
    case encryptedTwoFAS
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case .noRecognizableTokens:
            "没有找到可导入的令牌"
        case .unsupportedFile:
            "无法识别这个文件，请选择 OTP 备份、Aegis/2FAS 导出或包含 otpauth 链接的文本"
        case .encryptedAegis:
            "Aegis 备份已加密，请先在 Aegis 中导出未加密备份"
        case .encryptedTwoFAS:
            "2FAS 备份已加密，请先在 2FAS 中导出未加密备份"
        case .malformed(let reason):
            reason
        }
    }
}
