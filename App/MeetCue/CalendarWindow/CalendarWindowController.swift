import AppKit
import MeetCueCore
import SwiftUI

/// The calendar window. The app shows a Dock icon while it's open. Each time it opens, the notes
/// editor starts in the tab chosen in Settings.
@MainActor
final class CalendarWindowController: NSObject, NSWindowDelegate {
    private let model: CalendarWindowModel
    private let settings: AppSettings
    private let dock: DockPresence
    private var window: NSWindow?

    init(model: CalendarWindowModel, settings: AppSettings, dock: DockPresence) {
        self.model = model
        self.settings = settings
        self.dock = dock
    }

    /// Opens the window, on `meeting`'s day with it selected when given.
    func show(selecting meeting: Meeting? = nil) {
        let window = window ?? makeWindow()
        self.window = window
        if !window.isVisible && !window.isMiniaturized {
            model.editorMode = settings.notesEditorMode
        }
        model.dayDidChange()
        if let meeting {
            model.show(meeting)
        } else {
            model.reload()
        }
        dock.opened(.calendar)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        dock.closed(.calendar)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1240, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MeetCue"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        // An empty unified toolbar moves the traffic lights 19 pt in, inside the floating
        // sidebar's rounded corner; without one they sit at 9 pt and straddle its edge.
        window.toolbar = NSToolbar(identifier: "CalendarWindow")
        window.toolbarStyle = .unified
        let controller = NSHostingController(rootView: CalendarWindowView(model: model))
        controller.sizingOptions = [.minSize]
        window.contentViewController = controller
        window.setContentSize(NSSize(width: 1240, height: 780))
        window.center()
        window.setFrameAutosaveName("CalendarWindow")
        window.delegate = self
        model.startTracking()
        return window
    }
}
