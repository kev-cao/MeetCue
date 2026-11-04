import AppKit
import SwiftUI

/// A borderless, transparent panel on every Space and above full-screen apps. It's non-activating
/// so showing it doesn't switch Spaces or pull the user out of a full-screen app.
class OverlayPanel: NSPanel {
    init(level: NSWindow.Level) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
    }
}

/// The full-screen alert on one display. It becomes key so `esc` and `↩` reach the app without
/// activating it.
final class AlertPanel: OverlayPanel {
    init(screen: NSScreen, model: OverlayModel) {
        super.init(level: .screenSaver)
        let hostingView = NSHostingView(rootView: AlertScreen(model: model))
        // The view fills whatever it's given; without this the hosting view would size the panel to the card.
        hostingView.sizingOptions = []
        contentView = hostingView
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { true }
}

/// The pill stack in the top-right corner of the main screen. It never takes focus.
final class CornerPanel<Content: View>: OverlayPanel {
    private let hostingView: FirstClickHostingView<Content>

    init(rootView: Content) {
        hostingView = FirstClickHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        super.init(level: .statusBar)
        contentView = hostingView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Pins the panel below the menu bar at the right edge of the screen with the menu bar.
    func place(size: CGSize) {
        guard let screen = NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        setFrame(NSRect(x: visible.maxX - size.width, y: visible.maxY - size.height, width: size.width, height: size.height), display: true)
    }
}

/// Buttons in a panel that never becomes key would otherwise need a first click to focus the panel.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
