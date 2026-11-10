import AppKit
import MeetCueCore
import Observation

/// Shows and hides the overlay panels to match `OverlayModel`. Each overlay surface gets one
/// `sync` method. The pills and the notes card share the top-right corner, the card below the
/// pills, until the user drags either one. The pills return to the corner once they've all closed,
/// and each new card starts in the corner, full size. The alert goes on the displays the settings
/// choose and plays the alert sound when it appears.
@MainActor
final class OverlayController {
    private let model: OverlayModel
    private var alertPanels: [AlertPanel] = []
    private var alertPanelDisplays: AlertDisplays?
    private var shownStates: [OccurrenceID: OverlayState] = [:]
    private let pillPanel: CornerPanel<PillStack>
    private let cardPanel: CornerPanel<NotesCardStack>
    private let cardLayout = NotesCardLayout()
    private var cardMeetingID: OccurrenceID?
    private var cardDrag = PanelDrag()
    private var pillDrag = PanelDrag()
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

    /// The displays that get an alert panel: all of them, or the one with the menu bar.
    static func alertScreens<Screen>(_ screens: [Screen], displays: AlertDisplays) -> [Screen] {
        displays == .main ? Array(screens.prefix(1)) : screens
    }

    /// Whether a meeting entered the alert from waiting or a snooze, which is when the sound
    /// plays. `shown` and `wanted` hold the meetings in the alert or as pills at the last sync and
    /// now. Expanding a pill and rebuilding the panels for a display change are silent.
    static func alertChimes(from shown: [OccurrenceID: OverlayState], to wanted: [OccurrenceID: OverlayState]) -> Bool {
        wanted.contains { id, state in state == .alert && shown[id] != .alert && shown[id] != .pill }
    }

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
        let pillDrag = PillDragRelay()
        pillPanel = CornerPanel(rootView: PillStack(model: model, drag: { pillDrag.drag($0) }))
        cardPanel = CornerPanel(rootView: NotesCardStack(model: model, layout: cardLayout))
        pillDrag.drag = { [weak self] translation in self?.dragPills(by: translation) }
        cardLayout.drag = { [weak self] translation in self?.dragCard(by: translation) }
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
            _ = model.settings.alertDisplays
            _ = model.pillMeetings
            _ = model.notice
            _ = model.notesCardMeeting
            _ = cardLayout.size
        } onChange: { [weak self] in
            Task { @MainActor in self?.track() }
        }
        sync()
    }

    private func sync() {
        syncAlert()
        syncPill()
        syncNotesCard()
    }

    private func syncAlert() {
        let ids = Set(model.alertMeetings.map(\.id))
        var states: [OccurrenceID: OverlayState] = [:]
        for meeting in model.alertMeetings { states[meeting.id] = .alert }
        for meeting in model.pillMeetings { states[meeting.id] = .pill }
        if Self.alertChimes(from: shownStates, to: states) {
            model.settings.alertSound.play()
        }
        shownStates = states
        let displays = model.settings.alertDisplays
        if !ids.isEmpty && (alertPanels.isEmpty || alertPanelDisplays != displays) {
            closeAlert()
            showAlert(on: displays)
        } else if ids.isEmpty && !alertPanels.isEmpty {
            closeAlert()
        }
    }

    private func showAlert(on displays: AlertDisplays) {
        let screens = Self.alertScreens(NSScreen.screens, displays: displays)
        guard !screens.isEmpty else { return }
        alertPanels = screens.map { AlertPanel(screen: $0, model: model) }
        alertPanelDisplays = displays
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
        syncNotesCard()
    }

    private func syncPill() {
        if model.pillMeetings.isEmpty && model.notice == nil {
            pillPanel.orderOut(nil)
            pillDrag.reset()
        } else {
            placePills()
            pillPanel.orderFrontRegardless()
        }
    }

    private func placePills() {
        let rows = model.pillMeetings.count + (model.notice == nil ? 0 : 1)
        let size = PillStackContent.size(rows: rows)
        if let topRight = pillDrag.topRight {
            pillPanel.place(size: size, topRight: topRight, margin: PillStackContent.margin)
        } else {
            pillPanel.place(size: size)
        }
    }

    private func dragPills(by translation: CGSize?) {
        pillDrag.update(translation, mouse: NSEvent.mouseLocation, frame: pillPanel.frame)
        placePills()
        // A card waiting under the pills moves up into the corner once they leave it.
        if cardDrag.topRight == nil { placeNotesCard() }
    }

    private func syncNotesCard() {
        let meetingID = model.notesCardMeeting?.id
        if meetingID != cardMeetingID {
            cardMeetingID = meetingID
            cardDrag.reset()
            if cardLayout.isCompact { cardLayout.isCompact = false }
        }
        if meetingID == nil {
            cardPanel.orderOut(nil)
        } else {
            placeNotesCard()
            cardPanel.orderFrontRegardless()
        }
    }

    private func dragCard(by translation: CGSize?) {
        cardDrag.update(translation, mouse: NSEvent.mouseLocation, frame: cardPanel.frame)
        if translation != nil { placeNotesCard() }
    }

    /// Below the pills when they show in the corner, with the pills' spacing between the visible
    /// shapes, or where the user dragged it. Until the card reports its size, a typical one is assumed.
    private func placeNotesCard() {
        let pillsHeight = pillPanel.isVisible && pillDrag.topRight == nil && cardDrag.topRight == nil
            ? pillPanel.frame.height - PillStackContent.margin - NotesCardContent.margin + PillStackContent.spacing
            : 0
        if let screen = NSScreen.screens.first {
            let room = screen.visibleFrame.height - pillsHeight - 2 * NotesCardContent.margin - NotesCardContent.chromeHeight
            let maxNotesHeight = max(120, min(NotesCardContent.maxNotesHeight, room))
            if cardLayout.maxNotesHeight != maxNotesHeight { cardLayout.maxNotesHeight = maxNotesHeight }
        }
        let size = cardLayout.size
        let fitted = size.width > 0 && size.height > 0
            ? size
            : CGSize(width: NotesCardContent.width + 2 * NotesCardContent.margin, height: 240)
        if let cardTopRight = cardDrag.topRight {
            cardPanel.place(size: fitted, topRight: cardTopRight, margin: NotesCardContent.margin)
        } else {
            cardPanel.place(size: fitted, below: pillsHeight)
        }
    }
}

/// Lets the pill stack's view, created before the controller finishes initializing, reach the
/// controller's drag handler.
@MainActor
private final class PillDragRelay {
    var drag: (CGSize?) -> Void = { _ in }
}

extension AlertSound {
    func play() {
        guard self != .none else { return }
        NSSound(named: NSSound.Name(title))?.play()
    }
}
