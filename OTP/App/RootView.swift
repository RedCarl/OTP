import SwiftUI

enum AppTab: Hashable {
    case tokens
    case add
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

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hideInAppSwitcher") private var hideInAppSwitcher = true
    @AppStorage("firstLaunchAt") private var firstLaunchAt: Double = 0
    @AppStorage("lockPromptShown") private var lockPromptShown = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                TokenListView(model: model) {
                    selectedTab = .add
                }
                .tabItem {
                    Label("令牌", systemImage: "key.fill")
                }
                .tag(AppTab.tokens)

                AddTokenTabView(model: model) {
                    selectedTab = .tokens
                }
                .tabItem {
                    Label("添加", systemImage: "plus.circle.fill")
                }
                .tag(AppTab.add)

                SettingsView(model: model)
                    .tabItem {
                        Label("设置", systemImage: "gearshape.fill")
                    }
                    .tag(AppTab.settings)
            }

            if lock.isLocked {
                LockScreenView {
                    Task { await lock.unlock() }
                }
                .transition(.opacity)
            }

            if scenePhase != .active && hideInAppSwitcher {
                PrivacyShield()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: lock.isLocked)
        .task {
            if firstLaunchAt == 0 {
                firstLaunchAt = Date().timeIntervalSince1970
            }
            await model.start()
            #if DEBUG
            if AppConfiguration.shouldSeedDemoTokens {
                await model.seedDemoTokensIfEmpty()
            }
            #endif
            lock.prepareForLaunch(allowLock: hasCompletedOnboarding)
            if !hasCompletedOnboarding && !AppConfiguration.isAutomatedRun {
                showOnboarding = true
            }
            if lock.isLocked {
                await lock.unlock()
            }
            evaluateLockSuggestion()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { wantsImport in
                hasCompletedOnboarding = true
                showOnboarding = false
                if wantsImport {
                    showImportAfterOnboarding = true
                }
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showImportAfterOnboarding) {
            ImportFlowView(model: model, mode: .pick, onImported: { selectedTab = .tokens })
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
                if lock.isLocked {
                    Task { await lock.unlock() }
                }
            case .background:
                model.stopTicker()
            default:
                break
            }
        }
        .alert("给令牌加一道锁？", isPresented: $showLockSuggestion) {
            Button("开启") {
                enableUnlockProtection()
            }
            Button("以后再说", role: .cancel) {
                lockPromptShown = true
            }
        } message: {
            Text("使用 \(AppLockController.methodName) 解锁 OTP，别人拿到手机也看不到验证码。")
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

    private func enableUnlockProtection() {
        lockPromptShown = true
        UserDefaults.standard.set(true, forKey: "appLockEnabled")
        model.showToast("已开启解锁保护")
    }
}

private struct PrivacyShield: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
        }
    }
}