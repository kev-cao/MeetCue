import Foundation

public enum CarryOver {
    /// Appends the source note's unchecked task items to the target note,
    /// skipping items whose text the target already has. Each added item gets
    /// a carried marker with its original date.
    public static func carry(from source: String, sourceDate: Date, into target: String, calendar: Calendar) -> String {
        var present = Set(MarkdownTasks.items(in: target).map { normalized($0.text) })
        var newLines: [String] = []
        for item in MarkdownTasks.items(in: source) where !item.isChecked {
            guard present.insert(normalized(item.text)).inserted else { continue }
            let date = item.carriedFrom ?? dayString(sourceDate, calendar: calendar)
            newLines.append(MarkdownTasks.carriedLine(item.text, from: date))
        }
        return newLines.isEmpty ? target : MarkdownTasks.appending(newLines, to: target)
    }

    /// The earliest later occurrence of the same recurring series.
    public static func nextOccurrence(after meeting: Meeting, in meetings: [Meeting]) -> Meeting? {
        guard meeting.isRecurring else { return nil }
        return meetings
            .filter { $0.id.seriesKey == meeting.id.seriesKey && $0.start > meeting.start }
            .min { $0.start < $1.start }
    }

    static func normalized(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func dayString(_ date: Date, calendar: Calendar) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
