import Foundation
import Testing
@testable import CalpanionCore

struct Transition: Sendable, CustomTestStringConvertible {
    let from: OverlayState
    let event: OverlayEvent
    let to: OverlayState
    var testDescription: String { "\(from) + \(event) → \(to)" }
}

struct OverlayReducerTests {
    static let snoozeEnd = Fixtures.at(14, 29)

    static let table: [Transition] = {
        let snoozeEnd = OverlayReducerTests.snoozeEnd
        return [
        Transition(from: .waiting, event: .alertTime(quiet: false), to: .alert),
        Transition(from: .waiting, event: .alertTime(quiet: true), to: .dismissed),
        Transition(from: .alert, event: .snooze(until: snoozeEnd), to: .snoozed(until: snoozeEnd)),
        Transition(from: .snoozed(until: snoozeEnd), event: .snoozeElapsed, to: .alert),
        Transition(from: .snoozed(until: snoozeEnd), event: .startTime, to: .alert),
        Transition(from: .alert, event: .moveToCorner, to: .pill),
        Transition(from: .pill, event: .expand, to: .alert),
        Transition(from: .alert, event: .dismiss(afterStart: false), to: .dismissed),
        Transition(from: .pill, event: .dismiss(afterStart: false), to: .dismissed),
        Transition(from: .alert, event: .dismiss(afterStart: true), to: .notesCard),
        Transition(from: .alert, event: .join, to: .notesCard),
        Transition(from: .waiting, event: .join, to: .notesCard),
        Transition(from: .dismissed, event: .startTime, to: .notesCard),
        Transition(from: .pill, event: .startTime, to: .notesCard),
        Transition(from: .waiting, event: .startTime, to: .notesCard),
        Transition(from: .alert, event: .startTime, to: .alert),
        Transition(from: .notesCard, event: .hide, to: .hidden),
        Transition(from: .hidden, event: .show, to: .notesCard),
        Transition(from: .notesCard, event: .meetingEnded, to: .done),
        Transition(from: .hidden, event: .meetingEnded, to: .done),
        Transition(from: .alert, event: .meetingEnded, to: .done),
        Transition(from: .done, event: .alertTime(quiet: false), to: .done),
        Transition(from: .waiting, event: .hide, to: .waiting),
        Transition(from: .snoozed(until: snoozeEnd), event: .join, to: .notesCard),
        Transition(from: .pill, event: .join, to: .notesCard),
        Transition(from: .dismissed, event: .join, to: .notesCard),
        Transition(from: .hidden, event: .join, to: .notesCard),
        Transition(from: .notesCard, event: .join, to: .notesCard),
        Transition(from: .pill, event: .dismiss(afterStart: true), to: .notesCard),
        Transition(from: .pill, event: .meetingEnded, to: .done),
        Transition(from: .done, event: .show, to: .notesCard),
        Transition(from: .notesCard, event: .alertTime(quiet: false), to: .notesCard),
        ]
    }()

    @Test(arguments: table)
    func transition(_ t: Transition) {
        #expect(OverlayReducer.reduce(t.from, t.event, notes: NotesPolicy(hasNotes: true)) == t.to)
    }

    @Test func noNotesSkipsTheCard() {
        let policy = NotesPolicy(hasNotes: false)
        #expect(OverlayReducer.reduce(.alert, .join, notes: policy) == .done)
        #expect(OverlayReducer.reduce(.dismissed, .startTime, notes: policy) == .done)
        #expect(OverlayReducer.reduce(.alert, .dismiss(afterStart: true), notes: policy) == .done)
        #expect(OverlayReducer.reduce(.done, .show, notes: policy) == .done)
    }

    @Test func cardWithoutNotesWhenNotRequired() {
        let policy = NotesPolicy(onlyWithNotes: false, hasNotes: false)
        #expect(OverlayReducer.reduce(.dismissed, .startTime, notes: policy) == .notesCard)
    }

    @Test func cardOffInSettings() {
        let policy = NotesPolicy(showAtStart: false, hasNotes: true)
        #expect(OverlayReducer.reduce(.dismissed, .startTime, notes: policy) == .done)
        #expect(OverlayReducer.reduce(.alert, .join, notes: policy) == .notesCard)
        #expect(OverlayReducer.reduce(.alert, .dismiss(afterStart: true), notes: policy) == .done)
    }

    @Test func cardStaysAfterEndWhenHideAtEndIsOff() {
        let policy = NotesPolicy(hideAtEnd: false, hasNotes: true)
        #expect(OverlayReducer.reduce(.notesCard, .meetingEnded, notes: policy) == .notesCard)
        #expect(OverlayReducer.reduce(.hidden, .meetingEnded, notes: policy) == .hidden)
        #expect(OverlayReducer.reduce(.alert, .meetingEnded, notes: policy) == .done)
    }
}
