import Foundation

public struct CalendarFilter: Sendable, Equatable {
    public var hiddenCalendarIDs: Set<String>
    public var alertOffCalendarIDs: Set<String>
    public var skipDeclined: Bool

    public init(hiddenCalendarIDs: Set<String> = [], alertOffCalendarIDs: Set<String> = [], skipDeclined: Bool = true) {
        self.hiddenCalendarIDs = hiddenCalendarIDs
        self.alertOffCalendarIDs = alertOffCalendarIDs
        self.skipDeclined = skipDeclined
    }
}

public enum MeetingFilter {
    /// Meetings on visible calendars, one per occurrence, ordered by start.
    /// When an occurrence appears on several calendars, the first one in the input wins.
    public static func visible(_ meetings: [Meeting], filter: CalendarFilter) -> [Meeting] {
        var seen = Set<OccurrenceID>()
        return meetings
            .filter { !filter.hiddenCalendarIDs.contains($0.calendarID) }
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }

    /// Visible meetings that may trigger the full-screen alert.
    public static func alertable(_ meetings: [Meeting], filter: CalendarFilter) -> [Meeting] {
        visible(meetings, filter: filter).filter { meeting in
            !meeting.isAllDay
                && !filter.alertOffCalendarIDs.contains(meeting.calendarID)
                && !(filter.skipDeclined && meeting.myStatus == .declined)
        }
    }
}
