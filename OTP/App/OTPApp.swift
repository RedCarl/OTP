import SwiftUI

@main
struct OTPApp: App {
    @State private var model = TokenListModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
