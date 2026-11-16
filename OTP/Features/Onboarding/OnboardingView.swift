import SwiftUI

struct OnboardingView: View {
    /// Called with true when the user wants to import right after onboarding.
    var onFinish: (Bool) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)

            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("验证码，跟着 iCloud 走")
                    .font(.title2.weight(.bold))
                Text("端到端加密，自动同步到其他设备。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                Label("iCloud 钥匙串同步", systemImage: "icloud.fill")
                Label("扫码或文件导入", systemImage: "qrcode.viewfinder")
                Label("Face ID 与剪贴板保护", systemImage: "faceid")
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 40)
            .padding(.top, 8)

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
            .padding(.bottom, 28)
        }
    }
}