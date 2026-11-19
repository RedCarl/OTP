import SwiftUI

/// A single-line label that scrolls horizontally only when it overflows.
///
/// The scroll is driven by `phaseAnimator`: each phase change starts a Core
/// Animation on `offset`, so SwiftUI evaluates the body a handful of times per
/// cycle instead of 30 times a second (which is what a `TimelineView` per list
/// row cost before).
struct MarqueeText: View {
    let text: String
    var font: Font = .headline
    var height: CGFloat = 21
    var speed: CGFloat = 26
    var pause: TimeInterval = 1.6

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    private var overflow: CGFloat {
        max(0, textWidth - containerWidth)
    }

    private var scrollDuration: TimeInterval {
        max(3.5, Double(overflow) / Double(speed))
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if overflow < 1 {
                    measuredLabel
                } else {
                    measuredLabel
                        .phaseAnimator(MarqueePhase.allCases) { content, phase in
                            content.offset(x: -overflow * phase.travel)
                        } animation: { phase in
                            .linear(duration: phase.isScrolling ? scrollDuration : pause)
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
            }
            .onChange(of: geometry.size.width) { _, width in
                containerWidth = width
            }
        }
        .frame(height: height)
        .clipped()
    }

    private var label: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var measuredLabel: some View {
        label.background(
            GeometryReader { proxy in
                Color.clear.preference(key: MarqueeWidthKey.self, value: proxy.size.width)
            }
        )
    }
}

/// The marquee cycle: pause, scroll left, hold, scroll back.
private enum MarqueePhase: CaseIterable {
    case rest
    case forward
    case hold
    case back

    var travel: CGFloat {
        switch self {
        case .rest, .back: 0
        case .forward, .hold: 1
        }
    }

    var isScrolling: Bool {
        self == .forward || self == .back
    }
}

private struct MarqueeWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
