import AppKit
import Carbon
import PounceCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let session = HintSession()
    private let scrollSession = ScrollSession()
    private let warmer = AccessibilityWarmer()
    private var hotkey: GlobalHotkey?
    private var scrollHotkey: GlobalHotkey?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AccessibilityPermission.requestIfNeeded()
        warmer.start()

        let preference = HotkeyPreference.load()
        statusItem = StatusItemController(
            currentHotkey: preference,
            onSelectHotkey: { [weak self] preset in
                preset.save()
                self?.register(preset)
            },
            onToggleOCR: { [weak self] enabled in self?.session.setOCREnabled(enabled) },
            onQuit: { NSApp.terminate(nil) }
        )
        register(preference)

        scrollHotkey = GlobalHotkey(
            keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey | shiftKey), id: 2
        ) { [weak self] in
            MainActor.assumeIsolated {
                self?.session.cancel()
                self?.scrollSession.start()
            }
        }
        if scrollHotkey == nil {
            NSLog("Pounce: failed to register scroll hot key ⌘⇧S")
        }
    }

    private func register(_ preference: HotkeyPreference) {
        hotkey = nil
        hotkey = GlobalHotkey(keyCode: preference.keyCode, modifiers: preference.modifiers, id: 1) { [weak self] in
            MainActor.assumeIsolated {
                self?.scrollSession.cancel()
                self?.session.start()
            }
        }
        if hotkey == nil {
            NSLog("Pounce: failed to register hot key \(preference.name)")
        }
    }
}
