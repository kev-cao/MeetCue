import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
struct MenuBarModelTests {
    let source = FakeCalendarSource()
    let quiet: QuietMode
    let notes = NoteStore(repository: FlakyNoteRepository(), saveDelay: .seconds(60))
    let settings = AppSettings(storage: InMemorySettingsStorage())

    init() {
        quiet = QuietMode(storage: InMemoryQuietStorage())
    }

    func makeModel(at time: Date, locale: Locale = Locale(identifier: "en_US")) -> (MenuBarModel, (Date) -> Void) {
        var current = time
        let store = MeetingStore(source: source, now: { current }, calendar: AppFixtures.calendar)
        source.snapshots = [AppFixtures.event(start: AppFixtures.at(14, 30), location: "Room 4B · https://meet.google.com/abc")]
        store.refresh()
        let model = MenuBarModel(store: store, quiet: quiet, notes: notes, settings: settings, clock: { current }, calendar: AppFixtures.calendar, locale: locale)
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

    @Test func isLiveFollowsTheClock() {
        let (model, setTime) = makeModel(at: AppFixtures.at(14, 6))
        #expect(!model.isLive(model.featured!))
        setTime(AppFixtures.at(14, 48))
        #expect(model.isLive(model.featured!))
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

    @Test func moonGoesAwayWhenQuietExpires() {
        let (model, setTime) = makeModel(at: AppFixtures.at(13, 6))
        model.setQuiet(.oneHour)
        #expect(model.display.icon == .quiet)
        setTime(AppFixtures.at(14, 6))
        #expect(model.display.icon == .calendar)
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

    @Test func menuBarTextFollowsTheSettings() {
        let (model, setTime) = makeModel(at: AppFixtures.at(14, 6))
        settings.menuBarContent = .timeOnly
        #expect(model.display.time == "in 24m")
        #expect(model.display.title == nil)
        settings.menuBarContent = .iconOnly
        #expect(model.display.time == nil)
        #expect(model.display.icon == .calendar)
        settings.menuBarContent = .timeAndTitle
        settings.titleLength = 8
        #expect(model.menuBarSettings.titleLength == 8)
        #expect(model.display.scrollsTitle)
        settings.titleScroll = .never
        #expect(!model.display.scrollsTitle)
        settings.titleScroll = .nearMeetings
        setTime(AppFixtures.at(13, 6))
        #expect(!model.display.scrollsTitle)
        settings.titleScroll = .always
        #expect(model.display.scrollsTitle)
        settings.titleLength = 10
        #expect(!model.display.scrollsTitle)
    }

    @Test func joinTargetIsTheFeaturedMeetingWithAVideoLink() {
        let (model, _) = makeModel(at: AppFixtures.at(14, 6))
        #expect(model.joinTarget?.title == "Team Sync")
        source.snapshots = [AppFixtures.event("Lunch", start: AppFixtures.at(14, 30), location: "Cafeteria")]
        model.store.refresh()
        #expect(model.featured?.title == "Lunch")
        #expect(model.joinTarget == nil)
    }

    @Test func followsThe24HourSetting() {
        let (model, _) = makeModel(at: AppFixtures.at(13, 0), locale: Locale(identifier: "en_GB"))
        #expect(model.display.time == "14:30")
    }

    @Test func accessibilityLabelDescribesTheMeeting() {
        let (model, setTime) = makeModel(at: AppFixtures.at(14, 6))
        #expect(model.accessibilityLabel == "MeetCue, Next: Team Sync, in 24 min")
        setTime(AppFixtures.at(14, 48))
        #expect(model.accessibilityLabel == "MeetCue, Now: Team Sync, 12 min left")
        setTime(AppFixtures.at(13, 0))
        #expect(model.accessibilityLabel == "MeetCue, Next: Team Sync, at 2:30 PM")
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

    @Test func addsTopicsToTheFeaturedMeeting() throws {
        let (model, _) = makeModel(at: AppFixtures.at(14, 6))
        let meeting = try #require(model.featured)
        #expect(model.topicCount(for: meeting) == 0)
        model.addTopic("  Budget\nfor Q1 ", to: meeting)
        model.addTopic("Hiring", to: meeting)
        #expect(notes.markdown(for: meeting.id) == "- [ ] Budget for Q1\n- [ ] Hiring")
        #expect(model.topicCount(for: meeting) == 2)
    }
}
