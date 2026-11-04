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
    /// All-day events are included. When an occurrence is on several visible
    /// calendars, the copy on a calendar with alerts on wins, then the stronger
    /// reply, then the lower calendar ID, so the result doesn't depend on input order.
    public static func visible(_ meetings: [Meeting], filter: CalendarFilter) -> [Meeting] {
        var best: [OccurrenceID: Meeting] = [:]
        for meeting in meetings where !filter.hiddenCalendarIDs.contains(meeting.calendarID) {
            if let current = best[meeting.id], rank(current, filter) <= rank(meeting, filter) { continue }
            best[meeting.id] = meeting
        }
        return best.values.sorted {
            ($0.start, $0.title, $0.calendarID, $0.id.storageKey) < ($1.start, $1.title, $1.calendarID, $1.id.storageKey)
        }
    }

    /// Visible meetings that may trigger the full-screen alert.
    public static func alertable(_ meetings: [Meeting], filter: CalendarFilter) -> [Meeting] {
        visible(meetings, filter: filter).filter { meeting in
            !meeting.isAllDay
                && !filter.alertOffCalendarIDs.contains(meeting.calendarID)
                && !(filter.skipDeclined && meeting.myStatus == .declined)
        }
    }

    private static func rank(_ meeting: Meeting, _ filter: CalendarFilter) -> (Int, Int, String) {
        (filter.alertOffCalendarIDs.contains(meeting.calendarID) ? 1 : 0, replyRank(meeting.myStatus), meeting.calendarID)
    }

    private static func replyRank(_ status: RSVP) -> Int {
        switch status {
        case .accepted: 0
        case .tentative: 1
        case .pending: 2
        case .unknown: 3
        case .declined: 4
        }
    }
}
