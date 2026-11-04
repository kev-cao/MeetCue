import Foundation
import Testing
@testable import MeetCueCore

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
        let filter = CalendarFilter(alertOffCalendarIDs: ["team"])
        for input in [[mine, shared], [shared, mine]] {
            let result = MeetingFilter.visible(input, filter: filter)
            #expect(result.count == 1)
            #expect(result.first?.calendarID == "work")
        }
    }

    @Test func hiddenCopyLeavesVisibleCopy() {
        let hidden = Fixtures.meeting(start: Fixtures.at(14, 30), series: "x", calendarID: "work")
        let shown = Fixtures.meeting(start: Fixtures.at(14, 30), series: "x", calendarID: "team")
        let result = MeetingFilter.visible([hidden, shown], filter: CalendarFilter(hiddenCalendarIDs: ["work"]))
        #expect(result.count == 1)
        #expect(result.first?.calendarID == "team")
    }

    @Test func alertOnCopyWinsForAlerts() {
        let shared = Fixtures.meeting(start: Fixtures.at(14, 30), series: "x", calendarID: "team")
        let mine = Fixtures.meeting(start: Fixtures.at(14, 30), series: "x", calendarID: "work")
        let result = MeetingFilter.alertable([shared, mine], filter: CalendarFilter(alertOffCalendarIDs: ["team"]))
        #expect(result.count == 1)
        #expect(result.first?.calendarID == "work")
    }

    @Test func acceptedCopyBeatsPendingCopy() {
        let accepted = Fixtures.meeting(start: Fixtures.at(14, 30), series: "x", calendarID: "team", status: .accepted)
        let pending = Fixtures.meeting(start: Fixtures.at(14, 30), series: "x", calendarID: "work", status: .pending)
        for input in [[accepted, pending], [pending, accepted]] {
            let result = MeetingFilter.visible(input, filter: CalendarFilter())
            #expect(result.count == 1)
            #expect(result.first?.calendarID == "team")
        }
    }

    @Test func sameStartSortsByTitle() {
        let beta = Fixtures.meeting("Beta", start: Fixtures.at(9, 0), series: "b")
        let alpha = Fixtures.meeting("Alpha", start: Fixtures.at(9, 0), series: "a")
        let result = MeetingFilter.visible([beta, alpha], filter: CalendarFilter())
        #expect(result.map(\.title) == ["Alpha", "Beta"])
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

    @Test func declinedBeatsUnknownReply() {
        let declined = Fixtures.meeting(start: Fixtures.at(14, 30), series: "x", calendarID: "work", status: .declined)
        let unknown = Fixtures.meeting(start: Fixtures.at(14, 30), series: "x", calendarID: "team", status: .unknown)
        for input in [[declined, unknown], [unknown, declined]] {
            let result = MeetingFilter.visible(input, filter: CalendarFilter())
            #expect(result.map(\.calendarID) == ["work"])
            #expect(MeetingFilter.alertable(input, filter: CalendarFilter()).isEmpty)
        }
    }

    @Test func relevantDropsDeclinedButKeepsAllDay() {
        let declined = Fixtures.meeting("Declined", start: Fixtures.at(10, 0), series: "a", status: .declined)
        let allDay = Fixtures.meeting("Holiday", start: Fixtures.at(0, 0), series: "b", allDay: true)
        let normal = Fixtures.meeting("Normal", start: Fixtures.at(11, 0), series: "c")
        let input = [declined, allDay, normal]
        #expect(MeetingFilter.relevant(input, filter: CalendarFilter()).map(\.title) == ["Holiday", "Normal"])
        #expect(MeetingFilter.relevant(input, filter: CalendarFilter(skipDeclined: false)).map(\.title) == ["Holiday", "Declined", "Normal"])
    }
}
