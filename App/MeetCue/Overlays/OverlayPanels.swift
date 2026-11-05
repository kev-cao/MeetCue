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

/// The pill stack or the notes card, in the top-right corner of the main screen or, for the notes
/// card, where the user drags it. It never takes focus.
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

    /// Puts the panel's top-right corner at `topRight`, kept on the screen under its center.
    /// `margin` is the transparent border around the content, which may go past the screen's edge.
    func place(size: CGSize, topRight: NSPoint, margin: CGFloat) {
        let center = NSPoint(x: topRight.x - size.width / 2, y: topRight.y - size.height / 2)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.screens.first else { return }
        setFrame(Self.anchoredFrame(size: size, topRight: topRight, margin: margin, in: screen.visibleFrame), display: true)
    }

    /// A frame of `size` with its top-right corner at `topRight`, moved inside `visible` grown by
    /// `margin`. A frame taller than that keeps its top on screen.
    static func anchoredFrame(size: CGSize, topRight: NSPoint, margin: CGFloat, in visible: NSRect) -> NSRect {
        let bounds = visible.insetBy(dx: -margin, dy: -margin)
        let x = min(max(topRight.x - size.width, bounds.minX), bounds.maxX - size.width)
        let y = min(max(topRight.y - size.height, bounds.minY), bounds.maxY - size.height)
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}

/// Buttons in a panel that never becomes key would otherwise need a first click to focus the panel.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
