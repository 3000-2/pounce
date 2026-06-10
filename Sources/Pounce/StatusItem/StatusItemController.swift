import AppKit

@MainActor
final class StatusItemController {
    private let item: NSStatusItem
    private let titleItem: NSMenuItem
    private let ocrItem: NSMenuItem
    private let hotkeyMenu = NSMenu()
    private let onSelectHotkey: (HotkeyPreference) -> Void
    private let onToggleOCR: (Bool) -> Void
    private let onQuit: () -> Void

    init(
        currentHotkey: HotkeyPreference,
        onSelectHotkey: @escaping (HotkeyPreference) -> Void,
        onToggleOCR: @escaping (Bool) -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onSelectHotkey = onSelectHotkey
        self.onToggleOCR = onToggleOCR
        self.onQuit = onQuit

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "cursorarrow.rays",
                                     accessibilityDescription: "Pounce")

        titleItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        ocrItem = NSMenuItem(title: "OCR 폴백 (화면 기록 필요)",
                             action: #selector(toggleOCR), keyEquivalent: "")
        ocrItem.state = .off

        let menu = NSMenu()
        menu.addItem(titleItem)
        menu.addItem(.separator())

        let hotkeyRoot = NSMenuItem(title: "활성화 단축키", action: nil, keyEquivalent: "")
        for preset in HotkeyPreference.presets {
            let entry = NSMenuItem(title: preset.name, action: #selector(selectHotkey(_:)), keyEquivalent: "")
            entry.target = self
            hotkeyMenu.addItem(entry)
        }
        hotkeyRoot.submenu = hotkeyMenu
        menu.addItem(hotkeyRoot)

        ocrItem.target = self
        menu.addItem(ocrItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "종료", action: #selector(quitTapped), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu

        reflect(hotkey: currentHotkey)
    }

    func reflect(hotkey: HotkeyPreference) {
        titleItem.title = "Pounce — \(hotkey.name) 힌트 · ⌘⇧S 스크롤"
        for entry in hotkeyMenu.items {
            entry.state = entry.title == hotkey.name ? .on : .off
        }
    }

    @objc private func selectHotkey(_ sender: NSMenuItem) {
        guard let preset = HotkeyPreference.presets.first(where: { $0.name == sender.title }) else { return }
        reflect(hotkey: preset)
        onSelectHotkey(preset)
    }

    @objc private func toggleOCR() {
        let enabled = ocrItem.state != .on
        ocrItem.state = enabled ? .on : .off
        onToggleOCR(enabled)
    }

    @objc private func quitTapped() {
        onQuit()
    }
}
