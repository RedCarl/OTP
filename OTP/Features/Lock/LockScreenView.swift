import SwiftUI

struct LockScreenView: View {
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
                Text("验证码已被隐藏，解锁后即可复制。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    onUnlock()
                } label: {
                    Label("使用 Face ID 解锁", systemImage: "faceid")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
            }
            .padding(32)
        }
    }
}
