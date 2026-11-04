import Foundation

public struct AlertConfig: Sendable, Equatable {
    public var leadTime: TimeInterval
    /// How long after start a missed alert is still shown, e.g. after waking the Mac.
    public var lateAlertWindow: TimeInterval
    /// Nil when quiet mode is off; `.distantFuture` for "until I turn it off".
    /// Quiet mode is checked when the alert comes due (or when the Mac wakes after that); a meeting skipped while quiet stays skipped.
    public var quietUntil: Date?

    public init(leadTime: TimeInterval = 120, lateAlertWindow: TimeInterval = 300, quietUntil: Date? = nil) {
        self.leadTime = leadTime
        self.lateAlertWindow = lateAlertWindow
        self.quietUntil = quietUntil
    }

    public func isQuiet(at now: Date) -> Bool {
        quietUntil.map { now < $0 } ?? false
    }
}

public enum AlertRules {
    /// The event due for `meeting` at `now`, or nil if nothing is due.
    /// A meeting's end closes any open alert or pill; the notes card follows `hideAtEnd`.
    public static func dueEvent(for meeting: Meeting, state: OverlayState, now: Date, config: AlertConfig) -> OverlayEvent? {
        if state == .done { return nil }
        if now >= meeting.end { return .meetingEnded }
        switch state {
        case .waiting:
            if now >= meeting.start.addingTimeInterval(config.lateAlertWindow) { return .startTime }
            if now >= meeting.start.addingTimeInterval(-config.leadTime) {
                return .alertTime(quiet: config.isQuiet(at: now))
            }
            return nil
        case .snoozed(let until):
            return now >= until ? .snoozeElapsed : nil
        case .pill, .dismissed:
            return now >= meeting.start ? .startTime : nil
        case .alert, .notesCard, .hidden, .done:
            return nil
        }
    }

    /// Applies due events until the state stops changing.
    public static func settle(
        _ meeting: Meeting,
        state: OverlayState,
        now: Date,
        config: AlertConfig,
        notes: NotesPolicy
    ) -> OverlayState {
        var current = state
        while let event = dueEvent(for: meeting, state: current, now: now, config: config) {
            let next = OverlayReducer.reduce(current, event, notes: notes)
            if next == current { break }
            current = next
        }
        return current
    }

    /// The earliest moment after `now` at which an event may become due.
    /// Entries must already be settled at `now`.
    public static func nextWake(
        _ entries: [(meeting: Meeting, state: OverlayState)],
        now: Date,
        config: AlertConfig
    ) -> Date? {
        var candidates: [Date] = []
        for (meeting, state) in entries {
            let alertAt = meeting.start.addingTimeInterval(-config.leadTime)
            let lateAlertEnds = meeting.start.addingTimeInterval(config.lateAlertWindow)
            switch state {
            case .done:
                continue
            case .waiting:
                candidates += [alertAt, lateAlertEnds, meeting.end]
            case .snoozed(let until):
                candidates += [until, meeting.end]
            case .pill, .dismissed:
                candidates += [meeting.start, meeting.end]
            case .alert, .notesCard, .hidden:
                candidates.append(meeting.end)
            }
        }
        return candidates.filter { $0 > now }.min()
    }

    /// The earliest moment after `now` at which a full-screen alert may appear: a waiting
    /// meeting's alert time or the end of a snooze. Quiet mode is ignored, since it's checked
    /// only when the alert comes due. Entries must already be settled at `now`.
    public static func nextAlert(
        _ entries: [(meeting: Meeting, state: OverlayState)],
        now: Date,
        config: AlertConfig
    ) -> Date? {
        entries
            .compactMap { meeting, state -> Date? in
                switch state {
                case .waiting: meeting.start.addingTimeInterval(-config.leadTime)
                case .snoozed(let until): until
                default: nil
                }
            }
            .filter { $0 > now }
            .min()
    }
}
