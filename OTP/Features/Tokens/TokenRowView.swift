import SwiftUI

/// `Equatable` so the list can skip rebuilding a row whose code did not change
/// (the countdown inside the row ticks on its own).
struct TokenRowView: View, Equatable {
    let token: OTPToken
    let code: String?

    var body: some View {
        HStack(spacing: 12) {
            TokenIconView(token: token, size: 36)

            VStack(alignment: .leading, spacing: 1) {
                MarqueeText(text: token.displayIssuer, font: .headline, height: 21)
                if !token.displayAccount.isEmpty {
                    Text(token.displayAccount)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if token.kind == .hotp {
                    Text("基于计数器")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if token.kind == .totp {
                // Only this subtree re-evaluates on the clock tick. Keeping the
                // countdown inside the row leaves the list (and every other
                // row) untouched, instead of invalidating all of it twice a
                // second from the model.
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    trailing(at: context.date)
                }
            } else {
                trailing(at: nil)
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("token.row")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("轻点复制验证码")
    }

    /// `date` is nil for counter-based tokens, which have no countdown.
    private func trailing(at date: Date?) -> some View {
        let remaining = date.map { TOTP.remaining(at: $0, period: token.period) } ?? 0
        let progress = date.map { TOTP.progress(at: $0, period: token.period) } ?? 0
        let isUrgent = date != nil && remaining <= 5

        return HStack(spacing: 8) {
            if let code {
                Text(OTPCodeFormatter.grouped(code))
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(isUrgent ? Color.orange : Color.primary)
                    .contentTransition(.numericText())
                    .privacySensitive()
            } else {
                Text(token.kind == .hotp ? L10n.t("点击生成") : "—")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if token.kind == .totp {
                CountdownRing(progress: progress, urgent: isUrgent, seconds: remaining, size: 30)
            }
        }
        .fixedSize()
    }

    private var accessibilityLabel: String {
        var parts: [String] = [token.displayIssuer]
        if !token.displayAccount.isEmpty { parts.append(token.displayAccount) }
        if let code {
            parts.append(L10n.format("验证码 %@", OTPCodeFormatter.grouped(code)))
            if token.kind == .totp {
                parts.append(L10n.format("剩余 %lld 秒", TOTP.remaining(at: Date(), period: token.period)))
            }
        } else if token.kind == .hotp {
            parts.append(L10n.t("基于计数器，点按生成验证码"))
        }
        return parts.joined(separator: L10n.isEnglish ? ", " : "，")
    }
}
