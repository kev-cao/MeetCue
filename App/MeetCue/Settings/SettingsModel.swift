import AppKit
import Foundation
import MeetCueCore
import Observation

/// What the Settings window shows and does: the selected section and the actions behind its
/// controls. Most controls bind straight to `settings`.
@MainActor
@Observable
final class SettingsModel {
    enum Section: String, CaseIterable, Identifiable {
        case general, alerts, calendars, notes, appearance

        var id: Self { self }
        var title: String { rawValue.capitalized }
    }

    var section: Section = .general
    /// How the last export went, shown under the Export button.
    private(set) var exportStatus: String?

    let settings: AppSettings
    let quiet: QuietMode
    let store: MeetingStore
    let launchAtLogin: LaunchAtLogin
    @ObservationIgnored private let visibility: CalendarVisibility
    @ObservationIgnored private let notes: NoteStore
    @ObservationIgnored private let notesFile: URL?
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let reveal: @MainActor (URL) -> Void

    init(
        settings: AppSettings,
        quiet: QuietMode,
        store: MeetingStore,
        visibility: CalendarVisibility,
        notes: NoteStore,
        launchAtLogin: LaunchAtLogin,
        notesFile: URL?,
        clock: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent,
        reveal: @escaping @MainActor (URL) -> Void = { NSWorkspace.shared.activateFileViewerSelecting([$0]) }
    ) {
        self.settings = settings
        self.quiet = quiet
        self.store = store
        self.visibility = visibility
        self.notes = notes
        self.launchAtLogin = launchAtLogin
        self.notesFile = notesFile
        self.clock = clock
        self.calendar = calendar
        self.reveal = reveal
    }

    /// Reads again what can change outside the app while Settings is closed.
    func refresh() {
        launchAtLogin.refresh()
    }

    // MARK: Alerts

    /// The quiet mode menu's choice, nil for Off. Choosing a preset measures it from now.
    var quietPreset: QuietMode.Preset? {
        get { quiet.isOn(at: clock()) ? quiet.preset : nil }
        set {
            if let newValue {
                quiet.turnOn(newValue, now: clock(), calendar: calendar)
            } else {
                quiet.turnOff()
            }
        }
    }

    // MARK: Calendars

    var calendarGroups: [CalendarWindowModel.CalendarGroup] { CalendarWindowModel.groups(of: store.calendars) }

    func isVisible(_ calendarID: String) -> Bool { visibility.isVisible(calendarID) }

    func setVisible(_ visible: Bool, calendarID: String) { visibility.setVisible(visible, calendarID: calendarID) }

    func alertsOn(_ calendarID: String) -> Bool { visibility.alertsOn(calendarID) }

    func setAlertsOn(_ on: Bool, calendarID: String) { visibility.setAlertsOn(on, calendarID: calendarID) }

    // MARK: Notes

    /// "~/Library/Application Support/MeetCue".
    var notesFolderPath: String? {
        notesFile.map { ($0.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath }
    }

    func showNotesInFinder() {
        if let notesFile { reveal(notesFile) }
    }

    /// Asks for a folder, then exports every note to it.
    func chooseExportFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        panel.message = "Choose a folder for your notes. Files with the same names are replaced."
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        exportNotes(to: folder)
    }

    func exportNotes(to folder: URL) {
        do {
            let count = try NoteExporter(notes: notes, store: store, calendar: calendar).export(to: folder)
            exportStatus = switch count {
            case 0: "There are no notes to export."
            case 1: "Exported 1 note to \(folder.lastPathComponent)."
            default: "Exported \(count) notes to \(folder.lastPathComponent)."
            }
        } catch {
            exportStatus = "Couldn't export the notes. \(error.localizedDescription)"
        }
    }
}
