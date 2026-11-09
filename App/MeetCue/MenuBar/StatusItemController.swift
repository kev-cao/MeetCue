import AppKit
import Observation
import SwiftUI

/// Lets clicks fall through to the status item button underneath.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// The dropdown's window: a borderless panel with the system menu material, under the status
/// item like other menu bar items' menus. It's non-activating, so it takes typing without
/// pulling the user out of the app they're in.
final class DropdownPanel: NSPanel {
    static let cornerRadius: CGFloat = 12
    /// The gap between the menu bar and the panel.
    static let gap: CGFloat = 4
    /// The closest the panel comes to the screen's sides.
    static let inset: CGFloat = 6

    var onCancel: () -> Void = {}

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    /// Replaces the content, so each opening starts fresh like a menu: an empty topic field
    /// with the focus in it.
    func show(_ content: some View) {
        let controller = NSHostingController(rootView: content.background(MenuMaterial(cornerRadius: Self.cornerRadius)))
        controller.sizingOptions = .preferredContentSize
        contentViewController = controller
        setContentSize(controller.view.fittingSize)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }

    /// A frame of `size` hanging from the bottom of the menu bar at `item`'s left edge, moved left
    /// when it would pass the right side of `screen`.
    static func frame(size: CGSize, below item: NSRect, in screen: NSRect) -> NSRect {
        let x = max(screen.minX + inset, min(item.minX, screen.maxX - inset - size.width))
        return NSRect(x: x, y: item.minY - gap - size.height, width: size.width, height: size.height)
    }
}

/// The material and rounded shape of a system menu.
private struct MenuMaterial: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

@MainActor
final class StatusItemController: NSObject, NSWindowDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = DropdownPanel()
    private var dropdown = AnyView(EmptyView())
    private let model: MenuBarModel
    private let label: PassthroughHostingView<MenuBarLabel>
    private var ticker: Timer?
    private var clickMonitors: [Any] = []

    init<Dropdown: View>(model: MenuBarModel, dropdown: (_ dismiss: @escaping @MainActor () -> Void) -> Dropdown) {
        self.model = model
        label = PassthroughHostingView(rootView: MenuBarLabel(model: model))
        super.init()
        self.dropdown = AnyView(dropdown { [weak self] in self?.closeDropdown() })
        panel.onCancel = { [weak self] in self?.closeDropdown() }
        panel.delegate = self

        if let button = statusItem.button {
            button.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                label.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            ])
            label.setAccessibilityElement(false)
            button.target = self
            button.action = #selector(toggleDropdown)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        resize()
        trackSize()
        let nextBoundary = Date(timeIntervalSinceReferenceDate: (Date().timeIntervalSinceReferenceDate / 10).rounded(.up) * 10)
        let timer = Timer(fire: nextBoundary, interval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.tick() }
        }
        // The .common mode keeps the timer firing while a menu tracks events.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func resize() {
        label.layoutSubtreeIfNeeded()
        let width = label.fittingSize.width
        if statusItem.length != width {
            statusItem.length = width
        }
        statusItem.button?.setAccessibilityLabel(model.accessibilityLabel)
    }

    /// The label's width changes with its text, and the status item doesn't size itself to a subview.
    private func trackSize() {
        withObservationTracking {
            _ = model.display
            _ = model.needsAccess
            _ = model.accessibilityLabel
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.resize()
                self?.trackSize()
            }
        }
    }

    @objc private func toggleDropdown() {
        if panel.isVisible {
            closeDropdown()
            return
        }
        model.store.refresh()
        model.tick()
        model.showsSimulateItem = NSApp.currentEvent?.modifierFlags.contains(.option) ?? false
        panel.show(dropdown)
        place()
        panel.makeKeyAndOrderFront(nil)
        watchClicks()
        statusItem.button?.highlight(true)
    }

    private func closeDropdown() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        panel.contentViewController = nil
        for monitor in clickMonitors {
            NSEvent.removeMonitor(monitor)
        }
        clickMonitors = []
        statusItem.button?.highlight(false)
    }

    private func place() {
        guard let button = statusItem.button, let window = button.window else { return }
        let item = window.convertToScreen(button.convert(button.bounds, to: nil))
        guard let screen = window.screen ?? NSScreen.screens.first else { return }
        panel.setFrame(DropdownPanel.frame(size: panel.frame.size, below: item, in: screen.frame), display: true)
    }

    /// Clicks in other apps, or in MeetCue's other windows, close the dropdown. Clicks on the
    /// status item are left to `toggleDropdown`, and clicks in a menu opened from the dropdown
    /// (such as quiet mode's), which sits at the pop-up menu level, leave it open.
    private func watchClicks() {
        guard clickMonitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.closeDropdown() }
        }) {
            clickMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let window = event.window
            MainActor.assumeIsolated {
                guard let self, window !== self.panel, window !== self.statusItem.button?.window,
                      (window?.level ?? .normal) < .popUpMenu else { return }
                self.closeDropdown()
            }
            return event
        }) {
            clickMonitors.append(local)
        }
    }

    /// Keeps the top edge under the menu bar as the content changes height.
    func windowDidResize(_ notification: Notification) {
        if panel.isVisible { place() }
        panel.invalidateShadow()
    }

    func windowDidResignKey(_ notification: Notification) {
        closeDropdown()
    }
}
