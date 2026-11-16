import SwiftUI

struct CountdownRing: View {
    let progress: Double
    let urgent: Bool
    var seconds: Int?
    var size: CGFloat = 32

    private var lineWidth: CGFloat {
        size >= 30 ? 3 : 2.4
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(urgent ? Color.orange : Color.accentColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let seconds {
                Text("\(seconds)")
                    .font(.system(size: size * 0.35, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(urgent ? Color.orange : Color.secondary)
            }
        }
        .frame(width: size, height: size)
        .animation(.linear(duration: 0.5), value: progress)
    }
}

#Preview {
    HStack(spacing: 16) {
        CountdownRing(progress: 1, urgent: false, seconds: 30)
        CountdownRing(progress: 0.4, urgent: false, seconds: 12)
        CountdownRing(progress: 0.1, urgent: true, seconds: 3)
    }
    .padding()
}
