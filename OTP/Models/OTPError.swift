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
            "这不是一个 otpauth:// 链接"
        case .unsupportedKind(let kind):
            "不支持的令牌类型：\(kind)"
        case .missingSecret:
            "缺少密钥（secret）"
        case .invalidSecret:
            "密钥不是合法的 Base32 字符串"
        case .invalidDigits(let digits):
            "验证码位数必须在 6 到 8 之间（当前 \(digits)）"
        case .invalidPeriod(let period):
            "刷新周期必须在 1 到 3600 秒之间（当前 \(period)）"
        case .invalidCounter(let value):
            "计数器不合法：\(value)"
        case .invalidAlgorithm(let algorithm):
            "不支持的哈希算法：\(algorithm)"
        case .unsupportedVersion(let version):
            "该令牌来自更新版本（v\(version)），当前版本无法读取"
        case .invalidRecord(let reason):
            "令牌数据损坏：\(reason)"
        }
    }
}
