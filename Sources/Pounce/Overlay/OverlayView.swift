import AppKit
import PounceCore

final class OverlayView: NSView {
    var badges: [LaidOutBadge] = [] { didSet { needsDisplay = true } }
    var typed: String = "" { didSet { needsDisplay = true } }

    private static let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
    private static let padding = NSSize(width: 5, height: 2)

    /// Sizes must be known before layout runs; keep measurement and drawing on
    /// the same font/padding constants so boxes never clip their labels.
    static func badgeSize(for label: String) -> CGSize {
        let textSize = (label.uppercased() as NSString).size(withAttributes: [.font: font])
        return CGSize(
            width: ceil(textSize.width) + padding.width * 2,
            height: ceil(textSize.height) + padding.height * 2
        )
    }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        for frame in OutlinePolicy.framesToOutline(badges: badges, typed: typed) {
            strokeOutline(frame)
        }
        for badge in badges where typed.isEmpty || badge.label.hasPrefix(typed) {
            drawChip(badge, matchedCount: typed.count)
        }
    }

    private func strokeOutline(_ frame: CGRect) {
        let path = NSBezierPath(roundedRect: frame.insetBy(dx: -1, dy: -1), xRadius: 4, yRadius: 4)
        NSColor.systemBlue.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    private func drawChip(_ badge: LaidOutBadge, matchedCount: Int) {
        let radius = badge.box.height / 2
        let path = NSBezierPath(roundedRect: badge.box, xRadius: radius, yRadius: radius)
        NSColor.systemBlue.withAlphaComponent(0.95).setFill()
        path.fill()
        NSColor.black.withAlphaComponent(0.3).setStroke()
        path.lineWidth = 1
        path.stroke()

        let label = badge.label.uppercased()
        let matched = String(label.prefix(matchedCount))
        let rest = String(label.dropFirst(matchedCount))
        let text = NSMutableAttributedString(
            string: matched,
            attributes: [.font: Self.font, .foregroundColor: NSColor.white.withAlphaComponent(0.45)]
        )
        text.append(NSAttributedString(
            string: rest,
            attributes: [.font: Self.font, .foregroundColor: NSColor.white]
        ))
        text.draw(at: NSPoint(
            x: badge.box.minX + Self.padding.width,
            y: badge.box.minY + Self.padding.height
        ))
    }
}
