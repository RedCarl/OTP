import SwiftUI

struct SyncInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section(
                    title: "同步是怎么工作的",
                    body: "每个令牌都是一条 iCloud 钥匙串条目。iCloud 钥匙串由 Apple 端到端加密，App 不经过任何服务器，也不会上传明文密钥。"
                )

                section(
                    title: "同步需要满足",
                    bullets: [
                        "所有设备登录同一个 Apple ID",
                        "已开启双重认证",
                        "已开启「iCloud 钥匙串」（设置 → 你的名字 → iCloud → 密码与钥匙串 → 同步此 iPhone）",
                        "设备设置了锁屏密码",
                    ]
                )

                section(
                    title: "如何确认已经同步",
                    bullets: [
                        "在 A 设备添加或修改一个令牌",
                        "在 B 设备把 App 切回前台或下拉刷新",
                        "删除同样会同步：B 设备上刷新后会消失",
                    ]
                )

                section(
                    title: "常见问题",
                    body: "同步时机由系统决定，通常几秒到几分钟。App 无法读取系统的同步状态，所以这里显示的是本机钥匙串里的条目数。如果长时间不同步，请检查上面的设置，或先导出备份再重装 App 试试。"
                )

                section(
                    title: "卸载与换机",
                    body: "钥匙串条目不随 App 删除而删除。换新设备或重装后，只要 iCloud 钥匙串开启，令牌会自动回来；因此「清空所有令牌」需要在 App 内主动操作。"
                )
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("iCloud 同步")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func section(title: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 8) {
                    Text("•").foregroundStyle(.tertiary)
                    Text(bullet)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
