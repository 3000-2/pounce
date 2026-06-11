import Carbon
import Foundation

struct Hotkey: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var display: String

    func conflicts(with other: Hotkey) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }
}

enum HotkeyRole: String, CaseIterable {
    case hint
    case scroll

    var label: String {
        switch self {
        case .hint: return "힌트 모드"
        case .scroll: return "스크롤 모드"
        }
    }

    var defaultHotkey: Hotkey {
        switch self {
        case .hint:
            return Hotkey(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(optionKey | shiftKey), display: "⌥⇧F")
        case .scroll:
            return Hotkey(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey | shiftKey), display: "⇧⌘S")
        }
    }
}

enum HotkeyStore {
    static func load(_ role: HotkeyRole, defaults: UserDefaults = .standard) -> Hotkey {
        guard let stored = defaults.dictionary(forKey: key(role)),
              let keyCode = stored["keyCode"] as? Int,
              let modifiers = stored["modifiers"] as? Int,
              let display = stored["display"] as? String else {
            return role.defaultHotkey
        }
        return Hotkey(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers), display: display)
    }

    static func save(_ hotkey: Hotkey, for role: HotkeyRole, defaults: UserDefaults = .standard) {
        defaults.set([
            "keyCode": Int(hotkey.keyCode),
            "modifiers": Int(hotkey.modifiers),
            "display": hotkey.display,
        ], forKey: key(role))
    }

    private static func key(_ role: HotkeyRole) -> String {
        "hotkey.\(role.rawValue)"
    }
}
