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
            return L10n.t("没有可备份的令牌")
        case .passphraseTooShort(let minimum):
            return L10n.format("备份密码至少需要 %lld 位字符", minimum)
        case .missingPassphrase:
            return L10n.t("这个备份已加密，请输入备份密码")
        case .wrongPassphraseOrCorrupted:
            return L10n.t("密码错误，或备份文件已损坏")
        case .notBackupFile:
            return L10n.t("这不是 OTP 备份文件")
        case .unsupportedVersion(let version):
            return L10n.format("备份文件来自更新版本（v%lld），请升级 App 后再导入", version)
        case .cryptoFailed:
            return L10n.t("加密处理失败")
        }
    }
}
