import Foundation
import Testing
@testable import MeetCueCore

struct MenuBarTextTests {
    let sync = Fixtures.meeting(start: Fixtures.at(14, 30))

    func show(_ meetings: [Meeting], at now: Date, quiet: Bool = false, settings: MenuBarSettings = MenuBarSettings()) -> MenuBarDisplay {
        MenuBarText.display(meetings: meetings, now: now, quiet: quiet, settings: settings, calendar: Fixtures.calendar)
    }

    @Test func clockTimeWhenMoreThanAnHourAway() {
        let display = show([sync], at: Fixtures.at(13, 6))
        #expect(display == MenuBarDisplay(icon: .calendar, time: "2:30 PM", title: "Team Sync", scrollsTitle: false))
    }

    @Test func clockTimeFollows24HourSetting() {
        let morning = Fixtures.meeting("Standup", start: Fixtures.at(9, 5), series: "b")
        let settings = MenuBarSettings(uses24HourClock: true)
        #expect(show([sync], at: Fixtures.at(13, 6), settings: settings).time == "14:30")
        #expect(show([morning], at: Fixtures.at(7, 0), settings: settings).time == "09:05")
        #expect(show([morning], at: Fixtures.at(7, 0)).time == "9:05 AM")
    }

    @Test func countdownWithinTheHour() {
        #expect(show([sync], at: Fixtures.at(14, 6)).time == "in 24m")
        #expect(show([sync], at: Fixtures.at(14, 6, second: 30)).time == "in 24m")
        #expect(show([sync], at: Fixtures.at(14, 29, second: 50)).time == "in 1m")
    }

    @Test func timeLeftDuringMeeting() {
        let display = show([sync], at: Fixtures.at(14, 48))
        #expect(display.icon == .live)
        #expect(display.time == "12m left")
    }

    @Test func currentMeetingBeatsNextOne() {
        let next = Fixtures.meeting("Design review", start: Fixtures.at(15, 0), series: "b")
        #expect(show([next, sync], at: Fixtures.at(14, 48)).title == "Team Sync")
    }

    @Test func quietShowsMoonWithNothingLeft() {
        #expect(show([sync], at: Fixtures.at(17, 10), quiet: true) == MenuBarDisplay(icon: .quiet, time: nil, title: nil, scrollsTitle: false))
    }

    @Test func quietIconUnlessLive() {
        #expect(show([sync], at: Fixtures.at(13, 6), quiet: true).icon == .quiet)
        #expect(show([sync], at: Fixtures.at(14, 48), quiet: true).icon == .live)
    }

    @Test func doneWhenNothingLeftToday() {
        let tomorrow = Fixtures.meeting("Standup", start: Fixtures.at(9, 0, day: 5), series: "b")
        let display = show([sync, tomorrow], at: Fixtures.at(17, 10))
        #expect(display == MenuBarDisplay(icon: .doneForToday, time: nil, title: nil, scrollsTitle: false))
    }

    @Test func allDayEventsAreIgnored() {
        let offsite = Fixtures.meeting("Offsite", start: Fixtures.at(0, 0), minutes: 24 * 60, allDay: true)
        #expect(show([offsite], at: Fixtures.at(13, 6)).icon == .doneForToday)
    }

    @Test func longTitleScrollsOnlyNearTheMeeting() {
        let review = Fixtures.meeting("PITR design review", start: Fixtures.at(11, 0))
        #expect(show([review], at: Fixtures.at(9, 0)).scrollsTitle == false)
        #expect(show([review], at: Fixtures.at(10, 36)).scrollsTitle == true)
        #expect(show([review], at: Fixtures.at(11, 10)).scrollsTitle == true)
    }

    @Test func scrollSettingOverrides() {
        let review = Fixtures.meeting("PITR design review", start: Fixtures.at(11, 0))
        #expect(show([review], at: Fixtures.at(9, 0), settings: MenuBarSettings(scroll: .always)).scrollsTitle == true)
        #expect(show([review], at: Fixtures.at(10, 36), settings: MenuBarSettings(scroll: .never)).scrollsTitle == false)
    }

    @Test func titleAtTheLimitDoesNotScroll() {
        let tenChars = Fixtures.meeting("ABCDEFGHIJ", start: Fixtures.at(14, 30))
        #expect(show([tenChars], at: Fixtures.at(14, 6)).scrollsTitle == false)
    }

    @Test func contentSetting() {
        #expect(show([sync], at: Fixtures.at(14, 6), settings: MenuBarSettings(content: .timeOnly)).title == nil)
        #expect(show([sync], at: Fixtures.at(14, 6), settings: MenuBarSettings(content: .timeOnly)).time == "in 24m")
        let iconOnly = show([sync], at: Fixtures.at(14, 6), settings: MenuBarSettings(content: .iconOnly))
        #expect(iconOnly.time == nil)
        #expect(iconOnly.title == nil)
    }

    @Test func exactlyAnHourAwayCountsDown() {
        #expect(show([sync], at: Fixtures.at(13, 30)).time == "in 60m")
        #expect(show([sync], at: Fixtures.at(13, 29, second: 59)).time == "2:30 PM")
    }

    @Test func liveFromStartToJustBeforeEnd() {
        let start = show([sync], at: Fixtures.at(14, 30))
        #expect(start.icon == .live)
        #expect(start.time == "30m left")
        #expect(show([sync], at: Fixtures.at(14, 59, second: 59)).time == "1m left")
        #expect(show([sync], at: Fixtures.at(15, 0)).icon == .doneForToday)
    }

    @Test func latestStartedLiveMeetingWins() {
        let focus = Fixtures.meeting("Focus", start: Fixtures.at(9, 0), minutes: 480, series: "f")
        let display = show([focus, sync], at: Fixtures.at(14, 40))
        #expect(display.title == "Team Sync")
        #expect(display.time == "20m left")
    }

    @Test func meetingJustAfterMidnightShowsWithinTheHour() {
        let late = Fixtures.meeting("Late call", start: Fixtures.at(0, 10, day: 5), series: "l")
        let near = show([late], at: Fixtures.at(23, 30))
        #expect(near.time == "in 40m")
        #expect(near.title == "Late call")
        #expect(show([late], at: Fixtures.at(22, 30)).icon == .doneForToday)
    }

    @Test func customTitleLength() {
        let settings = MenuBarSettings(titleLength: 5)
        #expect(show([sync], at: Fixtures.at(14, 6), settings: settings).scrollsTitle == true)
    }

    @Test func featuredMatchesDisplay() {
        let featured = MenuBarText.featured(in: [sync], now: Fixtures.at(14, 6), calendar: Fixtures.calendar)
        #expect(featured?.title == "Team Sync")
        #expect(MenuBarText.featured(in: [sync], now: Fixtures.at(17, 10), calendar: Fixtures.calendar) == nil)
    }

    @Test func nextMeetingTieBreaksByTitle() {
        let zeta = Fixtures.meeting("Zeta", start: Fixtures.at(14, 30), series: "z")
        let alpha = Fixtures.meeting("Alpha", start: Fixtures.at(14, 30), series: "a")
        let featured = MenuBarText.featured(in: [zeta, alpha], now: Fixtures.at(14, 6), calendar: Fixtures.calendar)
        #expect(featured?.title == "Alpha")
    }

    @Test func detailShowsRangeAndCountdown() {
        let detail = { (now: Date) in
            MenuBarText.detail(for: sync, now: now, calendar: Fixtures.calendar, uses24Hour: false)
        }
        #expect(detail(Fixtures.at(13, 6)) == "2:30 – 3:00 PM")
        #expect(detail(Fixtures.at(14, 6)) == "2:30 – 3:00 PM · in 24 min")
        #expect(detail(Fixtures.at(14, 48)) == "2:30 – 3:00 PM · 12 min left")
    }

    @Test func detailRangeAcrossNoonAnd24Hour() {
        let lunch = Fixtures.meeting("Lunch", start: Fixtures.at(11, 30), minutes: 60, series: "l")
        #expect(MenuBarText.detail(for: lunch, now: Fixtures.at(9, 0), calendar: Fixtures.calendar, uses24Hour: false) == "11:30 AM – 12:30 PM")
        #expect(MenuBarText.detail(for: sync, now: Fixtures.at(9, 0), calendar: Fixtures.calendar, uses24Hour: true) == "14:30 – 15:00")
    }

    @Test func longLiveMeetingShowsHours() {
        let focus = Fixtures.meeting("Focus", start: Fixtures.at(9, 0), minutes: 480, series: "f")
        let detail = { (now: Date) in
            MenuBarText.detail(for: focus, now: now, calendar: Fixtures.calendar, uses24Hour: false)
        }
        #expect(show([focus], at: Fixtures.at(9, 40)).time == "7h 20m left")
        #expect(detail(Fixtures.at(9, 40)) == "9:00 AM – 5:00 PM · 7 hr 20 min left")
        #expect(show([focus], at: Fixtures.at(16, 0)).time == "1h left")
        #expect(detail(Fixtures.at(16, 0)).hasSuffix("· 1 hr left"))
    }

    @Test func detailBoundaries() {
        let detail = { (now: Date) in
            MenuBarText.detail(for: sync, now: now, calendar: Fixtures.calendar, uses24Hour: false)
        }
        #expect(detail(Fixtures.at(14, 30)) == "2:30 – 3:00 PM · 30 min left")
        #expect(detail(Fixtures.at(15, 0)) == "2:30 – 3:00 PM")
        #expect(detail(Fixtures.at(13, 30)) == "2:30 – 3:00 PM · in 60 min")
        #expect(detail(Fixtures.at(13, 29)) == "2:30 – 3:00 PM")
    }
}
