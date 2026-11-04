import Foundation
import MeetCueCore
@testable import MeetCue

enum AppFixtures {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    /// A wall-clock time in New York, on Wednesday Nov 4 2026 unless given.
    static func at(_ hour: Int, _ minute: Int, day: Int = 4) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    static func event(
        _ title: String = "Team Sync",
        start: Date,
        minutes: Int = 30,
        series: String = "series-1",
        status: RSVP = .accepted,
        location: String? = nil
    ) -> EventSnapshot {
        EventSnapshot(
            seriesKey: series,
            title: title,
            start: start,
            end: start.addingTimeInterval(TimeInterval(minutes * 60)),
            location: location,
            calendarID: "work",
            myStatus: status
        )
    }
}

/// UserDefaults in a suite of its own, removed when the test that holds it ends.
final class TestDefaults {
    let defaults: UserDefaults
    private let suiteName = "MeetCueTests-\(UUID().uuidString)"

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
final class FakeCalendarSource: CalendarSource {
    var access: CalendarAccess = .granted
    var accessAfterRequest: CalendarAccess = .granted
    var snapshots: [EventSnapshot] = []
    var onChange: (@MainActor () -> Void)?
    private(set) var requestedRange: (start: Date, end: Date)?

    func requestAccess() async -> CalendarAccess {
        access = accessAfterRequest
        return access
    }

    func events(from start: Date, to end: Date) -> [EventSnapshot] {
        requestedRange = (start, end)
        return snapshots.filter { $0.start < end && $0.end > start }
    }
}
