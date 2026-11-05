import Foundation
import MeetCueCore
import Observation

@MainActor
@Observable
final class MenuBarModel {
    let store: MeetingStore
    let quiet: QuietMode
    let notes: NoteStore
    let settings: AppSettings
    private(set) var now: Date
    /// Set when the dropdown opens with Option held, to reveal "Simulate meeting in 2 minutes".
    var showsSimulateItem = false
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let clock: () -> Date

    init(
        store: MeetingStore,
        quiet: QuietMode,
        notes: NoteStore,
        settings: AppSettings,
        clock: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) {
        self.store = store
        self.quiet = quiet
        self.notes = notes
        self.settings = settings
        self.clock = clock
        self.calendar = calendar
        self.locale = locale
        now = clock()
    }

    func tick() {
        now = clock()
        quiet.clearIfExpired(at: now)
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

    var menuBarSettings: MenuBarSettings {
        MenuBarSettings(
            content: settings.menuBarContent,
            titleLength: settings.titleLength,
            scroll: settings.titleScroll,
            uses24HourClock: ClockStyle.uses24Hour(locale)
        )
    }

    var featured: Meeting? {
        MenuBarText.featured(in: store.meetings, now: now, calendar: calendar)
    }

    /// The meeting ⌥⌘J joins: the featured one, when it has a video link.
    var joinTarget: Meeting? {
        featured.flatMap { $0.joinLink == nil ? nil : $0 }
    }

    var display: MenuBarDisplay {
        MenuBarText.display(meetings: store.meetings, now: now, quiet: quiet.isOn(at: now), settings: menuBarSettings, calendar: calendar)
    }

    /// What VoiceOver reads for the status item.
    var accessibilityLabel: String {
        if needsAccess { return "MeetCue, calendar access needed" }
        let quietSuffix = quiet.isOn(at: now) ? ", quiet mode on" : ""
        guard let meeting = featured else { return "MeetCue, no more meetings today" + quietSuffix }
        let lead = isLive(meeting) ? "Now" : "Next"
        let countdown = detail(for: meeting).components(separatedBy: " · ")
        let when = countdown.count > 1
            ? countdown[1]
            : "at " + MenuBarText.clockTime(meeting.start, calendar: calendar, uses24Hour: menuBarSettings.uses24HourClock)
        return "MeetCue, \(lead): \(meeting.title), \(when)" + quietSuffix
    }

    /// Topics still to bring up in the meeting's note.
    func topicCount(for meeting: Meeting) -> Int { notes.openTopicCount(meeting.id) }

    func addTopic(_ topic: String, to meeting: Meeting) {
        notes.appendTopic(topic, to: meeting)
    }

    func isLive(_ meeting: Meeting) -> Bool { meeting.start <= now && now < meeting.end }

    func detail(for meeting: Meeting) -> String {
        MenuBarText.detail(for: meeting, now: now, calendar: calendar, uses24Hour: menuBarSettings.uses24HourClock)
    }

    var quietStatus: String {
        guard quiet.isOn(at: now), let until = quiet.until else { return "Quiet mode: Off" }
        if until == .distantFuture { return "Quiet until you turn it off" }
        if quiet.preset == .endOfToday { return "Quiet until end of today" }
        return "Quiet until \(MenuBarText.clockTime(until, calendar: calendar, uses24Hour: menuBarSettings.uses24HourClock))"
    }
}
