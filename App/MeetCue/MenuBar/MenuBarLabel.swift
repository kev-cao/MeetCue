import AppKit
import MeetCueCore
import SwiftUI

struct MenuBarLabel: View {
    static let font = NSFont.menuBarFont(ofSize: 0)
    let model: MenuBarModel

    var body: some View {
        let display = model.display
        HStack(spacing: 4) {
            icon(for: display)
            if let time = display.time {
                Text(time).monospacedDigit()
            }
            if let title = display.title {
                Text("·")
                MarqueeText(text: title, visibleCharacters: model.settings.titleLength, scrolls: display.scrollsTitle, font: Self.font)
            }
        }
        .font(Font(Self.font as CTFont))
        .padding(.horizontal, 6)
        .fixedSize()
    }

    @ViewBuilder
    private func icon(for display: MenuBarDisplay) -> some View {
        if model.needsAccess {
            Image(systemName: "calendar.badge.exclamationmark")
        } else {
            switch display.icon {
            case .calendar: Image(systemName: "calendar")
            case .live: Circle().fill(.red).frame(width: 7, height: 7)
            case .quiet: Image(systemName: "moon")
            case .doneForToday: Image(systemName: "calendar.badge.checkmark")
            }
        }
    }
}
