import SwiftUI

struct TokenRowView: View {
    let token: OTPToken
    let code: String?
    let remaining: Int
    let progress: Double
    let isCopied: Bool

    private var urgent: Bool { remaining <= 5 }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(token.displayIssuer)
                    .font(.headline)
                    .lineLimit(1)
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

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                if let code {
                    Text(OTPCodeFormatter.grouped(code))
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
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
                    HStack(spacing: 5) {
                        CountdownRing(progress: progress, urgent: urgent)
                        Text("\(remaining)s")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                            .frame(width: 22, alignment: .leading)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .overlay(alignment: .trailing) {
            if isCopied {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: isCopied)
                    .offset(x: 26)
            }
        }
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