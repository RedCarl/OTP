import SwiftUI

/// Full-screen confirmation card. The card fits its content exactly, so the
/// buttons stay balanced without a tall empty sheet underneath.
struct ClearTokensSheet: View {
    let model: TokenListModel
    var onDismiss: () -> Void

    @State private var isClearing = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    guard !isClearing else { return }
                    onDismiss()
                }

            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.red)

                    Text("清空所有令牌？")
                        .font(.title3.weight(.semibold))

                    Text("所有设备上的令牌都会被删除，无法撤销。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    HoldToClearButton(isEnabled: !isClearing, isClearing: isClearing) {
                        Task {
                            isClearing = true
                            await model.deleteAll()
                            isClearing = false
                            onDismiss()
                            model.showToast(L10n.t("已清空"))
                        }
                    }

                    Button {
                        onDismiss()
                    } label: {
                        Text("取消")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemFill))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isClearing)
                }
                .padding(.top, 2)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
            .padding(.horizontal, 28)
            .accessibilityAddTraits(.isModal)
        }
    }
}
