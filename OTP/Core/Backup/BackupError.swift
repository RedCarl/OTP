import Foundation

enum BackupError: LocalizedError, Equatable {
    case noTokens
    case passphraseTooShort(Int)
    case missingPassphrase
    case wrongPassphraseOrCorrupted
    case notBackupFile
    case unsupportedVersion(Int)
    case cryptoFailed

    var errorDescription: String? {
        switch self {
        case .noTokens:
            return "没有可备份的令牌"
        case .passphraseTooShort(let minimum):
            return "备份密码至少需要 \(minimum) 位字符"
        case .missingPassphrase:
            return "这个备份已加密，请输入备份密码"
        case .wrongPassphraseOrCorrupted:
            return "密码错误，或备份文件已损坏"
        case .notBackupFile:
            return "这不是 OTP 备份文件"
        case .unsupportedVersion(let version):
            return "备份文件来自更新版本（v\(version)），请升级 App 后再导入"
        case .cryptoFailed:
            return "加密处理失败"
        }
    }
}
