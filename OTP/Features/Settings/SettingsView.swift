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
                        Label("iCloud 钥匙串", systemImage: "icloud")
                        Spacer()
                        Text("\(model.tokens.count) 个令牌")
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    NavigationLink {
                        SyncInfoView()
                    } label: {
                        Label("同步帮助", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("iCloud").textCase(nil)
                }

                Section("安全") {
                    Toggle("Face ID 解锁", isOn: $appLockEnabled)
                    Toggle("复制后清空剪贴板", isOn: $clipboardExpiryEnabled)
                    Toggle("后台隐藏内容", isOn: $hideInAppSwitcher)
                }

                Section("备份") {
                    Button {
                        showBackupExport = true
                    } label: {
                        Label("导出备份", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showImport = true
                    } label: {
                        Label("导入数据", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        showCopyLinksConfirmation = true
                    } label: {
                        Label("复制令牌链接", systemImage: "doc.on.doc")
                    }
                    .disabled(model.tokens.isEmpty)
                    HStack {
                        Text("上次备份")
                        Spacer()
                        Text(lastBackupText)
                            .foregroundStyle(lastBackupAt == 0 && model.tokens.count >= 3 ? Color.orange : Color.secondary)
                    }
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

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("关于 OTP", systemImage: "info.circle")
                    }
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
                    model.showToast("已复制 \(model.tokens.count) 个链接")
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("链接包含密钥，请谨慎粘贴。")
            }
            .alert("清空所有令牌？", isPresented: $showClearConfirmation) {
                Button("清空", role: .destructive) {
                    Task {
                        isClearing = true
                        await model.deleteAll()
                        isClearing = false
                        model.showToast("已清空")
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("所有设备上的令牌都会被删除，无法撤销。")
            }
        }
    }

    private var lastBackupText: String {
        guard lastBackupAt > 0 else { return "从未备份" }
        return Date(timeIntervalSince1970: lastBackupAt).formatted(date: .numeric, time: .omitted)
    }
}