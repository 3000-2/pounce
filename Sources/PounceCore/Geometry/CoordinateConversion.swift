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
}
