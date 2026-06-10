import ApplicationServices
import CoreGraphics

public struct HintTarget: Identifiable {
    public let id: Int
    /// Frame in AX/Quartz global coordinates (top-left origin).
    public let frame: CGRect
    public let kind: Kind

    public enum Kind {
        case accessibility(AXUIElement)
        case screenPoint
    }

    public init(id: Int, frame: CGRect, kind: Kind) {
        self.id = id
        self.frame = frame
        self.kind = kind
    }
}
