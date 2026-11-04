import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
struct CalendarWindowModelTests {
    let source = FakeCalendarSource()
    let hidden = InMemoryHiddenCalendarStorage()
    let notes = NoteStore(repository: FlakyNoteRepository(), saveDelay: .seconds(60))

    init() {
        source.calendarList = [
            CalendarInfo(id: "work", title: "Work", account: "Google", color: CalendarColor(red: 0.04, green: 0.42, blue: 0.94)),
            CalendarInfo(id: "team", title: "DR Team", account: "Google", color: .gray),
            CalendarInfo(id: "home", title: "Personal", account: "iCloud", color: .gray),
        ]
        source.snapshots = [
            AppFixtures.event(start: AppFixtures.at(14, 30)),
            AppFixtures.event("Next week", start: AppFixtures.at(10, 0, day: 11), series: "n"),
        ]
    }

    func makeModel(store: MeetingStore? = nil, opened: (@MainActor (URL) -> Void)? = nil) -> CalendarWindowModel {
        let store = store ?? MeetingStore(source: source, now: { AppFixtures.at(9, 0) }, calendar: AppFixtures.calendar)
        store.refresh()
        let model = CalendarWindowModel(
            store: store,
            notes: notes,
            visibility: CalendarVisibility(store: store, storage: hidden),
            clock: { AppFixtures.at(9, 0) },
            calendar: AppFixtures.calendar,
            locale: Locale(identifier: "en_US"),
            openURL: opened ?? { _ in }
        )
        model.reload()
        return model
    }

    @Test func weekViewShowsTheWeeksMeetings() {
        let model = makeModel()
        #expect(model.mode == .week)
        #expect(model.days.count == 7)
        #expect(model.meetings.map(\.title) == ["Team Sync"])
        #expect(model.title == ("November", "2026"))
        model.step(1)
        #expect(model.meetings.map(\.title) == ["Next week"])
        model.goToToday()
        #expect(model.meetings.map(\.title) == ["Team Sync"])
    }

    @Test func dayAndMonthViews() {
        let model = makeModel()
        model.mode = .month
        #expect(model.days.count == 35)
        #expect(model.meetings.map(\.title) == ["Team Sync", "Next week"])
        model.go(to: AppFixtures.at(0, 0, day: 11), mode: .day)
        #expect(model.meetings.map(\.title) == ["Next week"])
        #expect(model.title == ("Wednesday, November 11", "2026"))
    }

    @Test func showOpensTheMeetingsWeekAndSelectsIt() throws {
        let model = makeModel()
        let nextWeek = MeetingMapper.meeting(from: source.snapshots[1])
        model.show(nextWeek)
        #expect(model.days.first == AppFixtures.at(0, 0, day: 8))
        #expect(model.selected?.title == "Next week")
        model.step(-1)
        #expect(model.selected?.title == "Next week")
    }

    @Test func aDeletedSelectionClears() {
        let store = MeetingStore(source: source, now: { AppFixtures.at(9, 0) }, calendar: AppFixtures.calendar)
        let model = makeModel(store: store)
        model.select(model.meetings.first)
        source.snapshots = []
        store.refresh()
        model.reload()
        #expect(model.selected == nil)
    }

    @Test func hiddenCalendarsLeaveTheWindowAndStayHidden() {
        let model = makeModel()
        #expect(model.isVisible("work"))
        model.setVisible(false, calendarID: "work")
        #expect(!model.isVisible("work"))
        #expect(model.meetings.isEmpty)
        #expect(model.store.meetings.isEmpty)
        #expect(hidden.hiddenCalendarIDs == ["work"])

        let relaunched = makeModel()
        #expect(relaunched.store.filter.hiddenCalendarIDs == ["work"])
        relaunched.setVisible(true, calendarID: "work")
        #expect(relaunched.meetings.map(\.title) == ["Team Sync"])
        #expect(hidden.hiddenCalendarIDs.isEmpty)
    }

    @Test func calendarsAreGroupedByAccount() {
        let model = makeModel()
        #expect(model.calendarGroups.map(\.account) == ["Google", "iCloud"])
        #expect(model.calendarGroups[0].calendars.map(\.title) == ["DR Team", "Work"])
        #expect(model.color(for: model.meetings[0]).blue == 0.94)
    }

    @Test func reloadsWhenTheStoreRefreshes() async {
        let store = MeetingStore(source: source, now: { AppFixtures.at(9, 0) }, calendar: AppFixtures.calendar)
        let model = makeModel(store: store)
        model.startTracking()
        source.snapshots.append(AppFixtures.event("Added", start: AppFixtures.at(16, 0, day: 6), series: "a"))
        store.refresh()
        #expect(await eventually { model.meetings.map(\.title) == ["Team Sync", "Added"] })
    }

    @Test func gridSplitsTimedAndAllDayMeetings() {
        source.snapshots.append(EventSnapshot(seriesKey: "h", title: "Holiday", start: AppFixtures.at(0, 0), end: AppFixtures.at(0, 0, day: 5), isAllDay: true, calendarID: "work"))
        source.snapshots.append(AppFixtures.event("Overlap", start: AppFixtures.at(14, 45), series: "o"))
        let model = makeModel()
        let today = AppFixtures.at(0, 0)
        #expect(model.allDayMeetings(on: today).map(\.title) == ["Holiday"])
        #expect(model.allDayMeetings(on: AppFixtures.at(0, 0, day: 5)).isEmpty)
        #expect(model.placed(on: today).map { "\($0.meeting.title) \($0.column)/\($0.columns)" } == ["Team Sync 0/2", "Overlap 1/2"])
        #expect(model.hours(of: AppFixtures.at(14, 30), on: today) == 14.5)
        #expect(model.isToday(today))
    }

    @Test func inspectorText() {
        source.snapshots = [EventSnapshot(
            seriesKey: "s", title: "Team Sync", start: AppFixtures.at(14, 30), end: AppFixtures.at(15, 0),
            location: "https://meet.google.com/abc-defg-hij", calendarID: "work", myStatus: .accepted, attendeeCount: 6
        )]
        var opened: [URL] = []
        let model = makeModel { opened.append($0) }
        let meeting = model.meetings[0]
        #expect(model.dateLine(for: meeting) == "Wednesday, Nov 4 · 2:30 – 3:00 PM")
        #expect(model.attendeeLine(for: meeting) == "6 attendees · you accepted")
        #expect(model.calendarLine(for: meeting) == "Work · Google")
        #expect(model.hourLabel(0) == "12 AM")
        #expect(model.hourLabel(12) == "Noon")
        #expect(model.hourLabel(15) == "3 PM")
        #expect(model.weekdayLabel(AppFixtures.at(0, 0)) == "Wed")
        model.join(meeting)
        #expect(opened == [URL(string: "https://meet.google.com/abc-defg-hij")!])
    }

    @Test func notesGoThroughTheNoteStore() {
        let model = makeModel()
        let meeting = model.meetings[0]
        model.addTopic("Budget", to: meeting)
        model.toggleTask(line: 0, for: meeting)
        #expect(model.markdown(for: meeting) == "- [x] Budget")
        #expect(model.hasNotes(meeting))
        model.setMarkdown("", for: meeting)
        #expect(!model.hasNotes(meeting))
    }
}
