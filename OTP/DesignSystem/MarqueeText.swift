import SwiftUI

/// A single-line label that scrolls horizontally only when it overflows.
struct MarqueeText: View {
    let text: String
    var font: Font = .headline
    var height: CGFloat = 21
    var speed: CGFloat = 26

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var startDate = Date()

    private var overflow: CGFloat {
        max(0, textWidth - containerWidth)
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if overflow < 1 {
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .background(GeometryReader { proxy in
                            Color.clear.preference(key: MarqueeWidthKey.self, value: proxy.size.width)
                        })
                } else {
                    TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                        Text(text)
                            .font(font)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .offset(x: offset(at: max(0, context.date.timeIntervalSince(startDate))))
                    }
                }
            }
            .onPreferenceChange(MarqueeWidthKey.self) { width in
                if abs(width - textWidth) > 0.5 {
                    textWidth = width
                }
            }
            .onAppear {
                containerWidth = geometry.size.width
                startDate = Date()
            }
            .onChange(of: geometry.size.width) { _, width in
                containerWidth = width
            }
        }
        .frame(height: height)
        .clipped()
    }

    private func offset(at elapsed: TimeInterval) -> CGFloat {
        let distance = overflow
        guard distance >= 1 else { return 0 }
        let duration = max(3.5, Double(distance) / Double(speed))
        let pause = 1.6
        let cycle = duration + pause * 2
        let phase = elapsed.truncatingRemainder(dividingBy: cycle)

        if phase < pause {
            return 0
        }
        if phase < pause + duration {
            return -distance * CGFloat((phase - pause) / duration)
        }
        return -distance
    }
}

private struct MarqueeWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}