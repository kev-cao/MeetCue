import AppKit
import Testing
@testable import MeetCue

@MainActor
struct DropdownPanelTests {
    let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
    let size = CGSize(width: 332, height: 400)

    /// The dropdown hangs below the menu bar at the item's left edge, like a system menu.
    @Test func hangsFromTheItemsLeftEdge() {
        let item = NSRect(x: 900, y: 876, width: 90, height: 24)
        #expect(DropdownPanel.frame(size: size, below: item, in: screen) == NSRect(x: 900, y: 472, width: 332, height: 400))
    }

    /// An item near the right side of the screen moves the dropdown left so it stays on screen.
    @Test func staysOnScreenNearTheRightEdge() {
        let item = NSRect(x: 1300, y: 876, width: 90, height: 24)
        let frame = DropdownPanel.frame(size: size, below: item, in: screen)
        #expect(frame.maxX == screen.maxX - DropdownPanel.inset)
        #expect(frame.maxY == item.minY - DropdownPanel.gap)
    }
}
