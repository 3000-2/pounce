import ApplicationServices
import CoreGraphics
import PounceCore

enum AXTopology {
    static func rootWindows(of appElement: AXUIElement) -> [AXUIElement] {
        // Right after the accessibility wake calls, Chrome's AXFocusedWindow can
        // briefly resolve to a junk element; the role check rejects it.
        if let focused = axElement(appElement, kAXFocusedWindowAttribute as String),
           axString(focused, kAXRoleAttribute as String) == kAXWindowRole {
            return [focused]
        }
        let windows = axElements(appElement, kAXWindowsAttribute as String)
        return windows.isEmpty ? [appElement] : windows
    }

    static func quartzScreenBounds() -> CGRect {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count > 0 else { return .infinite }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return ids.reduce(CGRect.null) { $0.union(CGDisplayBounds($1)) }
    }
}
