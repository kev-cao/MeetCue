import Foundation
import MeetCueCore

/// Where dismissed alerts are kept between launches.
protocol DismissedAlertStorage: AnyObject {
    /// Occurrence storage keys, each mapped to the start time its meeting had when it was recorded.
    var records: [String: Date] { get set }
}

final class UserDefaultsDismissedAlertStorage: DismissedAlertStorage {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var records: [String: Date] {
        get { defaults.dictionary(forKey: "dismissedAlerts") as? [String: Date] ?? [:] }
        set { defaults.set(newValue, forKey: "dismissedAlerts") }
    }
}

/// Meetings whose alert is over, so a relaunch doesn't show it again: dismissed, joined, skipped
/// while quiet, or past. A record counts only while the meeting keeps the start time it had when
/// recorded, because a moved meeting alerts again.
@MainActor
final class DismissedAlerts {
    private let storage: DismissedAlertStorage
    private var records: [String: Date]

    init(storage: DismissedAlertStorage = UserDefaultsDismissedAlertStorage()) {
        self.storage = storage
        records = storage.records
    }

    func contains(_ meeting: Meeting) -> Bool {
        records[meeting.id.storageKey] == meeting.start
    }

    func insert(_ meeting: Meeting) {
        guard !contains(meeting) else { return }
        records[meeting.id.storageKey] = meeting.start
        storage.records = records
    }

    func remove(_ id: OccurrenceID) {
        guard records.removeValue(forKey: id.storageKey) != nil else { return }
        storage.records = records
    }

    /// Forgets meetings that started before `date`, normally the start of today.
    func prune(before date: Date) {
        let kept = records.filter { $0.value >= date }
        guard kept.count != records.count else { return }
        records = kept
        storage.records = records
    }
}
