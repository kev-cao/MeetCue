import AppKit
import SwiftUI

/// Shows `text` in a window `visibleCharacters` wide. When `scrolls` is on and the text is longer,
/// it scrolls through, pauses at the start, and repeats.
struct MarqueeText: View {
    let text: String
    let visibleCharacters: Int
    let scrolls: Bool
    let font: NSFont

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let pointsPerSecond: CGFloat = 30
    private static let pause: TimeInterval = 2
    private static let gap: CGFloat = 24

    var body: some View {
        if text.count <= visibleCharacters {
            Text(text)
        } else if scrolls && !reduceMotion {
            scrolling
        } else {
            Text(String(text.prefix(visibleCharacters)) + "…")
        }
    }

    private var scrolling: some View {
        let distance = width(of: text) + Self.gap
        let cycle = Self.pause + distance / Self.pointsPerSecond
        return TimelineView(.periodic(from: .now, by: 1.0 / 30)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
            let offset = phase < Self.pause ? 0 : -CGFloat(phase - Self.pause) * Self.pointsPerSecond
            HStack(spacing: Self.gap) {
                Text(text)
                Text(text)
            }
            .fixedSize()
            .offset(x: offset)
        }
        .frame(width: width(of: String(text.prefix(visibleCharacters))), alignment: .leading)
        .clipped()
    }

    private func width(of string: String) -> CGFloat {
        ceil((string as NSString).size(withAttributes: [.font: font]).width)
    }
}
