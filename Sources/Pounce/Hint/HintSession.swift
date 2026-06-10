import AppKit
import ApplicationServices
import PounceCore

@MainActor
final class HintSession {
    private var active = false
    private var hints: [String: HintTarget] = [:]
    private var typed = ""
    private var overlay: OverlayWindow?
    private var overlayView: OverlayView?
    private var keyTap: HintKeyTap?
    private var mouseMonitor: Any?
    private var appChangeObserver: (any NSObjectProtocol)?

    private var ocrEnabled = false
    private let messagingTimeout: Float = 0.2
    private let ocrFallbackThreshold = 3

    func setOCREnabled(_ enabled: Bool) {
        ocrEnabled = enabled
        if enabled, !ScreenRecordingPermission.isGranted {
            ScreenRecordingPermission.request()
        }
    }

    func start() {
        guard !active else { return }
        guard AccessibilityPermission.isTrusted else {
            AccessibilityPermission.requestIfNeeded()
            return
        }
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        active = true

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        ManualAccessibility.enable(for: appElement, bundleID: app.bundleIdentifier)
        AXUIElementSetMessagingTimeout(appElement, messagingTimeout)
        let roots = AXTopology.rootWindows(of: appElement)
        // Timeout propagation from the app element to derived elements is
        // undocumented; re-assert on each root so a beachballing app can't hang
        // the background scan.
        roots.forEach { AXUIElementSetMessagingTimeout($0, messagingTimeout) }

        var config = ScanConfig()
        config.visibleBounds = AXTopology.quartzScreenBounds()

        DispatchQueue.global(qos: .userInitiated).async {
            let start = Date()
            let elements = ElementScanner().scan(roots: roots, config: config)
            NSLog("Pounce: scanned %d targets in %.0fms", elements.count,
                  Date().timeIntervalSince(start) * 1000)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.afterAXScan(elements, pid: pid) }
            }
        }
    }

    private func afterAXScan(_ elements: [ClickableElement], pid: pid_t) {
        guard active else { return }

        // Dedup before the OCR-threshold check so duplicates can't mask an
        // effectively empty screen, and before labeling so short hints aren't
        // wasted on clones.
        let axTargets = TargetDeduplicator.deduplicate(
            elements.map { HintTarget(id: $0.id, frame: $0.frame, kind: .accessibility($0.element)) },
            pressEquivalent: Self.pressEquivalent
        )

        guard ocrEnabled, axTargets.count < ocrFallbackThreshold else {
            if axTargets.isEmpty { end() } else { present(axTargets) }
            return
        }

        NSLog("Pounce: AX returned \(axTargets.count) target(s) — falling back to OCR")
        Task { @MainActor in
            let ocrTargets = await VisionScanner.scanFrontWindow(pid: pid, startID: axTargets.count)
            guard self.active else { return }
            let combined = axTargets + ocrTargets
            if combined.isEmpty {
                self.end()
            } else {
                self.present(combined)
            }
        }
    }

    private func present(_ rawTargets: [HintTarget]) {
        guard active else { end(); return }
        // OCR targets may duplicate surviving AX ones; dedup is idempotent.
        let targets = TargetDeduplicator.deduplicate(rawTargets, pressEquivalent: Self.pressEquivalent)
        guard !targets.isEmpty else { end(); return }

        let labels = HintLabeler.generate(count: targets.count)
        hints = Dictionary(uniqueKeysWithValues: zip(labels, targets))
        typed = ""

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let union = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }

        let placements = zip(labels, targets).enumerated().map { index, pair -> BadgePlacement in
            let (label, target) = pair
            let cocoa = CoordinateConversion.cocoaRect(fromAXRect: target.frame, primaryHeight: primaryHeight)
                .offsetBy(dx: -union.minX, dy: -union.minY)
            return BadgePlacement(
                id: index, label: label,
                elementFrame: cocoa, size: OverlayView.badgeSize(for: label)
            )
        }
        var layoutConfig = LayoutConfig()
        layoutConfig.bounds = CGRect(origin: .zero, size: union.size)

        let window = OverlayWindow(frame: union)
        let view = OverlayView(frame: NSRect(origin: .zero, size: union.size))
        view.badges = BadgeLayout.resolve(placements, config: layoutConfig)
        window.contentView = view
        window.orderFrontRegardless()
        overlay = window
        overlayView = view

        let tap = HintKeyTap(onKey: { [weak self] key in
            MainActor.assumeIsolated { self?.handle(key) }
        })
        if tap.start() {
            keyTap = tap
        } else {
            NSLog("Pounce: event tap creation failed — is Accessibility granted?")
            end()
            return
        }

        // The overlay is a snapshot: a click-through panel lets the user drag
        // windows underneath, which would leave badges floating over stale
        // positions. Any mouse-down or app switch invalidates the snapshot.
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.end() }
            }
        }
        appChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.end() }
            }
        }
    }

    func cancel() {
        end()
    }

    private func handle(_ key: HintKey) {
        switch key {
        case .escape, .confirm:
            end()
        case .tab:
            break
        case .delete:
            if !typed.isEmpty {
                typed.removeLast()
                overlayView?.typed = typed
            }
        case .char(let character):
            let candidate = typed + character.lowercased()
            let matches = hints.keys.filter { $0.hasPrefix(candidate) }
            guard !matches.isEmpty else {
                NSSound.beep()
                return
            }
            typed = candidate
            // Hint strings are prefix-free, so an exact key means a unique target.
            if let target = hints[typed] {
                end()
                ElementActuator.activate(target)
                return
            }
            overlayView?.typed = typed
        }
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
        overlayView = nil
        hints = [:]
        typed = ""
        active = false
    }

    /// Strict equivalence: only literally the same AX object reached twice
    /// counts. Parent/child pairs are never assumed equivalent — a row and its
    /// inner button can legitimately do different things.
    private static func pressEquivalent(_ a: HintTarget, _ b: HintTarget) -> Bool {
        if case .accessibility(let elementA) = a.kind,
           case .accessibility(let elementB) = b.kind {
            return CFEqual(elementA, elementB)
        }
        return false
    }
}
