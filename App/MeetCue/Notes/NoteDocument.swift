import Foundation
import Markdown
import MeetCueCore

/// One block of a rendered note. Lists are flattened, so every item is its own block with a depth.
struct NoteBlock: Equatable, Identifiable {
    enum Kind: Equatable {
        case heading(level: Int)
        case paragraph
        /// A task item `MarkdownTasks` found on `line`, so its checkbox can be ticked. `source` is the
        /// item's Markdown text, which `MarkdownTasks.toggle` checks before ticking.
        case task(line: Int, source: String, isChecked: Bool, carriedFrom: String?)
        /// A checkbox that `MarkdownTasks` doesn't count as an item, such as one in a block quote.
        /// It's drawn but can't be ticked.
        case inertTask(isChecked: Bool)
        case bullet(marker: String)
        case code
        case rule
    }

    let id: Int
    let kind: Kind
    let text: AttributedString
    /// List nesting depth, 0 outside lists.
    let depth: Int
    let isQuoted: Bool

    var plainText: String { String(text.characters) }
}

/// Parses a note with swift-markdown into blocks for the notes card and the inspector's Preview.
/// Which checkboxes are live comes from `MarkdownTasks.items` line numbers, because swift-markdown
/// and `MarkdownTasks` can disagree, for example on fences indented inside list items. A lone
/// carriage return is a line break to swift-markdown but not to `MarkdownTasks`, so notes with one
/// have no live checkboxes.
enum NoteDocument {
    static func blocks(from markdown: String) -> [NoteBlock] {
        let items = hasLoneCarriageReturn(markdown) ? [] : MarkdownTasks.items(in: markdown)
        var builder = Builder(items: Dictionary(items.map { ($0.line, $0) }, uniquingKeysWith: { first, _ in first }))
        for child in Document(parsing: markdown).children {
            builder.visit(child, depth: 0, quoted: false)
        }
        return builder.blocks
    }

    private static func hasLoneCarriageReturn(_ markdown: String) -> Bool {
        let bytes = Array(markdown.utf8)
        return bytes.indices.contains { bytes[$0] == UInt8(ascii: "\r") && (bytes.indices.contains($0 + 1) ? bytes[$0 + 1] != UInt8(ascii: "\n") : true) }
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// "Carried over from Nov 3" for a marker date in `yyyy-MM-dd` form.
    static func carriedLabel(_ date: String, locale: Locale = .autoupdatingCurrent) -> String {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        let calendar = utc
        guard parts.count == 3,
              let day = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return "Carried over" }
        let style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .month(.abbreviated)
            .day()
        return "Carried over from \(day.formatted(style))"
    }

    /// The `<!-- carried:… -->` markers, which the Markdown editor dims.
    static func carriedMarkerRanges(in markdown: String) -> [NSRange] {
        markdown.ranges(of: /<!--\s*carried:(?:(?!-->).)*-->/).map { NSRange($0, in: markdown) }
    }

    private struct Builder {
        let items: [Int: TaskItem]
        var blocks: [NoteBlock] = []

        mutating func visit(_ markup: Markup, depth: Int, quoted: Bool) {
            switch markup {
            case let heading as Heading:
                append(.heading(level: heading.level), inline(heading), depth: depth, quoted: quoted)
            case let paragraph as Paragraph:
                append(.paragraph, inline(paragraph), depth: depth, quoted: quoted)
            case let list as UnorderedList:
                for item in list.listItems {
                    visitItem(item, marker: "•", depth: depth, quoted: quoted)
                }
            case let list as OrderedList:
                for (offset, item) in list.listItems.enumerated() {
                    visitItem(item, marker: "\(Int(list.startIndex) + offset).", depth: depth, quoted: quoted)
                }
            case let quote as BlockQuote:
                for child in quote.children {
                    visit(child, depth: depth, quoted: true)
                }
            case let code as CodeBlock:
                var text = code.code
                if text.hasSuffix("\n") { text.removeLast() }
                append(.code, AttributedString(text), depth: depth, quoted: quoted)
            case is ThematicBreak:
                append(.rule, AttributedString(), depth: depth, quoted: quoted)
            case let html as HTMLBlock:
                let raw = html.rawHTML.trimmingCharacters(in: .whitespacesAndNewlines)
                if !Self.isComment(raw) {
                    append(.paragraph, AttributedString(raw), depth: depth, quoted: quoted)
                }
            case let table as Table:
                let rows = [Array(table.head.cells)] + table.body.rows.map { Array($0.cells) }
                for row in rows {
                    append(.paragraph, AttributedString(row.map(\.plainText).joined(separator: "  |  ")), depth: depth, quoted: quoted)
                }
            default:
                for child in markup.children {
                    visit(child, depth: depth, quoted: quoted)
                }
            }
        }

        private mutating func visitItem(_ item: ListItem, marker: String, depth: Int, quoted: Bool) {
            let children = Array(item.children)
            let lead = children.first as? Paragraph
            let kind: NoteBlock.Kind
            if let checkbox = item.checkbox {
                let line = (item.range?.lowerBound.line ?? 0) - 1
                if let task = items[line] {
                    kind = .task(line: line, source: task.text, isChecked: task.isChecked, carriedFrom: task.carriedFrom)
                } else {
                    kind = .inertTask(isChecked: checkbox == .checked)
                }
            } else {
                kind = .bullet(marker: marker)
            }
            append(kind, lead.map(inline) ?? AttributedString(), depth: depth, quoted: quoted)
            for child in children.dropFirst(lead == nil ? 0 : 1) {
                visit(child, depth: depth + 1, quoted: quoted)
            }
        }

        /// HTML comments, which include carried markers, are hidden. Other HTML shows as typed.
        private static func isComment(_ html: String) -> Bool { html.hasPrefix("<!--") }

        /// Links to anything but web and mail addresses render as plain text.
        private static func safeURL(_ destination: String) -> URL? {
            guard let url = URL(string: destination), let scheme = url.scheme?.lowercased(),
                  ["http", "https", "mailto"].contains(scheme) else { return nil }
            return url
        }

        private mutating func append(_ kind: NoteBlock.Kind, _ text: AttributedString, depth: Int, quoted: Bool) {
            blocks.append(NoteBlock(id: blocks.count, kind: kind, text: text, depth: depth, isQuoted: quoted))
        }

        private func inline(_ markup: Markup) -> AttributedString {
            var text = AttributedString()
            for child in markup.children {
                text += inline(child, intent: [], link: nil)
            }
            while let last = text.characters.last, last.isWhitespace {
                text.characters.removeLast()
            }
            return text
        }

        private func inline(_ markup: Markup, intent: InlinePresentationIntent, link: URL?) -> AttributedString {
            func styled(_ string: String, _ extra: InlinePresentationIntent = []) -> AttributedString {
                var text = AttributedString(string)
                let combined = intent.union(extra)
                if !combined.isEmpty { text.inlinePresentationIntent = combined }
                if let link { text.link = link }
                return text
            }
            func children(_ extra: InlinePresentationIntent = [], link: URL? = link) -> AttributedString {
                markup.children.reduce(into: AttributedString()) { $0 += inline($1, intent: intent.union(extra), link: link) }
            }
            switch markup {
            case let text as Markdown.Text: return styled(text.string)
            case is SoftBreak: return styled(" ")
            case is LineBreak: return styled("\n")
            case let code as InlineCode: return styled(code.code, .code)
            case is Strong: return children(.stronglyEmphasized)
            case is Emphasis: return children(.emphasized)
            case is Strikethrough: return children(.strikethrough)
            case let anchor as Markdown.Link: return children(link: anchor.destination.flatMap(Self.safeURL) ?? link)
            case let html as InlineHTML: return Self.isComment(html.rawHTML) ? AttributedString() : styled(html.rawHTML)
            default: return styled((markup as? PlainTextConvertibleMarkup)?.plainText ?? "")
            }
        }
    }
}
