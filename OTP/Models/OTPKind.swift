import Foundation

enum OTPKind: String, Codable, CaseIterable, Sendable {
    case totp
    case hotp

    var displayName: String {
        switch self {
        case .totp: L10n.t("基于时间")
        case .hotp: L10n.t("基于计数器")
        }
    }
}
