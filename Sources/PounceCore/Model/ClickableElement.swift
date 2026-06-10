import ApplicationServices
import CoreGraphics

public struct ClickableElement: Identifiable {
    public let id: Int
    public let role: String
    /// Frame in AX/Quartz global coordinates (top-left origin).
    public let frame: CGRect
    public let element: AXUIElement

    public init(id: Int, role: String, frame: CGRect, element: AXUIElement) {
        self.id = id
        self.role = role
        self.frame = frame
        self.element = element
    }
}
