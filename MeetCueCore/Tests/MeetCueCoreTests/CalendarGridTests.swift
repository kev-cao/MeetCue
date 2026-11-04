import Foundation
import Testing
@testable import MeetCueCore

struct CalendarGridTests {
    @Test func dayShowsOnlyThatDay() {
        #expect(CalendarGrid.days(.day, containing: Fixtures.at(14, 30), calendar: Fixtures.calendar) == [Fixtures.at(0, 0)])
    }

    @Test func weekStartsOnTheFirstWeekday() {
        let sundayFirst = CalendarGrid.days(.week, containing: Fixtures.at(14, 30), calendar: Fixtures.calendar)
        #expect(sundayFirst.first == Fixtures.at(0, 0, day: 1))
        #expect(sundayFirst.last == Fixtures.at(0, 0, day: 7))
        var mondayFirst = Fixtures.calendar
        mondayFirst.firstWeekday = 2
        let week = CalendarGrid.days(.week, containing: Fixtures.at(14, 30), calendar: mondayFirst)
        #expect(week.first == Fixtures.at(0, 0, day: 2))
        #expect(week.count == 7)
    }

    @Test func monthCoversEveryWeekOfTheMonth() {
        let days = CalendarGrid.days(.month, containing: Fixtures.at(14, 30), calendar: Fixtures.calendar)
        #expect(days.count == 35)
        #expect(days.first == Fixtures.at(0, 0, day: 1))
        #expect(days.last == Fixtures.at(0, 0, month: 12, day: 5))
    }

    @Test func weekAcrossTheDaylightSavingChangeHasSevenMidnights() {
        let days = CalendarGrid.days(.week, containing: Fixtures.at(9, 0, day: 2), calendar: Fixtures.calendar)
        #expect(days.count == 7)
        #expect(days.allSatisfy { Fixtures.calendar.component(.hour, from: $0) == 0 })
    }

    @Test func intervalEndsAtTheStartOfTheDayAfter() {
        let interval = CalendarGrid.interval(.week, containing: Fixtures.at(14, 30), calendar: Fixtures.calendar)
        #expect(interval.start == Fixtures.at(0, 0, day: 1))
        #expect(interval.end == Fixtures.at(0, 0, day: 8))
    }

    @Test func stepMovesByTheViewsUnit() {
        let now = Fixtures.at(14, 30)
        #expect(CalendarGrid.step(.day, from: now, by: -1, calendar: Fixtures.calendar) == Fixtures.at(0, 0, day: 3))
        #expect(CalendarGrid.step(.week, from: now, by: 1, calendar: Fixtures.calendar) == Fixtures.at(0, 0, day: 11))
        #expect(CalendarGrid.step(.month, from: now, by: 1, calendar: Fixtures.calendar) == Fixtures.at(0, 0, month: 12, day: 4))
    }
}

struct DayLayoutTests {
    func placed(_ meetings: [Meeting]) -> [String: (Int, Int)] {
        Dictionary(uniqueKeysWithValues: DayLayout.place(meetings).map { ($0.meeting.title, ($0.column, $0.columns)) })
    }

    @Test func separateMeetingsTakeTheFullWidth() {
        let result = placed([
            Fixtures.meeting("A", start: Fixtures.at(9, 0), series: "a"),
            Fixtures.meeting("B", start: Fixtures.at(9, 30), series: "b"),
        ])
        #expect(result["A"]! == (0, 1))
        #expect(result["B"]! == (0, 1))
    }

    @Test func overlappingMeetingsShareTheWidth() {
        let result = placed([
            Fixtures.meeting("Long", start: Fixtures.at(9, 0), minutes: 120, series: "a"),
            Fixtures.meeting("First", start: Fixtures.at(9, 15), series: "b"),
            Fixtures.meeting("Second", start: Fixtures.at(9, 30), series: "c"),
            Fixtures.meeting("Third", start: Fixtures.at(9, 45), series: "d"),
        ])
        #expect(result["Long"]! == (0, 3))
        #expect(result["First"]! == (1, 3))
        #expect(result["Second"]! == (2, 3))
        #expect(result["Third"]! == (1, 3))
    }

    @Test func aLaterGroupStartsOver() {
        let result = placed([
            Fixtures.meeting("A", start: Fixtures.at(9, 0), series: "a"),
            Fixtures.meeting("B", start: Fixtures.at(9, 10), series: "b"),
            Fixtures.meeting("C", start: Fixtures.at(11, 0), series: "c"),
        ])
        #expect(result["C"]! == (0, 1))
        #expect(result["B"]! == (1, 2))
    }
}
