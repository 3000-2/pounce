import XCTest
import CoreGraphics
@testable import PounceCore

final class BadgeLayoutTests: XCTestCase {
    private let badgeSize = CGSize(width: 24, height: 18)

    private func placement(_ id: Int, _ frame: CGRect) -> BadgePlacement {
        BadgePlacement(id: id, label: "h\(id)", elementFrame: frame, size: badgeSize)
    }

    private func assertNoOverlaps(_ badges: [LaidOutBadge], file: StaticString = #filePath, line: UInt = #line) {
        for (i, a) in badges.enumerated() {
            for b in badges[(i + 1)...] {
                XCTAssertFalse(a.box.intersects(b.box),
                               "badge \(a.id) overlaps \(b.id)", file: file, line: line)
            }
        }
    }

    func testStackedAnchorsFanOutWithoutOverlap() {
        let frame = CGRect(x: 50, y: 500, width: 160, height: 28)
        let result = BadgeLayout.resolve([
            placement(0, frame), placement(1, frame), placement(2, frame),
        ])
        assertNoOverlaps(result)
        XCTAssertEqual(result[0].box.midX, frame.maxX - badgeSize.width * 0.15)
        XCTAssertEqual(result[0].box.midY, frame.maxY - badgeSize.height * 0.15)
    }

    func testBadgeStraddlesTopRightCornerRegardlessOfSize() {
        let closeButton = CGRect(x: 100, y: 100, width: 16, height: 16)
        let wideRow = CGRect(x: 0, y: 0, width: 600, height: 200)
        let result = BadgeLayout.resolve([placement(0, closeButton), placement(1, wideRow)])
        for (badge, frame) in zip(result, [closeButton, wideRow]) {
            XCTAssertEqual(badge.box.midX, frame.maxX - badgeSize.width * 0.15)
            XCTAssertEqual(badge.box.midY, frame.maxY - badgeSize.height * 0.15)
        }
    }

    func testSeparatedBadgesStayAtTheirAnchors() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 30)
        let b = CGRect(x: 300, y: 300, width: 100, height: 30)
        let result = BadgeLayout.resolve([placement(0, a), placement(1, b)])
        for (badge, frame) in zip(result, [a, b]) {
            XCTAssertEqual(badge.box.midX, frame.maxX - badgeSize.width * 0.15)
            XCTAssertEqual(badge.box.midY, frame.maxY - badgeSize.height * 0.15)
        }
    }

    func testDeterministic() {
        let frames = (0..<20).map { CGRect(x: CGFloat($0 % 5) * 10, y: 100, width: 60, height: 24) }
        let placements = frames.enumerated().map { placement($0.offset, $0.element) }
        XCTAssertEqual(BadgeLayout.resolve(placements), BadgeLayout.resolve(placements))
    }

    func testClampedIntoBounds() {
        var config = LayoutConfig()
        config.bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let nearEdge = CGRect(x: 790, y: 590, width: 40, height: 20)
        let result = BadgeLayout.resolve([placement(0, nearEdge)], config: config)
        XCTAssertTrue(config.bounds.contains(result[0].box))
    }

    func testTinyElementGetsFullSizeBadge() {
        let closeButton = CGRect(x: 4, y: 6, width: 16, height: 16)
        let result = BadgeLayout.resolve([placement(0, closeButton)])
        XCTAssertEqual(result[0].box.size, badgeSize, "badges never shrink for tiny elements")
    }
}
