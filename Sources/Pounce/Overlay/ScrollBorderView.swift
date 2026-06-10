import AppKit

final class ScrollBorderView: NSView {
    var borderRect: CGRect = .zero { didSet { needsDisplay = true } }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard borderRect != .zero else { return }
        let path = NSBezierPath(roundedRect: borderRect.insetBy(dx: 2, dy: 2), xRadius: 6, yRadius: 6)
        NSColor.systemBlue.withAlphaComponent(0.85).setStroke()
        path.lineWidth = 3
        path.stroke()
    }
}
