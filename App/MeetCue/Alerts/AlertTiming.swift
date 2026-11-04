import Foundation
import MeetCueCore

/// When alerts appear and how long they wait. `AppSettings` sets the lead time and snooze length.
struct AlertTiming: Equatable {
    var leadTime: TimeInterval = 120
    /// How long after start a missed alert still appears, e.g. after waking the Mac.
    var lateAlertWindow: TimeInterval = 300
    var snoozeLength: TimeInterval = 60
    /// How long the pill shows meetings that left the calendar.
    var cancelNoticeDuration: TimeInterval = 5
    /// How long before an alert the app holds a `ProcessInfo` activity, so App Nap can't delay the timer.
    var activityLeadTime: TimeInterval = 300

    static let standard = AlertTiming()

    func config(quietUntil: Date?) -> AlertConfig {
        AlertConfig(leadTime: leadTime, lateAlertWindow: lateAlertWindow, quietUntil: quietUntil)
    }
}
