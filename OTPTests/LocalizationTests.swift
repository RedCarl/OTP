import Foundation
import Testing
@testable import OTP

struct LocalizationTests {
    @Test func resolvesSystemLanguage() {
        #expect(AppLanguage.resolved(for: .system, preferredLanguages: ["zh-Hans-CN"]) == .simplifiedChinese)
        #expect(AppLanguage.resolved(for: .system, preferredLanguages: ["zh-Hant-TW"]) == .simplifiedChinese)
        #expect(AppLanguage.resolved(for: .system, preferredLanguages: ["en-US"]) == .english)
        #expect(AppLanguage.resolved(for: .system, preferredLanguages: ["fr-FR"]) == .english)
        #expect(AppLanguage.resolved(for: .english, preferredLanguages: ["zh-Hans-CN"]) == .english)
    }

    @Test func findsEnglishTranslations() {
        #expect(L10n.localized("令牌", language: .english) == "Tokens")
        #expect(L10n.localized("设置", language: .english) == "Settings")
        #expect(L10n.localized("跟随系统", language: .english) == "Follow System")
        #expect(L10n.localized("没有令牌", language: .english) == "No tokens")
    }

    @Test func keepsChineseSourceStrings() {
        #expect(L10n.localized("令牌", language: .simplifiedChinese) == "令牌")
        #expect(L10n.localized("设置", language: .simplifiedChinese) == "设置")
    }

    @Test func unknownKeysFallBackToSource() {
        #expect(L10n.localized("没有这个键", language: .english) == "没有这个键")
    }

    @Test func localizedFormatsUseArguments() {
        let english = L10n.localized("%lld 个令牌", language: .english)
        #expect(String(format: english, 3) == "Tokens: 3")
        let restored = L10n.localized("已恢复：新增 %lld，更新 %lld", language: .english)
        #expect(String(format: restored, 2, 1) == "Restored — added: 2, updated: 1")
    }
}
