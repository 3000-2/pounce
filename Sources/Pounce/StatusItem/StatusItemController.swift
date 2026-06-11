import AppKit
import Carbon

@MainActor
final class StatusItemController {
    private let item: NSStatusItem
    private let hintItem: NSMenuItem
    private let scrollItem: NSMenuItem
    private let launchItem: NSMenuItem
    private let onOpenSettings: () -> Void
    private let onToggleLaunchAtLogin: () -> Void
    private let onQuit: () -> Void

    init(
        onOpenSettings: @escaping () -> Void,
        onToggleLaunchAtLogin: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onOpenSettings = onOpenSettings
        self.onToggleLaunchAtLogin = onToggleLaunchAtLogin
        self.onQuit = onQuit

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "cursorarrow.rays",
                                     accessibilityDescription: "Pounce")

        hintItem = NSMenuItem(title: "힌트 모드", action: nil, keyEquivalent: "")
        scrollItem = NSMenuItem(title: "스크롤 모드", action: nil, keyEquivalent: "")
        launchItem = NSMenuItem(title: "로그인 시 열기",
                                action: #selector(launchToggled), keyEquivalent: "")

        let menu = NSMenu()
        menu.addItem(hintItem)
        menu.addItem(scrollItem)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "설정…", action: #selector(settingsTapped), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        launchItem.target = self
        menu.addItem(launchItem)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Pounce 종료", action: #selector(quitTapped), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
    }

    func reflect(hint: Hotkey, scroll: Hotkey) {
        apply(hint, to: hintItem, base: "힌트 모드")
        apply(scroll, to: scrollItem, base: "스크롤 모드")
    }

    func reflectLaunchAtLogin(_ enabled: Bool) {
        launchItem.state = enabled ? .on : .off
    }

    /// Informational rows: the combo renders as a native right-aligned key
    /// equivalent when representable, otherwise falls back into the title.
    private func apply(_ hotkey: Hotkey, to menuItem: NSMenuItem, base: String) {
        if let character = Self.keyEquivalentCharacter(for: hotkey.keyCode) {
            menuItem.title = base
            menuItem.keyEquivalent = character
            menuItem.keyEquivalentModifierMask = Self.cocoaFlags(fromCarbon: hotkey.modifiers)
        } else {
            menuItem.title = "\(base): \(hotkey.display)"
            menuItem.keyEquivalent = ""
        }
    }

    private static func keyEquivalentCharacter(for keyCode: UInt32) -> String? {
        if Int(keyCode) == kVK_Space { return " " }
        guard let name = HotkeyRecorderButton.keyNames[Int(keyCode)], name.count == 1 else {
            return nil
        }
        return name.lowercased()
    }

    private static func cocoaFlags(fromCarbon modifiers: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    @objc private func settingsTapped() {
        onOpenSettings()
    }

    @objc private func launchToggled() {
        onToggleLaunchAtLogin()
    }

    @objc private func quitTapped() {
        onQuit()
    }
}
