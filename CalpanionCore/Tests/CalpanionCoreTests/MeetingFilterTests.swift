import Foundation
import Testing
@testable import CalpanionCore

struct MeetingFilterTests {
    @Test func hidesCalendarsAndSortsByStart() {
        let late = Fixtures.meeting("Late", start: Fixtures.at(16, 0), series: "a")
        let early = Fixtures.meeting("Early", start: Fixtures.at(9, 0), series: "b")
        let hidden = Fixtures.meeting("Hidden", start: Fixtures.at(10, 0), series: "c", calendarID: "personal")
        let result = MeetingFilter.visible([late, hidden, early], filter: CalendarFilter(hiddenCalendarIDs: ["personal"]))
        #expect(result.map(\.title) == ["Early", "Late"])
    }

    @Test func sameOccurrenceOnTwoCalendarsAppearsOnce() {
        let mine = Fixtures.meeting(start: Fixtures.at(14, 30), series: "x", calendarID: "work")
        let shared = Fixtures.meeting(start: Fixtures.at(14, 30), series: "x", calendarID: "team")
        let result = MeetingFilter.visible([mine, shared], filter: CalendarFilter())
        #expect(result.count == 1)
        #expect(result.first?.calendarID == "work")
    }

    @Test func alertableDropsAllDayDeclinedAndAlertOffCalendars() {
        let normal = Fixtures.meeting("Normal", start: Fixtures.at(9, 0), series: "a")
        let allDay = Fixtures.meeting("Offsite", start: Fixtures.at(0, 0), series: "b", allDay: true)
        let declined = Fixtures.meeting("Declined", start: Fixtures.at(10, 0), series: "c", status: .declined)
        let focus = Fixtures.meeting("Focus", start: Fixtures.at(11, 0), series: "d", calendarID: "focus")
        let filter = CalendarFilter(alertOffCalendarIDs: ["focus"])
        let result = MeetingFilter.alertable([normal, allDay, declined, focus], filter: filter)
        #expect(result.map(\.title) == ["Normal"])
    }

    @Test func declinedAlertsWhenSkipIsOff() {
        let declined = Fixtures.meeting("Declined", start: Fixtures.at(10, 0), status: .declined)
        let result = MeetingFilter.alertable([declined], filter: CalendarFilter(skipDeclined: false))
        #expect(result.count == 1)
    }
}
