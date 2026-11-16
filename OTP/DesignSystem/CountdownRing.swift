import SwiftUI

struct CountdownRing: View {
    let progress: Double
    let urgent: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(urgent ? Color.orange : Color.accentColor,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 22, height: 22)
        .animation(.linear(duration: 0.5), value: progress)
    }
}

#Preview {
    HStack {
        CountdownRing(progress: 1, urgent: false)
        CountdownRing(progress: 0.4, urgent: false)
        CountdownRing(progress: 0.1, urgent: true)
    }
    .padding()
}
