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

    private static let escape: UInt16 = 53
    private static let returnKey: UInt16 = 36
    private static let keypadEnter: UInt16 = 76

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
        alertPanels = NSScreen.screens.map { AlertPanel(screen: $0, model: model) }
        for panel in alertPanels {
            panel.orderFrontRegardless()
        }
        alertPanels.first?.makeKeyAndOrderFront(nil)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = event.keyCode
            let hasModifiers = !event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty
            let handled = MainActor.assumeIsolated { self?.handleKey(keyCode, hasModifiers: hasModifiers) ?? false }
            // Handled keys are swallowed so they don't also press the focused button.
            return handled ? nil : event
        }
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
    }

    private func handleKey(_ keyCode: UInt16, hasModifiers: Bool) -> Bool {
        guard !alertPanels.isEmpty, !hasModifiers else { return false }
        switch keyCode {
        case Self.escape:
            model.pressEscape()
        case Self.returnKey, Self.keypadEnter:
            model.pressReturn()
        default:
            return false
        }
        return true
    }

    private func screensChanged() {
        if !alertPanels.isEmpty {
            closeAlert()
            showAlert()
        }
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
