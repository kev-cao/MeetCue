import Foundation
import MeetCueCore

/// One occurrence's Markdown notes.
struct Note: Equatable, Sendable {
    /// `OccurrenceID.storageKey` of the occurrence the note belongs to.
    var occurrenceID: String
    var seriesKey: String
    /// The occurrence's start when the note was last written.
    var occurrenceStart: Date
    var markdown: String
    var updatedAt: Date
    /// Set once carry-over has run for this occurrence, so its topics move forward only once.
    var carriedForward: Bool

    /// Only occurrences of recurring meetings carry topics forward. A one-off meeting's storage key
    /// is its series key alone.
    var isRecurring: Bool { occurrenceID != seriesKey }
}

/// Where notes are kept. The app uses SwiftData; tests can swap in a store that fails.
@MainActor
protocol NoteRepository: AnyObject {
    func loadAll() throws -> [Note]
    /// Inserts or updates each note by `occurrenceID`.
    func save(_ notes: [Note]) throws
}
