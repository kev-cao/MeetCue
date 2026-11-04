import Foundation

public struct TaskItem: Equatable, Sendable {
    /// Zero-based line index in the note's text.
    public let line: Int
    public let text: String
    public let isChecked: Bool
    /// The `yyyy-MM-dd` date from a carried marker, if the item has one.
    public let carriedFrom: String?
}

public enum MarkdownTasks {
    /// GitHub-style task items (`- [ ]`, `* [x]`, `1. [ ]`, any indent), skipping fenced code blocks.
    /// An unclosed code fence runs to the end of the note, so later task lines aren't items.
    public static func items(in markdown: String) -> [TaskItem] {
        scan(markdown).items
    }

    /// Flips the checkbox on `line`. Returns the text unchanged unless that line is a task item whose
    /// text is `expectedText`, so a stale line number can't tick a different topic.
    public static func toggle(_ markdown: String, line index: Int, expectedText: String) -> String {
        guard items(in: markdown).contains(where: { $0.line == index && $0.text == expectedText }) else { return markdown }
        var lines = markdown.components(separatedBy: "\n")
        guard let parts = matchTask(lines[index]) else { return markdown }
        let mark = parts.mark == " " ? "x" : " "
        lines[index] = "\(parts.lead)\(mark)\(parts.close)\(parts.body)\(parts.eol)"
        return lines.joined(separator: "\n")
    }

    /// Adds `- [ ] topic` as a new last line.
    public static func appendTopic(_ topic: String, to markdown: String) -> String {
        let topic = topic
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !topic.isEmpty else { return markdown }
        return appending(["- [ ] \(topic)"], to: markdown)
    }

    static func carriedLine(_ text: String, from date: String) -> String {
        "- [ ] \(text) <!-- carried:\(date) -->"
    }

    static func appending(_ newLines: [String], to markdown: String) -> String {
        let eol = markdown.contains("\r\n") ? "\r\n" : "\n"
        var lines = newLines
        if let open = scan(markdown).openFence {
            lines.insert(String(repeating: open.character, count: open.length), at: 0)
        }
        let block = lines.joined(separator: eol)
        if markdown.isEmpty { return block }
        return markdown.utf8.last == UInt8(ascii: "\n") ? markdown + block : markdown + eol + block
    }

    private static func scan(_ markdown: String) -> (items: [TaskItem], openFence: Fence?) {
        var result: [TaskItem] = []
        var openFence: Fence?
        for (index, line) in markdown.components(separatedBy: "\n").enumerated() {
            if let open = openFence {
                if let candidate = fence(in: line), candidate.closes(open) { openFence = nil }
                continue
            }
            if let opening = fence(in: line) {
                openFence = opening
                continue
            }
            guard let parts = matchTask(line) else { continue }
            let (text, carriedFrom) = splitMarker(String(parts.body))
            guard !text.isEmpty else { continue }
            result.append(TaskItem(line: index, text: text, isChecked: parts.mark != " ", carriedFrom: carriedFrom))
        }
        return (result, openFence)
    }

    private struct Fence {
        let character: Character
        let length: Int
        let hasOnlyWhitespaceAfterRun: Bool

        func closes(_ open: Fence) -> Bool {
            character == open.character && length >= open.length && hasOnlyWhitespaceAfterRun
        }
    }

    private static func fence(in line: String) -> Fence? {
        guard let match = line.wholeMatch(of: /(?<indent> {0,3})(?<run>`{3,}|~{3,})(?<rest>[^\r]*)\r?/),
              let character = match.output.run.first else { return nil }
        let rest = match.output.rest
        if character == "`" && rest.contains("`") { return nil }
        return Fence(
            character: character,
            length: match.output.run.count,
            hasOnlyWhitespaceAfterRun: rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }

    private static func matchTask(_ line: String) -> (lead: Substring, mark: Substring, close: Substring, body: Substring, eol: Substring)? {
        guard let match = line.wholeMatch(of: /(?<lead>\s*(?:[-*+]|\d+[.)])[ \t]+\[)(?<mark>[ xX])(?<close>\][ \t]+)(?<body>.*?)(?<eol>\r?)/) else {
            return nil
        }
        return (match.output.lead, match.output.mark, match.output.close, match.output.body, match.output.eol)
    }

    private static func splitMarker(_ body: String) -> (text: String, carriedFrom: String?) {
        guard let match = body.firstMatch(of: /\s*<!--\s*carried:(?<value>(?:(?!-->).)*?)\s*-->\s*$/) else {
            return (body.trimmingCharacters(in: .whitespaces), nil)
        }
        let text = String(body[..<match.range.lowerBound]).trimmingCharacters(in: .whitespaces)
        return (text, validDate(String(match.output.value)))
    }

    private static func validDate(_ value: String) -> String? {
        guard let parts = value.wholeMatch(of: /(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})/),
              let year = Int(parts.output.year), let month = Int(parts.output.month), let day = Int(parts.output.day)
        else { return nil }
        let components = DateComponents(calendar: Calendar(identifier: .gregorian), year: year, month: month, day: day)
        return components.isValidDate ? value : nil
    }
}
