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
        let hostingView = FirstClickHostingView(rootView: AlertScreen(model: model))
        // The view fills whatever it's given; without this the hosting view would size the panel to the card.
        hostingView.sizingOptions = []
        contentView = hostingView
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { true }
}

/// The pill stack or the notes card in the top-right corner of the main screen. It never takes focus.
final class CornerPanel<Content: View>: OverlayPanel {
    private let hostingView: FirstClickHostingView<Content>

    init(rootView: Content) {
        hostingView = FirstClickHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        super.init(level: .statusBar)
        allowsToolTipsWhenApplicationIsInactive = true
        contentView = hostingView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Pins the panel `offset` points below the menu bar at the right edge of the screen with the menu bar.
    func place(size: CGSize, below offset: CGFloat = 0) {
        guard let screen = NSScreen.screens.first else { return }
        setFrame(Self.cornerFrame(size: size, below: offset, in: screen.visibleFrame), display: true)
    }

    static func cornerFrame(size: CGSize, below offset: CGFloat, in visible: NSRect) -> NSRect {
        NSRect(x: visible.maxX - size.width, y: visible.maxY - offset - size.height, width: size.width, height: size.height)
    }
}

/// Buttons in a panel that never becomes key would otherwise need a first click to focus the panel.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
