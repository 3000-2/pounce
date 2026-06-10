import AppKit
import ApplicationServices
import PounceCore

/// No pid cache on purpose: Chromium auto-disables accessibility after idle
/// periods, and the read-guard in `enable` makes repeats nearly free.
@MainActor
final class AccessibilityWarmer {
    private var observer: (any NSObjectProtocol)?

    func start() {
        warm(NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.warm(app) }
        }
    }

    private func warm(_ app: NSRunningApplication?) {
        guard let app else { return }
        ManualAccessibility.enable(
            for: AXUIElementCreateApplication(app.processIdentifier),
            bundleID: app.bundleIdentifier
        )
    }
}
