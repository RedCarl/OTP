import Foundation
import Security

enum KeychainError: LocalizedError, Equatable {
    case interactionNotAllowed
    case quotaExceeded
    case missingEntitlement
    case unexpectedStatus(OSStatus)
    case encodingFailed

    static func from(_ status: OSStatus) -> KeychainError {
        switch status {
        case errSecInteractionNotAllowed:
            return .interactionNotAllowed
        case errSecQuotaExceeded, errSecAllocate:
            return .quotaExceeded
        case errSecMissingEntitlement:
            return .missingEntitlement
        default:
            return .unexpectedStatus(status)
        }
    }

    var errorDescription: String? {
        switch self {
        case .interactionNotAllowed:
            return L10n.t("设备已锁定，解锁后请重试")
        case .quotaExceeded:
            return L10n.t("钥匙串空间不足，请先导出备份并清理旧令牌")
        case .missingEntitlement:
            return L10n.t("钥匙串不可用：签名缺少钥匙串权限")
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? L10n.t("未知错误")
            return L10n.format("钥匙串操作失败（%lld）：%@", Int(status), message)
        case .encodingFailed:
            return L10n.t("令牌数据无法编码")
        }
    }
}
