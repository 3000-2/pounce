import AppKit
import Carbon

/// Click to arm, then the next key combination is reported via `onRecord`.
/// Capture happens in the responder chain (`keyDown`/`performKeyEquivalent`)
/// rather than an event monitor — monitors silently miss events when an
/// accessory app fails to become active, and ⌘-combos arrive as key
/// equivalents. Registered global hotkeys must be paused while recording or
/// they consume the combination first.
final class HotkeyRecorderButton: NSButton {
    var onRecord: ((Hotkey) -> Void)?
    var onArm: (() -> Void)?
    /// Called when the pressed combination lacks a ⌘/⌃/⌥ modifier.
    var onInvalid: (() -> Void)?

    private var armed = false
    private var currentDisplay = ""
    private var currentDirty = false

    convenience init(hotkey: Hotkey) {
        self.init(title: "", target: nil, action: nil)
        bezelStyle = .rounded
        target = self
        action = #selector(arm)
        translatesAutoresizingMaskIntoConstraints = false
        // Fixed size: the recording prompt is wider than most combos and must
        // not reflow the settings grid.
        widthAnchor.constraint(equalToConstant: 150).isActive = true
        heightAnchor.constraint(equalToConstant: 24).isActive = true
        show(hotkey, dirty: false)
    }

    func show(_ hotkey: Hotkey, dirty: Bool) {
        currentDisplay = hotkey.display
        currentDirty = dirty
        showIdleTitle()
    }

    override var acceptsFirstResponder: Bool { true }

    @objc private func arm() {
        armed = true
        setTitle("단축키 입력", color: .secondaryLabelColor)
        window?.makeFirstResponder(self)
        onArm?()
    }

    override func resignFirstResponder() -> Bool {
        if armed {
            armed = false
            showIdleTitle()
        }
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard armed else { return super.keyDown(with: event) }
        capture(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard armed, event.type == .keyDown else { return super.performKeyEquivalent(with: event) }
        capture(event)
        return true
    }

    private func capture(_ event: NSEvent) {
        armed = false
        showIdleTitle()
        if event.keyCode == UInt16(kVK_Escape) { return }

        let flags = event.modifierFlags
        let carbon = Self.carbonModifiers(from: flags)
        guard carbon & UInt32(cmdKey | controlKey | optionKey) != 0 else {
            onInvalid?()
            return
        }
        onRecord?(Hotkey(
            keyCode: UInt32(event.keyCode),
            modifiers: carbon,
            display: Self.display(for: event, flags: flags)
        ))
    }

    private func showIdleTitle() {
        setTitle(currentDisplay, color: currentDirty ? .controlAccentColor : .labelColor)
    }

    private func setTitle(_ text: String, color: NSColor) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: color,
            .paragraphStyle: style,
        ])
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        return modifiers
    }

    private static func display(for event: NSEvent, flags: NSEvent.ModifierFlags) -> String {
        var symbols = ""
        if flags.contains(.control) { symbols += "⌃" }
        if flags.contains(.option) { symbols += "⌥" }
        if flags.contains(.shift) { symbols += "⇧" }
        if flags.contains(.command) { symbols += "⌘" }
        return symbols + keyName(for: Int(event.keyCode), event: event)
    }

    /// Carbon registers by physical key code, so the label must come from a
    /// layout-independent table — `charactersIgnoringModifiers` returns Hangul
    /// jamo under a Korean input source.
    private static func keyName(for keyCode: Int, event: NSEvent) -> String {
        if let name = keyNames[keyCode] { return name }
        return event.charactersIgnoringModifiers?.uppercased() ?? "?"
    }

    static let keyNames: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
        kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
        kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
        kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
        kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
        kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_Space: "Space", kVK_Return: "Return", kVK_Tab: "Tab",
        kVK_Delete: "Delete", kVK_ANSI_Grave: "`", kVK_ANSI_Minus: "-",
        kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'",
        kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12",
    ]
}
