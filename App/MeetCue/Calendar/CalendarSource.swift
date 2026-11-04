import Foundation
import MeetCueCore

enum CalendarAccess: Equatable {
    case notDetermined
    case granted
    case denied
}

@MainActor
protocol CalendarSource: AnyObject {
    var access: CalendarAccess { get }
    /// Called whenever the underlying calendars change.
    var onChange: (@MainActor () -> Void)? { get set }
    func requestAccess() async -> CalendarAccess
    func events(from start: Date, to end: Date) -> [EventSnapshot]
}
