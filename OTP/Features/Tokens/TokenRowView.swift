import SwiftUI

struct TokenRowView: View {
    let token: OTPToken
    let code: String?
    let remaining: Int
    let progress: Double
    let isCopied: Bool

    private var urgent: Bool {
        token.kind == .totp && remaining <= 5
    }

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

            HStack(spacing: 8) {
                if let code {
                    Text(OTPCodeFormatter.grouped(code))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(urgent ? Color.orange : Color.primary)
                        .contentTransition(.numericText())
                        .privacySensitive()
                } else {
                    Text(token.kind == .hotp ? "点击生成" : "—")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                if token.kind == .totp {
                    CountdownRing(progress: progress, urgent: urgent, seconds: remaining, size: 30)
                }
            }
            .fixedSize()
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("token.row")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("轻点复制验证码")
    }

    private var accessibilityLabel: String {
        var parts: [String] = [token.displayIssuer]
        if !token.displayAccount.isEmpty { parts.append(token.displayAccount) }
        if let code {
            parts.append("验证码 " + OTPCodeFormatter.grouped(code))
            parts.append("剩余 \(remaining) 秒")
        } else if token.kind == .hotp {
            parts.append("基于计数器，点按生成验证码")
        }
        return parts.joined(separator: "，")
    }
}