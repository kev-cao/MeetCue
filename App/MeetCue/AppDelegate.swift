import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var alertScheduler: AlertScheduler?
    private var overlayController: OverlayController?
    private var notes: NoteStore?
    private var calendarWindow: CalendarWindowController?
    private var hotKeys: GlobalHotKeys?
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // `xcodebuild test` launches the app as the test host, where a calendar-access dialog would block on the user.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        let store = MeetingStore(source: EventKitSource())
        let quiet = QuietMode()
        let settings = AppSettings()
        let notes = NoteStore(repository: Self.noteRepository())
        self.notes = notes
        let model = MenuBarModel(store: store, quiet: quiet, notes: notes, settings: settings)
        let overlays = OverlayModel(store: store, quiet: quiet, notes: notes, dismissed: DismissedAlerts(), settings: settings)
        let visibility = CalendarVisibility(store: store, settings: settings)
        let calendarWindow = CalendarWindowController(model: CalendarWindowModel(store: store, notes: notes, visibility: visibility))
        self.calendarWindow = calendarWindow
        let carrier = NoteCarrier(notes: notes, store: store, settings: settings)
        let scheduler = AlertScheduler(model: overlays)
        scheduler.beforeRefresh = { carrier.run(now: Date()) }
        alertScheduler = scheduler
        overlayController = OverlayController(model: overlays, openMeeting: { calendarWindow.show(selecting: $0) })
        let hotKeys = GlobalHotKeys()
        hotKeys.register(keyCode: kVK_ANSI_N) { overlays.toggleNotesCard() }
        hotKeys.register(keyCode: kVK_ANSI_O) { calendarWindow.show() }
        hotKeys.register(keyCode: kVK_ANSI_J) {
            model.tick()
            if let meeting = model.joinTarget { overlays.join(meeting) }
        }
        self.hotKeys = hotKeys
        statusItem = StatusItemController(model: model) { dismiss in
            DropdownView(
                model: model,
                dismiss: dismiss,
                overlays: overlays,
                openMeetCue: { calendarWindow.show() },
                simulateMeeting: { overlays.simulateMeeting() }
            )
        }
        observeSystemChanges {
            store.refresh()
            model.tick()
            scheduler.refresh()
        }
        store.refresh()
        scheduler.start()
        if store.access == .notDetermined {
            Task { await store.requestAccess() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        notes?.flush()
    }

    private static func noteRepository() -> NoteRepository {
        do {
            return try SwiftDataNoteRepository(url: SwiftDataNoteRepository.defaultURL())
        } catch {
            return UnavailableNoteRepository()
        }
    }

    /// Waking, a clock, time zone or locale change, and midnight all change which meetings are "today" or how times read.
    private func observeSystemChanges(_ handler: @escaping @MainActor @Sendable () -> Void) {
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        let sources: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.didWakeNotification),
            (center, .NSCalendarDayChanged),
            (center, .NSSystemClockDidChange),
            (center, .NSSystemTimeZoneDidChange),
            (center, NSLocale.currentLocaleDidChangeNotification),
        ]
        for (notificationCenter, name) in sources {
            observers.append(notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { handler() }
            })
        }
    }
}
