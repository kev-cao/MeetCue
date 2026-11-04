import Foundation
import Observation

@MainActor
@Observable
final class QuietMode {
    enum Duration: CaseIterable, Identifiable {
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
    private static let key = "quietUntil"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        until = defaults.object(forKey: Self.key) as? Date
    }

    func turnOn(_ duration: Duration, now: Date, calendar: Calendar) {
        switch duration {
        case .oneHour:
            until = now.addingTimeInterval(3600)
        case .endOfToday:
            until = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        case .untilTurnedOff:
            until = .distantFuture
        }
        defaults.set(until, forKey: Self.key)
    }

    func turnOff() {
        until = nil
        defaults.removeObject(forKey: Self.key)
    }

    func isOn(at now: Date) -> Bool {
        until.map { now < $0 } ?? false
    }
}
