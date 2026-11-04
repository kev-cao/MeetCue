import Foundation
import MeetCueCore
import Observation

/// Every note, in memory, saved to the repository 0.5 s after the last change. When a save fails,
/// the text stays in memory, `saveFailed` is set, and the save is retried on the next change and
/// every 10 s until it succeeds.
@MainActor
@Observable
final class NoteStore {
    private(set) var notes: [String: Note] = [:]
    private(set) var saveFailed = false

    @ObservationIgnored private let repository: NoteRepository
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let saveDelay: Duration
    @ObservationIgnored private let retryInterval: Duration
    @ObservationIgnored private var unsaved: Set<String> = []
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(
        repository: NoteRepository,
        clock: @escaping () -> Date = Date.init,
        saveDelay: Duration = .milliseconds(500),
        retryInterval: Duration = .seconds(10)
    ) {
        self.repository = repository
        self.clock = clock
        self.saveDelay = saveDelay
        self.retryInterval = retryInterval
        let loaded = (try? repository.loadAll()) ?? []
        notes = Dictionary(loaded.map { ($0.occurrenceID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func note(for id: OccurrenceID) -> Note? { notes[id.storageKey] }

    func markdown(for id: OccurrenceID) -> String { notes[id.storageKey]?.markdown ?? "" }

    /// Whether the note has any text besides whitespace.
    func hasNotes(_ id: OccurrenceID) -> Bool {
        !markdown(for: id).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Unchecked task items: the topics still to bring up.
    func openTopicCount(_ id: OccurrenceID) -> Int {
        MarkdownTasks.items(in: markdown(for: id)).filter { !$0.isChecked }.count
    }

    func setMarkdown(_ markdown: String, for meeting: Meeting) {
        guard markdown != self.markdown(for: meeting.id) else { return }
        write(markdown, key: meeting.id.storageKey, seriesKey: meeting.id.seriesKey, start: meeting.start)
    }

    func toggleTask(line: Int, for meeting: Meeting) {
        setMarkdown(MarkdownTasks.toggle(markdown(for: meeting.id), line: line), for: meeting)
    }

    func appendTopic(_ topic: String, to meeting: Meeting) {
        setMarkdown(MarkdownTasks.appendTopic(topic, to: markdown(for: meeting.id)), for: meeting)
    }

    /// Saves pending changes now, such as when the app quits.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        guard !unsaved.isEmpty else { return }
        let batch = unsaved.sorted().compactMap { notes[$0] }
        do {
            try repository.save(batch)
            unsaved = []
            if saveFailed { saveFailed = false }
        } catch {
            if !saveFailed { saveFailed = true }
            scheduleSave(after: retryInterval)
        }
    }

    private func write(_ markdown: String, key: String, seriesKey: String, start: Date) {
        var note = notes[key] ?? Note(
            occurrenceID: key, seriesKey: seriesKey, occurrenceStart: start, markdown: "", updatedAt: clock(), carriedForward: false
        )
        note.markdown = markdown
        note.occurrenceStart = start
        note.updatedAt = clock()
        notes[key] = note
        changed(key)
    }

    private func changed(_ key: String) {
        unsaved.insert(key)
        scheduleSave(after: saveDelay)
    }

    private func scheduleSave(after delay: Duration) {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }
}
