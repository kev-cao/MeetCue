import AppKit
import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

/// Drives `OverlayController` with real panels.
@MainActor
final class OverlayControllerTests {
    let source = FakeCalendarSource()
    let settings = AppSettings(storage: InMemorySettingsStorage())
    /// Panels can outlive the test and keep asking for the time, so the clock mustn't refer to the test.
    let clock = MutableClock(AppFixtures.at(14, 28))
    lazy var store = MeetingStore(source: source, now: { [clock] in clock.now }, calendar: AppFixtures.calendar)
    var controller: OverlayController?

    init() {
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30))]
    }

    func makeModel() -> OverlayModel {
        store.refresh()
        let model = OverlayModel(
            store: store,
            quiet: QuietMode(storage: InMemoryQuietStorage()),
            notes: NoteStore(repository: FlakyNoteRepository(), saveDelay: .seconds(60)),
            dismissed: DismissedAlerts(storage: InMemoryDismissedAlertStorage()),
            settings: settings,
            clock: { [clock] in clock.now },
            calendar: AppFixtures.calendar,
            locale: Locale(identifier: "en_US"),
            openURL: { _ in }
        )
        model.refresh()
        return model
    }

    var visibleAlerts: [NSWindow] { controller?.alertPanels.filter(\.isVisible) ?? [] }
    var pillPanel: NSWindow? { controller?.pillPanel }

    /// The controller syncs on the main actor after each change.
    func settle(until done: () -> Bool) async {
        for _ in 0..<50 where !done() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func cornerPanelsGoToTheDisplayUnderThePointer() {
        let laptop = NSRect(x: 0, y: 0, width: 1728, height: 1117)
        let monitor = NSRect(x: -2560, y: -200, width: 2560, height: 1440)
        let screens = [("laptop", laptop), ("monitor", monitor)]
        func screen(_ mouse: NSPoint) -> String? { OverlayController.screen(under: mouse, in: screens, frame: \.1)?.0 }
        #expect(screen(NSPoint(x: -1200, y: 600)) == "monitor")
        #expect(screen(NSPoint(x: 900, y: 500)) == "laptop")
        #expect(screen(NSPoint(x: 900, y: 1117)) == "laptop")
        #expect(screen(NSPoint(x: 5000, y: 5000)) == "laptop")
        #expect(OverlayController.screen(under: .zero, in: [(String, NSRect)](), frame: \.1) == nil)
    }

    @Test(arguments: [AlertDisplays.all, .main])
    func movingTheAlertToTheCornerShowsThePill(displays: AlertDisplays) async throws {
        settings.alertDisplays = displays
        let model = makeModel()
        controller = OverlayController(model: model)
        #expect(!visibleAlerts.isEmpty)
        model.moveAlertToCorner()
        await settle { visibleAlerts.isEmpty && pillPanel?.isVisible == true }
        #expect(visibleAlerts.isEmpty)
        let pill = try #require(pillPanel)
        #expect(pill.isVisible)
        let screen = try #require(NSScreen.screens.first)
        #expect(screen.visibleFrame.intersects(pill.frame))
        #expect(pill.frame.size == PillStackContent.size(rows: 1))
        model.dismissPill(model.pillMeetings[0].id)
        await settle { pillPanel?.isVisible != true }
        #expect(pillPanel?.isVisible != true)
    }
}
