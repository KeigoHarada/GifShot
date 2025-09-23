import Foundation
import AppKit
import Carbon

struct HotkeyConfig {
  let keyCode: UInt32
  let modifiersCarbon: UInt32
}

final class HotkeyStore {
  private let keyKeyCode = "hotkey.keyCode"
  private let keyModifiers = "hotkey.modifiers"
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func load() -> HotkeyConfig {
    let storedKey = defaults.object(forKey: keyKeyCode) as? UInt32
    let storedMod = defaults.object(forKey: keyModifiers) as? UInt32
    return HotkeyConfig(
      keyCode: storedKey ?? UInt32(kVK_ANSI_6),
      modifiersCarbon: storedMod ?? UInt32(cmdKey | shiftKey)
    )
  }

  func save(_ config: HotkeyConfig) {
    defaults.set(config.keyCode, forKey: keyKeyCode)
    defaults.set(config.modifiersCarbon, forKey: keyModifiers)
  }

  static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var result: UInt32 = 0
    if flags.contains(.command) { result |= UInt32(cmdKey) }
    if flags.contains(.shift) { result |= UInt32(shiftKey) }
    if flags.contains(.option) { result |= UInt32(optionKey) }
    if flags.contains(.control) { result |= UInt32(controlKey) }
    return result
  }
}
