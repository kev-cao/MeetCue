import Foundation
import MeetCueCore
import Observation

/// Where the calendars hidden in the calendar window's sidebar are kept between launches.
protocol HiddenCalendarStorage: AnyObject {
    var hiddenCalendarIDs: Set<String> { get set }
}

final class UserDefaultsHiddenCalendarStorage: HiddenCalendarStorage {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hiddenCalendarIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: "hiddenCalendarIDs") ?? []) }
        set { defaults.set(newValue.sorted(), forKey: "hiddenCalendarIDs") }
    }
}

/// The calendars' Show and Alert switches, in the calendar window's sidebar and in Settings, and
/// the "Skip events I've declined" setting. They make up the store's filter, so a hidden calendar
/// leaves every surface, not only the calendar window, and a calendar with alerts off gets no
/// full-screen alerts. Changes made to the settings directly reach the filter too.
@MainActor
final class CalendarVisibility {
    private let store: MeetingStore
    private let settings: AppSettings
    private let storage: HiddenCalendarStorage

    init(store: MeetingStore, settings: AppSettings, storage: HiddenCalendarStorage = UserDefaultsHiddenCalendarStorage()) {
        self.store = store
        self.settings = settings
        self.storage = storage
        var filter = store.filter
        filter.hiddenCalendarIDs = storage.hiddenCalendarIDs
        apply(to: &filter)
        if store.filter != filter {
            store.filter = filter
        }
        trackSettings()
    }

    func isVisible(_ calendarID: String) -> Bool {
        !store.filter.hiddenCalendarIDs.contains(calendarID)
    }

    func setVisible(_ visible: Bool, calendarID: String) {
        var hidden = store.filter.hiddenCalendarIDs
        if visible {
            hidden.remove(calendarID)
        } else {
            hidden.insert(calendarID)
        }
        guard hidden != store.filter.hiddenCalendarIDs else { return }
        storage.hiddenCalendarIDs = hidden
        store.filter.hiddenCalendarIDs = hidden
    }

    func alertsOn(_ calendarID: String) -> Bool {
        !settings.alertOffCalendarIDs.contains(calendarID)
    }

    func setAlertsOn(_ on: Bool, calendarID: String) {
        if on {
            settings.alertOffCalendarIDs.remove(calendarID)
        } else {
            settings.alertOffCalendarIDs.insert(calendarID)
        }
        applySettings()
    }

    private func apply(to filter: inout CalendarFilter) {
        filter.alertOffCalendarIDs = settings.alertOffCalendarIDs
        filter.skipDeclined = settings.skipDeclined
    }

    private func applySettings() {
        var filter = store.filter
        apply(to: &filter)
        if store.filter != filter {
            store.filter = filter
        }
    }

    private func trackSettings() {
        withObservationTracking {
            _ = settings.alertOffCalendarIDs
            _ = settings.skipDeclined
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.applySettings()
                self?.trackSettings()
            }
        }
    }
}
