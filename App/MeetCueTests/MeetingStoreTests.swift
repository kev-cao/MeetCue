import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
struct MeetingStoreTests {
    let source = FakeCalendarSource()

    func makeStore(now: Date = AppFixtures.at(13, 0)) -> MeetingStore {
        MeetingStore(source: source, now: { now }, calendar: AppFixtures.calendar)
    }

    @Test func refreshLoadsTodayAndTomorrowWithoutDeclined() throws {
        source.snapshots = [
            AppFixtures.event(start: AppFixtures.at(14, 30)),
            AppFixtures.event("Declined", start: AppFixtures.at(15, 0), series: "d", status: .declined),
            AppFixtures.event("Late call", start: AppFixtures.at(0, 10, day: 5), series: "l"),
            AppFixtures.event("Far away", start: AppFixtures.at(9, 0, day: 7), series: "f"),
        ]
        let store = makeStore()
        store.refresh()
        #expect(store.meetings.map(\.title) == ["Team Sync", "Late call"])
        let range = try #require(source.requestedRange)
        #expect(range.start == AppFixtures.at(0, 0))
        #expect(range.end == AppFixtures.at(0, 0, day: 6))
    }

    @Test func noAccessMeansNoMeetings() {
        source.access = .denied
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30))]
        let store = makeStore()
        store.refresh()
        #expect(store.access == .denied)
        #expect(store.meetings.isEmpty)
    }

    @Test func grantingAccessLoadsMeetings() async {
        source.access = .notDetermined
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30))]
        let store = makeStore()
        await store.requestAccess()
        #expect(store.access == .granted)
        #expect(store.meetings.count == 1)
    }

    @Test func deniedRequestLeavesNoMeetings() async {
        source.access = .notDetermined
        source.accessAfterRequest = .denied
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30))]
        let store = makeStore()
        await store.requestAccess()
        #expect(store.access == .denied)
        #expect(store.meetings.isEmpty)
    }

    @Test func changingTheFilterReloads() {
        source.snapshots = [
            AppFixtures.event(start: AppFixtures.at(14, 30)),
            AppFixtures.event("Declined", start: AppFixtures.at(15, 0), series: "d", status: .declined),
        ]
        let store = makeStore()
        store.refresh()
        #expect(store.meetings.map(\.title) == ["Team Sync"])
        store.filter = CalendarFilter(skipDeclined: false)
        #expect(store.meetings.map(\.title) == ["Team Sync", "Declined"])
    }

    @Test func revokedAccessClearsMeetings() {
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30))]
        let store = makeStore()
        store.refresh()
        #expect(store.meetings.count == 1)
        source.access = .denied
        store.refresh()
        #expect(store.meetings.isEmpty)
        #expect(store.access == .denied)
    }

    @Test func calendarChangesReload() {
        let store = makeStore()
        store.refresh()
        #expect(store.meetings.isEmpty)
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30))]
        source.onChange?()
        #expect(store.meetings.map(\.title) == ["Team Sync"])
    }

    @Test func queriesAnyRangeWithTheFilter() {
        source.snapshots = [
            AppFixtures.event(start: AppFixtures.at(14, 30)),
            AppFixtures.event("Next week", start: AppFixtures.at(10, 0, day: 11), series: "n"),
            AppFixtures.event("Declined", start: AppFixtures.at(11, 0, day: 11), series: "d", status: .declined),
        ]
        let store = makeStore()
        #expect(store.meetings(from: AppFixtures.at(0, 0, day: 8), to: AppFixtures.at(0, 0, day: 15)).map(\.title) == ["Next week"])
        let everything = store.meetings(from: AppFixtures.at(0, 0, day: 8), to: AppFixtures.at(0, 0, day: 15), filter: CalendarFilter(skipDeclined: false))
        #expect(everything.map(\.title) == ["Next week", "Declined"])
        store.filter = CalendarFilter(hiddenCalendarIDs: ["work"])
        #expect(store.meetings(from: AppFixtures.at(0, 0, day: 8), to: AppFixtures.at(0, 0, day: 15)).isEmpty)
    }

    @Test func refreshListsCalendarsAndCountsRevisions() {
        let work = CalendarInfo(id: "work", title: "Work", account: "iCloud", color: .gray)
        source.calendarList = [work]
        let store = makeStore()
        #expect(store.calendars.isEmpty)
        store.refresh()
        #expect(store.calendars == [work])
        let revision = store.revision
        store.refresh()
        #expect(store.revision == revision + 1)
        source.access = .denied
        store.refresh()
        #expect(store.calendars.isEmpty)
        #expect(store.meetings(from: AppFixtures.at(0, 0), to: AppFixtures.at(0, 0, day: 5)).isEmpty)
    }

    @Test func googleMeetingsJoinTheMacsAndMatchedOnesAppearOnce() {
        let google = FakeCalendarSource()
        let meet = URL(string: "https://meet.google.com/abc-defg-hij")!
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30), series: "shared@google.com", status: .unknown)]
        var matched = AppFixtures.event("Team Sync (Google)", start: AppFixtures.at(14, 30), series: "shared@google.com", status: .tentative)
        matched.url = meet
        matched.calendarID = "google"
        var only = AppFixtures.event("Google only", start: AppFixtures.at(16, 0), series: "g")
        only.calendarID = "google"
        google.snapshots = [matched, only]
        let googleCalendar = CalendarInfo(id: "google", title: "Google Calendar", account: "me@example.com", color: .gray)
        google.calendarList = [googleCalendar]
        let store = MeetingStore(source: source, google: google, now: { AppFixtures.at(13, 0) }, calendar: AppFixtures.calendar)
        store.refresh()
        #expect(store.meetings.map(\.title) == ["Team Sync", "Google only"])
        #expect(store.meetings.first?.joinLink?.url == meet)
        #expect(store.meetings.first?.myStatus == .tentative)
        #expect(store.meetings.first?.calendarID == "work")
        #expect(store.calendars.contains(googleCalendar))
        store.filter = CalendarFilter(hiddenCalendarIDs: ["google"])
        #expect(store.meetings.map(\.title) == ["Team Sync"])
    }

    @Test func aDisconnectedGoogleSourceAddsNothing() {
        let google = FakeCalendarSource()
        google.access = .denied
        google.snapshots = [AppFixtures.event("Google only", start: AppFixtures.at(16, 0), series: "g")]
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30))]
        let store = MeetingStore(source: source, google: google, now: { AppFixtures.at(13, 0) }, calendar: AppFixtures.calendar)
        store.refresh()
        #expect(store.meetings.map(\.title) == ["Team Sync"])
        #expect(google.queries == 0)
    }

    @Test func googleChangesRefresh() {
        let google = FakeCalendarSource()
        let store = MeetingStore(source: source, google: google, now: { AppFixtures.at(13, 0) }, calendar: AppFixtures.calendar)
        store.refresh()
        #expect(store.meetings.isEmpty)
        google.snapshots = [AppFixtures.event("Google only", start: AppFixtures.at(16, 0), series: "g")]
        google.onChange?()
        #expect(store.meetings.map(\.title) == ["Google only"])
    }
}
