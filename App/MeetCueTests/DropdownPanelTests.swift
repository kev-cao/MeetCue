import AppKit
import Foundation
import MeetCueCore
import SwiftUI
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

    /// The dropdown settles on one size when shown, with the Option-click item too.
    @Test(arguments: [false, true])
    func showingTheDropdownSettlesOnASize(option: Bool) throws {
        let source = FakeCalendarSource()
        source.snapshots = [AppFixtures.event("PITR design review", start: AppFixtures.at(14, 30), location: "Room 4B; https://acme.zoom.us/j/1")]
        let store = MeetingStore(source: source, now: { AppFixtures.at(14, 6) }, calendar: AppFixtures.calendar)
        store.refresh()
        let settings = AppSettings(storage: InMemorySettingsStorage())
        let notes = NoteStore(repository: FlakyNoteRepository())
        let quiet = QuietMode(storage: InMemoryQuietStorage())
        let model = MenuBarModel(store: store, quiet: quiet, notes: notes, settings: settings, clock: { AppFixtures.at(14, 6) }, calendar: AppFixtures.calendar, locale: Locale(identifier: "en_US"))
        model.showsSimulateItem = option
        let overlays = OverlayModel(store: store, quiet: quiet, notes: notes, dismissed: DismissedAlerts(storage: InMemoryDismissedAlertStorage()), settings: settings)
        let panel = DropdownPanel()
        let item = NSRect(x: 900, y: 876, width: 90, height: 24)
        let placer = ResizePlacer { [screen] window in
            window.setFrame(DropdownPanel.frame(size: window.frame.size, below: item, in: screen), display: true)
        }
        panel.delegate = placer
        panel.show(DropdownView(model: model, dismiss: {}, overlays: overlays, openMeetCue: {}, openSettings: {}, simulateMeeting: {}))
        func layOut() {
            panel.setFrame(DropdownPanel.frame(size: panel.frame.size, below: item, in: screen), display: true)
            panel.contentView?.layoutSubtreeIfNeeded()
            panel.displayIfNeeded()
        }
        layOut()
        let settled = panel.frame.size
        layOut()
        layOut()
        #expect(settled.width == 300 && settled.height > 300)
        #expect(settled.height == settled.height.rounded())
        #expect(panel.frame.size == settled, "\(settled) became \(panel.frame.size)")
        #expect(placer.resizes < 5, "resized \(placer.resizes) times")
        panel.orderOut(nil)
    }
}

/// Re-places the panel after each resize, as `StatusItemController` does, and counts the resizes.
/// It stops re-placing after a few dozen, so a resize loop fails the test instead of overflowing
/// the stack.
@MainActor
private final class ResizePlacer: NSObject, NSWindowDelegate {
    private(set) var resizes = 0
    private let place: (NSWindow) -> Void

    init(place: @escaping (NSWindow) -> Void) {
        self.place = place
    }

    func windowDidResize(_ notification: Notification) {
        resizes += 1
        guard resizes < 40, let window = notification.object as? NSWindow else { return }
        place(window)
    }
}
