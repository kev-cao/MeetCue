import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
struct MenuBarModelTests {
    let source = FakeCalendarSource()
    let quiet = QuietMode(defaults: AppFixtures.isolatedDefaults())

    func makeModel(at time: Date, locale: Locale = Locale(identifier: "en_US")) -> (MenuBarModel, (Date) -> Void) {
        var current = time
        let store = MeetingStore(source: source, now: { current }, calendar: AppFixtures.calendar)
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30), location: "Room 4B · https://meet.google.com/abc")]
        store.refresh()
        let model = MenuBarModel(store: store, quiet: quiet, clock: { current }, calendar: AppFixtures.calendar, locale: locale)
        return (model, { current = $0; model.tick() })
    }

    @Test func displayFollowsTheClock() {
        let (model, setTime) = makeModel(at: AppFixtures.at(14, 6))
        #expect(model.display.time == "in 24m")
        #expect(model.display.title == "Team Sync")
        #expect(model.detail(for: model.featured!) == "2:30 – 3:00 PM · in 24 min")
        #expect(model.featured?.placeLine == "Room 4B · Google Meet")
        setTime(AppFixtures.at(14, 48))
        #expect(model.display.time == "12m left")
        #expect(model.display.icon == .live)
    }

    @Test func quietModeShowsTheMoon() {
        let (model, _) = makeModel(at: AppFixtures.at(13, 6))
        quiet.turnOn(.oneHour, now: AppFixtures.at(13, 6), calendar: AppFixtures.calendar)
        #expect(model.display.icon == .quiet)
        #expect(model.quietStatus == "Quiet until 2:06 PM")
        quiet.turnOn(.endOfToday, now: AppFixtures.at(13, 6), calendar: AppFixtures.calendar)
        #expect(model.quietStatus == "Quiet until end of today")
        quiet.turnOff()
        #expect(model.quietStatus == "Quiet mode: Off")
    }

    @Test func followsThe24HourSetting() {
        let (model, _) = makeModel(at: AppFixtures.at(13, 0), locale: Locale(identifier: "en_GB"))
        #expect(model.display.time == "14:30")
    }

    @Test func needsAccessWhenNotGranted() {
        source.access = .denied
        let (model, _) = makeModel(at: AppFixtures.at(13, 0))
        #expect(model.needsAccess)
    }
}
