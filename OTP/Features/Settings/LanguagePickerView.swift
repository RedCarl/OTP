import SwiftUI
import UIKit

/// Language chooser pushed from Settings.
///
/// Tapping a row applies the language immediately and leaves this screen where
/// it is: the check mark, the row labels and the title all update in place so
/// the user can keep comparing options. The previous `Picker(.navigationLink)`
/// popped back to Settings on every tap, and the whole-tree
/// `.id(appLanguage)` rebuild reset the navigation stack on top of that.
struct LanguagePickerView: View {
    /// Local mirror of the stored choice: setting it re-runs this body, which
    /// is what re-applies the navigation title in the new language. Relying on
    /// the shared store alone only refreshes the row that changed.
    @State private var selection = L10n.selectedLanguage

    var body: some View {
        List {
            ForEach(AppLanguage.allCases) { language in
                row(for: language)
            }
        }
        .navigationTitle(L10n.t("语言"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.language.page")
    }

    private func row(for language: AppLanguage) -> some View {
        let isSelected = selection == language
        return Button {
            guard !isSelected else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                L10n.select(language)
            }
            selection = language
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 12) {
                Text(language.displayName)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.language.row.\(language.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
