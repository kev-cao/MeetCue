import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
final class NoteExporterTests {
    let source = FakeCalendarSource()
    let notes = NoteStore(repository: FlakyNoteRepository(), saveDelay: .seconds(60))
    let folder = FileManager.default.temporaryDirectory.appending(path: "MeetCueExport-\(UUID().uuidString)")

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        source.calendarList = [CalendarInfo(id: "work", title: "Work", account: "Google", color: .gray)]
    }

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }

    func export() throws -> [String: String] {
        let store = MeetingStore(source: source, calendar: AppFixtures.calendar)
        store.refresh()
        let exporter = NoteExporter(notes: notes, store: store, calendar: AppFixtures.calendar, locale: Locale(identifier: "en_US"))
        let count = try exporter.export(to: folder)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(names.count == count)
        return try Dictionary(uniqueKeysWithValues: names.map { ($0, try String(contentsOf: folder.appending(path: $0), encoding: .utf8)) })
    }

    @Test func writesEachNoteWithTextUnderItsMeetingsTitle() throws {
        let sync = AppFixtures.event(start: AppFixtures.at(14, 30))
        let lunch = AppFixtures.event("Lunch", start: AppFixtures.at(12, 0), series: "lunch")
        source.snapshots = [sync, lunch]
        notes.setMarkdown("- [ ] Budget", for: MeetingMapper.meeting(from: sync))
        notes.setMarkdown("  \n", for: MeetingMapper.meeting(from: lunch))
        let files = try export()
        #expect(files == ["2026-11-04 Team Sync.md": "# Team Sync\n\nWednesday, November 4, 2026 · 2:30 – 3:00 PM · Work\n\n- [ ] Budget\n"])
    }

    @Test func namesNotesWithoutAMeetingByDateAndNumbersRepeats() throws {
        let first = AppFixtures.event(start: AppFixtures.at(9, 0), series: "a")
        let second = AppFixtures.event(start: AppFixtures.at(16, 0), series: "b")
        source.snapshots = [first, second]
        notes.setMarkdown("First", for: MeetingMapper.meeting(from: first))
        notes.setMarkdown("Second", for: MeetingMapper.meeting(from: second))
        notes.setMarkdown("Gone", for: MeetingMapper.meeting(from: AppFixtures.event("Deleted", start: AppFixtures.at(10, 0), series: "gone")))
        let files = try export()
        #expect(files["2026-11-04 Team Sync.md"]?.hasSuffix("\n\nFirst\n") == true)
        #expect(files["2026-11-04 Team Sync 2.md"]?.hasSuffix("\n\nSecond\n") == true)
        #expect(files["2026-11-04.md"] == "Gone\n")
    }

    @Test func findsMeetingsMoreThanFourYearsApart() throws {
        let old = AppFixtures.calendar.date(from: DateComponents(year: 2020, month: 3, day: 2, hour: 9))!
        let oldEvent = AppFixtures.event("Kickoff", start: old, series: "old")
        let sync = AppFixtures.event(start: AppFixtures.at(14, 30))
        source.snapshots = [oldEvent, sync]
        notes.setMarkdown("Old", for: MeetingMapper.meeting(from: oldEvent))
        notes.setMarkdown("New", for: MeetingMapper.meeting(from: sync))
        let files = try export()
        #expect(Set(files.keys) == ["2020-03-02 Kickoff.md", "2026-11-04 Team Sync.md"])
    }
}
