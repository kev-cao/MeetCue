import AppKit
import MeetCueCore
import SwiftUI

/// The calendar window. The app shows a Dock icon while it's open and goes back to being a menu
/// bar app when it closes.
@MainActor
final class CalendarWindowController: NSObject, NSWindowDelegate {
    private let model: CalendarWindowModel
    private var window: NSWindow?

    init(model: CalendarWindowModel) {
        self.model = model
    }

    /// Opens the window, on `meeting`'s day with it selected when given.
    func show(selecting meeting: Meeting? = nil) {
        let window = window ?? makeWindow()
        self.window = window
        if let meeting {
            model.show(meeting)
        } else {
            model.reload()
        }
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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
