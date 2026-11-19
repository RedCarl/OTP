import Foundation

enum OTPError: LocalizedError, Equatable {
    case notOTPAuthURL
    case unsupportedKind(String)
    case missingSecret
    case invalidSecret
    case invalidDigits(Int)
    case invalidPeriod(Int)
    case invalidCounter(String)
    case invalidAlgorithm(String)
    case unsupportedVersion(Int)
    case invalidRecord(String)

    var errorDescription: String? {
        switch self {
        case .notOTPAuthURL:
            L10n.t("这不是一个 otpauth:// 链接")
        case .unsupportedKind(let kind):
            L10n.format("不支持的令牌类型：%@", kind)
        case .missingSecret:
            L10n.t("缺少密钥（secret）")
        case .invalidSecret:
            L10n.t("密钥不是合法的 Base32 字符串")
        case .invalidDigits(let digits):
            L10n.format("验证码位数必须在 6 到 8 之间（当前 %lld）", digits)
        case .invalidPeriod(let period):
            L10n.format("刷新周期必须在 1 到 3600 秒之间（当前 %lld）", period)
        case .invalidCounter(let value):
            L10n.format("计数器不合法：%@", value)
        case .invalidAlgorithm(let algorithm):
            L10n.format("不支持的哈希算法：%@", algorithm)
        case .unsupportedVersion(let version):
            L10n.format("该令牌来自更新版本（v%lld），当前版本无法读取", version)
        case .invalidRecord(let reason):
            L10n.format("令牌数据损坏：%@", reason)
        }
    }
}
