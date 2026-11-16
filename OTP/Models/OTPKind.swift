import Foundation

enum OTPKind: String, Codable, CaseIterable, Sendable {
    case totp
    case hotp

    var displayName: String {
        switch self {
        case .totp: "基于时间"
        case .hotp: "基于计数器"
        }
    }
}
