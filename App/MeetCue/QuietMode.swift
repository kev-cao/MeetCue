import Foundation
import Observation

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
    @ObservationIgnored private let defaults: UserDefaults
    /// The preset last turned on, so the status can say "until end of today" without guessing from the time.
    private(set) var preset: Preset?
    private static let key = "quietUntil"
    private static let presetKey = "quietPreset"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        until = defaults.object(forKey: Self.key) as? Date
        preset = defaults.string(forKey: Self.presetKey).flatMap(Preset.init(rawValue:))
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
        defaults.set(until, forKey: Self.key)
        defaults.set(preset.rawValue, forKey: Self.presetKey)
    }

    func turnOff() {
        until = nil
        preset = nil
        defaults.removeObject(forKey: Self.key)
        defaults.removeObject(forKey: Self.presetKey)
    }

    func isOn(at now: Date) -> Bool {
        until.map { now < $0 } ?? false
    }
}
