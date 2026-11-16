import SwiftUI

struct SettingsView: View {
    let model: TokenListModel

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLockEnabled") private var appLockEnabled = true
    @AppStorage("clipboardExpiryEnabled") private var clipboardExpiryEnabled = true
    @AppStorage("hideInAppSwitcher") private var hideInAppSwitcher = true
    @AppStorage("lastBackupAt") private var lastBackupAt: Double = 0

    @State private var showBackupExport = false
    @State private var showImport = false
    @State private var showClearConfirmation = false
    @State private var showCopyLinksConfirmation = false
    @State private var isClearing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("同步方式", systemImage: "icloud")
                        Spacer()
                        Text("iCloud 钥匙串").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("令牌数量", systemImage: "key")
                        Spacer()
                        Text("\(model.tokens.count)").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("上次刷新", systemImage: "arrow.clockwise")
                        Spacer()
                        Text(lastRefreshText).foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Label("立即刷新", systemImage: "arrow.triangle.2.circlepath")
                    }
                    NavigationLink {
                        SyncInfoView()
                    } label: {
                        Label("如何跨设备同步？", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("iCloud 同步").textCase(nil)
                } footer: {
                    Text("令牌保存在 iCloud 钥匙串中，开启同步后同一 Apple ID 的设备会自动获得。")
                }

                Section {
                    Toggle(isOn: $appLockEnabled) {
                        Label("Face ID 解锁", systemImage: "faceid")
                    }
                    Toggle(isOn: $clipboardExpiryEnabled) {
                        Label("复制 30 秒后清空剪贴板", systemImage: "clipboard")
                    }
                    Toggle(isOn: $hideInAppSwitcher) {
                        Label("切换到后台时隐藏内容", systemImage: "eye.slash")
                    }
                } header: {
                    Text("安全").textCase(nil)
                } footer: {
                    Text("Face ID 不可用时（例如未设置密码）会自动跳过锁定，避免把自己锁在外面。")
                }

                Section {
                    Button {
                        showBackupExport = true
                    } label: {
                        Label("导出备份", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showImport = true
                    } label: {
                        Label("导入备份或其他 App 数据", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        showCopyLinksConfirmation = true
                    } label: {
                        Label("复制全部令牌链接", systemImage: "doc.on.doc")
                    }
                    .disabled(model.tokens.isEmpty)
                    HStack {
                        Label("上次备份", systemImage: "clock")
                        Spacer()
                        Text(lastBackupText)
                            .foregroundStyle(lastBackupAt == 0 && model.tokens.count >= 3 ? Color.orange : Color.secondary)
                    }
                } header: {
                    Text("备份与迁移").textCase(nil)
                } footer: {
                    Text("备份文件可保存到 iCloud Drive；二维码导出在令牌的长按菜单里。")
                }

                Section {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        if isClearing {
                            ProgressView()
                        } else {
                            Text("清空所有令牌")
                        }
                    }
                    .disabled(model.tokens.isEmpty || isClearing)
                } header: {
                    Text("数据").textCase(nil)
                } footer: {
                    Text("会删除钥匙串中的所有令牌（包括已同步到其他设备的），建议先导出备份。")
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("安全与隐私", systemImage: "hand.raised")
                    }
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(versionString).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("关于").textCase(nil)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showBackupExport) {
                BackupExportView(model: model)
            }
            .sheet(isPresented: $showImport) {
                ImportFlowView(model: model, mode: .file)
            }
            .alert("复制明文链接？", isPresented: $showCopyLinksConfirmation) {
                Button("复制") {
                    let links = model.tokens.map(\.uri).joined(separator: "\n")
                    Clipboard.copy(links, expiresIn: 60)
                    model.showToast("已复制 \(model.tokens.count) 个令牌链接")
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("链接中包含密钥，任何拿到剪贴板的人都能导入。请只粘贴到可信的位置。")
            }
            .alert("清空所有令牌？", isPresented: $showClearConfirmation) {
                Button("清空", role: .destructive) {
                    Task {
                        isClearing = true
                        await model.deleteAll()
                        isClearing = false
                        model.showToast("已清空所有令牌")
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("这个操作会删除所有设备上的令牌，且无法撤销。建议先导出备份。")
            }
        }
    }

    private var lastRefreshText: String {
        guard let date = model.lastRefreshedAt else { return "尚未刷新" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private var lastBackupText: String {
        guard lastBackupAt > 0 else { return "从未备份" }
        return Date(timeIntervalSince1970: lastBackupAt).formatted(date: .numeric, time: .shortened)
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}