import AppKit

/// Esc closes the window only when no recorder is armed — an armed recorder is
/// first responder and consumes Esc as recording-cancel before this is reached.
private final class SettingsContentView: NSView {
    var onCancel: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    /// Registers the hotkey; `false` means another app owns the combination.
    private let onApply: (HotkeyRole, Hotkey) -> Bool
    private var recorders: [HotkeyRole: HotkeyRecorderButton] = [:]
    private var pending: [HotkeyRole: Hotkey] = [:]
    private let errorLabel = NSTextField(wrappingLabelWithString: "")
    private let saveButton = NSButton(title: "저장", target: nil, action: nil)
    private var keyObserver: (any NSObjectProtocol)?

    init(onApply: @escaping (HotkeyRole, Hotkey) -> Bool) {
        self.onApply = onApply

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pounce 설정"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let grid = NSGridView()
        grid.rowSpacing = 12
        grid.columnSpacing = 8
        for role in HotkeyRole.allCases {
            let label = NSTextField(labelWithString: role.label)
            let recorder = HotkeyRecorderButton(hotkey: HotkeyStore.load(role))
            recorder.onRecord = { [weak self] hotkey in self?.recorded(hotkey, for: role) }
            recorder.onArm = { [weak self] in self?.showError(nil) }
            recorder.onInvalid = { [weak self] in
                self?.showError("⌘, ⌥, ⌃ 중 하나 이상을 포함해야 합니다.")
            }
            recorders[role] = recorder
            grid.addRow(with: [label, recorder])
        }
        grid.column(at: 0).xPlacement = .trailing

        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        errorLabel.preferredMaxLayoutWidth = 320

        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveTapped)
        saveButton.keyEquivalent = "\r"
        saveButton.isEnabled = false

        let content = SettingsContentView()
        content.onCancel = { [weak self] in self?.window?.close() }
        for view in [grid, errorLabel, saveButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),

            errorLabel.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 10),
            errorLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            errorLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),

            saveButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 12),
            saveButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),

            content.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
        ])
        window.contentView = content
        content.layoutSubtreeIfNeeded()
        window.setContentSize(content.fittingSize)

        keyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak window] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { _ = window?.makeFirstResponder(nil) }
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }

    deinit {
        if let keyObserver { NotificationCenter.default.removeObserver(keyObserver) }
    }

    func present() {
        for role in HotkeyRole.allCases {
            pending[role] = HotkeyStore.load(role)
            recorders[role]?.show(pending[role]!, dirty: false)
        }
        showError(nil)
        updateSaveEnabled()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func recorded(_ hotkey: Hotkey, for role: HotkeyRole) {
        let other: HotkeyRole = role == .hint ? .scroll : .hint
        if let otherHotkey = pending[other], otherHotkey.conflicts(with: hotkey) {
            showError("\(hotkey.display) 단축키는 이미 '\(other.label)'에서 사용 중입니다.")
            return
        }
        if SystemShortcuts.conflicts(keyCode: hotkey.keyCode, carbonModifiers: hotkey.modifiers) {
            showError("\(hotkey.display) 단축키는 이미 macOS 시스템에서 사용 중입니다.")
            return
        }
        pending[role] = hotkey
        recorders[role]?.show(hotkey, dirty: hotkey != HotkeyStore.load(role))
        showError(nil)
        updateSaveEnabled()
    }

    @objc private func saveTapped() {
        for role in HotkeyRole.allCases {
            guard let hotkey = pending[role], hotkey != HotkeyStore.load(role) else { continue }
            guard onApply(role, hotkey) else {
                pending[role] = HotkeyStore.load(role)
                recorders[role]?.show(pending[role]!, dirty: false)
                showError("\(hotkey.display) 단축키는 이미 다른 앱에서 사용 중입니다.")
                updateSaveEnabled()
                return
            }
        }
        window?.close()
    }

    private func updateSaveEnabled() {
        let dirty = HotkeyRole.allCases.contains { pending[$0] != HotkeyStore.load($0) }
        saveButton.isEnabled = dirty
        window?.isDocumentEdited = dirty
    }

    private func showError(_ message: String?) {
        errorLabel.stringValue = message ?? ""
    }
}
