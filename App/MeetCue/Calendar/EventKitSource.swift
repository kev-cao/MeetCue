import EventKit
import MeetCueCore

@MainActor
final class EventKitSource: CalendarSource {
    var onChange: (@MainActor () -> Void)?
    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private var hasReadWithAccess = false

    init() {
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onChange?() }
        }
    }

    var access: CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func requestAccess() async -> CalendarAccess {
        _ = try? await store.requestFullAccessToEvents()
        return access
    }

    func events(from start: Date, to end: Date) -> [EventSnapshot] {
        guard access == .granted else { return [] }
        // A store created before access was granted can keep returning no events.
        if !hasReadWithAccess { store.reset(); hasReadWithAccess = true }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).filter { $0.status != .canceled }.map(Self.snapshot)
    }

    private static func snapshot(of event: EKEvent) -> EventSnapshot {
        EventSnapshot(
            seriesKey: event.calendarItemExternalIdentifier ?? event.calendarItemIdentifier,
            occurrenceDate: event.occurrenceDate ?? event.startDate,
            isRecurring: event.hasRecurrenceRules || event.isDetached,
            title: event.title ?? "",
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            location: event.location,
            url: event.url,
            notes: event.notes,
            calendarID: event.calendar.calendarIdentifier,
            myStatus: myStatus(in: event),
            attendeeCount: event.attendees?.count ?? 0
        )
    }

    /// An event without attendees is my own entry, so it counts as accepted. With attendees, an event I
    /// organize counts as accepted, and one where no attendee is recognized as me is unknown.
    private static func myStatus(in event: EKEvent) -> RSVP {
        guard let attendees = event.attendees, !attendees.isEmpty else { return .accepted }
        guard let me = attendees.first(where: \.isCurrentUser) else {
            return event.organizer?.isCurrentUser == true ? .accepted : .unknown
        }
        switch me.participantStatus {
        case .accepted: return .accepted
        case .tentative: return .tentative
        case .declined: return .declined
        case .pending: return .pending
        default: return .unknown
        }
    }
}
