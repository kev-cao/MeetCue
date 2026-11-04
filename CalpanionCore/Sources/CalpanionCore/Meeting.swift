import Foundation

public enum RSVP: Sendable, Equatable {
    case accepted, tentative, declined
    /// Invited and hasn't replied.
    case pending
    /// No reply information, such as an event without attendees.
    case unknown
}

public enum VideoService: Sendable, Equatable {
    case zoom, meet, teams

    public var displayName: String {
        switch self {
        case .zoom: "Zoom"
        case .meet: "Google Meet"
        case .teams: "Microsoft Teams"
        }
    }
}

public struct JoinLink: Sendable, Equatable {
    public let url: URL
    public let service: VideoService

    public init(url: URL, service: VideoService) {
        self.url = url
        self.service = service
    }
}

/// Identifies one occurrence of a meeting across fetches and syncs.
///
/// `seriesKey` is the calendar server's identifier for the event. A recurring
/// meeting adds the occurrence's original date so each instance is distinct.
/// A one-off meeting has no date, so moving it keeps the same ID.
/// The date is truncated to whole seconds, so fetches that differ by a
/// fraction of a second produce equal IDs.
public struct OccurrenceID: Hashable, Sendable {
    public let seriesKey: String
    public let originalDate: Date?

    public init(seriesKey: String, originalDate: Date?) {
        self.seriesKey = seriesKey
        self.originalDate = originalDate
    }

    public static func make(externalID: String, occurrenceDate: Date, isRecurring: Bool) -> OccurrenceID {
        let wholeSeconds = Date(timeIntervalSince1970: occurrenceDate.timeIntervalSince1970.rounded(.down))
        return OccurrenceID(seriesKey: externalID, originalDate: isRecurring ? wholeSeconds : nil)
    }

    /// A stable string form for use as a storage key.
    public var storageKey: String {
        guard let originalDate else { return seriesKey }
        return "\(seriesKey)|\(Int(originalDate.timeIntervalSince1970))"
    }
}

public struct Meeting: Sendable, Equatable, Identifiable {
    public let id: OccurrenceID
    public var title: String
    public var start: Date
    public var end: Date
    /// Physical location, with any video links removed.
    public var location: String?
    public var joinLink: JoinLink?
    public var calendarID: String
    public var myStatus: RSVP
    public var attendeeCount: Int
    public var isAllDay: Bool

    public init(
        id: OccurrenceID,
        title: String,
        start: Date,
        end: Date,
        location: String? = nil,
        joinLink: JoinLink? = nil,
        calendarID: String,
        myStatus: RSVP = .accepted,
        attendeeCount: Int = 0,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.location = location
        self.joinLink = joinLink
        self.calendarID = calendarID
        self.myStatus = myStatus
        self.attendeeCount = attendeeCount
        self.isAllDay = isAllDay
    }

    public var isRecurring: Bool { id.originalDate != nil }

    /// "Room 4B · Google Meet", either part alone, or nil when there is neither.
    public var placeLine: String? {
        let parts = [location, joinLink?.service.displayName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
