import AppKit
import PounceCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let session = HintSession()
    private let scrollSession = ScrollSession()
    private let warmer = AccessibilityWarmer()
    private var hotkeys: [HotkeyRole: GlobalHotkey] = [:]
    private var statusItem: StatusItemController?
    private var settings: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AccessibilityPermission.requestIfNeeded()
        warmer.start()

        statusItem = StatusItemController(
            onOpenSettings: { [weak self] in self?.openSettings() },
            onToggleLaunchAtLogin: { [weak self] in
                LaunchAtLogin.toggle()
                self?.statusItem?.reflectLaunchAtLogin(LaunchAtLogin.isEnabled)
            },
            onQuit: { NSApp.terminate(nil) }
        )
        statusItem?.reflectLaunchAtLogin(LaunchAtLogin.isEnabled)

        for role in HotkeyRole.allCases {
            register(HotkeyStore.load(role), for: role)
        }
        reflectHotkeys()
    }

    private func openSettings() {
        if settings == nil {
            settings = SettingsWindowController { [weak self] role, hotkey in
                guard let self else { return false }
                guard self.register(hotkey, for: role) else { return false }
                HotkeyStore.save(hotkey, for: role)
                self.reflectHotkeys()
                return true
            }
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: settings?.window,
                queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.resumeHotkeys() }
                }
            }
        }
        // Registered combos are consumed system-wide before they can reach the
        // recorder — pressing the current hotkey would trigger a session instead
        // of recording. Pause all hotkeys while the settings window is open.
        hotkeys.removeAll()
        settings?.present()
    }

    private func resumeHotkeys() {
        for role in HotkeyRole.allCases {
            register(HotkeyStore.load(role), for: role)
        }
        reflectHotkeys()
    }

    @discardableResult
    private func register(_ hotkey: Hotkey, for role: HotkeyRole) -> Bool {
        // Carbon ids start at 1; derive stably from the role.
        let id = UInt32(HotkeyRole.allCases.firstIndex(of: role)! + 1)
        hotkeys[role] = nil
        hotkeys[role] = GlobalHotkey(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers, id: id) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                switch role {
                case .hint:
                    self.scrollSession.cancel()
                    self.session.start()
                case .scroll:
                    self.session.cancel()
                    self.scrollSession.start()
                }
            }
        }
        if hotkeys[role] == nil {
            NSLog("Pounce: failed to register %@ hot key %@", role.rawValue, hotkey.display)
            return false
        }
        return true
    }

    private func reflectHotkeys() {
        statusItem?.reflect(hint: HotkeyStore.load(.hint), scroll: HotkeyStore.load(.scroll))
    }
}
