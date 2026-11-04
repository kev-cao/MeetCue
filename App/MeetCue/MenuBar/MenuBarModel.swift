import Foundation
import MeetCueCore
import Observation

@MainActor
@Observable
final class MenuBarModel {
    let store: MeetingStore
    let quiet: QuietMode
    private(set) var now: Date
    @ObservationIgnored private let calendar: Calendar
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

    /// Turns quiet mode on with `preset`, or off for nil, measured from the current time.
    func setQuiet(_ preset: QuietMode.Preset?) {
        tick()
        if let preset {
            quiet.turnOn(preset, now: now, calendar: calendar)
        } else {
            quiet.turnOff()
        }
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

    /// What VoiceOver reads for the status item.
    var accessibilityLabel: String {
        if needsAccess { return "MeetCue, calendar access needed" }
        let quietSuffix = quiet.isOn(at: now) ? ", quiet mode on" : ""
        guard let meeting = featured, let time = display.time else { return "MeetCue, no more meetings today" + quietSuffix }
        let lead = meeting.start <= now ? "Now" : "Next"
        return "MeetCue, \(lead): \(meeting.title), \(time)" + quietSuffix
    }

    func detail(for meeting: Meeting) -> String {
        MenuBarText.detail(for: meeting, now: now, calendar: calendar, uses24Hour: settings.uses24HourClock)
    }

    var quietStatus: String {
        guard quiet.isOn(at: now), let until = quiet.until else { return "Quiet mode: Off" }
        if until == .distantFuture { return "Quiet until you turn it off" }
        if quiet.preset == .endOfToday { return "Quiet until end of today" }
        return "Quiet until \(MenuBarText.clockTime(until, calendar: calendar, uses24Hour: settings.uses24HourClock))"
    }
}
