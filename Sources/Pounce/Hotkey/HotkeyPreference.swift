import Carbon
import Foundation

struct HotkeyPreference: Equatable {
    let name: String
    let keyCode: UInt32
    let modifiers: UInt32

    /// ⌘⇧Space leads because bare ⌥Space and ⌃Space collide with Spotlight
    /// (some setups) and input-source switching respectively — they stay
    /// available for users whose systems have those freed up.
    static let presets: [HotkeyPreference] = [
        HotkeyPreference(name: "⌘⇧Space", keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey)),
        HotkeyPreference(name: "⌥Space", keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)),
        HotkeyPreference(name: "⌃⌥Space", keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey)),
        HotkeyPreference(name: "⌘⇧J", keyCode: UInt32(kVK_ANSI_J), modifiers: UInt32(cmdKey | shiftKey)),
    ]

    static let `default` = presets[0]

    private static let keyCodeKey = "hotkeyKeyCode"
    private static let modifiersKey = "hotkeyModifiers"

    static func load(from defaults: UserDefaults = .standard) -> HotkeyPreference {
        guard defaults.object(forKey: keyCodeKey) != nil else { return .default }
        let keyCode = UInt32(defaults.integer(forKey: keyCodeKey))
        let modifiers = UInt32(defaults.integer(forKey: modifiersKey))
        return presets.first { $0.keyCode == keyCode && $0.modifiers == modifiers } ?? .default
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(Int(keyCode), forKey: Self.keyCodeKey)
        defaults.set(Int(modifiers), forKey: Self.modifiersKey)
    }
}
