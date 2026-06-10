import AppKit
import ApplicationServices
import PounceCore

@MainActor
final class ScrollSession {
    private var active = false
    private var areas: [ClickableElement] = []
    private var activeIndex = 0
    private var screenUnion = CGRect.zero
    private var overlay: OverlayWindow?
    private var borderView: ScrollBorderView?
    private var keyTap: HintKeyTap?
    private var mouseMonitor: Any?
    private var appChangeObserver: (any NSObjectProtocol)?

    private let messagingTimeout: Float = 0.2
    private let lineStep: Int32 = 40

    func start() {
        guard !active else { return }
        guard AccessibilityPermission.isTrusted else {
            AccessibilityPermission.requestIfNeeded()
            return
        }
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        active = true

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        ManualAccessibility.enable(for: appElement, bundleID: app.bundleIdentifier)
        AXUIElementSetMessagingTimeout(appElement, messagingTimeout)
        let roots = AXTopology.rootWindows(of: appElement)
        roots.forEach { AXUIElementSetMessagingTimeout($0, messagingTimeout) }

        var config = ScanConfig()
        config.visibleBounds = AXTopology.quartzScreenBounds()

        DispatchQueue.global(qos: .userInitiated).async {
            let start = Date()
            let found = ElementScanner().scanScrollAreas(roots: roots, config: config)
            NSLog("Pounce scroll: %d area(s) in %.0fms — %@", found.count,
                  Date().timeIntervalSince(start) * 1000,
                  found.prefix(5).map { "\($0.role) \(Int($0.frame.width))x\(Int($0.frame.height))" }
                      .joined(separator: ", "))
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.present(found) }
            }
        }
    }

    func cancel() {
        end()
    }

    private func present(_ found: [ClickableElement]) {
        guard active else { return }
        let unique = TargetDeduplicator.deduplicate(
            found.map { HintTarget(id: $0.id, frame: $0.frame, kind: .accessibility($0.element)) },
            pressEquivalent: { _, _ in false }
        )
        guard !unique.isEmpty else { end(); return }

        areas = unique.compactMap { target -> ClickableElement? in
            guard case .accessibility(let element) = target.kind else { return nil }
            return ClickableElement(id: target.id, role: "", frame: target.frame, element: element)
        }
        .sorted { $0.frame.width * $0.frame.height > $1.frame.width * $1.frame.height }
        guard !areas.isEmpty else { end(); return }
        activeIndex = 0

        screenUnion = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        let window = OverlayWindow(frame: screenUnion)
        let view = ScrollBorderView(frame: NSRect(origin: .zero, size: screenUnion.size))
        view.borderRect = cocoaRect(of: areas[activeIndex].frame)
        window.contentView = view
        window.orderFrontRegardless()
        overlay = window
        borderView = view

        let tap = HintKeyTap(onKey: { [weak self] key in
            MainActor.assumeIsolated { self?.handle(key) }
        })
        guard tap.start() else {
            NSLog("Pounce: scroll event tap creation failed")
            end()
            return
        }
        keyTap = tap

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.end() } }
        }
        appChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.end() } }
        }
    }

    private func handle(_ key: HintKey) {
        switch key {
        case .escape, .confirm:
            end()
        case .delete:
            break
        case .tab:
            guard !areas.isEmpty else { return }
            activeIndex = (activeIndex + 1) % areas.count
            borderView?.borderRect = cocoaRect(of: areas[activeIndex].frame)
        case .char(let character):
            guard let command = ScrollKeymap.command(for: character) else {
                NSSound.beep()
                return
            }
            perform(command)
        }
    }

    private func perform(_ command: ScrollCommand) {
        guard areas.indices.contains(activeIndex) else { return }
        let frame = areas[activeIndex].frame
        let center = CoordinateConversion.axCenter(of: frame)
        NSLog("Pounce scroll: %@ at (%.0f, %.0f)", String(describing: command), center.x, center.y)
        switch command {
        case .line(let dx, let dy):
            postScroll(dx: Int32(dx) * lineStep, dy: Int32(dy) * lineStep, at: center)
        case .halfPage(let up):
            let amount = Int32(frame.height / 2)
            postScroll(dx: 0, dy: up ? amount : -amount, at: center)
        case .edge(let top):
            postScroll(dx: 0, dy: top ? 100_000 : -100_000, at: center)
        }
    }

    private func postScroll(dx: Int32, dy: Int32, at point: CGPoint) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel,
            wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0
        ) else { return }
        // Wheel events route by event location, so no cursor warp is needed.
        event.location = point
        event.post(tap: .cghidEventTap)
    }

    private func cocoaRect(of axFrame: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CoordinateConversion.cocoaRect(fromAXRect: axFrame, primaryHeight: primaryHeight)
            .offsetBy(dx: -screenUnion.minX, dy: -screenUnion.minY)
    }

    private func end() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        if let appChangeObserver { NSWorkspace.shared.notificationCenter.removeObserver(appChangeObserver) }
        appChangeObserver = nil
        keyTap?.stop()
        keyTap = nil
        overlay?.orderOut(nil)
        overlay = nil
        borderView = nil
        areas = []
        activeIndex = 0
        active = false
    }
}
