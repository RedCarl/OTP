import Foundation

/// Deterministic ISO-8601 formatting for the keychain / backup schema.
enum ISO8601Value {
    private static let fractionalStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let plainStyle = Date.ISO8601FormatStyle()

    static func string(from date: Date) -> String {
        date.formatted(fractionalStyle)
    }

    static func date(from string: String) -> Date? {
        if let parsed = try? Date(string, strategy: fractionalStyle) {
            return parsed
        }
        return try? Date(string, strategy: plainStyle)
    }
}
