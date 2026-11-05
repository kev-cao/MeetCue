import Foundation
import MeetCueCore

/// Writes every note with text to a folder as a Markdown file named `<yyyy-MM-dd> <title>.md`,
/// with the meeting's title, time and calendar at the top (spec 7.1). Titles come from the
/// calendars, so a note whose meeting is gone is named by its date alone and has no heading.
/// Files of the same name in the folder are replaced.
@MainActor
struct NoteExporter {
    let notes: NoteStore
    let store: MeetingStore
    var calendar: Calendar = .autoupdatingCurrent
    var locale: Locale = .autoupdatingCurrent

    struct Result: Equatable {
        struct Failure: Equatable {
            let fileName: String
            let reason: String
        }

        var written = 0
        var failures: [Failure] = []
        var total: Int { written + failures.count }
    }

    /// Writes every file it can; a file that fails to write is reported in the result and doesn't stop the rest.
    func export(to folder: URL) -> Result {
        let exported = notes.notes.values
            .filter { !$0.markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { ($0.occurrenceStart, $0.occurrenceID) < ($1.occurrenceStart, $1.occurrenceID) }
        guard let first = exported.first, let last = exported.last else { return Result() }
        let meetings = meetings(
            from: calendar.date(byAdding: .day, value: -1, to: first.occurrenceStart)!,
            to: calendar.date(byAdding: .day, value: NoteCarrier.searchDays, to: last.occurrenceStart)!
        )
        let names = NoteExport.fileNames(for: exported.map { note in
            let meeting = meetings[note.occurrenceID]
            return NoteExport.baseName(date: meeting?.start ?? note.occurrenceStart, title: meeting?.title, calendar: calendar)
        })
        var result = Result()
        for (note, name) in zip(exported, names) {
            var text = (meetings[note.occurrenceID].map(header) ?? "") + note.markdown
            if !text.hasSuffix("\n") { text += "\n" }
            do {
                try Data(text.utf8).write(to: folder.appendingPathComponent(name), options: .atomic)
                result.written += 1
            } catch {
                result.failures.append(Result.Failure(fileName: name, reason: error.localizedDescription))
            }
        }
        return result
    }

    /// Meetings by storage key, from every calendar, declined ones included. EventKit reads at most
    /// four years per query, so this reads a year at a time.
    private func meetings(from start: Date, to end: Date) -> [String: Meeting] {
        var found: [String: Meeting] = [:]
        var from = start
        while from < end {
            let to = min(end, calendar.date(byAdding: .year, value: 1, to: from)!)
            for meeting in store.meetings(from: from, to: to, filter: CalendarFilter(skipDeclined: false)) where found[meeting.id.storageKey] == nil {
                found[meeting.id.storageKey] = meeting
            }
            from = to
        }
        return found
    }

    /// "# Team Sync", then "Wednesday, November 4, 2026 · 2:30 – 3:00 PM · Work".
    private func header(for meeting: Meeting) -> String {
        var style = Date.FormatStyle().weekday(.wide).month(.wide).day().year()
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        style.locale = locale
        let time = meeting.isAllDay
            ? "All day"
            : MenuBarText.timeRange(meeting.start, meeting.end, calendar: calendar, uses24Hour: ClockStyle.uses24Hour(locale))
        let calendarTitle = store.calendars.first { $0.id == meeting.calendarID }?.title
        let line = [meeting.start.formatted(style), time, calendarTitle].compactMap { $0 }.joined(separator: " · ")
        return "# \(meeting.title)\n\n\(line)\n\n"
    }
}
