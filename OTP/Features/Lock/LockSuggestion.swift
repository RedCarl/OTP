import Foundation

enum LockSuggestion {
    static let minimumTokens = 3
    static let minimumDays = 5

    static func shouldAsk(
        tokenCount: Int,
        firstLaunchAt: Date,
        now: Date,
        hasAsked: Bool,
        isEnabled: Bool
    ) -> Bool {
        guard !hasAsked, !isEnabled, tokenCount >= 1 else { return false }
        if tokenCount >= minimumTokens { return true }
        let days = now.timeIntervalSince(firstLaunchAt) / 86_400
        return days >= Double(minimumDays)
    }
}
