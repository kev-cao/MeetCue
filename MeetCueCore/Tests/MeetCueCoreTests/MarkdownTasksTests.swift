import Foundation
import Testing
@testable import MeetCueCore

struct MarkdownTasksTests {
    let note = """
    ### Topics
    - [ ] Move staging backups
    - [x] Review alert thresholds
      * [X] Nested item
    1. [ ] Numbered item
    - plain bullet

    ```
    - [ ] inside a code block
    ```
    """

    @Test func findsTaskItemsOutsideCodeBlocks() {
        let items = MarkdownTasks.items(in: note)
        #expect(items.map(\.text) == ["Move staging backups", "Review alert thresholds", "Nested item", "Numbered item"])
        #expect(items.map(\.isChecked) == [false, true, true, false])
        #expect(items.map(\.line) == [1, 2, 3, 4])
    }

    @Test func readsAndStripsCarriedMarker() {
        let items = MarkdownTasks.items(in: "- [ ] Move staging backups <!-- carried:2026-10-28 -->")
        #expect(items.first?.text == "Move staging backups")
        #expect(items.first?.carriedFrom == "2026-10-28")
    }

    @Test func toggleChangesOnlyThatLine() {
        let toggled = MarkdownTasks.toggle(note, line: 1, expectedText: "Move staging backups")
        var expected = note.components(separatedBy: "\n")
        expected[1] = "- [x] Move staging backups"
        #expect(toggled == expected.joined(separator: "\n"))
        #expect(MarkdownTasks.toggle(toggled, line: 1, expectedText: "Move staging backups") == note)
    }

    @Test func toggleIgnoresNonTaskLines() {
        #expect(MarkdownTasks.toggle(note, line: 0, expectedText: "Topics") == note)
        #expect(MarkdownTasks.toggle(note, line: 8, expectedText: "inside a code block") == note)
        #expect(MarkdownTasks.toggle(note, line: 99, expectedText: "Topics") == note)
    }

    @Test func toggleRequiresTheExpectedText() {
        #expect(MarkdownTasks.toggle(note, line: 1, expectedText: "Review alert thresholds") == note)
        #expect(MarkdownTasks.toggle("- [ ] a <!-- carried:2026-10-28 -->", line: 0, expectedText: "a") == "- [x] a <!-- carried:2026-10-28 -->")
    }

    @Test func appendTopic() {
        #expect(MarkdownTasks.appendTopic("Ask about Q1", to: "") == "- [ ] Ask about Q1")
        #expect(MarkdownTasks.appendTopic("Ask about Q1", to: "Intro\n") == "Intro\n- [ ] Ask about Q1")
        #expect(MarkdownTasks.appendTopic("Ask about Q1", to: "Intro") == "Intro\n- [ ] Ask about Q1")
        #expect(MarkdownTasks.appendTopic("  two\nlines  ", to: "") == "- [ ] two lines")
        #expect(MarkdownTasks.appendTopic("   ", to: "Intro") == "Intro")
    }

    @Test func crlfNotesHaveItems() {
        let items = MarkdownTasks.items(in: "- [ ] a\r\n- [x] b\r\n")
        #expect(items.map(\.text) == ["a", "b"])
        #expect(items.map(\.isChecked) == [false, true])
    }

    @Test func crlfToggleRoundTrips() {
        let original = "- [ ] a\r\n- [x] b\r\n"
        let toggled = MarkdownTasks.toggle(original, line: 0, expectedText: "a")
        #expect(toggled == "- [x] a\r\n- [x] b\r\n")
        #expect(MarkdownTasks.toggle(toggled, line: 0, expectedText: "a") == original)
    }

    @Test func tildeLineInsideBacktickFenceDoesNotClose() {
        let items = MarkdownTasks.items(in: "```\n~~~\n- [ ] a\n```\n- [ ] b")
        #expect(items.map(\.text) == ["b"])
    }

    @Test func shorterFenceDoesNotClose() {
        let items = MarkdownTasks.items(in: "````\n```\n- [ ] a\n````\n- [ ] b")
        #expect(items.map(\.text) == ["b"])
    }

    @Test func inlineBackticksAreNotAFence() {
        let items = MarkdownTasks.items(in: "text ```code``` more\n- [ ] a")
        #expect(items.map(\.text) == ["a"])
    }

    @Test func tildeFenceWithInfoString() {
        let items = MarkdownTasks.items(in: "~~~ notes\n- [ ] hidden\n~~~\n- [ ] shown")
        #expect(items.map(\.text) == ["shown"])
    }

    @Test func unclosedFenceHidesTheRest() {
        #expect(MarkdownTasks.items(in: "```\n- [ ] a\n- [ ] b").isEmpty)
    }

    @Test func emptyTaskTextIsNotAnItem() {
        let items = MarkdownTasks.items(in: "- [ ] \n- [ ] real")
        #expect(items.map(\.text) == ["real"])
    }

    @Test func unicodeSpacesAroundTheCheckboxAreNotItems() {
        #expect(MarkdownTasks.items(in: "-\u{00A0}[ ] a").isEmpty)
        #expect(MarkdownTasks.items(in: "- [ ]\u{00A0}a").isEmpty)
        #expect(MarkdownTasks.items(in: "- [ ]\ta").map(\.text) == ["a"])
    }

    @Test func checkboxAtEndOfLineIsNotAnItem() {
        #expect(MarkdownTasks.items(in: "- [ ]").isEmpty)
        #expect(MarkdownTasks.items(in: "- [ ]\r\n- [ ] b").map(\.text) == ["b"])
    }

    @Test func blockQuotedTasksAreNotItems() {
        #expect(MarkdownTasks.items(in: "> - [ ] x").isEmpty)
    }

    @Test func appendTopicKeepsCRLF() {
        #expect(MarkdownTasks.appendTopic("Q1", to: "Intro\r\n") == "Intro\r\n- [ ] Q1")
        #expect(MarkdownTasks.appendTopic("Q1", to: "Intro\r\nMore") == "Intro\r\nMore\r\n- [ ] Q1")
    }

    @Test func malformedMarkerIsStripped() {
        let item = MarkdownTasks.items(in: "- [ ] Topic <!-- carried:2026-1-4 -->").first
        #expect(item?.text == "Topic")
        #expect(item?.carriedFrom == nil)
    }

    @Test func appendTopicClosesAnOpenFence() {
        let result = MarkdownTasks.appendTopic("Ask Q1", to: "Notes\n```\ncode")
        #expect(result == "Notes\n```\ncode\n```\n- [ ] Ask Q1")
        #expect(MarkdownTasks.items(in: result).map(\.text) == ["Ask Q1"])
    }

    @Test func appendTopicFlattensAllLineBreaks() {
        for topic in ["a\r\nb", "a\rb", "a\u{2028}b"] {
            #expect(MarkdownTasks.appendTopic(topic, to: "") == "- [ ] a b")
        }
    }
}
