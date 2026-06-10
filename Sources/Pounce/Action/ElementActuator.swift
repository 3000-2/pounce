import ApplicationServices
import CoreGraphics
import PounceCore

enum ElementActuator {
    static func activate(_ target: HintTarget) {
        switch target.kind {
        case .accessibility(let element):
            if AXUIElementPerformAction(element, kAXPressAction as CFString) == .success {
                return
            }
            synthesizeClick(at: CoordinateConversion.axCenter(of: target.frame))
        case .screenPoint:
            synthesizeClick(at: CoordinateConversion.axCenter(of: target.frame))
        }
    }

    private static func synthesizeClick(at point: CGPoint) {
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                           mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                         mouseCursorPosition: point, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
