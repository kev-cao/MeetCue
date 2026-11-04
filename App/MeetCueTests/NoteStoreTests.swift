import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
struct NoteStoreTests {
    let sync = MeetingMapper.meeting(from: AppFixtures.event(start: AppFixtures.at(14, 30)))

    func makeStore(_ repository: NoteRepository, retry: Duration = .seconds(10)) -> NoteStore {
        NoteStore(repository: repository, clock: { AppFixtures.at(9, 0) }, saveDelay: .milliseconds(20), retryInterval: retry)
    }

    @Test func editsSaveAfterAShortDelay() async throws {
        let repository = try SwiftDataNoteRepository.inMemory()
        let store = makeStore(repository)
        store.setMarkdown("- [ ] Budget", for: sync)
        #expect(store.markdown(for: sync.id) == "- [ ] Budget")
        #expect(try repository.loadAll().isEmpty)
        #expect(await eventually { (try? repository.loadAll().count) == 1 })
        let saved = try #require(try repository.loadAll().first)
        #expect(saved.occurrenceID == sync.id.storageKey)
        #expect(saved.seriesKey == "series-1")
        #expect(saved.occurrenceStart == sync.start)
        #expect(saved.updatedAt == AppFixtures.at(9, 0))
        #expect(!saved.carriedForward)
    }

    @Test func quickEditsSaveOnce() async {
        let repository = FlakyNoteRepository()
        let store = makeStore(repository)
        store.setMarkdown("- [ ] B", for: sync)
        store.setMarkdown("- [ ] Bu", for: sync)
        store.setMarkdown("- [ ] Budget", for: sync)
        #expect(await eventually { repository.saved[sync.id.storageKey]?.markdown == "- [ ] Budget" })
        #expect(repository.attempts == 1)
    }

    @Test func loadsSavedNotes() {
        let note = Note(occurrenceID: sync.id.storageKey, seriesKey: "series-1", occurrenceStart: sync.start, markdown: "Agenda", updatedAt: .now, carriedForward: false)
        let store = makeStore(FlakyNoteRepository(notes: [note]))
        #expect(store.markdown(for: sync.id) == "Agenda")
        #expect(store.hasNotes(sync.id))
    }

    @Test func aFailedSaveKeepsTheTextAndRetries() async {
        let repository = FlakyNoteRepository(failures: 1)
        let store = makeStore(repository, retry: .milliseconds(100))
        store.setMarkdown("- [ ] Budget", for: sync)
        #expect(await eventually { store.saveFailed })
        #expect(store.markdown(for: sync.id) == "- [ ] Budget")
        #expect(repository.saved.isEmpty)
        #expect(await eventually { !store.saveFailed })
        #expect(repository.saved[sync.id.storageKey]?.markdown == "- [ ] Budget")
    }

    @Test func theNextEditRetriesAFailedSave() async {
        let repository = FlakyNoteRepository(failures: 1)
        let store = makeStore(repository)
        store.setMarkdown("- [ ] Budget", for: sync)
        #expect(await eventually { store.saveFailed })
        store.appendTopic("Hiring", to: sync)
        #expect(await eventually { !store.saveFailed })
        #expect(repository.saved[sync.id.storageKey]?.markdown == "- [ ] Budget\n- [ ] Hiring")
    }

    @Test func flushSavesAtOnce() {
        let repository = FlakyNoteRepository()
        let store = makeStore(repository)
        store.setMarkdown("Agenda", for: sync)
        store.flush()
        #expect(repository.saved[sync.id.storageKey]?.markdown == "Agenda")
    }

    @Test func topicsCountOnlyUncheckedItems() {
        let store = makeStore(FlakyNoteRepository())
        #expect(!store.hasNotes(sync.id))
        store.setMarkdown("  \n", for: sync)
        #expect(!store.hasNotes(sync.id))
        store.setMarkdown("- [ ] Budget\n- [x] Hiring\n- [ ] Offsite\nNotes", for: sync)
        #expect(store.openTopicCount(sync.id) == 2)
        store.toggleTask(line: 0, for: sync)
        #expect(store.markdown(for: sync.id) == "- [x] Budget\n- [x] Hiring\n- [ ] Offsite\nNotes")
        #expect(store.openTopicCount(sync.id) == 1)
    }

    @Test func writingFollowsAMovedOccurrence() {
        let store = makeStore(FlakyNoteRepository())
        store.appendTopic("Budget", to: sync)
        var moved = sync
        moved.start = AppFixtures.at(15, 0)
        store.appendTopic("Hiring", to: moved)
        #expect(store.note(for: sync.id)?.occurrenceStart == AppFixtures.at(15, 0))
    }
}
