import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // `xcodebuild test` launches the app as the test host, where a calendar-access dialog would block on the user.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        let store = MeetingStore(source: EventKitSource())
        let model = MenuBarModel(store: store, quiet: QuietMode())
        statusItem = StatusItemController(model: model) { dismiss in DropdownView(model: model, dismiss: dismiss) }
        observeSystemChanges {
            store.refresh()
            model.tick()
        }
        store.refresh()
        if store.access == .notDetermined {
            Task { await store.requestAccess() }
        }
    }

    /// Waking, a clock or time zone change, and midnight all change which meetings are "today".
    private func observeSystemChanges(_ handler: @escaping @MainActor @Sendable () -> Void) {
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        let sources: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.didWakeNotification),
            (center, .NSCalendarDayChanged),
            (center, .NSSystemClockDidChange),
            (center, .NSSystemTimeZoneDidChange),
        ]
        for (notificationCenter, name) in sources {
            observers.append(notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { handler() }
            })
        }
    }
}
