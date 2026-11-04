import AppKit
import Foundation
import MeetCueCore
import Observation

/// When the scheduler should settle the overlays again, and whether to keep App Nap away until then.
struct OverlaySchedule: Equatable {
    var wake: Date?
    var holdsActivity: Bool
}

/// The pill's "<title> is no longer on your calendar" line, shown until `until`. A meeting disappears
/// when it is cancelled, declined, or its calendar is hidden.
struct CancelNotice: Equatable {
    let text: String
    let until: Date
}

/// Each timed meeting's overlay state, the actions the alert, pill and notes card offer, and what
/// they show. Overlay windows render it. `refresh()` must run whenever the store's meetings or filter, quiet
/// mode, or the clock change, because `schedule` doesn't depend on them; `AlertScheduler` does so.
@MainActor
@Observable
final class OverlayModel {
    struct Entry: Equatable {
        var meeting: Meeting
        var state: OverlayState
        /// A simulated meeting ignores quiet mode and isn't remembered across launches.
        var isSimulated: Bool
        /// On a calendar with its Alert switch off, which acts as permanent quiet mode: no
        /// full-screen alert, but the notes card still appears at the start.
        var alertsOff = false
    }

    static let simulatedMeetingDelay: TimeInterval = 120

    let store: MeetingStore
    let quiet: QuietMode
    let notes: NoteStore
    let timing: AlertTiming
    private(set) var entries: [OccurrenceID: Entry] = [:]
    private(set) var notice: CancelNotice?
    private(set) var schedule = OverlaySchedule(wake: nil, holdsActivity: false)

    @ObservationIgnored private var noticeTitles: [String] = []
    @ObservationIgnored private var simulated: [Meeting] = []
    private let dismissed: DismissedAlerts
    private let clock: () -> Date
    private let calendar: Calendar
    private let locale: Locale
    private let openURL: @MainActor (URL) -> Void

    init(
        store: MeetingStore,
        quiet: QuietMode,
        notes: NoteStore,
        dismissed: DismissedAlerts,
        timing: AlertTiming = .standard,
        clock: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        openURL: @escaping @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.store = store
        self.quiet = quiet
        self.notes = notes
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

    /// The meeting on the notes card. When several have the card, the one that started last wins.
    var notesCardMeeting: Meeting? { Self.latestStarted(meetings(in: .notesCard)) }

    /// Whether `showNotesCard()` would bring up a card.
    var canShowNotesCard: Bool { notesCardMeeting == nil && notesCardCandidate != nil }

    func state(of id: OccurrenceID) -> OverlayState? { entries[id]?.state }

    func timeRange(for meeting: Meeting) -> String {
        MenuBarText.timeRange(meeting.start, meeting.end, calendar: calendar, uses24Hour: ClockStyle.uses24Hour(locale))
    }

    /// Topics still to bring up: the note's unchecked task items.
    func topicCount(for meeting: Meeting) -> Int { notes.openTopicCount(meeting.id) }

    // MARK: Actions

    func snoozeAlert() {
        let until = clock().addingTimeInterval(timing.snoozeLength)
        apply(to: alertMeetings) { _ in .snooze(until: until) }
    }

    /// The pill only counts down to the start, so meetings that have started stay in the alert.
    func moveAlertToCorner() {
        let now = clock()
        apply(to: alertMeetings.filter { now < $0.start }) { _ in .moveToCorner }
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
        let others = entries[id]?.state == .alert ? alertMeetings.filter { $0.id != id } : []
        let now = clock()
        apply(to: [meeting] + others) { $0.id == id ? .join : .dismiss(afterStart: now >= $0.start) }
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

    func hideNotesCard() {
        apply(to: meetings(in: .notesCard)) { _ in .hide }
    }

    /// Brings back the card of the meeting in progress that started last, if it has notes.
    func showNotesCard() {
        guard let meeting = notesCardCandidate else { return }
        apply(to: [meeting]) { _ in .show }
    }

    /// ⌥⌘N: hides the card if it's showing, or brings it back.
    func toggleNotesCard() {
        if notesCardMeeting != nil {
            hideNotesCard()
        } else {
            showNotesCard()
        }
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
        for meeting in store.meetings where !meeting.isAllDay {
            let alertsOff = store.filter.alertOffCalendarIDs.contains(meeting.calendarID)
            next[meeting.id] = reconciled(meeting, isSimulated: false, alertsOff: alertsOff)
        }
        for meeting in simulated {
            next[meeting.id] = reconciled(meeting, isSimulated: true)
        }

        let gone = entries.values
            .filter { next[$0.meeting.id] == nil && ($0.state == .alert || $0.state == .pill) && now < $0.meeting.end }
            .map(\.meeting)
            .sorted(by: Self.isOrderedBefore)
        if !gone.isEmpty {
            if let notice, notice.until > now {
                noticeTitles += gone.map { Self.shortened($0.title) }
            } else {
                noticeTitles = gone.map { Self.shortened($0.title) }
            }
            var seen = Set<String>()
            noticeTitles = noticeTitles.filter { seen.insert($0).inserted }
            let verb = noticeTitles.count == 1 ? "is" : "are"
            notice = CancelNotice(
                text: "\(Self.listed(noticeTitles)) \(verb) no longer on your calendar",
                until: now.addingTimeInterval(timing.cancelNoticeDuration)
            )
        } else if let notice, notice.until <= now {
            self.notice = nil
        }

        for (id, entry) in next {
            let quietUntil: Date? = entry.isSimulated ? nil : entry.alertsOff ? .distantFuture : quiet.until
            let config = timing.config(quietUntil: quietUntil)
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

    private func reconciled(_ meeting: Meeting, isSimulated: Bool, alertsOff: Bool = false) -> Entry {
        guard var entry = entries[meeting.id] else {
            let isRecorded = !isSimulated && dismissed.contains(meeting)
            if !isSimulated && !isRecorded { dismissed.remove(meeting.id) }
            let state: OverlayState = isRecorded ? .dismissed : .waiting
            return Entry(meeting: meeting, state: state, isSimulated: isSimulated, alertsOff: alertsOff)
        }
        if entry.meeting.start != meeting.start {
            entry.state = .waiting
            dismissed.remove(meeting.id)
        }
        if alertsOff {
            // Turning a calendar's alerts off closes its open alert as if dismissed.
            switch entry.state {
            case .alert, .snoozed, .pill: entry.state = .dismissed
            default: break
            }
        }
        entry.meeting = meeting
        entry.alertsOff = alertsOff
        return entry
    }

    private func makeSchedule(now: Date) -> OverlaySchedule {
        let pairs = entries.values.map { (meeting: $0.meeting, state: $0.state) }
        let alerting = entries.values.filter { !$0.alertsOff }.map { (meeting: $0.meeting, state: $0.state) }
        let config = timing.config(quietUntil: nil)
        let nextAlert = AlertRules.nextAlert(alerting, now: now, config: config)
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

    /// The card appears at the start, only for meetings with notes, and hides at the end. The Settings
    /// window will make the first three configurable.
    private func notesPolicy(for meeting: Meeting) -> NotesPolicy {
        NotesPolicy(hasNotes: notes.hasNotes(meeting.id))
    }

    /// The meeting in progress whose card `.show` would bring up, latest start first.
    private var notesCardCandidate: Meeting? {
        let now = clock()
        let candidates = entries.values
            .filter { $0.meeting.start <= now && now < $0.meeting.end }
            .filter { OverlayReducer.reduce($0.state, .show, notes: notesPolicy(for: $0.meeting)) == .notesCard }
            .map(\.meeting)
        return Self.latestStarted(candidates)
    }

    private static func latestStarted(_ meetings: [Meeting]) -> Meeting? {
        meetings.min { ($1.start, $0.title, $0.id.storageKey) < ($0.start, $1.title, $1.id.storageKey) }
    }

    private static let noticeTitleLimit = 30

    /// Keeps the notice's fixed suffix on screen when it is shown on one line.
    private static func shortened(_ title: String) -> String {
        title.count > noticeTitleLimit ? title.prefix(noticeTitleLimit - 1) + "…" : title
    }

    /// "A", "A and B", "A, B and C".
    private static func listed(_ titles: [String]) -> String {
        guard let last = titles.last, titles.count > 1 else { return titles.first ?? "" }
        return titles.dropLast().joined(separator: ", ") + " and " + last
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
