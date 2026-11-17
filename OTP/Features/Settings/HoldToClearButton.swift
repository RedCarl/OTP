import SwiftUI
import UIKit

/// Destructive action that requires holding the button until the fill completes.
/// Releasing early cancels; releasing after the bar is full clears.
struct HoldToClearButton: View {
    var isEnabled: Bool
    var isClearing: Bool
    var onClear: () -> Void

    private let holdDuration: TimeInterval = 1.5

    @State private var progress: CGFloat = 0
    @State private var isPressing = false
    @State private var isFull = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red)

            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.22))
                    .frame(width: geometry.size.width * progress)
            }

            HStack(spacing: 10) {
                if isClearing {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.small)
                } else {
                    Image(systemName: isFull ? "checkmark.circle.fill" : "trash")
                }
                Text(title)
            }
            .font(.body.weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
        }
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(isEnabled || isClearing ? 1 : 0.45)
        .onLongPressGesture(
            minimumDuration: holdDuration,
            maximumDistance: 40,
            pressing: { pressing in
                if pressing {
                    if isEnabled && !isClearing {
                        beginHold()
                    }
                } else {
                    endHold()
                }
            },
            perform: {}
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("清空所有令牌")
        .accessibilityHint("按住 1.5 秒，进度走满后松手清空")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("settings.clear")
        .accessibilityAction(named: "清空所有令牌") {
            guard isEnabled, !isClearing else { return }
            onClear()
        }
        .onDisappear {
            holdTask?.cancel()
            holdTask = nil
        }
        .onChange(of: isClearing) { _, clearing in
            guard !clearing else { return }
            progress = 0
            isPressing = false
            isFull = false
        }
    }

    private var title: String {
        if isClearing { return "正在清空…" }
        if isFull { return "松手清空" }
        if isPressing { return "继续按住" }
        return "按住清空"
    }

    private func beginHold() {
        isPressing = true
        isFull = false
        progress = 0
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.linear(duration: holdDuration)) {
            progress = 1
        }

        holdTask?.cancel()
        holdTask = Task {
            try? await Task.sleep(for: .seconds(holdDuration))
            guard !Task.isCancelled, isPressing else { return }
            isFull = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func endHold() {
        guard isPressing else { return }
        isPressing = false
        holdTask?.cancel()
        holdTask = nil

        if isFull {
            progress = 1
            onClear()
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                progress = 0
            }
        }
        isFull = false
    }
}