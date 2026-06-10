import ApplicationServices

public enum ManualAccessibility {
    /// Chromium browsers ignore the Electron-only AXManualAccessibility; they
    /// only build the web AX tree when they see the attribute VoiceOver sets.
    public static let chromiumBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.canary",
        "org.chromium.Chromium",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.vivaldi.Vivaldi",
        "company.thebrowser.Browser",
        "com.naver.Whale",
    ]

    /// `AXManualAccessibility` wakes Electron apps and is a harmless no-op
    /// elsewhere, so it's always set. `AXEnhancedUserInterface` wakes Chromium
    /// browsers but is known to break window positioning in some AppKit apps,
    /// so it's gated to the browser list.
    ///
    /// Both writes are guarded by a read: re-writing an already-true value
    /// kicks Chrome's AX bridge into a rebuild during which window queries
    /// return garbage for tens of seconds (measured) — the guard also lets
    /// callers re-invoke this freely, so Chromium's accessibility auto-disable
    /// gets re-enabled on the next app activation.
    public static func enable(for application: AXUIElement, bundleID: String?) {
        setIfNeeded(application, "AXManualAccessibility")
        if let bundleID, chromiumBundleIDs.contains(bundleID) {
            // Chrome answers this write with attributeUnsupported (-25208) yet
            // still enables web accessibility on seeing the attempt (measured;
            // tree populates ~0.5-2s later) — so the result is ignored.
            setIfNeeded(application, "AXEnhancedUserInterface")
        }
    }

    private static func setIfNeeded(_ application: AXUIElement, _ attribute: String) {
        var current: AnyObject?
        if AXUIElementCopyAttributeValue(application, attribute as CFString, &current) == .success,
           (current as? Bool) == true {
            return
        }
        AXUIElementSetAttributeValue(application, attribute as CFString, kCFBooleanTrue)
    }
}
