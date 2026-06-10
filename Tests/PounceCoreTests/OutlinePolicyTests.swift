import XCTest
import CoreGraphics
@testable import PounceCore

final class OutlinePolicyTests: XCTestCase {
    private func badge(_ id: Int, label: String, frame: CGRect) -> LaidOutBadge {
        LaidOutBadge(id: id, label: label,
                     box: CGRect(origin: frame.origin, size: CGSize(width: 24, height: 18)),
                     elementFrame: frame)
    }

    private var badges: [LaidOutBadge] {
        [
            badge(0, label: "fa", frame: CGRect(x: 0, y: 0, width: 160, height: 28)),
            badge(1, label: "fb", frame: CGRect(x: 4, y: 6, width: 16, height: 16)),
            badge(2, label: "j", frame: CGRect(x: 300, y: 0, width: 80, height: 28)),
        ]
    }

    func testQuietAtRest() {
        XCTAssertTrue(OutlinePolicy.framesToOutline(badges: badges, typed: "").isEmpty)
    }

    func testUniqueMatchNeedsNoOutline() {
        XCTAssertTrue(OutlinePolicy.framesToOutline(badges: badges, typed: "j").isEmpty)
    }

    func testAmbiguousPrefixOutlinesAllCandidates() {
        let frames = OutlinePolicy.framesToOutline(badges: badges, typed: "f")
        XCTAssertEqual(frames, [badges[0].elementFrame, badges[1].elementFrame])
    }

    func testNonMatchingPrefixOutlinesNothing() {
        XCTAssertTrue(OutlinePolicy.framesToOutline(badges: badges, typed: "x").isEmpty)
    }
}
