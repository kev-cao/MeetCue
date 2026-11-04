import Foundation

/// The fields MeetCue reads from a calendar event, independent of EventKit.
public struct EventSnapshot: Sendable, Equatable {
    /// The calendar server's identifier for the event, shared by every occurrence of a series.
    public var seriesKey: String
    /// For an occurrence of a recurring event, its original date, even if it was rescheduled.
    public var occurrenceDate: Date
    public var isRecurring: Bool
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var location: String?
    public var url: URL?
    public var notes: String?
    public var calendarID: String
    public var myStatus: RSVP
    public var attendeeCount: Int

    public init(
        seriesKey: String,
        occurrenceDate: Date? = nil,
        isRecurring: Bool = false,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        url: URL? = nil,
        notes: String? = nil,
        calendarID: String,
        myStatus: RSVP = .unknown,
        attendeeCount: Int = 0
    ) {
        self.seriesKey = seriesKey
        self.occurrenceDate = occurrenceDate ?? start
        self.isRecurring = isRecurring
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.url = url
        self.notes = notes
        self.calendarID = calendarID
        self.myStatus = myStatus
        self.attendeeCount = attendeeCount
    }
}

public enum MeetingMapper {
    public static func meeting(from event: EventSnapshot) -> Meeting {
        let parsed = JoinLinkParser.parse(url: event.url, location: event.location, notes: event.notes)
        let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return Meeting(
            id: .make(externalID: event.seriesKey, occurrenceDate: event.occurrenceDate, isRecurring: event.isRecurring),
            title: title.isEmpty ? "Untitled" : title,
            start: event.start,
            end: event.end,
            location: parsed.location,
            joinLink: parsed.joinLink,
            calendarID: event.calendarID,
            myStatus: event.myStatus,
            attendeeCount: event.attendeeCount,
            isAllDay: event.isAllDay
        )
    }
}
