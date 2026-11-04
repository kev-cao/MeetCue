import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
struct MenuBarModelTests {
    let source = FakeCalendarSource()
    let testDefaults = TestDefaults()
    let quiet: QuietMode

    init() {
        quiet = QuietMode(defaults: testDefaults.defaults)
    }

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
        model.setQuiet(.oneHour)
        #expect(model.display.icon == .quiet)
        #expect(model.quietStatus == "Quiet until 2:06 PM")
        model.setQuiet(.endOfToday)
        #expect(model.quietStatus == "Quiet until end of today")
        model.setQuiet(nil)
        #expect(model.quietStatus == "Quiet mode: Off")
    }

    @Test func oneHourAt11PMIsNotEndOfToday() {
        let (model, _) = makeModel(at: AppFixtures.at(23, 0))
        model.setQuiet(.oneHour)
        #expect(model.quietStatus == "Quiet until 12:00 AM")
    }

    @Test func quietStatusAfterExpiry() {
        let (model, setTime) = makeModel(at: AppFixtures.at(13, 6))
        model.setQuiet(.oneHour)
        setTime(AppFixtures.at(14, 6))
        #expect(model.quietStatus == "Quiet mode: Off")
    }

    @Test func untilTurnedOffStatus() {
        let (model, _) = makeModel(at: AppFixtures.at(13, 6))
        model.setQuiet(.untilTurnedOff)
        #expect(model.quietStatus == "Quiet until you turn it off")
    }

    @Test func followsThe24HourSetting() {
        let (model, _) = makeModel(at: AppFixtures.at(13, 0), locale: Locale(identifier: "en_GB"))
        #expect(model.display.time == "14:30")
    }

    @Test func accessibilityLabelDescribesTheMeeting() {
        let (model, setTime) = makeModel(at: AppFixtures.at(14, 6))
        #expect(model.accessibilityLabel == "MeetCue, Next: Team Sync, in 24m")
        setTime(AppFixtures.at(14, 48))
        #expect(model.accessibilityLabel == "MeetCue, Now: Team Sync, 12m left")
        setTime(AppFixtures.at(17, 10))
        model.setQuiet(.untilTurnedOff)
        #expect(model.accessibilityLabel == "MeetCue, no more meetings today, quiet mode on")

        source.access = .denied
        let (denied, _) = makeModel(at: AppFixtures.at(14, 6))
        #expect(denied.accessibilityLabel == "MeetCue, calendar access needed")
    }

    @Test func needsAccessWhenNotGranted() {
        source.access = .denied
        let (model, _) = makeModel(at: AppFixtures.at(13, 0))
        #expect(model.needsAccess)
    }
}
