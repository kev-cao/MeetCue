import AppKit

/// Shows the Dock icon while any of the app's windows is open, and makes the app a menu bar app
/// again (spec 5) once the last one closes. Every window reports here, so closing one doesn't hide
/// the icon while another is still open.
@MainActor
final class DockPresence {
    enum Window: Hashable {
        case calendar
        case settings
    }

    private var openWindows: Set<Window> = []
    private let setPolicy: @MainActor (NSApplication.ActivationPolicy) -> Void

    init(setPolicy: @escaping @MainActor (NSApplication.ActivationPolicy) -> Void = { _ = NSApp.setActivationPolicy($0) }) {
        self.setPolicy = setPolicy
    }

    func opened(_ window: Window) {
        guard openWindows.insert(window).inserted, openWindows.count == 1 else { return }
        setPolicy(.regular)
    }

    func closed(_ window: Window) {
        guard openWindows.remove(window) != nil, openWindows.isEmpty else { return }
        setPolicy(.accessory)
    }
}
