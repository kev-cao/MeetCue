import Foundation
import Testing
@testable import MeetCue

@MainActor
struct NoteRepositoryTests {
    func note(_ key: String = "series-1|1793817000", markdown: String = "- [ ] Budget") -> Note {
        Note(
            occurrenceID: key,
            seriesKey: "series-1",
            occurrenceStart: AppFixtures.at(14, 30),
            markdown: markdown,
            updatedAt: AppFixtures.at(9, 0),
            carriedForward: false
        )
    }

    @Test func savesAndLoadsNotes() throws {
        let repository = try SwiftDataNoteRepository.inMemory()
        try repository.save([note()])
        #expect(try repository.loadAll() == [note()])
    }

    @Test func savingAgainUpdatesTheNoteInPlace() throws {
        let repository = try SwiftDataNoteRepository.inMemory()
        try repository.save([note()])
        var edited = note(markdown: "- [x] Budget")
        edited.carriedForward = true
        try repository.save([edited, note("series-2", markdown: "Agenda")])
        let loaded = try repository.loadAll().sorted { $0.occurrenceID < $1.occurrenceID }
        #expect(loaded == [edited, note("series-2", markdown: "Agenda")])
    }

    @Test func notesInAFileOutliveTheRepository() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(components: "MeetCueTests-\(UUID().uuidString)", "Notes.store")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try SwiftDataNoteRepository(url: url).save([note()])
        #expect(try SwiftDataNoteRepository(url: url).loadAll() == [note()])
    }

    @Test func defaultLocationIsInApplicationSupport() throws {
        let url = try SwiftDataNoteRepository.defaultURL()
        #expect(url.lastPathComponent == "Notes.store")
        #expect(url.deletingLastPathComponent().lastPathComponent == "MeetCue")
        #expect(url.path(percentEncoded: false).contains("/Library/Application Support/"))
    }
}
