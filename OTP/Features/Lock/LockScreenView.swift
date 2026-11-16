import SwiftUI

struct LockScreenView: View {
    var isAuthenticating: Bool = false
    var onUnlock: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

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

                if isAuthenticating {
                    ProgressView()
                        .controlSize(.large)
                        .padding(.top, 4)
                } else {
                    Button {
                        onUnlock()
                    } label: {
                        Label(
                            "使用 \(AppLockController.methodName) 解锁",
                            systemImage: AppLockController.methodIcon
                        )
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 4)
                }
            }
            .padding(32)
        }
    }
}
