import Foundation
import MeetCueCore
import Observation

/// Where settings are kept between launches: `UserDefaults` in the app, a dictionary in tests.
protocol SettingsStorage: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: SettingsStorage {}

/// A built-in macOS sound, played once when the full-screen alert appears.
enum AlertSound: String, CaseIterable, Identifiable {
    case none, glass, hero, ping, purr, submarine

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

enum AlertDisplays: String, CaseIterable, Identifiable {
    case all, main

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All displays"
        case .main: "Main display only"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

extension MenuBarSettings.Content {
    var title: String {
        switch self {
        case .timeAndTitle: "Time and title"
        case .timeOnly: "Time only"
        case .iconOnly: "Icon only"
        }
    }
}

extension MenuBarSettings.Scroll {
    var title: String {
        switch self {
        case .always: "Always"
        case .nearMeetings: "Within the hour and during meetings"
        case .never: "Never"
        }
    }
}

/// Every setting in the Settings window, saved as it changes. The app's parts read from it, so a
/// change takes effect at once. Hidden calendars and quiet mode keep their own storage
/// (`CalendarVisibility`, `QuietMode`), and launch at login is the system's (`LaunchAtLogin`).
@MainActor
@Observable
final class AppSettings {
    static let titleLengths = [8, 10, 12, 16]
    /// Minutes.
    static let leadTimes = [1, 2, 3, 5, 10, 15]
    /// Minutes.
    static let snoozeLengths = [1, 2, 5]

    var menuBarContent: MenuBarSettings.Content { didSet { save(menuBarContent.rawValue, .menuBarContent) } }
    /// One of `titleLengths`.
    var titleLength: Int { didSet { save(titleLength, .titleLength) } }
    var titleScroll: MenuBarSettings.Scroll { didSet { save(titleScroll.rawValue, .titleScroll) } }
    /// Minutes before the start, one of `leadTimes`.
    var leadTime: Int { didSet { save(leadTime, .leadTime) } }
    /// Minutes, one of `snoozeLengths`.
    var snoozeLength: Int { didSet { save(snoozeLength, .snoozeLength) } }
    var alertSound: AlertSound { didSet { save(alertSound.rawValue, .alertSound) } }
    var alertDisplays: AlertDisplays { didSet { save(alertDisplays.rawValue, .alertDisplays) } }
    var skipDeclined: Bool { didSet { save(skipDeclined, .skipDeclined) } }
    /// Calendars whose Alert switch is off.
    var alertOffCalendarIDs: Set<String> { didSet { save(alertOffCalendarIDs.sorted(), .alertOffCalendarIDs) } }
    var showNotesAtStart: Bool { didSet { save(showNotesAtStart, .showNotesAtStart) } }
    var notesOnlyWithNotes: Bool { didSet { save(notesOnlyWithNotes, .notesOnlyWithNotes) } }
    var hideNotesAtEnd: Bool { didSet { save(hideNotesAtEnd, .hideNotesAtEnd) } }
    var carryOver: Bool { didSet { save(carryOver, .carryOver) } }
    /// The inspector's tab when the calendar window opens.
    var notesEditorMode: CalendarWindowModel.EditorMode { didSet { save(notesEditorMode.rawValue, .notesEditorMode) } }
    var appearance: AppearanceMode { didSet { save(appearance.rawValue, .appearance) } }
    /// From 0, the glass as the system draws it, to 1, opaque.
    var glassOpacity: Double { didSet { save(glassOpacity, .glassOpacity) } }

    @ObservationIgnored private let storage: SettingsStorage

    private enum Key: String {
        case menuBarContent, titleLength, titleScroll, leadTime, snoozeLength, alertSound, alertDisplays
        case skipDeclined, alertOffCalendarIDs, showNotesAtStart, notesOnlyWithNotes, hideNotesAtEnd
        case carryOver, notesEditorMode, appearance, glassOpacity
    }

    init(storage: SettingsStorage = UserDefaults.standard) {
        self.storage = storage
        func choice<T: RawRepresentable>(_ key: Key, _ fallback: T) -> T where T.RawValue == String {
            (storage.object(forKey: key.rawValue) as? String).flatMap { T(rawValue: $0) } ?? fallback
        }
        func number(_ key: Key, in options: [Int], _ fallback: Int) -> Int {
            (storage.object(forKey: key.rawValue) as? Int).flatMap { options.contains($0) ? $0 : nil } ?? fallback
        }
        func flag(_ key: Key, _ fallback: Bool) -> Bool {
            storage.object(forKey: key.rawValue) as? Bool ?? fallback
        }
        menuBarContent = choice(.menuBarContent, .timeAndTitle)
        titleLength = number(.titleLength, in: Self.titleLengths, 10)
        titleScroll = choice(.titleScroll, .nearMeetings)
        leadTime = number(.leadTime, in: Self.leadTimes, 2)
        snoozeLength = number(.snoozeLength, in: Self.snoozeLengths, 1)
        alertSound = choice(.alertSound, .none)
        alertDisplays = choice(.alertDisplays, .all)
        skipDeclined = flag(.skipDeclined, true)
        alertOffCalendarIDs = Set(storage.object(forKey: Key.alertOffCalendarIDs.rawValue) as? [String] ?? [])
        showNotesAtStart = flag(.showNotesAtStart, true)
        notesOnlyWithNotes = flag(.notesOnlyWithNotes, true)
        hideNotesAtEnd = flag(.hideNotesAtEnd, true)
        carryOver = flag(.carryOver, true)
        notesEditorMode = choice(.notesEditorMode, .preview)
        appearance = choice(.appearance, .system)
        glassOpacity = min(1, max(0, storage.object(forKey: Key.glassOpacity.rawValue) as? Double ?? 0))
    }

    var alertTiming: AlertTiming {
        AlertTiming(leadTime: TimeInterval(leadTime * 60), snoozeLength: TimeInterval(snoozeLength * 60))
    }

    func notesPolicy(hasNotes: Bool) -> NotesPolicy {
        NotesPolicy(showAtStart: showNotesAtStart, onlyWithNotes: notesOnlyWithNotes, hideAtEnd: hideNotesAtEnd, hasNotes: hasNotes)
    }

    private func save(_ value: Any, _ key: Key) {
        storage.set(value, forKey: key.rawValue)
    }
}
