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

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hideInAppSwitcher") private var hideInAppSwitcher = true

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
        .onChange(of: scenePhase) { _, phase in
            lock.handleScenePhase(phase)
            switch phase {
            case .active:
                model.startTicker()
                Task { await model.refresh() }
                if lock.isLocked {
                    Task { await lock.unlock() }
                }
            case .background:
                model.stopTicker()
            default:
                break
            }
        }
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