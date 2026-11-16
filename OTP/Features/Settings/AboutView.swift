import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                Text("令牌只保存在 iCloud 钥匙串，App 不联网、不上传数据。")
            } footer: {
                Text("版本 \(versionString)")
            }
            Section("备份") {
                Text("AES-256-GCM 加密，忘记密码无法恢复。")
            }
            Section("支持导入") {
                Text("otpauth 链接、Google Authenticator、Aegis、2FAS、OTP 备份。")
            }
        }
        .navigationTitle("关于 OTP")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
