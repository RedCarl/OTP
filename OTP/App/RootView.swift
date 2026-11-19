import SwiftUI
import UIKit

enum AppTab: Hashable {
    case tokens
    case settings
}

struct RootView: View {
    let model: TokenListModel

    @Environment(\.scenePhase) private var scenePhase
    @State private var lock = AppLockController()
    @State private var showOnboarding = false
    @State private var showImportAfterOnboarding = false
    @State private var selectedTab: AppTab = .tokens
    @State private var showLockSuggestion = false
    @State private var showAddSheet = false
    @State private var showClearConfirm = false

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hideInAppSwitcher") private var hideInAppSwitcher = true
    @AppStorage("firstLaunchAt") private var firstLaunchAt: Double = 0
    @AppStorage("lockPromptShown") private var lockPromptShown = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                TokenListView(model: model) {
                    showAddSheet = true
                }
                .tabItem {
                    Label("令牌", systemImage: "key.fill")
                }
                .tag(AppTab.tokens)

                SettingsView(model: model, onRequestClear: { showClearConfirm = true })
                    .tabItem {
                        Label("设置", systemImage: "gearshape.fill")
                    }
                    .tag(AppTab.settings)
            }

            ToastOverlay(model: model)
                .zIndex(3)

            if showClearConfirm {
                ClearTokensSheet(model: model) {
                    showClearConfirm = false
                }
                .transition(.opacity)
                .zIndex(4)
            }

            if lock.isLocked {
                LockScreenView(isAuthenticating: lock.isAuthenticating) {
                    Task { await lock.unlock() }
                }
                .transition(.opacity)
                .zIndex(5)
            }

            if scenePhase != .active && hideInAppSwitcher {
                PrivacyShield()
                    .transition(.opacity)
                    .zIndex(6)
            }
        }
        .environment(\.locale, L10n.locale)
        .animation(.easeInOut(duration: 0.25), value: scenePhase != .active)
        .animation(.easeInOut(duration: 0.2), value: showClearConfirm)
        .task {
            if firstLaunchAt == 0 {
                firstLaunchAt = Date().timeIntervalSince1970
            }
            await model.start()
            if !AppConfiguration.isAutomatedRun {
                let tokens = model.tokens
                // Fingerprinting + export are pure CPU/IO; keep them off the
                // main actor so launch is not held up.
                Task.detached(priority: .utility) {
                    await BackupAutomation.backupIfNeeded(tokens: tokens)
                }
            }
            #if DEBUG
            if AppConfiguration.shouldSeedDemoTokens {
                await model.seedDemoTokensIfEmpty()
            }
            #endif
            lock.prepareForLaunch(allowLock: hasCompletedOnboarding)
            if !hasCompletedOnboarding && !AppConfiguration.isAutomatedRun {
                showOnboarding = true
            }
            evaluateLockSuggestion()
            if lock.isLocked {
                Task {
                    try? await Task.sleep(for: .milliseconds(100))
                    await lock.unlock()
                }
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { wantsImport in
                hasCompletedOnboarding = true
                showOnboarding = false
                if wantsImport {
                    showImportAfterOnboarding = true
                }
            }
            .environment(\.locale, L10n.locale)
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showImportAfterOnboarding) {
            ImportFlowView(model: model, mode: .pick, onImported: { selectedTab = .tokens })
                .environment(\.locale, L10n.locale)
        }
        .sheet(isPresented: $showAddSheet) {
            AddTokenSheetView(model: model) {
                showAddSheet = false
                selectedTab = .tokens
            }
            .environment(\.locale, L10n.locale)
        }
        .onChange(of: lock.isLocked) { _, locked in
            guard locked else {
                // Nothing on screen needs a clock while the cover is up.
                model.startTicker()
                return
            }
            model.stopTicker()
            Task {
                // Let the lock screen finish appearing before the system prompt.
                try? await Task.sleep(for: .milliseconds(350))
                await lock.unlock()
            }
        }
        .onChange(of: model.tokens.count) { _, _ in
            evaluateLockSuggestion()
        }
        .onChange(of: scenePhase) { _, phase in
            lock.handleScenePhase(phase)
            switch phase {
            case .active:
                model.startTicker()
                Task {
                    await model.refresh()
                    evaluateLockSuggestion()
                }
            case .background:
                model.stopTicker()
                let tokens = model.tokens
                Task.detached(priority: .utility) {
                    await BackupAutomation.backupIfNeeded(tokens: tokens)
                }
            default:
                break
            }
        }
        .alert("给令牌加一道锁？", isPresented: $showLockSuggestion) {
            Button("开启") {
                lockPromptShown = true
                Task {
                    if await AppLockController.authenticate(reason: L10n.t("开启解锁保护")) {
                        UserDefaults.standard.set(true, forKey: "appLockEnabled")
                        model.showToast(L10n.format("已开启 %@", AppLockController.methodName))
                    }
                }
            }
            Button("以后再说", role: .cancel) {
                lockPromptShown = true
            }
        } message: {
            Text(L10n.format("使用 %@ 解锁 OTP，别人拿到手机也看不到验证码。", AppLockController.methodName))
        }
    }

    private func evaluateLockSuggestion() {
        guard !AppConfiguration.isAutomatedRun else { return }
        let stored = UserDefaults.standard.object(forKey: "appLockEnabled") as? Bool ?? false
        guard LockSuggestion.shouldAsk(
            tokenCount: model.tokens.count,
            firstLaunchAt: Date(timeIntervalSince1970: firstLaunchAt),
            now: Date(),
            hasAsked: lockPromptShown,
            isEnabled: stored
        ), AppLockController.canAuthenticate else {
            return
        }
        showLockSuggestion = true
    }
}

/// Owns the toast so a toast appearing only re-evaluates this overlay instead of
/// the whole root tree (the animation modifier also stays scoped to it).
private struct ToastOverlay: View {
    let model: TokenListModel

    var body: some View {
        VStack {
            if let toast = model.toastMessage {
                Text(toast)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.snappy(duration: 0.25), value: model.toastMessage)
        // Purely informational: never swallow taps meant for the list.
        .allowsHitTesting(false)
    }
}

private struct PrivacyShield: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
        }
    }
}