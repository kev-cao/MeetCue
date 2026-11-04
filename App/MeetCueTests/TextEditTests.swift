import Foundation
import Testing
@testable import MeetCue

struct TextEditTests {
    @Test func identicalTextsHaveNoChange() {
        #expect(TextEdit.minimalChange(from: "abc", to: "abc") == nil)
        #expect(TextEdit.minimalChange(from: "", to: "") == nil)
    }

    @Test func aTickedCheckboxChangesOneCharacter() {
        let change = TextEdit.minimalChange(from: "- [ ] Budget\n- [ ] Hiring", to: "- [x] Budget\n- [ ] Hiring")
        #expect(change == TextEdit.Change(range: NSRange(location: 3, length: 1), replacement: "x"))
    }

    @Test func anAppendedTopicIsAnInsertionAtTheEnd() {
        let change = TextEdit.minimalChange(from: "- [ ] A", to: "- [ ] A\n- [ ] B")
        #expect(change == TextEdit.Change(range: NSRange(location: 7, length: 0), replacement: "\n- [ ] B"))
    }

    @Test func aDeletionHasAnEmptyReplacement() {
        let change = TextEdit.minimalChange(from: "one two three", to: "one three")
        #expect(change == TextEdit.Change(range: NSRange(location: 5, length: 4), replacement: ""))
    }

    @Test func replacingEverythingCoversTheWholeText() {
        let change = TextEdit.minimalChange(from: "abc", to: "xyz")
        #expect(change == TextEdit.Change(range: NSRange(location: 0, length: 3), replacement: "xyz"))
    }

    @Test func repeatedCharactersDoNotOverlapThePrefixAndSuffix() {
        let change = TextEdit.minimalChange(from: "aa", to: "aaa")
        let applied = apply(change, to: "aa")
        #expect(applied == "aaa")
    }

    @Test func aChangeNeverSplitsASurrogatePair() throws {
        let change = try #require(TextEdit.minimalChange(from: "a\u{1F600}b", to: "a\u{1F601}b"))
        #expect(change == TextEdit.Change(range: NSRange(location: 1, length: 2), replacement: "\u{1F601}"))
    }

    @Test func applyingTheChangeProducesTheNewText() {
        let pairs = [("", "x"), ("x", ""), ("hello world", "hello brave new world"), ("a\u{1F600}", "a\u{1F600}\u{1F600}"), ("é", "e\u{301}")]
        for (old, new) in pairs {
            #expect(apply(TextEdit.minimalChange(from: old, to: new), to: old) == new)
        }
    }

    @Test func aCaretBeforeTheChangeStaysPut() {
        let change = TextEdit.Change(range: NSRange(location: 10, length: 1), replacement: "x")
        #expect(TextEdit.selection(NSRange(location: 4, length: 0), through: change, newLength: 30) == NSRange(location: 4, length: 0))
    }

    @Test func aCaretAfterTheChangeShiftsWithIt() {
        let change = TextEdit.Change(range: NSRange(location: 2, length: 0), replacement: "abc")
        #expect(TextEdit.selection(NSRange(location: 5, length: 0), through: change, newLength: 30) == NSRange(location: 8, length: 0))
    }

    @Test func aSelectionInsideTheChangeMovesToItsEnd() {
        let change = TextEdit.Change(range: NSRange(location: 2, length: 6), replacement: "ab")
        #expect(TextEdit.selection(NSRange(location: 4, length: 2), through: change, newLength: 30) == NSRange(location: 4, length: 0))
    }

    @Test func aSelectionSpanningTheChangeKeepsBothEnds() {
        let change = TextEdit.Change(range: NSRange(location: 5, length: 1), replacement: "xy")
        #expect(TextEdit.selection(NSRange(location: 2, length: 10), through: change, newLength: 30) == NSRange(location: 2, length: 11))
    }

    @Test func aSelectionIsClampedToTheNewLength() {
        let change = TextEdit.Change(range: NSRange(location: 0, length: 20), replacement: "")
        #expect(TextEdit.selection(NSRange(location: 15, length: 3), through: change, newLength: 4) == NSRange(location: 0, length: 0))
        #expect(TextEdit.clamped(NSRange(location: 3, length: 10), toLength: 5) == NSRange(location: 3, length: 2))
        #expect(TextEdit.clamped(NSRange(location: 9, length: 2), toLength: 5) == NSRange(location: 5, length: 0))
    }

    private func apply(_ change: TextEdit.Change?, to text: String) -> String {
        guard let change else { return text }
        return (text as NSString).replacingCharacters(in: change.range, with: change.replacement)
    }
}
