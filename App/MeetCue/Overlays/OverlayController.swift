import AppKit
import Observation

/// Shows and hides the overlay panels to match `OverlayModel`. Each overlay surface gets one
/// `sync` method; the notes card will add another `CornerPanel` and its own `sync`.
@MainActor
final class OverlayController {
    private let model: OverlayModel
    private var alertPanels: [AlertPanel] = []
    private let pillPanel: CornerPanel<PillStack>
    private var keyMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?

    enum OverlayKey: Equatable {
        case escape
        case `return`
    }

    private static let escape: UInt16 = 53
    private static let returnKey: UInt16 = 36
    private static let keypadEnter: UInt16 = 76
    private static let blockingModifiers: NSEvent.ModifierFlags = [.shift, .control, .option, .command]

    /// Caps Lock, keypad, function and help flags don't count as modifiers.
    static func overlayKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> OverlayKey? {
        guard modifiers.intersection(blockingModifiers).isEmpty else { return nil }
        switch keyCode {
        case escape: return .escape
        case returnKey, keypadEnter: return .return
        default: return nil
        }
    }

    init(model: OverlayModel) {
        self.model = model
        pillPanel = CornerPanel(rootView: PillStack(model: model))
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
        track()
    }

    /// Syncs the panels and calls itself again on the next change.
    private func track() {
        withObservationTracking {
            _ = model.alertMeetings
            _ = model.pillMeetings
            _ = model.notice
        } onChange: { [weak self] in
            Task { @MainActor in self?.track() }
        }
        sync()
    }

    private func sync() {
        syncAlert()
        syncPill()
    }

    private func syncAlert() {
        let wanted = !model.alertMeetings.isEmpty
        if wanted && alertPanels.isEmpty {
            showAlert()
        } else if !wanted && !alertPanels.isEmpty {
            closeAlert()
        }
    }

    private func showAlert() {
        guard !NSScreen.screens.isEmpty else { return }
        alertPanels = NSScreen.screens.map { AlertPanel(screen: $0, model: model) }
        for panel in alertPanels {
            panel.orderFrontRegardless()
        }
        alertPanels.first?.makeKeyAndOrderFront(nil)
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let keyCode = event.keyCode
                let modifiers = event.modifierFlags
                let inAlert = event.window is AlertPanel
                let handled = MainActor.assumeIsolated {
                    inAlert && (self?.handleKey(keyCode, modifiers: modifiers) ?? false)
                }
                // Consuming the event stops the system beep and any default handling.
                return handled ? nil : event
            }
        }
        if activationObserver == nil {
            activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.reclaimKey() }
            }
        }
    }

    /// Lets `esc` and `↩` reach the alert after another app is activated, e.g. with ⌘-Tab.
    private func reclaimKey() {
        guard let panel = alertPanels.first else { return }
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    private func closeAlert() {
        for panel in alertPanels {
            panel.orderOut(nil)
        }
        alertPanels = []
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
    }

    private func handleKey(_ keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard !alertPanels.isEmpty, let key = Self.overlayKey(keyCode: keyCode, modifiers: modifiers) else { return false }
        switch key {
        case .escape:
            model.pressEscape()
        case .return:
            model.pressReturn()
        }
        return true
    }

    private func screensChanged() {
        closeAlert()
        syncAlert()
        syncPill()
    }

    private func syncPill() {
        if model.pillMeetings.isEmpty && model.notice == nil {
            pillPanel.orderOut(nil)
        } else {
            let rows = model.pillMeetings.count + (model.notice == nil ? 0 : 1)
            pillPanel.place(size: PillStackContent.size(rows: rows))
            pillPanel.orderFrontRegardless()
        }
    }
}
