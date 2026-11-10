import Foundation

/// One page of the Calendar API's events.list response.
public struct GoogleEventList: Decodable, Sendable {
    /// The calendar's title. For the primary calendar it's the account's email address.
    public var summary: String?
    public var items: [GoogleEvent]?
    public var nextPageToken: String?
}

public struct GoogleEvent: Decodable, Sendable {
    public struct Time: Decodable, Sendable {
        /// RFC 3339, for timed events.
        public var dateTime: String?
        /// yyyy-mm-dd, for all-day events.
        public var date: String?
    }

    public struct Person: Decodable, Sendable {
        public var isSelf: Bool?
        public var responseStatus: String?
        public var isResource: Bool?

        enum CodingKeys: String, CodingKey {
            case isSelf = "self"
            case responseStatus
            case isResource = "resource"
        }
    }

    public struct Conference: Decodable, Sendable {
        public struct EntryPoint: Decodable, Sendable {
            public var entryPointType: String?
            public var uri: String?
        }

        public var entryPoints: [EntryPoint]?
    }

    public var id: String
    public var status: String?
    public var eventType: String?
    public var iCalUID: String?
    public var summary: String?
    public var description: String?
    public var location: String?
    public var start: Time?
    public var end: Time?
    public var recurringEventId: String?
    public var originalStartTime: Time?
    public var attendees: [Person]?
    public var organizer: Person?
    public var hangoutLink: String?
    public var conferenceData: Conference?
}

public enum GoogleEventMapper {
    /// Snapshots of the events MeetCue shows. Cancelled events, working-location entries, and events
    /// without readable times are left out. All-day dates are read in `calendar`'s time zone.
    public static func snapshots(from events: [GoogleEvent], calendarID: String, calendar: Calendar) -> [EventSnapshot] {
        events.compactMap { snapshot(of: $0, calendarID: calendarID, calendar: calendar) }
    }

    private static func snapshot(of event: GoogleEvent, calendarID: String, calendar: Calendar) -> EventSnapshot? {
        guard event.status != "cancelled", event.eventType != "workingLocation",
              let start = event.start.flatMap({ date($0, calendar: calendar) }),
              let end = event.end.flatMap({ date($0, calendar: calendar) })
        else { return nil }
        let original = event.originalStartTime.flatMap { date($0, calendar: calendar) }
        let people = (event.attendees ?? []).filter { $0.isResource != true }
        return EventSnapshot(
            // EventKit's external identifier for an event synced over CalDAV, as Google accounts on
            // the Mac are, is this UID, so a meeting on both gets the same occurrence ID.
            seriesKey: event.iCalUID ?? event.id,
            occurrenceDate: original ?? start,
            isRecurring: event.recurringEventId != nil,
            title: event.summary ?? "",
            start: start,
            end: end,
            isAllDay: event.start?.dateTime == nil,
            location: event.location,
            url: joinURL(of: event),
            notes: event.description,
            calendarID: calendarID,
            myStatus: myStatus(in: event, people: people),
            attendeeCount: people.count
        )
    }

    private static func joinURL(of event: GoogleEvent) -> URL? {
        let video = event.conferenceData?.entryPoints?.first { $0.entryPointType == "video" }?.uri
        return (video ?? event.hangoutLink).flatMap(URL.init(string:))
    }

    /// Follows the same rules as EventKit's events: no attendees means my own entry, and an event I
    /// organize without an attendee entry for me counts as accepted.
    private static func myStatus(in event: GoogleEvent, people: [GoogleEvent.Person]) -> RSVP {
        guard !people.isEmpty else { return .accepted }
        guard let me = people.first(where: { $0.isSelf == true }) else {
            return event.organizer?.isSelf == true ? .accepted : .unknown
        }
        switch me.responseStatus {
        case "accepted": return .accepted
        case "tentative": return .tentative
        case "declined": return .declined
        case "needsAction": return .pending
        default: return .unknown
        }
    }

    private static func date(_ time: GoogleEvent.Time, calendar: Calendar) -> Date? {
        if let dateTime = time.dateTime {
            return (try? Date(dateTime, strategy: .iso8601))
                ?? (try? Date(dateTime, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
        }
        guard let day = time.date else { return nil }
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
