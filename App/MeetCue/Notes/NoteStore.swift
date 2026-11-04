import Foundation
import MeetCueCore
import Observation

/// Every note, in memory, saved to the repository 0.5 s after the last change, and at least every
/// 5 s during continuous edits. When a save fails, the text stays in memory, `saveFailed` is set,
/// and the save is retried on the next change and every 10 s until it succeeds.
///
/// When the notes can't be loaded, nothing is saved, so existing records are never written over.
/// `isStorageAvailable` is false until a load succeeds, which is tried again on each change; the
/// edits made meanwhile stay in memory and are saved with the loaded notes.
@MainActor
@Observable
final class NoteStore {
    private(set) var notes: [String: Note] = [:]
    private(set) var saveFailed = false
    private(set) var isStorageAvailable = true

    @ObservationIgnored private let repository: NoteRepository
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let saveDelay: Duration
    @ObservationIgnored private let maxSaveDelay: Duration
    @ObservationIgnored private let retryInterval: Duration
    @ObservationIgnored private var unsaved: Set<String> = []
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var oldestUnsaved: ContinuousClock.Instant?

    init(
        repository: NoteRepository,
        clock: @escaping () -> Date = Date.init,
        saveDelay: Duration = .milliseconds(500),
        maxSaveDelay: Duration = .seconds(5),
        retryInterval: Duration = .seconds(10)
    ) {
        self.repository = repository
        self.clock = clock
        self.saveDelay = saveDelay
        self.maxSaveDelay = maxSaveDelay
        self.retryInterval = retryInterval
        isStorageAvailable = false
        loadIfNeeded()
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

    /// Notes whose carry-over hasn't run yet, for recurring occurrences that started before `date`.
    func pendingCarryOvers(startedBefore date: Date) -> [Note] {
        notes.values
            .filter { $0.isRecurring && !$0.carriedForward && $0.occurrenceStart < date }
            .sorted { ($0.occurrenceStart, $0.occurrenceID) < ($1.occurrenceStart, $1.occurrenceID) }
    }

    /// Appends `source`'s unchecked topics to `target`'s note with carried markers, creating the note
    /// if needed, and marks `source` as carried forward.
    func carry(_ source: Note, into target: Meeting, calendar: Calendar) {
        let merged = CarryOver.carry(from: source.markdown, sourceDate: source.occurrenceStart, into: markdown(for: target.id), calendar: calendar)
        setMarkdown(merged, for: target)
        markCarriedForward(source)
    }

    func markCarriedForward(_ source: Note) {
        guard var note = notes[source.occurrenceID], !note.carriedForward else { return }
        note.carriedForward = true
        notes[source.occurrenceID] = note
        changed(source.occurrenceID)
    }

    /// Saves pending changes now, such as when the app quits.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        oldestUnsaved = nil
        loadIfNeeded()
        guard isStorageAvailable, !unsaved.isEmpty else { return }
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
            occurrenceID: key, seriesKey: seriesKey, occurrenceStart: start, markdown: "", updatedAt: .distantPast, carriedForward: false
        )
        note.markdown = markdown
        note.occurrenceStart = start
        note.updatedAt = clock()
        notes[key] = note
        changed(key)
    }

    private func changed(_ key: String) {
        loadIfNeeded()
        unsaved.insert(key)
        guard isStorageAvailable else { return }
        let now = ContinuousClock.now
        let oldest = oldestUnsaved ?? now
        oldestUnsaved = oldest
        scheduleSave(after: max(.zero, min(saveDelay, now.duration(to: oldest + maxSaveDelay))))
    }

    /// Notes edited in memory before the load succeeded win over the loaded ones.
    private func loadIfNeeded() {
        guard !isStorageAvailable, let loaded = try? repository.loadAll() else { return }
        for note in loaded where notes[note.occurrenceID] == nil {
            notes[note.occurrenceID] = note
        }
        isStorageAvailable = true
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
