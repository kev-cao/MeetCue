import Foundation
import MeetCueCore

/// Moves unchecked topics from each ended occurrence of a recurring meeting to the next one
/// (spec 7.2). The alert scheduler runs it before every refresh of the overlays, which covers
/// launch, occurrences that ended while the app was closed, every meeting's end, and calendar
/// changes.
///
/// Topics carried into an occurrence that is deleted later move on once that occurrence's start
/// passes, because its note becomes a source like any other. An occurrence that can't be found
/// (deleted, declined or moved) may still be in progress, so its note is carried only once its
/// stored start is `missingOccurrenceDelay` past.
@MainActor
final class NoteCarrier {
    static let searchDays = 60
    static let missingOccurrenceDelay: TimeInterval = 12 * 60 * 60

    private let notes: NoteStore
    private let store: MeetingStore
    private let calendar: Calendar
    /// Occurrences already handled this session. One whose next occurrence wasn't found is tried
    /// again at the next launch.
    private var attempted: Set<String> = []

    init(notes: NoteStore, store: MeetingStore, calendar: Calendar = .autoupdatingCurrent) {
        self.notes = notes
        self.store = store
        self.calendar = calendar
    }

    /// Carries every pending note whose occurrence has ended by `now`. A target that has itself
    /// ended gets its turn in the same run, so topics reach the next occurrence still to come.
    func run(now: Date) {
        guard store.access == .granted else { return }
        let pending = notes.pendingCarryOvers(startedBefore: now)
        guard let earliest = pending.first, let latest = pending.last else { return }
        // Notes created during the run start before `now`, so `now` bounds every later search.
        let from = calendar.date(byAdding: .day, value: -1, to: earliest.occurrenceStart)!
        let to = calendar.date(byAdding: .day, value: Self.searchDays, to: max(latest.occurrenceStart, now))!
        // Declined occurrences are skipped, so topics go to one I'll attend.
        let all = store.meetings(from: from, to: to, filter: CalendarFilter())
        var waiting: Set<String> = []
        while let source = notes.pendingCarryOvers(startedBefore: now)
            .first(where: { !attempted.contains($0.occurrenceID) && !waiting.contains($0.occurrenceID) })
        {
            let searchEnd = calendar.date(byAdding: .day, value: Self.searchDays, to: source.occurrenceStart)!
            let meetings = all.filter { $0.start < searchEnd }
            let occurrence = meetings.first { $0.id.storageKey == source.occurrenceID }
            let stillRunning = occurrence.map { $0.end > now }
                ?? (now < source.occurrenceStart.addingTimeInterval(Self.missingOccurrenceDelay))
            if stillRunning {
                waiting.insert(source.occurrenceID)
                continue
            }
            attempted.insert(source.occurrenceID)
            let start = occurrence?.start ?? source.occurrenceStart
            let anchor = occurrence ?? Meeting(
                id: OccurrenceID(seriesKey: source.seriesKey, originalDate: start),
                title: "",
                start: start,
                end: start,
                calendarID: ""
            )
            if let next = CarryOver.nextOccurrence(after: anchor, in: meetings) {
                notes.carry(source, into: next, calendar: calendar)
            } else if searchEnd <= now {
                // No occurrence came within the search window, and none can be added to it any more.
                notes.markCarriedForward(source)
            }
        }
    }
}
