import Foundation
import Testing
@testable import MeetCue

struct NoteDocumentTests {
    @Test func liveCheckboxesComeFromTaskLines() {
        let blocks = NoteDocument.blocks(from: """
        ## Agenda
        - [ ] Budget <!-- carried:2026-11-03 -->
        - [x] Hiring plan
          - [ ] Offsite dates
        - [ ] <!-- carried:2026-11-03 -->
        > - [ ] Quoted, not a topic
        """)
        #expect(blocks.map(\.kind) == [
            .heading(level: 2),
            .task(line: 1, source: "Budget", isChecked: false, carriedFrom: "2026-11-03"),
            .task(line: 2, source: "Hiring plan", isChecked: true, carriedFrom: nil),
            .task(line: 3, source: "Offsite dates", isChecked: false, carriedFrom: nil),
            .inertTask(isChecked: false),
            .bullet(marker: "•"),
        ])
        #expect(blocks.map(\.plainText) == ["Agenda", "Budget", "Hiring plan", "Offsite dates", "", "[ ] Quoted, not a topic"])
        #expect(blocks.map(\.depth) == [0, 0, 0, 1, 0, 0])
        #expect(blocks.map(\.isQuoted) == [false, false, false, false, false, true])
    }

    @Test func taskLinesInsideFencesAreCode() {
        let blocks = NoteDocument.blocks(from: "```\n- [ ] not a task\n```\n1. First\n2. Second")
        #expect(blocks.map(\.kind) == [.code, .bullet(marker: "1."), .bullet(marker: "2.")])
        #expect(blocks[0].plainText == "- [ ] not a task")
    }

    @Test func crlfNotesKeepTheirLineNumbers() {
        let blocks = NoteDocument.blocks(from: "Intro\r\n\r\n- [ ] Budget\r\n")
        #expect(blocks.map(\.kind) == [.paragraph, .task(line: 2, source: "Budget", isChecked: false, carriedFrom: nil)])
    }

    @Test func inlineStylesAndLinks() throws {
        let blocks = NoteDocument.blocks(from: "Read **the doc** at [the wiki](https://wiki.example.com), `code` and *this*.")
        let text = try #require(blocks.first?.text)
        #expect(String(text.characters) == "Read the doc at the wiki, code and this.")
        let runs = text.runs.map { (String(text[$0.range].characters), $0.inlinePresentationIntent, $0.link) }
        #expect(runs.contains { $0.0 == "the doc" && $0.1 == .stronglyEmphasized })
        #expect(runs.contains { $0.0 == "the wiki" && $0.2 == URL(string: "https://wiki.example.com") })
        #expect(runs.contains { $0.0 == "code" && $0.1 == .code })
        #expect(runs.contains { $0.0 == "this" && $0.1 == .emphasized })
    }

    @Test func taskSourceKeepsTheMarkdownText() {
        let blocks = NoteDocument.blocks(from: "- [ ] **Budget** review")
        #expect(blocks.map(\.kind) == [.task(line: 0, source: "**Budget** review", isChecked: false, carriedFrom: nil)])
        #expect(blocks[0].plainText == "Budget review")
    }

    @Test func onlyWebAndMailLinksStayLinks() throws {
        let markdown = "[a](javascript:alert(1)) [b](file:///etc/passwd) [c](relative/path) [d](https://x.example) [e](MAILTO:me@x.example) [f](HTTP://y.example)"
        let text = try #require(NoteDocument.blocks(from: markdown).first?.text)
        let links = text.runs.compactMap { run in run.link.map { (String(text[run.range].characters), $0.scheme?.lowercased()) } }
        #expect(links.map(\.0) == ["d", "e", "f"])
        #expect(links.map(\.1) == ["https", "mailto", "http"])
        #expect(String(text.characters) == "a b c d e f")
    }

    @Test func htmlLikeTextIsShownAndCommentsAreHidden() {
        let blocks = NoteDocument.blocks(from: "Ask <Alice> about budget <!-- note -->\n\n<!-- hidden -->\n\n<div>raw</div>")
        #expect(blocks.map(\.plainText) == ["Ask <Alice> about budget", "<div>raw</div>"])
    }

    @Test func aLoneCarriageReturnMakesCheckboxesInert() {
        let blocks = NoteDocument.blocks(from: "Intro\rmore\n\n- [ ] a\n- [ ] b")
        #expect(blocks.map(\.kind) == [.paragraph, .inertTask(isChecked: false), .inertTask(isChecked: false)])
        #expect(blocks.map(\.plainText) == ["Intro more", "a", "b"])
    }

    @Test func carriedLabelReadsTheDate() {
        #expect(NoteDocument.carriedLabel("2026-11-03", locale: Locale(identifier: "en_US")) == "Carried over from Nov 3")
        #expect(NoteDocument.carriedLabel("soon", locale: Locale(identifier: "en_US")) == "Carried over")
    }

    @Test func findsCarriedMarkersToDim() {
        let markdown = "- [ ] Budget <!-- carried:2026-11-03 -->\n- [ ] Hiring <!--carried:2026-10-27-->"
        let ranges = NoteDocument.carriedMarkerRanges(in: markdown).map { (markdown as NSString).substring(with: $0) }
        #expect(ranges == ["<!-- carried:2026-11-03 -->", "<!--carried:2026-10-27-->"])
    }
}
