import Foundation
import Observation

/// Where quiet mode keeps its state between launches.
protocol QuietStorage: AnyObject {
    var until: Date? { get set }
    var preset: String? { get set }
}

final class UserDefaultsQuietStorage: QuietStorage {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var until: Date? {
        get { defaults.object(forKey: "quietUntil") as? Date }
        set { defaults.set(newValue, forKey: "quietUntil") }
    }

    var preset: String? {
        get { defaults.string(forKey: "quietPreset") }
        set { defaults.set(newValue, forKey: "quietPreset") }
    }
}

@MainActor
@Observable
final class QuietMode {
    enum Preset: String, CaseIterable, Identifiable {
        case oneHour
        case endOfToday
        case untilTurnedOff

        var id: Self { self }

        var title: String {
            switch self {
            case .oneHour: "For 1 hour"
            case .endOfToday: "Until end of today"
            case .untilTurnedOff: "Until I turn it off"
            }
        }
    }

    /// Nil when off; `.distantFuture` for "until I turn it off".
    private(set) var until: Date?
    @ObservationIgnored private let storage: QuietStorage
    /// The preset last turned on, so the status can say "until end of today" without guessing from the time.
    private(set) var preset: Preset?
    init(storage: QuietStorage = UserDefaultsQuietStorage()) {
        self.storage = storage
        until = storage.until
        preset = storage.preset.flatMap(Preset.init(rawValue:))
    }

    func turnOn(_ preset: Preset, now: Date, calendar: Calendar) {
        switch preset {
        case .oneHour:
            until = now.addingTimeInterval(3600)
        case .endOfToday:
            until = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        case .untilTurnedOff:
            until = .distantFuture
        }
        self.preset = preset
        storage.until = until
        storage.preset = preset.rawValue
    }

    func turnOff() {
        until = nil
        preset = nil
        storage.until = nil
        storage.preset = nil
    }

    /// Turns quiet mode off once its end has passed, so every reader sees it as off.
    func clearIfExpired(at now: Date) {
        if let until, now >= until { turnOff() }
    }

    func isOn(at now: Date) -> Bool {
        until.map { now < $0 } ?? false
    }
}
