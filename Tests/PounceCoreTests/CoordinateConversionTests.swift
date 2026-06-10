import XCTest
import CoreGraphics
@testable import PounceCore

final class CoordinateConversionTests: XCTestCase {
    func testFlipsYAroundPrimaryHeight() {
        let ax = CGRect(x: 100, y: 50, width: 200, height: 30)
        let cocoa = CoordinateConversion.cocoaRect(fromAXRect: ax, primaryHeight: 1000)
        XCTAssertEqual(cocoa, CGRect(x: 100, y: 920, width: 200, height: 30))
    }

    func testFlipIsItsOwnInverse() {
        let ax = CGRect(x: 12, y: 340, width: 88, height: 22)
        let once = CoordinateConversion.cocoaRect(fromAXRect: ax, primaryHeight: 900)
        let twice = CoordinateConversion.cocoaRect(fromAXRect: once, primaryHeight: 900)
        XCTAssertEqual(twice, ax)
    }

    func testCenterMatchesQuartzMidpoint() {
        let ax = CGRect(x: 10, y: 20, width: 40, height: 60)
        XCTAssertEqual(CoordinateConversion.axCenter(of: ax), CGPoint(x: 30, y: 50))
    }

    func testVisionFullBoxCoversDisplay() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let rect = CoordinateConversion.screenRect(
            fromVisionBoundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
            displayBounds: display
        )
        XCTAssertEqual(rect, display)
    }

    func testVisionBottomLeftBoxMapsToScreenBottomLeft() {
        // Vision origin is bottom-left; the bottom-left quadrant maps to the lower
        // half of the screen (large y in top-left Quartz space).
        let display = CGRect(x: 100, y: 200, width: 1000, height: 800)
        let rect = CoordinateConversion.screenRect(
            fromVisionBoundingBox: CGRect(x: 0, y: 0, width: 0.5, height: 0.5),
            displayBounds: display
        )
        XCTAssertEqual(rect, CGRect(x: 100, y: 600, width: 500, height: 400))
    }
}
