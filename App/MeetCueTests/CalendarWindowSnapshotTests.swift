import Foundation
import MeetCueCore
import SwiftUI
import Testing
@testable import MeetCue

/// Renders the calendar window's views. Set `TEST_RUNNER_MEETCUE_SNAPSHOT_DIR` when running
/// `xcodebuild test` to also write them as PNGs.
@MainActor
struct CalendarWindowSnapshotTests {
    let source = FakeCalendarSource()
    let notes = NoteStore(repository: FlakyNoteRepository())
    static let windowSize = CGSize(width: 1360, height: 820)

    func makeModel() -> CalendarWindowModel {
        source.calendarList = SampleWeek.calendars
        source.snapshots = SampleWeek.events
        let store = MeetingStore(source: source, now: { SampleWeek.now }, calendar: AppFixtures.calendar)
        store.refresh()
        let model = CalendarWindowModel(
            store: store,
            notes: notes,
            visibility: CalendarVisibility(store: store, storage: InMemoryHiddenCalendarStorage()),
            clock: { SampleWeek.now },
            calendar: AppFixtures.calendar,
            locale: Locale(identifier: "en_US")
        )
        model.reload()
        let sync = model.meetings.first { $0.title == "Team Sync" }!
        notes.setMarkdown(SampleWeek.note, for: sync)
        notes.setMarkdown("- [ ] Ask about the offsite", for: model.meetings.first { $0.title == "1:1" }!)
        model.select(sync)
        return model
    }

    @Test func rendersWeekWithInspector() throws {
        let model = makeModel()
        for dark in [false, true] {
            try renderHosted(CalendarWindowView(model: model), size: Self.windowSize, dark: dark, named: dark ? "calendar-week-dark" : "calendar-week")
        }
    }

    @Test func rendersDayAndMonth() throws {
        let model = makeModel()
        model.mode = .day
        try renderHosted(CalendarWindowView(model: model), size: Self.windowSize, named: "calendar-day")
        model.mode = .month
        try renderHosted(CalendarWindowView(model: model), size: Self.windowSize, named: "calendar-month")
    }

    @Test func rendersMarkdownMode() throws {
        let model = makeModel()
        model.editorMode = .markdown
        try renderHosted(CalendarWindowView(model: model), size: Self.windowSize, named: "calendar-markdown")
    }
}

/// A week of meetings for renders: the mockup's week of November 1, 2026.
enum SampleWeek {
    static let now = AppFixtures.at(13, 4)

    static let calendars = [
        CalendarInfo(id: "work", title: "Work", account: "Google", color: CalendarColor(red: 0.04, green: 0.42, blue: 0.94)),
        CalendarInfo(id: "team", title: "DR Team", account: "Google", color: CalendarColor(red: 0.63, green: 0.31, blue: 0.82)),
        CalendarInfo(id: "home", title: "Personal", account: "iCloud", color: CalendarColor(red: 0.16, green: 0.67, blue: 0.31)),
        CalendarInfo(id: "focus", title: "Focus time", account: "iCloud", color: CalendarColor(red: 0.47, green: 0.47, blue: 0.5)),
    ]

    static let note = """
    ## Topics
    - [ ] Move staging backups to every 4 hours? <!-- carried:2026-10-28 -->
    - [ ] Share restore throughput from last week's run
    - [x] Who owns the on-call runbook update

    Bring numbers from the [restore benchmark doc](https://example.com/bench). Compare against the **v24.3** baseline.
    """

    static var events: [EventSnapshot] {
        func event(_ title: String, day: Int, _ hour: Int, _ minute: Int = 0, minutes: Int = 60, calendar: String = "work", recurring: Bool = false, location: String? = nil, attendees: Int = 0) -> EventSnapshot {
            let start = AppFixtures.at(hour, minute, day: day)
            return EventSnapshot(
                seriesKey: "\(title)-\(recurring ? "series" : "\(day)")",
                isRecurring: recurring,
                title: title,
                start: start,
                end: start.addingTimeInterval(TimeInterval(minutes * 60)),
                location: location,
                calendarID: calendar,
                myStatus: .accepted,
                attendeeCount: attendees
            )
        }
        var events = (2...6).map { event("Standup", day: $0, 10, minutes: 25, calendar: "team", recurring: true) }
        events += [
            event("Restore planning", day: 2, 13),
            event("Interview debrief", day: 2, 15, 30, minutes: 30),
            event("Lunch", day: 3, 11, 30, calendar: "home"),
            event("Design review", day: 3, 14),
            event("PITR design review", day: 4, 11, location: "https://acme.zoom.us/j/1"),
            event("Team Sync", day: 4, 14, 30, minutes: 30, recurring: true, location: "Room 4B; https://meet.google.com/abc-defg-hij", attendees: 6),
            event("1:1", day: 4, 16, minutes: 30),
            event("Eng all-hands", day: 5, 13, 30),
            event("Lunch & learn", day: 6, 12, calendar: "home"),
            event("Focus time", day: 6, 15, calendar: "focus"),
            event("Hike", day: 7, 9, minutes: 180, calendar: "home"),
        ]
        events.append(EventSnapshot(seriesKey: "election", title: "Election Day", start: AppFixtures.at(0, 0, day: 3), end: AppFixtures.at(0, 0, day: 4), isAllDay: true, calendarID: "home"))
        return events
    }
}
