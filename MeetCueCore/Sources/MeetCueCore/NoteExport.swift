import Foundation

/// File names for exporting notes as Markdown files, `<yyyy-MM-dd> <title>.md` (spec 7.1).
public enum NoteExport {
    /// macOS file names hold at most 255 bytes of UTF-8; this leaves room for the date, a repeat
    /// number and the extension.
    static let maxTitleBytes = 200

    /// "2026-11-04 Team Sync", or "2026-11-04" when there's no title or nothing of it a file name
    /// can keep. Slashes and colons become dashes, line breaks and other control characters become
    /// spaces, runs of spaces collapse, and leading dots go so the file isn't hidden.
    public static func baseName(date: Date, title: String?, calendar: Calendar) -> String {
        let day = CarryOver.dayString(date, calendar: calendar)
        let cleaned = cleanTitle(title ?? "")
        return cleaned.isEmpty ? day : "\(day) \(cleaned)"
    }

    /// Adds ".md" to each base name, and " 2", " 3" and so on to repeats, so no two files share a
    /// name. Names are compared ignoring case, as the default APFS volume does.
    public static func fileNames(for baseNames: [String]) -> [String] {
        var used = Set<String>()
        return baseNames.map { base in
            var candidate = base
            var number = 2
            while used.contains(candidate.lowercased()) {
                candidate = "\(base) \(number)"
                number += 1
            }
            used.insert(candidate.lowercased())
            return candidate + ".md"
        }
    }

    static func cleanTitle(_ title: String) -> String {
        let replaced = String(title.map { character -> Character in
            if character == "/" || character == ":" { return "-" }
            if character.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) || CharacterSet.newlines.contains($0) }) {
                return " "
            }
            return character
        })
        var words = replaced.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        while words.hasPrefix(".") { words.removeFirst() }
        var kept = ""
        for character in words.trimmingCharacters(in: .whitespaces) {
            guard kept.utf8.count + String(character).utf8.count <= maxTitleBytes else { break }
            kept.append(character)
        }
        return kept.trimmingCharacters(in: .whitespaces)
    }
}
