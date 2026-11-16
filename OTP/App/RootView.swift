import SwiftUI

struct RootView: View {
    let model: TokenListModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TokenListView(model: model)
            .task {
                #if DEBUG
                if AppConfiguration.shouldSeedDemoTokens {
                    await model.seedDemoTokensIfEmpty()
                }
                #endif
                await model.start()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    model.startTicker()
                    Task { await model.refresh() }
                case .background:
                    model.stopTicker()
                default:
                    break
                }
            }
    }
}