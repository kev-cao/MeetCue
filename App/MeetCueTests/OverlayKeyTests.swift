import AppKit
import Testing
@testable import MeetCue

@MainActor
struct OverlayKeyTests {
    @Test func escapeWithCapsLockIsEscape() {
        #expect(OverlayController.overlayKey(keyCode: 53, modifiers: [.capsLock]) == .escape)
    }

    @Test func returnWithCapsLockIsReturn() {
        #expect(OverlayController.overlayKey(keyCode: 36, modifiers: [.capsLock]) == .return)
    }

    @Test func keypadEnterIsReturn() {
        #expect(OverlayController.overlayKey(keyCode: 76, modifiers: [.numericPad, .function]) == .return)
    }

    @Test func escapeWithCommandIsIgnored() {
        #expect(OverlayController.overlayKey(keyCode: 53, modifiers: [.command]) == nil)
    }

    @Test func otherKeysAreIgnored() {
        #expect(OverlayController.overlayKey(keyCode: 0, modifiers: []) == nil)
    }
}
