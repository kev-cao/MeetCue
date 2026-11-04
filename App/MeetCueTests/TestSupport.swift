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
    static func at(_ hour: Int, _ minute: Int, second: Int = 0, day: Int = 4) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
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

final class InMemoryQuietStorage: QuietStorage {
    var until: Date?
    var preset: String?
}

final class InMemoryDismissedAlertStorage: DismissedAlertStorage {
    var records: [String: Date] = [:]
}

@MainActor
final class FakeCalendarSource: CalendarSource {
    var access: CalendarAccess = .granted
    var accessAfterRequest: CalendarAccess = .granted
    var snapshots: [EventSnapshot] = []
    var calendarList: [CalendarInfo] = []
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

    func calendars() -> [CalendarInfo] { calendarList }
}

/// Fails the first `failures` saves, then saves into memory.
@MainActor
final class FlakyNoteRepository: NoteRepository {
    struct SaveFailed: Error {}

    var failures: Int
    private(set) var saved: [String: Note] = [:]
    private(set) var attempts = 0

    init(failures: Int = 0, notes: [Note] = []) {
        self.failures = failures
        saved = Dictionary(uniqueKeysWithValues: notes.map { ($0.occurrenceID, $0) })
    }

    func loadAll() throws -> [Note] { Array(saved.values) }

    func save(_ notes: [Note]) throws {
        attempts += 1
        if failures > 0 {
            failures -= 1
            throw SaveFailed()
        }
        for note in notes { saved[note.occurrenceID] = note }
    }
}

/// Polls `condition` until it holds or `timeout` passes.
@MainActor
func eventually(timeout: Duration = .seconds(2.5), _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}
