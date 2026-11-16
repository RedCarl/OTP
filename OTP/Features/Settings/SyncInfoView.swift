import SwiftUI

struct SyncInfoView: View {
    var body: some View {
        List {
            Section("开启条件") {
                Text("所有设备登录同一 Apple ID，开启双重认证和 iCloud 钥匙串。")
            }
            Section("同步时机") {
                Text("由系统决定。回到 App 或下拉刷新即可读取最新数据。")
            }
            Section("卸载与换机") {
                Text("钥匙串不随 App 删除，重装后自动恢复。")
            }
        }
        .navigationTitle("同步帮助")
        .navigationBarTitleDisplayMode(.inline)
    }
}
