import SwiftUI

struct LockScreenView: View {
    var isAuthenticating: Bool = false
    var onUnlock: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if isAuthenticating {
                // Minimal privacy cover while Face ID is up. Keeps codes hidden
                // without showing a full lock page for less than a second.
                Image(systemName: "lock.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .transition(.opacity)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(.tint)
                    Text("OTP 已锁定")
                        .font(.title3.weight(.semibold))
                    Text("解锁后查看验证码。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        onUnlock()
                    } label: {
                        Label(
                            L10n.format("使用 %@ 解锁", AppLockController.methodName),
                            systemImage: AppLockController.methodIcon
                        )
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 4)
                }
                .padding(32)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isAuthenticating)
    }
}
