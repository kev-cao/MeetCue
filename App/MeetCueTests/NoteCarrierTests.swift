import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
struct NoteCarrierTests {
    let source = FakeCalendarSource()
    let notes = NoteStore(repository: FlakyNoteRepository(), saveDelay: .seconds(60))

    func weekly(day: Int, month: Int = 11, status: RSVP = .accepted) -> EventSnapshot {
        let start = AppFixtures.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 14, minute: 30))!
        return AppFixtures.event(start: start, series: "weekly", status: status, recurring: true)
    }

    func meeting(_ event: EventSnapshot) -> Meeting { MeetingMapper.meeting(from: event) }

    func makeCarrier(store: MeetingStore? = nil) -> NoteCarrier {
        NoteCarrier(notes: notes, store: store ?? MeetingStore(source: source, calendar: AppFixtures.calendar), calendar: AppFixtures.calendar)
    }

    @Test func carriesUncheckedTopicsWhenTheOccurrenceEnds() throws {
        source.snapshots = [weekly(day: 4), weekly(day: 11)]
        notes.setMarkdown("- [ ] Budget\n- [x] Hiring\nNotes", for: meeting(weekly(day: 4)))
        let carrier = makeCarrier()
        carrier.run(now: AppFixtures.at(14, 45))
        #expect(!notes.hasNotes(meeting(weekly(day: 11)).id))
        carrier.run(now: AppFixtures.at(15, 0))
        #expect(notes.markdown(for: meeting(weekly(day: 11)).id) == "- [ ] Budget <!-- carried:2026-11-04 -->")
        #expect(try #require(notes.note(for: meeting(weekly(day: 4)).id)).carriedForward)
    }

    @Test func carriesOnlyOnce() {
        source.snapshots = [weekly(day: 4), weekly(day: 11)]
        notes.setMarkdown("- [ ] Budget", for: meeting(weekly(day: 4)))
        makeCarrier().run(now: AppFixtures.at(15, 0))
        notes.setMarkdown("", for: meeting(weekly(day: 11)))
        makeCarrier().run(now: AppFixtures.at(15, 0))
        #expect(notes.markdown(for: meeting(weekly(day: 11)).id) == "")
    }

    @Test func oneOffMeetingsNeverCarry() {
        let oneOff = AppFixtures.event(start: AppFixtures.at(14, 30), series: "weekly")
        source.snapshots = [oneOff, weekly(day: 11)]
        notes.setMarkdown("- [ ] Budget", for: meeting(oneOff))
        makeCarrier().run(now: AppFixtures.at(15, 0))
        #expect(!notes.hasNotes(meeting(weekly(day: 11)).id))
    }

    @Test func skipsDeclinedOccurrences() {
        source.snapshots = [weekly(day: 4), weekly(day: 11, status: .declined), weekly(day: 18)]
        notes.setMarkdown("- [ ] Budget", for: meeting(weekly(day: 4)))
        makeCarrier().run(now: AppFixtures.at(15, 0))
        #expect(!notes.hasNotes(meeting(weekly(day: 11)).id))
        #expect(notes.hasNotes(meeting(weekly(day: 18)).id))
    }

    @Test func looksOnlySixtyDaysAhead() throws {
        source.snapshots = [weekly(day: 4), weekly(day: 13, month: 1)]
        notes.setMarkdown("- [ ] Budget", for: meeting(weekly(day: 4)))
        makeCarrier().run(now: AppFixtures.at(15, 0))
        #expect(!notes.hasNotes(meeting(weekly(day: 13, month: 1)).id))
        #expect(try #require(notes.note(for: meeting(weekly(day: 4)).id)).carriedForward == false)

        let later = AppFixtures.calendar.date(from: DateComponents(year: 2027, month: 1, day: 10))!
        makeCarrier().run(now: later)
        #expect(try #require(notes.note(for: meeting(weekly(day: 4)).id)).carriedForward)
    }

    @Test func occurrencesThatEndedWhileClosedPassTopicsAlong() {
        source.snapshots = [weekly(day: 21, month: 10), weekly(day: 28, month: 10), weekly(day: 4)]
        notes.setMarkdown("- [ ] Budget", for: meeting(weekly(day: 21, month: 10)))
        makeCarrier().run(now: AppFixtures.at(9, 0))
        #expect(notes.markdown(for: meeting(weekly(day: 4)).id) == "- [ ] Budget <!-- carried:2026-10-21 -->")
    }

    @Test func waitsForCalendarAccess() {
        source.access = .notDetermined
        source.snapshots = [weekly(day: 4), weekly(day: 11)]
        notes.setMarkdown("- [ ] Budget", for: meeting(weekly(day: 4)))
        let store = MeetingStore(source: source, calendar: AppFixtures.calendar)
        let carrier = makeCarrier(store: store)
        carrier.run(now: AppFixtures.at(15, 0))
        #expect(notes.note(for: meeting(weekly(day: 4)).id)?.carriedForward == false)
        source.access = .granted
        store.refresh()
        carrier.run(now: AppFixtures.at(15, 0))
        #expect(notes.hasNotes(meeting(weekly(day: 11)).id))
    }
}
