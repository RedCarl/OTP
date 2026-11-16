import SwiftUI

struct OnboardingView: View {
    /// Called with true when the user wants to import right after onboarding.
    var onFinish: (Bool) -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 12)

            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.tint)
                .padding(.bottom, 2)

            VStack(spacing: 8) {
                Text("验证码，跟着 iCloud 走")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("所有令牌都保存在 iCloud 钥匙串里，端到端加密，自动同步到你的其他设备。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "icloud.fill", title: "iCloud 钥匙串同步", detail: "换设备、重装 App 后自动恢复，无需注册账号")
                featureRow(icon: "qrcode.viewfinder", title: "扫码与导入", detail: "支持 otpauth 链接、Google Authenticator 迁移码、Aegis 与 2FAS")
                featureRow(icon: "faceid", title: "Face ID 保护", detail: "离开后自动锁定，复制验证码 30 秒后自动清空剪贴板")
            }
            .padding(.horizontal, 30)
            .padding(.top, 6)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    onFinish(false)
                } label: {
                    Text("开始使用")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("从 Google Authenticator 导入") {
                    onFinish(true)
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.tint)
            }
            .padding(.horizontal, 30)

            Text("不联网、不上传、不收集任何数据。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
