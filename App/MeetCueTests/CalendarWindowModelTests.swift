import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

private final class Flag: @unchecked Sendable {
    var value = false
}

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

    func makeModel(store: MeetingStore? = nil, now: @escaping () -> Date = { AppFixtures.at(9, 0) }, opened: (@MainActor (URL) -> Void)? = nil) -> CalendarWindowModel {
        let store = store ?? MeetingStore(source: source, now: now, calendar: AppFixtures.calendar)
        store.refresh()
        let model = CalendarWindowModel(
            store: store,
            notes: notes,
            visibility: CalendarVisibility(store: store, storage: hidden),
            clock: now,
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

    @Test func aStoreRefreshReloadsOnce() async {
        let store = MeetingStore(source: source, now: { AppFixtures.at(9, 0) }, calendar: AppFixtures.calendar)
        let model = makeModel(store: store)
        model.startTracking()
        for round in 1...2 {
            let before = source.queries
            source.snapshots.append(AppFixtures.event("Added \(round)", start: AppFixtures.at(16, 0, day: 6), series: "a\(round)"))
            store.refresh()
            let storeQueries = source.queries - before
            #expect(await eventually { model.meetings.count == round + 1 })
            try? await Task.sleep(for: .milliseconds(100))
            #expect(source.queries - before == storeQueries + 1)
        }
    }

    @Test func startingTrackingAgainDoesNotStackObservers() async {
        let store = MeetingStore(source: source, now: { AppFixtures.at(9, 0) }, calendar: AppFixtures.calendar)
        let model = makeModel(store: store)
        model.startTracking()
        model.startTracking()
        model.startTracking()
        let before = source.queries
        source.snapshots.append(AppFixtures.event("Added", start: AppFixtures.at(16, 0, day: 6), series: "a"))
        store.refresh()
        let storeQueries = source.queries - before
        #expect(await eventually { model.meetings.count == 2 })
        try? await Task.sleep(for: .milliseconds(100))
        #expect(source.queries - before == storeQueries + 1)
    }

    @Test func aReloadWithNothingNewInvalidatesNothing() {
        let model = makeModel()
        model.select(model.meetings.first)
        let invalidated = Flag()
        withObservationTracking {
            _ = model.meetings
            _ = model.selected
        } onChange: {
            invalidated.value = true
        }
        model.reload()
        #expect(!invalidated.value)
    }

    @Test func hidingTheSelectionsCalendarClearsIt() {
        let model = makeModel()
        model.select(model.meetings.first)
        model.setVisible(false, calendarID: "work")
        #expect(model.selected == nil)
    }

    @Test func aSelectionOffScreenIsKept() {
        let model = makeModel()
        model.select(model.meetings.first)
        model.step(1)
        model.step(1)
        #expect(model.selected?.title == "Team Sync")
        model.reload()
        #expect(model.selected?.title == "Team Sync")
    }

    @Test func theViewFollowsTodayAcrossMidnight() {
        var now = AppFixtures.at(23, 59)
        let model = makeModel(now: { now })
        #expect(model.anchor == AppFixtures.at(0, 0))
        now = AppFixtures.at(0, 1, day: 5)
        model.dayDidChange()
        #expect(model.anchor == AppFixtures.at(0, 0, day: 5))
        #expect(model.isToday(AppFixtures.at(0, 0, day: 5)))
    }

    @Test func aViewOnAnotherDayStaysPutAcrossMidnight() {
        var now = AppFixtures.at(23, 59)
        let model = makeModel(now: { now })
        model.step(1)
        let anchor = model.anchor
        now = AppFixtures.at(0, 1, day: 5)
        model.dayDidChange()
        #expect(model.anchor == anchor)
    }

    @Test func dayColumnsAreLabelledWithTheirEventCount() {
        let model = makeModel()
        #expect(model.columnLabel(for: AppFixtures.at(0, 0)) == "Wednesday, November 4, 1 event")
        #expect(model.columnLabel(for: AppFixtures.at(0, 0, day: 5)) == "Thursday, November 5, no events")
        source.snapshots.append(AppFixtures.event("Second", start: AppFixtures.at(16, 0), series: "x"))
        model.reload()
        #expect(model.columnLabel(for: AppFixtures.at(0, 0)) == "Wednesday, November 4, 2 events")
    }

    @Test func monthCellsShowOnlyWhatFits() {
        #expect(MonthLayout.visibleCount(total: 0, height: 100) == 0)
        #expect(MonthLayout.visibleCount(total: 2, height: 100) == 2)
        #expect(MonthLayout.visibleCount(total: 3, height: 100) == 3)
        #expect(MonthLayout.visibleCount(total: 4, height: 100) == 2)
        #expect(MonthLayout.visibleCount(total: 10, height: 50) == 0)
        #expect(MonthLayout.visibleCount(total: 2, height: -5) == 0)
        #expect(MonthLayout.visibleCount(total: 3, height: 91) == 3)
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

    @Test func hoursFollowTheWallClockOnDaylightSavingDays() {
        let model = makeModel()
        func date(_ day: Int, _ hour: Int) -> Date {
            AppFixtures.calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
        }
        let springForward = date(8, 0)
        #expect(model.hours(of: date(8, 10), on: springForward) == 10)
        #expect(model.hours(of: date(8, 23), on: springForward) == 23)
        #expect(model.hours(of: date(9, 0), on: springForward) == 24)
        #expect(model.hours(of: date(7, 20), on: springForward) == 0)
        let fallBack = AppFixtures.calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        #expect(model.hours(of: AppFixtures.calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 10))!, on: fallBack) == 10)
    }

    @Test func inspectorText() {
        source.snapshots = [EventSnapshot(
            seriesKey: "s", title: "Team Sync", start: AppFixtures.at(14, 30), end: AppFixtures.at(15, 0),
            location: "https://meet.google.com/abc-defg-hij", calendarID: "work", myStatus: .accepted, attendeeCount: 6
        )]
        var opened: [URL] = []
        let model = makeModel(opened: { opened.append($0) })
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
        model.toggleTask(line: 0, text: "Budget", for: meeting)
        #expect(model.markdown(for: meeting) == "- [x] Budget")
        #expect(model.hasNotes(meeting))
        model.setMarkdown("", for: meeting)
        #expect(!model.hasNotes(meeting))
    }
}
