import AppKit
import SwiftUI

/// The Settings window, opened from the dropdown and the app menu (⌘,). The app shows a Dock icon
/// while it's open.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let model: SettingsModel
    private let dock: DockPresence
    private var window: NSWindow?

    init(model: SettingsModel, dock: DockPresence) {
        self.model = model
        self.dock = dock
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        model.refresh()
        dock.opened(.settings)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        dock.closed(.settings)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: SettingsWindowView.size),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MeetCue Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        // An empty unified toolbar moves the traffic lights 19 pt in, inside the floating
        // sidebar's rounded corner, as in the calendar window.
        window.toolbar = NSToolbar(identifier: "SettingsWindow")
        window.toolbarStyle = .unified
        window.contentViewController = NSHostingController(rootView: SettingsWindowView(model: model))
        window.setContentSize(SettingsWindowView.size)
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.delegate = self
        return window
    }
}

extension AppearanceMode {
    /// The app's appearance for this choice; nil follows the system.
    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}
