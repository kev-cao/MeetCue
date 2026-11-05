import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
final class SettingsModelTests {
    let source = FakeCalendarSource()
    let settings = AppSettings(storage: InMemorySettingsStorage())
    let quiet = QuietMode(storage: InMemoryQuietStorage())
    let notes = NoteStore(repository: FlakyNoteRepository(), saveDelay: .seconds(60))
    let loginItem = FakeLoginItem()
    let notesFile = URL(fileURLWithPath: NSHomeDirectory()).appending(components: "Library", "Application Support", "MeetCue", "Notes.store")
    let folder = FileManager.default.temporaryDirectory.appending(path: "MeetCueSettings-\(UUID().uuidString)")
    var now = AppFixtures.at(13, 0)
    var revealed: [URL] = []
    lazy var store = MeetingStore(source: source, now: { [unowned self] in now }, calendar: AppFixtures.calendar)

    init() {
        source.calendarList = [
            CalendarInfo(id: "home", title: "Personal", account: "iCloud", color: .gray),
            CalendarInfo(id: "work", title: "Work", account: "Google", color: .gray),
            CalendarInfo(id: "team", title: "DR Team", account: "Google", color: .gray),
        ]
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30))]
    }

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }

    func makeModel() -> SettingsModel {
        store.refresh()
        return SettingsModel(
            settings: settings,
            quiet: quiet,
            store: store,
            visibility: CalendarVisibility(store: store, settings: settings, storage: InMemoryHiddenCalendarStorage()),
            notes: notes,
            launchAtLogin: LaunchAtLogin(service: loginItem),
            notesFile: notesFile,
            clock: { [unowned self] in now },
            calendar: AppFixtures.calendar,
            reveal: { [unowned self] in revealed.append($0) }
        )
    }

    @Test func quietModeChoiceIsTheSharedQuietMode() {
        let model = makeModel()
        #expect(model.quietPreset == nil)
        model.quietPreset = .oneHour
        #expect(quiet.until == AppFixtures.at(14, 0))
        #expect(model.quietPreset == .oneHour)
        now = AppFixtures.at(14, 0)
        #expect(model.quietPreset == nil)
        model.quietPreset = .untilTurnedOff
        model.quietPreset = nil
        #expect(quiet.until == nil)
    }

    @Test func calendarsAreGroupedByAccountWithTheirSwitches() {
        let model = makeModel()
        #expect(model.calendarGroups.map(\.account) == ["Google", "iCloud"])
        #expect(model.calendarGroups[0].calendars.map(\.title) == ["DR Team", "Work"])
        model.setVisible(false, calendarID: "work")
        #expect(!model.isVisible("work"))
        #expect(store.filter.hiddenCalendarIDs == ["work"])
        model.setAlertsOn(false, calendarID: "team")
        #expect(!model.alertsOn("team"))
        #expect(settings.alertOffCalendarIDs == ["team"])
    }

    @Test func showsWhereNotesAreKept() {
        let model = makeModel()
        #expect(model.notesFolderPath == "~/Library/Application Support/MeetCue")
        model.showNotesInFinder()
        #expect(revealed == [notesFile])
    }

    @Test func exportSaysHowItWent() throws {
        let model = makeModel()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        model.exportNotes(to: folder)
        #expect(model.exportStatus == "There are no notes to export.")
        notes.setMarkdown("- [ ] Budget", for: store.meetings[0])
        model.exportNotes(to: folder)
        #expect(model.exportStatus == "Exported 1 note to \(folder.lastPathComponent).")
        model.exportNotes(to: folder.appending(path: "missing"))
        #expect(model.exportStatus?.hasPrefix("Exported 0 of 1 notes. Couldn't write 2026-11-04 Team Sync.md: ") == true)
    }

    @Test func exportNamesTheFirstFailureAndCountsTheRest() throws {
        let other = AppFixtures.event("Standup", start: AppFixtures.at(16, 0), series: "b")
        source.snapshots += [other]
        let model = makeModel()
        notes.setMarkdown("- [ ] Budget", for: store.meetings[0])
        notes.setMarkdown("Notes", for: store.meetings[1])
        model.exportNotes(to: folder.appending(path: "missing"))
        #expect(model.exportStatus?.hasPrefix("Exported 0 of 2 notes. Couldn't write 2026-11-04 Team Sync.md and 1 more: ") == true)
    }

    @Test func exportReportsPartialSuccess() throws {
        let model = makeModel()
        try FileManager.default.createDirectory(at: folder.appending(path: "2026-11-04 Team Sync.md"), withIntermediateDirectories: true)
        notes.setMarkdown("- [ ] Budget", for: store.meetings[0])
        notes.setMarkdown("Other", for: MeetingMapper.meeting(from: AppFixtures.event("Gone", start: AppFixtures.at(10, 0), series: "gone")))
        model.exportNotes(to: folder)
        #expect(model.exportStatus?.hasPrefix("Exported 1 of 2 notes. Couldn't write ") == true)
    }

    @Test func refreshReadsLaunchAtLoginAgain() {
        let model = makeModel()
        #expect(!model.launchAtLogin.isOn)
        loginItem.status = .enabled
        model.refresh()
        #expect(model.launchAtLogin.isOn)
    }
}
