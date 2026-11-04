import Foundation

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

/// The sidebar's visibility checkboxes. Hidden calendars leave every surface, not only the
/// calendar window, because they go into the store's filter.
@MainActor
final class CalendarVisibility {
    private let store: MeetingStore
    private let storage: HiddenCalendarStorage

    init(store: MeetingStore, storage: HiddenCalendarStorage = UserDefaultsHiddenCalendarStorage()) {
        self.store = store
        self.storage = storage
        let hidden = storage.hiddenCalendarIDs
        if store.filter.hiddenCalendarIDs != hidden {
            store.filter.hiddenCalendarIDs = hidden
        }
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
}
