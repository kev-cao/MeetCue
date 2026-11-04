import AppKit
import Observation
import SwiftUI

/// Lets clicks fall through to the status item button underneath.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let model: MenuBarModel
    private let label: PassthroughHostingView<MenuBarLabel>
    private var ticker: Timer?

    init<Dropdown: View>(model: MenuBarModel, dropdown: (_ dismiss: @escaping @MainActor () -> Void) -> Dropdown) {
        self.model = model
        label = PassthroughHostingView(rootView: MenuBarLabel(model: model))
        super.init()

        if let button = statusItem.button {
            button.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                label.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            ])
            label.setAccessibilityElement(false)
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        let controller = NSHostingController(rootView: AnyView(dropdown { [weak self] in self?.popover.performClose(nil) }))
        controller.sizingOptions = .preferredContentSize
        popover.contentViewController = controller
        popover.behavior = .transient

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

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        model.store.refresh()
        model.tick()
        model.showsSimulateItem = NSApp.currentEvent?.modifierFlags.contains(.option) ?? false
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
    }
}
