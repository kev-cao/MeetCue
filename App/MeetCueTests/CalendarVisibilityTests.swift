import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
struct CalendarVisibilityTests {
    let source = FakeCalendarSource()
    let hidden = InMemoryHiddenCalendarStorage()
    let settings = AppSettings(storage: InMemorySettingsStorage())

    func makeStore() -> MeetingStore {
        source.snapshots = [
            AppFixtures.event(start: AppFixtures.at(14, 30)),
            AppFixtures.event("Declined", start: AppFixtures.at(15, 30), series: "d", status: .declined),
        ]
        let store = MeetingStore(source: source, now: { AppFixtures.at(9, 0) }, calendar: AppFixtures.calendar)
        store.refresh()
        return store
    }

    @Test func startsFromTheSavedSwitches() {
        hidden.hiddenCalendarIDs = ["home"]
        settings.alertOffCalendarIDs = ["work"]
        settings.skipDeclined = false
        let store = makeStore()
        _ = CalendarVisibility(store: store, settings: settings, storage: hidden)
        #expect(store.filter == CalendarFilter(hiddenCalendarIDs: ["home"], alertOffCalendarIDs: ["work"], skipDeclined: false))
        #expect(store.meetings.map(\.title) == ["Team Sync", "Declined"])
    }

    @Test func alertSwitchesAreSavedAndReachTheFilter() {
        let store = makeStore()
        let visibility = CalendarVisibility(store: store, settings: settings, storage: hidden)
        #expect(visibility.alertsOn("work"))
        visibility.setAlertsOn(false, calendarID: "work")
        #expect(!visibility.alertsOn("work"))
        #expect(settings.alertOffCalendarIDs == ["work"])
        #expect(store.filter.alertOffCalendarIDs == ["work"])
        visibility.setAlertsOn(true, calendarID: "work")
        #expect(store.filter.alertOffCalendarIDs.isEmpty)
    }

    @Test func skipDeclinedFollowsTheSetting() async {
        let store = makeStore()
        let visibility = CalendarVisibility(store: store, settings: settings, storage: hidden)
        #expect(store.meetings.map(\.title) == ["Team Sync"])
        settings.skipDeclined = false
        #expect(await eventually { store.meetings.map(\.title) == ["Team Sync", "Declined"] })
        withExtendedLifetime(visibility) {}
    }
}
