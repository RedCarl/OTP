import Foundation
import Testing
@testable import OTP

@MainActor
struct AppLinksTests {
    @Test func appStoreURLsPointAtTheListing() {
        #expect(AppLinks.appStoreURL.absoluteString == "https://apps.apple.com/app/id6835475936")
        #expect(AppLinks.writeReviewURL.absoluteString.hasSuffix("?action=write-review"))
        #expect(AppLinks.writeReviewAppURL.scheme == "itms-apps")
        #expect(AppLinks.writeReviewAppURL.absoluteString.contains("id6835475936"))
    }

    @Test func feedbackEmailIsPrefilled() throws {
        let url = try #require(AppLinks.feedbackURL)
        #expect(url.absoluteString.hasPrefix("mailto:carl030101@icloud.com?"))

        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        let subject = try #require(items.first { $0.name == "subject" }?.value)
        let body = try #require(items.first { $0.name == "body" }?.value)
        #expect(subject.contains("OTP"))
        #expect(subject.contains(AppLinks.appVersion))
        #expect(body.contains(AppLinks.appVersion))
        #expect(body.contains(AppLinks.buildNumber))
        #expect(body.contains("iOS"))
    }

    @Test func shareMessageCarriesTheAppName() {
        #expect(AppLinks.shareMessage.contains("OTP"))
    }

    @Test func supportRowsAreLocalized() {
        #expect(L10n.localized("去应用商店评分", language: .english) == "Rate on the App Store")
        #expect(L10n.localized("分享应用", language: .english) == "Share App")
        #expect(L10n.localized("意见反馈（邮件）", language: .english) == "Feedback (Email)")
    }
}
