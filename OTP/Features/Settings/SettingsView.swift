import SwiftUI

struct SettingsView: View {
    let model: TokenListModel
    var onRequestClear: () -> Void

    @Environment(\.openURL) private var openURL

    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("lockPromptShown") private var lockPromptShown = false
    @AppStorage("clipboardExpiryEnabled") private var clipboardExpiryEnabled = true
    @AppStorage("hideInAppSwitcher") private var hideInAppSwitcher = true
    @AppStorage("lastBackupAt") private var lastBackupAt: Double = 0

    @State private var showBackupExport = false
    @State private var showBackupCenter = false
    @State private var showImport = false
    @State private var showCopyLinksConfirmation = false
    @State private var showDeviceAuthAlert = false
    @State private var isRefreshing = false
    @State private var isEnablingLock = false
    @State private var openFailureMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        settingLabel("iCloud 钥匙串", systemImage: "icloud")
                        Spacer(minLength: 8)
                        Text(L10n.format("%lld 个令牌", model.tokens.count))
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
                    NavigationLink {
                        LanguagePickerView()
                    } label: {
                        HStack(spacing: 8) {
                            settingLabel("语言", systemImage: "globe")
                            Spacer(minLength: 8)
                            Text(L10n.selectedLanguage.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("settings.language")
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
                        showBackupCenter = true
                    } label: {
                        HStack {
                            settingLabel("iCloud 备份", systemImage: "icloud.and.arrow.up")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .tint(Color.primary)
                    .accessibilityIdentifier("settings.backupCenter")

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
                    .accessibilityIdentifier("settings.import")
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
                    Button {
                        rateApp()
                    } label: {
                        settingLabel("去应用商店评分", systemImage: "star")
                    }
                    .tint(Color.primary)
                    .accessibilityIdentifier("settings.rateApp")

                    ShareLink(
                        item: AppLinks.appStoreURL,
                        subject: Text(L10n.t("OTP · 两步验证")),
                        message: Text(AppLinks.shareMessage)
                    ) {
                        settingLabel("分享应用", systemImage: "square.and.arrow.up")
                    }
                    .tint(Color.primary)
                    .accessibilityIdentifier("settings.shareApp")

                    Button {
                        sendFeedback()
                    } label: {
                        settingLabel("意见反馈（邮件）", systemImage: "envelope")
                    }
                    .tint(Color.primary)
                    .accessibilityIdentifier("settings.feedback")
                }

                if !model.tokens.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            onRequestClear()
                        } label: {
                            Label("清空所有令牌", systemImage: "trash")
                        }
                        .accessibilityIdentifier("settings.clearRow")
                    }
                }

            }
            // Resolved string rather than a LocalizedStringKey: the navigation
            // bar keeps a title it received as a key, so it would stay in the
            // previous language until the screen was recreated.
            .navigationTitle(L10n.t("设置"))
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showBackupExport) {
                BackupExportView(model: model)
            }
            .sheet(isPresented: $showBackupCenter) {
                BackupCenterView(model: model)
            }
            .sheet(isPresented: $showImport) {
                // 先进导入页选来源；文件选择器在导入页里面弹，不再叠两层窗口。
                ImportFlowView(model: model, mode: .pick)
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
                    model.showToast(L10n.format("已复制 %lld 个链接", model.tokens.count))
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("链接包含密钥，请谨慎粘贴。")
            }
            .alert(L10n.t("无法完成操作"), isPresented: Binding(
                get: { openFailureMessage != nil },
                set: { presented in
                    if !presented { openFailureMessage = nil }
                }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(openFailureMessage ?? "")
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
        let success = await AppLockController.authenticate(reason: L10n.t("开启解锁保护"))
        isEnablingLock = false
        guard success else {
            model.showToast(L10n.t("未开启"))
            return
        }
        appLockEnabled = true
        lockPromptShown = true
        model.showToast(L10n.format("已开启 %@", AppLockController.methodName))
    }

    /// Opens the App Store app on the review form; Safari is the fallback when
    /// the store app cannot take the URL.
    private func rateApp() {
        openURL(AppLinks.writeReviewAppURL) { opened in
            guard !opened else { return }
            openURL(AppLinks.writeReviewURL) { fallbackOpened in
                guard !fallbackOpened else { return }
                openFailureMessage = L10n.t("无法打开 App Store，请稍后再试。")
            }
        }
    }

    private func sendFeedback() {
        guard let url = AppLinks.feedbackURL else {
            openFailureMessage = L10n.t("无法生成反馈邮件。")
            return
        }
        openURL(url) { opened in
            guard !opened else { return }
            openFailureMessage = L10n.format("没有可用的邮件 App。请手动发送到 %@。", AppLinks.supportEmail)
        }
    }

    private func settingLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            Text(title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
        }
    }

    private var lastBackupText: String {
        guard lastBackupAt > 0 else { return L10n.t("从未备份") }
        return L10n.date(Date(timeIntervalSince1970: lastBackupAt))
    }
}