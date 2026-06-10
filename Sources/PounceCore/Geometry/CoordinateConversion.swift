import CoreGraphics

public enum CoordinateConversion {
    /// AX/Quartz is top-left-origin, AppKit bottom-left; the flip pivots on the
    /// primary display's height — the display whose AppKit origin is (0, 0).
    public static func cocoaRect(fromAXRect ax: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: ax.origin.x,
            y: primaryHeight - ax.origin.y - ax.size.height,
            width: ax.size.width,
            height: ax.size.height
        )
    }

    /// Directly usable as a `CGEvent` position — CGEvent shares the AX/Quartz
    /// top-left global space.
    public static func axCenter(of ax: CGRect) -> CGPoint {
        CGPoint(x: ax.midX, y: ax.midY)
    }

    /// Vision `boundingBox` is normalised with a bottom-left origin, relative to
    /// the captured display; output is an AX/Quartz global rect (top-left).
    public static func screenRect(fromVisionBoundingBox box: CGRect, displayBounds: CGRect) -> CGRect {
        let topLeftY = 1 - box.origin.y - box.size.height
        return CGRect(
            x: displayBounds.minX + box.origin.x * displayBounds.width,
            y: displayBounds.minY + topLeftY * displayBounds.height,
            width: box.size.width * displayBounds.width,
            height: box.size.height * displayBounds.height
        )
    }
}
