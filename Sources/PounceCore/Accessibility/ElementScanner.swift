import ApplicationServices
import CoreGraphics

public struct ScanConfig {
    /// Web AXWebArea trees nest far deeper than native AppKit; the visited cap
    /// below is the runaway guard, so depth can afford headroom.
    public var maxDepth: Int = 64
    public var maxElements: Int = 2000
    /// Caps total nodes visited, not just results — a huge tree with few
    /// qualifying elements would otherwise stall the scan.
    public var maxVisited: Int = 50_000
    public var roles: Set<String> = defaultClickableRoles
    public var probeRoles: Set<String> = actionProbeRoles
    /// AX/Quartz global bounds of the visible displays; subtrees fully outside
    /// are pruned.
    public var visibleBounds: CGRect = .infinite

    public init() {}
}

public struct ElementScanner {
    public init() {}

    public func scan(roots: [AXUIElement], config: ScanConfig) -> [ClickableElement] {
        var results: [ClickableElement] = []
        var queue: [(element: AXUIElement, depth: Int)] = []
        var seen = Set<AXElementKey>()
        var head = 0
        var visited = 0
        var nextID = 0

        for root in roots where seen.insert(AXElementKey(root)).inserted {
            queue.append((root, 0))
        }

        while head < queue.count {
            if results.count >= config.maxElements || visited >= config.maxVisited { break }
            visited += 1
            let (element, depth) = queue[head]
            head += 1
            if depth > config.maxDepth { continue }

            guard let snapshot = axScanSnapshot(element) else { continue }
            if let frame = snapshot.frame, !frame.intersects(config.visibleBounds) { continue }

            if snapshot.role == "AXWebArea",
               let found = axWebAreaInteractiveElements(element) {
                for interactive in found where results.count < config.maxElements {
                    guard seen.insert(AXElementKey(interactive)).inserted,
                          let s = axScanSnapshot(interactive),
                          let frame = s.frame, frame.width >= 1, frame.height >= 1,
                          s.enabled, frame.intersects(config.visibleBounds) else { continue }
                    results.append(ClickableElement(
                        id: nextID, role: s.role ?? kAXUnknownRole, frame: frame, element: interactive
                    ))
                    nextID += 1
                }
                // The browser already searched this whole subtree; descending
                // into it would re-pay the per-wrapper IPC the shortcut avoids.
                continue
            }

            if let role = snapshot.role,
               let frame = snapshot.frame, frame.width >= 1, frame.height >= 1,
               snapshot.enabled,
               TargetClassifier.qualifies(
                   role: role,
                   hasPressAction: axActions(element).contains(kAXPressAction as String),
                   clickableRoles: config.roles,
                   probeRoles: config.probeRoles
               ) {
                results.append(ClickableElement(id: nextID, role: role, frame: frame, element: element))
                nextID += 1
            }

            for child in snapshot.children where seen.insert(AXElementKey(child)).inserted {
                queue.append((child, depth + 1))
            }
        }
        return results
    }

    /// AXWebArea counts as scrollable — the page itself scrolls even when no
    /// AXScrollArea wraps it.
    public func scanScrollAreas(roots: [AXUIElement], config: ScanConfig) -> [ClickableElement] {
        var results: [ClickableElement] = []
        var queue: [(element: AXUIElement, depth: Int)] = []
        var seen = Set<AXElementKey>()
        var head = 0
        var visited = 0
        var nextID = 0

        for root in roots where seen.insert(AXElementKey(root)).inserted {
            queue.append((root, 0))
        }
        while head < queue.count {
            if visited >= config.maxVisited { break }
            visited += 1
            let (element, depth) = queue[head]
            head += 1
            if depth > config.maxDepth { continue }

            guard let snapshot = axScanSnapshot(element) else { continue }
            if let frame = snapshot.frame, !frame.intersects(config.visibleBounds) { continue }

            if let role = snapshot.role, role == "AXScrollArea" || role == "AXWebArea",
               let frame = snapshot.frame, frame.width >= 40, frame.height >= 40 {
                results.append(ClickableElement(id: nextID, role: role, frame: frame, element: element))
                nextID += 1
            }
            // Keep descending: web areas nest scrollable sub-regions.
            for child in snapshot.children where seen.insert(AXElementKey(child)).inserted {
                queue.append((child, depth + 1))
            }
        }
        return results
    }
}