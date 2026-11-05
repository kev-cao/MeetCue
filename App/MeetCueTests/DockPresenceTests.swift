import AppKit
import Testing
@testable import MeetCue

@MainActor
struct DockPresenceTests {
    @Test func showsTheDockIconWhileAnyWindowIsOpen() {
        var policies: [NSApplication.ActivationPolicy] = []
        let dock = DockPresence { policies.append($0) }
        dock.opened(.calendar)
        dock.opened(.settings)
        dock.opened(.calendar)
        #expect(policies == [.regular])
        dock.closed(.calendar)
        #expect(policies == [.regular])
        dock.closed(.settings)
        #expect(policies == [.regular, .accessory])
        dock.opened(.settings)
        #expect(policies == [.regular, .accessory, .regular])
    }

    @Test func closingAWindowThatWasntOpenChangesNothing() {
        var policies: [NSApplication.ActivationPolicy] = []
        let dock = DockPresence { policies.append($0) }
        dock.closed(.settings)
        #expect(policies.isEmpty)
    }
}
