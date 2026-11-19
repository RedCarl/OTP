import Foundation
import Observation

/// User-selectable interface language. Stored as a raw string in UserDefaults
/// so the value survives launches and `-appLanguage` launch arguments keep
/// working for UI tests and screenshots.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            L10n.t("跟随系统")
        case .simplifiedChinese:
            "简体中文"
        case .english:
            "English"
        }
    }

    /// Resolved once per process: `Locale.preferredLanguages` crosses into
    /// CFPreferences, and `L10n.t` runs for every label in every row body.
    private static let systemLanguage: AppLanguage = {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.lowercased().hasPrefix("zh") ? .simplifiedChinese : .english
    }()

    /// Resolves the language the interface should use. Any Chinese system
    /// language maps to Simplified Chinese; everything else falls back to
    /// English so non-Chinese users never see a Chinese-only UI.
    ///
    /// Pass `preferredLanguages` explicitly to bypass the cached system value.
    static func resolved(
        for language: AppLanguage,
        preferredLanguages: [String]? = nil
    ) -> AppLanguage {
        guard language == .system else { return language }
        guard let preferredLanguages else { return systemLanguage }
        let preferred = preferredLanguages.first ?? "en"
        return preferred.lowercased().hasPrefix("zh") ? .simplifiedChinese : .english
    }
}

/// Observable holder for the language preference and the loaded `.lproj`
/// bundles.
///
/// Every screen reads its copy through `L10n`, which touches `selection` on
/// this object. SwiftUI's Observation tracking therefore refreshes the whole
/// interface the moment a language is picked. The old implementation instead
/// rebuilt the entire tab tree with `.id(appLanguage)`, which reset the
/// navigation stack and made the language screen close itself right after a
/// tap.
@Observable
final class LanguageStore {
    /// Global instance. Created lazily on first read, after launch arguments
    /// have already been registered in `UserDefaults`.
    nonisolated(unsafe) static let shared = LanguageStore()

    /// Key the selection is stored under. Also the `-appLanguage` launch flag.
    static let defaultsKey = "appLanguage"

    @ObservationIgnored private let defaults: UserDefaults
    /// The raw user choice (`.system` included). Reading it is observable.
    private var selection: AppLanguage
    /// Loaded localization bundles, keyed by the language they serve.
    @ObservationIgnored private var bundles: [AppLanguage: Bundle] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.defaultsKey) ?? AppLanguage.system.rawValue
        selection = AppLanguage(rawValue: raw) ?? .system
        bundles[.english] = Self.loadBundle(named: "en")
        bundles[.simplifiedChinese] = Self.loadBundle(named: "zh-Hans")
    }

    /// Stored preference, including `.system`.
    var setting: AppLanguage { selection }

    /// Language actually in effect; never `.system`.
    var language: AppLanguage {
        AppLanguage.resolved(for: selection)
    }

    /// Applies a new choice immediately and persists it.
    func select(_ value: AppLanguage) {
        guard value != selection else { return }
        selection = value
        defaults.set(value.rawValue, forKey: Self.defaultsKey)
    }

    /// Localized string for the current language; falls back to the key,
    /// which is the Simplified Chinese source text.
    func string(_ key: String) -> String {
        guard let bundle = bundles[language] else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// Testable lookup that does not depend on the stored preference.
    func string(_ key: String, language: AppLanguage) -> String {
        guard let bundle = bundles[AppLanguage.resolved(for: language)] else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    private static func loadBundle(named name: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: name, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }
}

/// Runtime localization helper.
///
/// SwiftUI views use `LocalizedStringKey` lookups through the environment
/// locale, while strings produced in models, errors and toasts go through
/// these helpers. Both read the same compiled string catalog, and both follow
/// `LanguageStore` so a language change re-renders every screen in place.
enum L10n {
    static let languageKey = LanguageStore.defaultsKey

    static var selectedLanguage: AppLanguage {
        LanguageStore.shared.setting
    }

    static var language: AppLanguage {
        LanguageStore.shared.language
    }

    static var locale: Locale {
        Locale(identifier: language.rawValue)
    }

    static var isEnglish: Bool {
        language == .english
    }

    /// Switches the interface language right away, without leaving the
    /// current screen.
    static func select(_ language: AppLanguage) {
        LanguageStore.shared.select(language)
    }

    /// Localizes a key using the currently selected interface language.
    static func t(_ key: String) -> String {
        LanguageStore.shared.string(key)
    }

    /// Localizes a format string and fills its arguments with the selected
    /// language's number and date conventions.
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: locale, arguments: arguments)
    }

    /// Testable lookup that does not depend on the stored preference.
    ///
    /// `String(localized:locale:)` only uses the locale for formatting, not
    /// for choosing a `.lproj` table, so load the language bundle directly.
    static func localized(_ key: String, language: AppLanguage) -> String {
        LanguageStore.shared.string(key, language: language)
    }

    /// Formats a date using the selected interface language rather than the
    /// device locale, so the whole screen switches together.
    static func date(
        _ date: Date,
        dateStyle: Date.FormatStyle.DateStyle = .numeric,
        timeStyle: Date.FormatStyle.TimeStyle = .omitted
    ) -> String {
        date.formatted(
            Date.FormatStyle(date: dateStyle, time: timeStyle).locale(locale)
        )
    }
}
