import Foundation
import SwiftData

@Model
final class NoteRecord {
    @Attribute(.unique) var occurrenceID: String
    var seriesKey: String
    var occurrenceStart: Date
    var markdown: String
    var updatedAt: Date
    var carriedForward: Bool

    init(_ note: Note) {
        occurrenceID = note.occurrenceID
        seriesKey = note.seriesKey
        occurrenceStart = note.occurrenceStart
        markdown = note.markdown
        updatedAt = note.updatedAt
        carriedForward = note.carriedForward
    }

    func update(from note: Note) {
        seriesKey = note.seriesKey
        occurrenceStart = note.occurrenceStart
        markdown = note.markdown
        updatedAt = note.updatedAt
        carriedForward = note.carriedForward
    }

    var note: Note {
        Note(
            occurrenceID: occurrenceID,
            seriesKey: seriesKey,
            occurrenceStart: occurrenceStart,
            markdown: markdown,
            updatedAt: updatedAt,
            carriedForward: carriedForward
        )
    }
}

@MainActor
final class SwiftDataNoteRepository: NoteRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    /// A store in a file, such as `defaultURL()`.
    convenience init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try self.init(container: ModelContainer(for: NoteRecord.self, configurations: ModelConfiguration(url: url)))
    }

    static func inMemory() throws -> SwiftDataNoteRepository {
        try SwiftDataNoteRepository(container: ModelContainer(for: NoteRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    /// `~/Library/Application Support/MeetCue/Notes.store`.
    static func defaultURL() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(components: "MeetCue", "Notes.store")
    }

    func loadAll() throws -> [Note] {
        try container.mainContext.fetch(FetchDescriptor<NoteRecord>()).map(\.note)
    }

    func save(_ notes: [Note]) throws {
        let context = container.mainContext
        let keys = notes.map(\.occurrenceID)
        let existing = try context.fetch(FetchDescriptor<NoteRecord>(predicate: #Predicate { keys.contains($0.occurrenceID) }))
        var records = Dictionary(existing.map { ($0.occurrenceID, $0) }, uniquingKeysWith: { first, _ in first })
        for note in notes {
            if let record = records[note.occurrenceID] {
                record.update(from: note)
            } else {
                let record = NoteRecord(note)
                context.insert(record)
                records[note.occurrenceID] = record
            }
        }
        try context.save()
    }
}

/// Stands in when the notes file can't be opened: nothing loads, and every save fails, so the
/// editor keeps the text in memory and says it couldn't save.
@MainActor
final class UnavailableNoteRepository: NoteRepository {
    struct Unavailable: Error {}

    func loadAll() throws -> [Note] { [] }
    func save(_ notes: [Note]) throws { throw Unavailable() }
}
