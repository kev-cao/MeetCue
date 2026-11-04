import Foundation

/// The alert's live clock: time left before start, or time elapsed since.
public struct Countdown: Equatable, Sendable {
    public let hasStarted: Bool
    /// "1:42", or "1:05:03" from an hour on.
    public let clock: String

    public init(hasStarted: Bool, clock: String) {
        self.hasStarted = hasStarted
        self.clock = clock
    }
}

public enum AlertText {
    /// Time left is rounded up, so the clock reads "0:01" until the start and "0:00" exactly at it.
    /// Time elapsed is rounded down.
    public static func countdown(to start: Date, now: Date) -> Countdown {
        let remaining = start.timeIntervalSince(now)
        if remaining > 0 {
            return Countdown(hasStarted: false, clock: clock(Int(remaining.rounded(.up))))
        }
        return Countdown(hasStarted: true, clock: clock(Int((-remaining).rounded(.down))))
    }

    /// The pill's second line: "Starts in 1:42 · Room 4B · Zoom", or "Started 0:42 ago".
    public static func pillLine(for meeting: Meeting, now: Date) -> String {
        let countdown = countdown(to: meeting.start, now: now)
        let when = countdown.hasStarted ? "Started \(countdown.clock) ago" : "Starts in \(countdown.clock)"
        return [when, meeting.placeLine].compactMap { $0 }.joined(separator: " · ")
    }

    /// How far the pill's ring has filled, from 0 at alert time to 1 at the start.
    public static func progress(toward start: Date, now: Date, leadTime: TimeInterval) -> Double {
        guard leadTime > 0 else { return now >= start ? 1 : 0 }
        let remaining = start.timeIntervalSince(now)
        return min(1, max(0, 1 - remaining / leadTime))
    }

    static func clock(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = seconds % 3600 / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
