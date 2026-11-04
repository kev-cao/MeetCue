import Foundation
import Testing
@testable import CalpanionCore

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
        let toggled = MarkdownTasks.toggle(note, line: 1)
        var expected = note.components(separatedBy: "\n")
        expected[1] = "- [x] Move staging backups"
        #expect(toggled == expected.joined(separator: "\n"))
        #expect(MarkdownTasks.toggle(toggled, line: 1) == note)
    }

    @Test func toggleIgnoresNonTaskLines() {
        #expect(MarkdownTasks.toggle(note, line: 0) == note)
        #expect(MarkdownTasks.toggle(note, line: 8) == note)
        #expect(MarkdownTasks.toggle(note, line: 99) == note)
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
        let toggled = MarkdownTasks.toggle(original, line: 0)
        #expect(toggled == "- [x] a\r\n- [x] b\r\n")
        #expect(MarkdownTasks.toggle(toggled, line: 0) == original)
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

    @Test func blockQuotedTasksAreNotItems() {
        #expect(MarkdownTasks.items(in: "> - [ ] x").isEmpty)
    }
}
