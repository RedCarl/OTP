import SwiftUI

/// Secondary confirmation for the destructive action. The long-press progress
/// lives here, not on the settings list itself.
struct ClearTokensSheet: View {
    let model: TokenListModel

    @Environment(\.dismiss) private var dismiss
    @State private var isClearing = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.red)

            Text("清空所有令牌？")
                .font(.title3.weight(.semibold))

            Text("所有设备上的令牌都会被删除，无法撤销。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HoldToClearButton(isEnabled: !isClearing, isClearing: isClearing) {
                Task {
                    isClearing = true
                    await model.deleteAll()
                    isClearing = false
                    dismiss()
                    model.showToast("已清空")
                }
            }
            .padding(.top, 4)

            Button("取消") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .disabled(isClearing)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemGroupedBackground))
    }
}
