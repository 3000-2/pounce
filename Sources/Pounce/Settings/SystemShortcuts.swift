import Carbon
import Foundation

/// System shortcuts (Spotlight, Mission Control, …) win over Carbon hot keys
/// silently — registration succeeds but never fires — so conflicts must be
/// detected by reading the symbolic-hotkeys preferences up front.
enum SystemShortcuts {
    static func conflicts(keyCode: UInt32, carbonModifiers: UInt32) -> Bool {
        guard let entries = UserDefaults(suiteName: "com.apple.symbolichotkeys")?
            .dictionary(forKey: "AppleSymbolicHotKeys") else { return false }

        for value in entries.values {
            guard let entry = value as? [String: Any],
                  (entry["enabled"] as? NSNumber)?.boolValue == true,
                  let inner = entry["value"] as? [String: Any],
                  let parameters = inner["parameters"] as? [NSNumber],
                  parameters.count >= 3 else { continue }

            let systemKeyCode = parameters[1].intValue
            let systemModifiers = carbon(fromCocoaRaw: parameters[2].uintValue)
            if systemKeyCode == Int(keyCode), systemModifiers == carbonModifiers {
                return true
            }
        }
        return false
    }

    private static func carbon(fromCocoaRaw raw: UInt) -> UInt32 {
        var modifiers: UInt32 = 0
        if raw & (1 << 18) != 0 { modifiers |= UInt32(controlKey) }
        if raw & (1 << 19) != 0 { modifiers |= UInt32(optionKey) }
        if raw & (1 << 17) != 0 { modifiers |= UInt32(shiftKey) }
        if raw & (1 << 20) != 0 { modifiers |= UInt32(cmdKey) }
        return modifiers
    }
}
