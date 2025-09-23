import Foundation
import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let onPressed: () -> Void
    private let store = HotkeyStore()

    init(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed
    }

    @discardableResult
    func registerFromStore() -> Bool {
        let cfg = store.load()
        return register(keyCode: cfg.keyCode, modifiers: cfg.modifiersCarbon)
    }

    @discardableResult
    func register(keyCode: UInt32 = UInt32(kVK_ANSI_6), modifiers: UInt32 = UInt32(cmdKey | shiftKey)) -> Bool {
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let statusInstall = InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &eventHandlerRef)
        guard statusInstall == noErr else {
            Log.hotkey.error("InstallEventHandler failed: \(statusInstall)")
            return false
        }

        let hotKeyID = EventHotKeyID(signature: OSType("GFSH".fourCharCode), id: UInt32(1))
        let statusRegister = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if statusRegister == noErr {
            Log.hotkey.info("Registered hotkey: keyCode=\(keyCode) mod=\(modifiers)")
            return true
        } else {
            Log.hotkey.error("RegisterEventHotKey failed: \(statusRegister)")
            return false
        }
    }

    func saveAndRegister(keyCode: UInt32, modifiers: UInt32) {
        store.save(HotkeyConfig(keyCode: keyCode, modifiersCarbon: modifiers))
        _ = register(keyCode: keyCode, modifiers: modifiers)
    }

    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            Log.hotkey.info("Unregistered hotkey")
            self.hotKeyRef = nil
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        unregister()
    }

    fileprivate func handleHotKey() {
        Log.hotkey.info("Hotkey pressed")
        onPressed()
    }
}

private func hotKeyEventHandler(callRef: EventHandlerCallRef?, eventRef: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData = userData else { return noErr }
    let instance = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    instance.handleHotKey()
    return noErr
}

private extension String {
    var fourCharCode: FourCharCode {
        var result: FourCharCode = 0
        for character in utf16 {
            result = (result << 8) + FourCharCode(character)
        }
        return result
    }
}
