import Foundation
import Testing
@testable import OTP

struct LockSuggestionTests {
    private let firstLaunch = Date(timeIntervalSince1970: 1_700_000_000)
    private var now: Date { firstLaunch.addingTimeInterval(86_400) }

    @Test func asksAfterEnoughTokens() {
        #expect(LockSuggestion.shouldAsk(
            tokenCount: 3, firstLaunchAt: firstLaunch, now: now, hasAsked: false, isEnabled: false
        ))
    }

    @Test func asksAfterEnoughDays() {
        let later = firstLaunch.addingTimeInterval(6 * 86_400)
        #expect(LockSuggestion.shouldAsk(
            tokenCount: 1, firstLaunchAt: firstLaunch, now: later, hasAsked: false, isEnabled: false
        ))
    }

    @Test func staysQuietWhenAlreadyAnswered() {
        #expect(!LockSuggestion.shouldAsk(
            tokenCount: 5, firstLaunchAt: firstLaunch, now: now, hasAsked: true, isEnabled: false
        ))
        #expect(!LockSuggestion.shouldAsk(
            tokenCount: 5, firstLaunchAt: firstLaunch, now: now, hasAsked: false, isEnabled: true
        ))
    }

    @Test func waitsForFirstTokenAndTime() {
        #expect(!LockSuggestion.shouldAsk(
            tokenCount: 0, firstLaunchAt: firstLaunch, now: now, hasAsked: false, isEnabled: false
        ))
        #expect(!LockSuggestion.shouldAsk(
            tokenCount: 2, firstLaunchAt: firstLaunch, now: now, hasAsked: false, isEnabled: false
        ))
    }
}
