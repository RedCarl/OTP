import SwiftUI

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

                SettingsView(model: model)
                    .tabItem {
                        Label("设置", systemImage: "gearshape.fill")
                    }
                    .tag(AppTab.settings)
            }

            if let toast = model.toastMessage {
                VStack {
                    Text(toast)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                        .padding(.top, 6)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(3)
            }

            if lock.isLocked {
                LockScreenView(isAuthenticating: lock.isAuthenticating) {
                    Task { await lock.unlock() }
                }
                .transition(.opacity)
                .zIndex(1)
            }

            if scenePhase != .active && hideInAppSwitcher {
                PrivacyShield()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: scenePhase != .active)
        .animation(.snappy(duration: 0.25), value: model.toastMessage)
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
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showImportAfterOnboarding) {
            ImportFlowView(model: model, mode: .pick, onImported: { selectedTab = .tokens })
        }
        .sheet(isPresented: $showAddSheet) {
            AddTokenSheetView(model: model) {
                showAddSheet = false
                selectedTab = .tokens
            }
        }
        .onChange(of: lock.isLocked) { _, locked in
            guard locked else { return }
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
            default:
                break
            }
        }
        .alert("给令牌加一道锁？", isPresented: $showLockSuggestion) {
            Button("开启") {
                lockPromptShown = true
                Task {
                    if await AppLockController.authenticate(reason: "开启 Face ID 解锁") {
                        UserDefaults.standard.set(true, forKey: "appLockEnabled")
                        model.showToast("已开启 Face ID")
                    }
                }
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