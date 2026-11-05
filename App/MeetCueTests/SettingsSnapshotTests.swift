import Foundation
import MeetCueCore
import SwiftUI
import Testing
@testable import MeetCue

/// Renders each Settings pane. Set `TEST_RUNNER_MEETCUE_SNAPSHOT_DIR` when running
/// `xcodebuild test` to also write them as PNGs.
@MainActor
struct SettingsSnapshotTests {
    let source = FakeCalendarSource()
    let settings = AppSettings(storage: InMemorySettingsStorage())
    let loginItem = FakeLoginItem()

    func makeModel(_ section: SettingsModel.Section) -> SettingsModel {
        source.calendarList = SampleWeek.calendars
        let store = MeetingStore(source: source, now: { SampleWeek.now }, calendar: AppFixtures.calendar)
        store.refresh()
        let model = SettingsModel(
            settings: settings,
            quiet: QuietMode(storage: InMemoryQuietStorage()),
            store: store,
            visibility: CalendarVisibility(store: store, settings: settings, storage: InMemoryHiddenCalendarStorage()),
            notes: NoteStore(repository: FlakyNoteRepository()),
            launchAtLogin: LaunchAtLogin(service: loginItem),
            notesFile: URL(fileURLWithPath: NSHomeDirectory()).appending(components: "Library", "Application Support", "MeetCue", "Notes.store"),
            clock: { SampleWeek.now },
            calendar: AppFixtures.calendar,
            reveal: { _ in }
        )
        model.section = section
        return model
    }

    func render(_ model: SettingsModel, dark: Bool = false, named name: String) throws {
        try renderHosted(SettingsWindowView(model: model), size: SettingsWindowView.size, dark: dark, named: name)
    }

    @Test func rendersGeneral() throws {
        loginItem.status = .enabled
        try render(makeModel(.general), named: "settings-general")
        loginItem.status = .requiresApproval
        try render(makeModel(.general), named: "settings-general-approval")
    }

    @Test func rendersAlerts() throws {
        let model = makeModel(.alerts)
        try render(model, named: "settings-alerts")
        try render(model, dark: true, named: "settings-alerts-dark")
    }

    @Test func rendersCalendars() throws {
        settings.alertOffCalendarIDs = ["focus"]
        try render(makeModel(.calendars), named: "settings-calendars")
    }

    @Test func rendersNotes() throws {
        try render(makeModel(.notes), named: "settings-notes")
    }

    @Test func rendersAppearance() throws {
        settings.glassOpacity = 0.35
        try render(makeModel(.appearance), named: "settings-appearance")
    }
}
