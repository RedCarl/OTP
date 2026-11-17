import SwiftUI

struct SettingsView: View {
    let model: TokenListModel

    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("lockPromptShown") private var lockPromptShown = false
    @AppStorage("clipboardExpiryEnabled") private var clipboardExpiryEnabled = true
    @AppStorage("hideInAppSwitcher") private var hideInAppSwitcher = true
    @AppStorage("lastBackupAt") private var lastBackupAt: Double = 0

    @State private var showBackupExport = false
    @State private var showImport = false
    @State private var showClearConfirmation = false
    @State private var showCopyLinksConfirmation = false
    @State private var showDeviceAuthAlert = false
    @State private var isClearing = false
    @State private var isRefreshing = false
    @State private var isEnablingLock = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        settingLabel("iCloud 钥匙串", systemImage: "icloud")
                        Spacer(minLength: 8)
                        Text("\(model.tokens.count) 个令牌")
                            .foregroundStyle(.secondary)
                        Button {
                            Task {
                                guard !isRefreshing else { return }
                                withAnimation(.easeOut(duration: 0.15)) {
                                    isRefreshing = true
                                }
                                async let refresh: Void = model.refresh()
                                try? await Task.sleep(for: .milliseconds(700))
                                await refresh
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isRefreshing = false
                                }
                            }
                        } label: {
                            ZStack {
                                if isRefreshing {
                                    ProgressView()
                                        .controlSize(.small)
                                        .transition(.opacity.combined(with: .scale(scale: 0.7)))
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 14, weight: .semibold))
                                        .transition(.opacity.combined(with: .scale(scale: 0.7)))
                                }
                            }
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color(.tertiarySystemFill)))
                            .animation(.easeInOut(duration: 0.2), value: isRefreshing)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRefreshing)
                        .accessibilityLabel("刷新")
                        .accessibilityIdentifier("settings.refresh")
                    }
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { appLockEnabled || isEnablingLock },
                        set: { wantsOn in
                            if wantsOn {
                                Task { await enableLock() }
                            } else {
                                appLockEnabled = false
                            }
                        }
                    )) {
                        Text(AppLockController.methodName)
                    }
                    .disabled(isEnablingLock)
                    Toggle("复制后清空剪贴板", isOn: $clipboardExpiryEnabled)
                    Toggle("后台隐藏内容", isOn: $hideInAppSwitcher)
                }

                Section {
                    Button {
                        showBackupExport = true
                    } label: {
                        settingLabel("导出备份", systemImage: "square.and.arrow.up")
                    }
                    .tint(Color.primary)
                    Button {
                        showImport = true
                    } label: {
                        settingLabel("导入数据", systemImage: "square.and.arrow.down")
                    }
                    .tint(Color.primary)
                    Button {
                        showCopyLinksConfirmation = true
                    } label: {
                        settingLabel("复制令牌链接", systemImage: "doc.on.doc")
                    }
                    .tint(Color.primary)
                    .disabled(model.tokens.isEmpty)
                    HStack {
                        settingLabel("上次备份", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text(lastBackupText)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        if isClearing {
                            ProgressView()
                        } else {
                            Label("清空所有令牌", systemImage: "trash")
                        }
                    }
                    .disabled(model.tokens.isEmpty || isClearing)
                }

            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showBackupExport) {
                BackupExportView(model: model)
            }
            .sheet(isPresented: $showImport) {
                ImportFlowView(model: model, mode: .file)
            }
            .alert("无法开启解锁保护", isPresented: $showDeviceAuthAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text("请先在系统设置里为这台设备设置锁屏密码。")
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

    private func enableLock() async {
        guard !isEnablingLock else { return }
        guard AppLockController.canAuthenticate else {
            showDeviceAuthAlert = true
            return
        }
        isEnablingLock = true
        let success = await AppLockController.authenticate(reason: "开启 Face ID 解锁")
        isEnablingLock = false
        guard success else {
            model.showToast("未开启")
            return
        }
        appLockEnabled = true
        lockPromptShown = true
        model.showToast("已开启 Face ID")
    }

    private func settingLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
        }
    }

    private var lastBackupText: String {
        guard lastBackupAt > 0 else { return "从未备份" }
        return Date(timeIntervalSince1970: lastBackupAt).formatted(date: .numeric, time: .omitted)
    }
}