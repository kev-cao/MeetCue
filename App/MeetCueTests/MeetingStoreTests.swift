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

    @Test func calendarChangesReload() {
        let store = makeStore()
        store.refresh()
        #expect(store.meetings.isEmpty)
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30))]
        source.onChange?()
        #expect(store.meetings.map(\.title) == ["Team Sync"])
    }
}
