import AppKit
import Foundation
import MeetCueCore
import Observation

/// When the scheduler should settle the overlays again, and whether to keep App Nap away until then.
struct OverlaySchedule: Equatable {
    var wake: Date?
    var holdsActivity: Bool
}

/// The pill's "<title> was cancelled" line, shown until `until`.
struct CancelNotice: Equatable {
    let text: String
    let until: Date
}

/// Each alertable meeting's overlay state, the actions the alert and pill offer, and what they show.
/// Overlay windows render it; `AlertScheduler` calls `refresh()` at each deadline and system change.
@MainActor
@Observable
final class OverlayModel {
    struct Entry: Equatable {
        var meeting: Meeting
        var state: OverlayState
        /// A simulated meeting ignores quiet mode and isn't remembered across launches.
        var isSimulated: Bool
    }

    static let simulatedMeetingDelay: TimeInterval = 120

    let store: MeetingStore
    let quiet: QuietMode
    let timing: AlertTiming
    private(set) var entries: [OccurrenceID: Entry] = [:]
    private(set) var notice: CancelNotice?
    private(set) var schedule = OverlaySchedule(wake: nil, holdsActivity: false)

    @ObservationIgnored private var simulated: [Meeting] = []
    @ObservationIgnored private let dismissed: DismissedAlerts
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let openURL: @MainActor (URL) -> Void

    init(
        store: MeetingStore,
        quiet: QuietMode,
        dismissed: DismissedAlerts,
        timing: AlertTiming = .standard,
        clock: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        openURL: @escaping @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.store = store
        self.quiet = quiet
        self.dismissed = dismissed
        self.timing = timing
        self.clock = clock
        self.calendar = calendar
        self.locale = locale
        self.openURL = openURL
    }

    func currentTime() -> Date { clock() }

    /// Meetings sharing the full-screen alert card, earliest first.
    var alertMeetings: [Meeting] { meetings(in: .alert) }

    /// Meetings shown as corner pills, earliest first.
    var pillMeetings: [Meeting] { meetings(in: .pill) }

    func state(of id: OccurrenceID) -> OverlayState? { entries[id]?.state }

    func timeRange(for meeting: Meeting) -> String {
        MenuBarText.timeRange(meeting.start, meeting.end, calendar: calendar, uses24Hour: ClockStyle.uses24Hour(locale))
    }

    /// Topics noted for the meeting. Always 0 until notes exist, which hides the count.
    func topicCount(for meeting: Meeting) -> Int { 0 }

    // MARK: Actions

    func snoozeAlert() {
        let until = clock().addingTimeInterval(timing.snoozeLength)
        apply(to: alertMeetings) { _ in .snooze(until: until) }
    }

    func moveAlertToCorner() {
        apply(to: alertMeetings) { _ in .moveToCorner }
    }

    func expandPill() {
        apply(to: pillMeetings) { _ in .expand }
    }

    func dismissAlert() {
        dismiss(alertMeetings)
    }

    func dismissPill(_ id: OccurrenceID) {
        dismiss(pillMeetings.filter { $0.id == id })
    }

    func join(_ id: OccurrenceID) {
        guard let meeting = entries[id]?.meeting else { return }
        if let link = meeting.joinLink {
            openURL(link.url)
        }
        apply(to: [meeting]) { _ in .join }
    }

    /// ↩ on the alert joins the first meeting with a video link, or dismisses when none has one.
    func pressReturn() {
        if let meeting = alertMeetings.first(where: { $0.joinLink != nil }) {
            join(meeting.id)
        } else {
            dismissAlert()
        }
    }

    func pressEscape() {
        dismissAlert()
    }

    /// Adds a meeting starting in two minutes to the alert flow only, so the alert shows at once
    /// with a lead time of two minutes or more.
    func simulateMeeting() {
        let start = clock().addingTimeInterval(Self.simulatedMeetingDelay)
        simulated.append(Meeting(
            id: OccurrenceID(seriesKey: "meetcue-simulated-\(UUID().uuidString)", originalDate: nil),
            title: "Simulated meeting",
            start: start,
            end: start.addingTimeInterval(15 * 60),
            joinLink: JoinLink(url: URL(string: "https://zoom.us/test")!, service: .zoom),
            calendarID: "meetcue-simulated"
        ))
        refresh()
    }

    // MARK: Settling

    /// Brings every entry up to date with the store's meetings and the clock, then works out the next wake.
    func refresh() {
        let now = clock()
        dismissed.prune(before: calendar.startOfDay(for: now))

        var next: [OccurrenceID: Entry] = [:]
        for meeting in MeetingFilter.alertable(store.meetings, filter: store.filter) {
            next[meeting.id] = reconciled(meeting, isSimulated: false)
        }
        for meeting in simulated {
            next[meeting.id] = reconciled(meeting, isSimulated: true)
        }

        let cancelled = entries.values
            .filter { next[$0.meeting.id] == nil && ($0.state == .alert || $0.state == .pill) }
            .map(\.meeting)
            .sorted(by: Self.isOrderedBefore)
        if !cancelled.isEmpty {
            let titles = cancelled.map(\.title).joined(separator: " and ")
            notice = CancelNotice(
                text: "\(titles) \(cancelled.count == 1 ? "was" : "were") cancelled",
                until: now.addingTimeInterval(timing.cancelNoticeDuration)
            )
        } else if let notice, notice.until <= now {
            self.notice = nil
        }

        for (id, entry) in next {
            let config = timing.config(quietUntil: entry.isSimulated ? nil : quiet.until)
            let state = AlertRules.settle(entry.meeting, state: entry.state, now: now, config: config, notes: notesPolicy(for: entry.meeting))
            next[id]?.state = state
            if !entry.isSimulated && Self.isPastAlert(state) {
                dismissed.insert(entry.meeting)
            }
        }
        for meeting in simulated where next[meeting.id]?.state == .done {
            next[meeting.id] = nil
        }
        simulated.removeAll { next[$0.id] == nil }

        if next != entries { entries = next }
        let newSchedule = makeSchedule(now: now)
        if newSchedule != schedule { schedule = newSchedule }
    }

    private func reconciled(_ meeting: Meeting, isSimulated: Bool) -> Entry {
        guard var entry = entries[meeting.id] else {
            let state: OverlayState = !isSimulated && dismissed.contains(meeting) ? .dismissed : .waiting
            return Entry(meeting: meeting, state: state, isSimulated: isSimulated)
        }
        if entry.meeting.start != meeting.start {
            entry.state = .waiting
            dismissed.remove(meeting.id)
        }
        entry.meeting = meeting
        return entry
    }

    private func makeSchedule(now: Date) -> OverlaySchedule {
        let pairs = entries.values.map { (meeting: $0.meeting, state: $0.state) }
        let config = timing.config(quietUntil: nil)
        let nextAlert = AlertRules.nextAlert(pairs, now: now, config: config)
        let holdsActivity = nextAlert.map { $0.timeIntervalSince(now) <= timing.activityLeadTime } ?? false
        var wakes = [AlertRules.nextWake(pairs, now: now, config: config), notice?.until]
        if let nextAlert, !holdsActivity {
            wakes.append(nextAlert.addingTimeInterval(-timing.activityLeadTime))
        }
        return OverlaySchedule(wake: wakes.compactMap { $0 }.min(), holdsActivity: holdsActivity)
    }

    private func apply(to meetings: [Meeting], event: (Meeting) -> OverlayEvent) {
        guard !meetings.isEmpty else { return }
        var next = entries
        for meeting in meetings {
            guard let state = next[meeting.id]?.state else { continue }
            next[meeting.id]?.state = OverlayReducer.reduce(state, event(meeting), notes: notesPolicy(for: meeting))
        }
        entries = next
        refresh()
    }

    private func dismiss(_ meetings: [Meeting]) {
        let now = clock()
        apply(to: meetings) { .dismiss(afterStart: now >= $0.start) }
    }

    private func meetings(in state: OverlayState) -> [Meeting] {
        entries.values.filter { $0.state == state }.map(\.meeting).sorted(by: Self.isOrderedBefore)
    }

    /// Without a notes store, no meeting has notes, so meetings go to `.done` where the notes card would appear.
    private func notesPolicy(for meeting: Meeting) -> NotesPolicy {
        NotesPolicy(hasNotes: false)
    }

    private static func isPastAlert(_ state: OverlayState) -> Bool {
        switch state {
        case .dismissed, .notesCard, .hidden, .done: true
        case .waiting, .alert, .snoozed, .pill: false
        }
    }

    private static func isOrderedBefore(_ a: Meeting, _ b: Meeting) -> Bool {
        (a.start, a.title, a.id.storageKey) < (b.start, b.title, b.id.storageKey)
    }
}
