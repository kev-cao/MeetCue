import Foundation
import MeetCueCore

enum CalendarAccess: Equatable {
    case notDetermined
    case granted
    case denied
}

/// A calendar as the calendar window's sidebar lists it.
struct CalendarInfo: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    /// The account the calendar belongs to, such as "iCloud" or an email address.
    let account: String
    let color: CalendarColor
}

/// An sRGB color, so calendar colors stay `Sendable` and comparable.
struct CalendarColor: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    static let gray = CalendarColor(red: 0.56, green: 0.56, blue: 0.58)
}

@MainActor
protocol CalendarSource: AnyObject {
    var access: CalendarAccess { get }
    /// Called whenever the underlying calendars change.
    var onChange: (@MainActor () -> Void)? { get set }
    func requestAccess() async -> CalendarAccess
    func events(from start: Date, to end: Date) -> [EventSnapshot]
    func calendars() -> [CalendarInfo]
}
