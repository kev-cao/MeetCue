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

    init(model: MenuBarModel, dropdown: some View) {
        self.model = model
        label = PassthroughHostingView(rootView: MenuBarLabel(model: model))
        super.init()

        if let button = statusItem.button {
            button.addSubview(label)
            button.target = self
            button.action = #selector(togglePopover)
        }
        let controller = NSHostingController(rootView: AnyView(dropdown))
        controller.sizingOptions = .preferredContentSize
        popover.contentViewController = controller
        popover.behavior = .transient

        resize()
        trackSize()
        ticker = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.tick() }
        }
    }

    private func resize() {
        let size = label.fittingSize
        let height = statusItem.button?.bounds.height ?? size.height
        label.frame = NSRect(x: 0, y: (height - size.height) / 2, width: size.width, height: size.height)
        statusItem.length = size.width
    }

    /// The label's width changes with its text, and the status item doesn't size itself to a subview.
    private func trackSize() {
        withObservationTracking {
            _ = model.display
            _ = model.needsAccess
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
        model.tick()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
    }
}
