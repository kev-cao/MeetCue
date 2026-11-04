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
    public static func items(in markdown: String) -> [TaskItem] {
        var result: [TaskItem] = []
        var inFence = false
        for (index, line) in markdown.components(separatedBy: "\n").enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                continue
            }
            guard !inFence, let parts = matchTask(line) else { continue }
            let (text, carriedFrom) = splitMarker(String(parts.body))
            result.append(TaskItem(line: index, text: text, isChecked: parts.mark != " ", carriedFrom: carriedFrom))
        }
        return result
    }

    /// Flips the checkbox on `line`. Returns the text unchanged if that line isn't a task item.
    public static func toggle(_ markdown: String, line index: Int) -> String {
        guard items(in: markdown).contains(where: { $0.line == index }) else { return markdown }
        var lines = markdown.components(separatedBy: "\n")
        guard let parts = matchTask(lines[index]) else { return markdown }
        let mark = parts.mark == " " ? "x" : " "
        lines[index] = "\(parts.lead)\(mark)\(parts.close)\(parts.body)"
        return lines.joined(separator: "\n")
    }

    /// Adds `- [ ] topic` as a new last line.
    public static func appendTopic(_ topic: String, to markdown: String) -> String {
        let topic = topic
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !topic.isEmpty else { return markdown }
        return appending(["- [ ] \(topic)"], to: markdown)
    }

    static func appending(_ newLines: [String], to markdown: String) -> String {
        let block = newLines.joined(separator: "\n")
        if markdown.isEmpty { return block }
        return markdown.hasSuffix("\n") ? markdown + block : markdown + "\n" + block
    }

    private static func matchTask(_ line: String) -> (lead: Substring, mark: Substring, close: Substring, body: Substring)? {
        guard let match = line.wholeMatch(of: /(?<lead>\s*(?:[-*+]|\d+[.)])\s+\[)(?<mark>[ xX])(?<close>\]\s+)(?<body>.*)/) else {
            return nil
        }
        return (match.output.lead, match.output.mark, match.output.close, match.output.body)
    }

    private static func splitMarker(_ body: String) -> (text: String, carriedFrom: String?) {
        guard let match = body.firstMatch(of: /\s*<!--\s*carried:(?<date>\d{4}-\d{2}-\d{2})\s*-->\s*$/) else {
            return (body.trimmingCharacters(in: .whitespaces), nil)
        }
        let text = String(body[..<match.range.lowerBound]).trimmingCharacters(in: .whitespaces)
        return (text, String(match.output.date))
    }
}
