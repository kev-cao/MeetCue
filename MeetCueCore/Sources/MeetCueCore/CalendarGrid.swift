import Foundation

/// The calendar window's views.
public enum CalendarMode: String, Sendable, CaseIterable, Identifiable {
    case day, week, month

    public var id: Self { self }

    public var title: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        }
    }
}

public enum CalendarGrid {
    /// The days a view shows, each at the start of its day: the day itself, the week containing it
    /// (starting on the calendar's first weekday), or every week that overlaps its month.
    public static func days(_ mode: CalendarMode, containing date: Date, calendar: Calendar) -> [Date] {
        let day = calendar.startOfDay(for: date)
        let first: Date
        let last: Date
        switch mode {
        case .day:
            return [day]
        case .week:
            first = startOfWeek(day, calendar: calendar)
            last = addDays(6, to: first, calendar: calendar)
        case .month:
            let month = calendar.dateInterval(of: .month, for: day)!
            first = startOfWeek(month.start, calendar: calendar)
            let lastOfMonth = addDays(-1, to: month.end, calendar: calendar)
            last = addDays(6, to: startOfWeek(lastOfMonth, calendar: calendar), calendar: calendar)
        }
        var result: [Date] = []
        var current = first
        while current <= last {
            result.append(current)
            current = addDays(1, to: current, calendar: calendar)
        }
        return result
    }

    /// From the start of the first day shown to the start of the day after the last.
    public static func interval(_ mode: CalendarMode, containing date: Date, calendar: Calendar) -> DateInterval {
        let days = days(mode, containing: date, calendar: calendar)
        return DateInterval(start: days[0], end: addDays(1, to: days[days.count - 1], calendar: calendar))
    }

    /// `date` moved by `count` days, weeks or months.
    public static func step(_ mode: CalendarMode, from date: Date, by count: Int, calendar: Calendar) -> Date {
        let component: Calendar.Component = switch mode {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
        return calendar.date(byAdding: component, value: count, to: calendar.startOfDay(for: date))!
    }

    private static func startOfWeek(_ day: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return addDays(-offset, to: day, calendar: calendar)
    }

    /// A zone's midnight can be missing on a daylight saving change, and adding days to the shifted
    /// time of day would carry the shift into every later day.
    private static func addDays(_ count: Int, to day: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: count, to: day)!)
    }
}

/// A timed meeting's place in a day column: overlapping meetings share the width side by side.
public struct PlacedMeeting: Equatable, Sendable {
    public let meeting: Meeting
    /// Zero-based column within its group of overlapping meetings.
    public let column: Int
    /// How many columns the group needs.
    public let columns: Int
}

public enum DayLayout {
    /// Places meetings that overlap in time in side-by-side columns. Each group of meetings linked by
    /// overlaps splits the width evenly; a meeting takes the leftmost column free at its start.
    /// Meetings that only touch (one ends as the next starts) don't overlap.
    public static func place(_ meetings: [Meeting]) -> [PlacedMeeting] {
        let sorted = meetings.sorted {
            ($0.start, $1.end, $0.title, $0.id.storageKey) < ($1.start, $0.end, $1.title, $1.id.storageKey)
        }
        var result: [PlacedMeeting] = []
        var group: [(meeting: Meeting, column: Int)] = []
        var columnEnds: [Date] = []
        var groupEnd = Date.distantPast

        func closeGroup() {
            result += group.map { PlacedMeeting(meeting: $0.meeting, column: $0.column, columns: columnEnds.count) }
            group = []
            columnEnds = []
        }

        for meeting in sorted {
            if meeting.start >= groupEnd { closeGroup() }
            let end = max(meeting.end, meeting.start.addingTimeInterval(1))
            if let free = columnEnds.firstIndex(where: { $0 <= meeting.start }) {
                columnEnds[free] = end
                group.append((meeting, free))
            } else {
                columnEnds.append(end)
                group.append((meeting, columnEnds.count - 1))
            }
            groupEnd = max(groupEnd, end)
        }
        closeGroup()
        return result
    }
}
