import AppKit
import Carbon.HIToolbox

/// System-wide shortcuts that work while another app is active, through Carbon's hot key API,
/// which needs no Accessibility permission.
@MainActor
final class GlobalHotKeys {
    private var actions: [UInt32: @MainActor () -> Void] = [:]
    private var hotKeys: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    private static let signature: OSType = 0x4D_43_75_65 // "MCue"

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &id
            )
            guard status == noErr else { return status }
            let hotKeys = Unmanaged<GlobalHotKeys>.fromOpaque(userData).takeUnretainedValue()
            // Carbon delivers hot key events on the main thread.
            MainActor.assumeIsolated { hotKeys.fire(id.id) }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    /// Registers ⌘⌥ + `keyCode` (a `kVK_` constant). Does nothing if another app holds the shortcut.
    func register(keyCode: Int, action: @escaping @MainActor () -> Void) {
        let id = UInt32(actions.count + 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(cmdKey | optionKey), EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { return }
        hotKeys.append(ref)
        actions[id] = action
    }

    private func fire(_ id: UInt32) {
        actions[id]?()
    }
}
