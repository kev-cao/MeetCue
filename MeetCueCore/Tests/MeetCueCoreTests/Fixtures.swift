import Foundation
@testable import MeetCueCore

enum Fixtures {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    /// A wall-clock time in New York, on Wednesday Nov 4 2026 unless given.
    static func at(_ hour: Int, _ minute: Int, second: Int = 0, month: Int = 11, day: Int = 4) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    static func meeting(
        _ title: String = "Team Sync",
        start: Date,
        minutes: Int = 30,
        series: String = "series-1",
        recurring: Bool = false,
        calendarID: String = "work",
        status: RSVP = .accepted,
        allDay: Bool = false,
        location: String? = nil,
        joinLink: JoinLink? = nil
    ) -> Meeting {
        Meeting(
            id: .make(externalID: series, occurrenceDate: start, isRecurring: recurring),
            title: title,
            start: start,
            end: start.addingTimeInterval(TimeInterval(minutes * 60)),
            location: location,
            joinLink: joinLink,
            calendarID: calendarID,
            myStatus: status,
            isAllDay: allDay
        )
    }
}
