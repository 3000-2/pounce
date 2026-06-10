import ApplicationServices
import CoreGraphics

public func axCopyValue(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    return result == .success ? value : nil
}

public func axString(_ element: AXUIElement, _ attribute: String) -> String? {
    axCopyValue(element, attribute) as? String
}

public func axBool(_ element: AXUIElement, _ attribute: String) -> Bool? {
    axCopyValue(element, attribute) as? Bool
}

public func axFrame(_ element: AXUIElement) -> CGRect? {
    guard let positionValue = axCopyValue(element, kAXPositionAttribute as String),
          let sizeValue = axCopyValue(element, kAXSizeAttribute as String),
          CFGetTypeID(positionValue) == AXValueGetTypeID(),
          CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }

    var point = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
          AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
    return CGRect(origin: point, size: size)
}

public func axElements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
    guard let value = axCopyValue(element, attribute),
          CFGetTypeID(value) == CFArrayGetTypeID() else { return [] }
    let array = value as! [AnyObject]
    return array.compactMap { child in
        CFGetTypeID(child) == AXUIElementGetTypeID() ? (child as! AXUIElement) : nil
    }
}

public func axElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
    guard let value = axCopyValue(element, attribute),
          CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return (value as! AXUIElement)
}

public func axActions(_ element: AXUIElement) -> [String] {
    var names: CFArray?
    let result = AXUIElementCopyActionNames(element, &names)
    guard result == .success, let names = names as? [String] else { return [] }
    return names
}

/// Real AX trees contain cycles and duplicate edges (measured in Chrome and
/// Finder menu trees); a traversal without identity-based dedup re-visits
/// subtrees exponentially. CFEqual/CFHash compare the underlying AX object,
/// not the wrapper pointer.
public struct AXElementKey: Hashable {
    public let element: AXUIElement

    public init(_ element: AXUIElement) {
        self.element = element
    }

    public static func == (lhs: AXElementKey, rhs: AXElementKey) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(element))
    }
}

public struct AXScanSnapshot {
    public let role: String?
    public let frame: CGRect?
    public let enabled: Bool
    public let children: [AXUIElement]
}

private let scanAttributes = [
    kAXRoleAttribute, kAXPositionAttribute, kAXSizeAttribute,
    kAXEnabledAttribute, kAXChildrenAttribute,
] as CFArray

/// One batched IPC replaces ~6 individual round-trips; measured ~3.5× faster
/// per element. Failed attributes arrive as AXError-typed placeholders, which
/// the per-field type checks below turn into nil/defaults.
public func axScanSnapshot(_ element: AXUIElement) -> AXScanSnapshot? {
    var values: CFArray?
    guard AXUIElementCopyMultipleAttributeValues(element, scanAttributes, AXCopyMultipleAttributeOptions(), &values) == .success,
          let array = values as? [AnyObject], array.count == 5 else { return nil }

    var frame: CGRect?
    if CFGetTypeID(array[1]) == AXValueGetTypeID(), CFGetTypeID(array[2]) == AXValueGetTypeID() {
        var point = CGPoint.zero
        var size = CGSize.zero
        if AXValueGetValue(array[1] as! AXValue, .cgPoint, &point),
           AXValueGetValue(array[2] as! AXValue, .cgSize, &size) {
            frame = CGRect(origin: point, size: size)
        }
    }
    var children: [AXUIElement] = []
    if CFGetTypeID(array[4]) == CFArrayGetTypeID() {
        children = (array[4] as! [AnyObject]).compactMap {
            CFGetTypeID($0) == AXUIElementGetTypeID() ? ($0 as! AXUIElement) : nil
        }
    }
    return AXScanSnapshot(
        role: array[0] as? String,
        frame: frame,
        enabled: (array[3] as? Bool) ?? true,
        children: children
    )
}

/// Web-area fast path: ask the browser to search its own (cached) tree for
/// visible interactive descendants in one parameterized query, instead of
/// walking hundreds of AXGroup wrappers over IPC. Supported by Chromium,
/// WebKit and Electron. Returns nil when unsupported or failed — caller falls
/// back to traversal. A successful empty result is trusted.
public func axWebAreaInteractiveElements(_ webArea: AXUIElement) -> [AXUIElement]? {
    var names: CFArray?
    guard AXUIElementCopyParameterizedAttributeNames(webArea, &names) == .success,
          let supported = names as? [String],
          supported.contains("AXUIElementsForSearchPredicate") else { return nil }

    let query: [String: Any] = [
        "AXDirection": "AXDirectionNext",
        "AXImmediateDescendantsOnly": false,
        "AXResultsLimit": -1,
        "AXVisibleOnly": true,
        "AXSearchKey": [
            "AXButtonSearchKey", "AXCheckBoxSearchKey", "AXControlSearchKey",
            "AXGraphicSearchKey", "AXLinkSearchKey", "AXRadioGroupSearchKey",
            "AXTextFieldSearchKey",
        ],
    ]
    var result: AnyObject?
    guard AXUIElementCopyParameterizedAttributeValue(
        webArea, "AXUIElementsForSearchPredicate" as CFString, query as CFDictionary, &result
    ) == .success, let result, CFGetTypeID(result) == CFArrayGetTypeID() else { return nil }

    return (result as! [AnyObject]).compactMap {
        CFGetTypeID($0) == AXUIElementGetTypeID() ? ($0 as! AXUIElement) : nil
    }
}

public let defaultClickableRoles: Set<String> = [
    kAXButtonRole,
    "AXLink",
    kAXMenuItemRole,
    kAXMenuButtonRole,
    kAXPopUpButtonRole,
    kAXCheckBoxRole,
    kAXRadioButtonRole,
    kAXTextFieldRole,
    kAXTextAreaRole,
    kAXComboBoxRole,
    kAXDisclosureTriangleRole,
    kAXSliderRole,
    kAXIncrementorRole,
    kAXMenuBarItemRole,
]

/// Generic roles that aren't inherently interactive but often back custom
/// controls. We treat them as targets only when they advertise an `AXPress`
/// action, so the extra per-element query stays scoped to ambiguous elements.
public let actionProbeRoles: Set<String> = [
    kAXGroupRole,
    kAXImageRole,
    kAXUnknownRole,
    kAXCellRole,
    kAXStaticTextRole,
]
