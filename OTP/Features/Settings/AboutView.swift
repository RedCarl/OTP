import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("数据在哪里")
                        .font(.headline)
                    Text("所有令牌只保存在你的 iCloud 钥匙串里，由 Apple 端到端加密。App 不包含任何网络请求、分析或第三方 SDK。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("备份")
                        .font(.headline)
                    Text("备份文件是明文 JSON 或用密码加密的 JSON（PBKDF2-HMAC-SHA256 + AES-256-GCM）。密码不会保存在设备上，遗忘后无法恢复。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("支持的格式")
                        .font(.headline)
                    Text("otpauth:// 链接、Google Authenticator 迁移二维码、Aegis 明文备份、2FAS 明文备份、本 App 备份文件。不支持 Steam Guard 与加密的 Aegis/2FAS 备份。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("时间准确性")
                        .font(.headline)
                    Text("基于时间的验证码依赖系统时间，请保持「自动设置时间」开启。若验证码总是不对，先检查时间，再检查密钥或时区设置。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("安全与隐私")
        .navigationBarTitleDisplayMode(.inline)
    }
}
