import Foundation
import MeetCueCore
import Observation

@MainActor
@Observable
final class MenuBarModel {
    let store: MeetingStore
    let quiet: QuietMode
    private(set) var now: Date
    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let clock: () -> Date

    init(
        store: MeetingStore,
        quiet: QuietMode,
        clock: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) {
        self.store = store
        self.quiet = quiet
        self.clock = clock
        self.calendar = calendar
        self.locale = locale
        now = clock()
    }

    func tick() {
        now = clock()
    }

    var needsAccess: Bool { store.access != .granted }

    var settings: MenuBarSettings {
        MenuBarSettings(uses24HourClock: ClockStyle.uses24Hour(locale))
    }

    var featured: Meeting? {
        MenuBarText.featured(in: store.meetings, now: now, calendar: calendar)
    }

    var display: MenuBarDisplay {
        MenuBarText.display(meetings: store.meetings, now: now, quiet: quiet.isOn(at: now), settings: settings, calendar: calendar)
    }

    func detail(for meeting: Meeting) -> String {
        MenuBarText.detail(for: meeting, now: now, calendar: calendar, uses24Hour: settings.uses24HourClock)
    }

    var quietStatus: String {
        guard quiet.isOn(at: now), let until = quiet.until else { return "Quiet mode: Off" }
        if until == .distantFuture { return "Quiet until you turn it off" }
        let parts = calendar.dateComponents([.hour, .minute], from: until)
        if parts.hour == 0 && parts.minute == 0 { return "Quiet until end of today" }
        return "Quiet until \(MenuBarText.clockTime(until, calendar: calendar, uses24Hour: settings.uses24HourClock))"
    }
}
