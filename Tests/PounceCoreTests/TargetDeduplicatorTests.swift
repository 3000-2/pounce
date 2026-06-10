import XCTest
import CoreGraphics
@testable import PounceCore

final class TargetDeduplicatorTests: XCTestCase {
    private func target(_ id: Int, _ frame: CGRect) -> HintTarget {
        HintTarget(id: id, frame: frame, kind: .screenPoint)
    }

    private let never: (HintTarget, HintTarget) -> Bool = { _, _ in false }
    private let always: (HintTarget, HintTarget) -> Bool = { _, _ in true }

    func testIdenticalFramesKeepFirstOccurrence() {
        let frame = CGRect(x: 10, y: 10, width: 100, height: 30)
        let result = TargetDeduplicator.deduplicate(
            [target(0, frame), target(1, frame), target(2, frame)],
            pressEquivalent: never
        )
        XCTAssertEqual(result.map(\.id), [0])
    }

    func testSubPixelJitterMergesButCloseButtonDoesNot() {
        let tab = CGRect(x: 0, y: 0, width: 160, height: 28)
        let jittered = tab.offsetBy(dx: 1, dy: 1)
        let closeButton = CGRect(x: 4, y: 6, width: 16, height: 16)
        let result = TargetDeduplicator.deduplicate(
            [target(0, tab), target(1, jittered), target(2, closeButton)],
            pressEquivalent: never
        )
        XCTAssertEqual(result.map(\.id), [0, 2])
    }

    // Edge deltas must exceed positionTolerance or A1 absorbs the pair as a
    // plain duplicate before containment is ever considered.
    private let dominantParent = CGRect(x: 0, y: 0, width: 400, height: 100)
    private let dominantChild = CGRect(x: 5, y: 3, width: 390, height: 94)

    func testParentDroppedWhenDominantChildIsPressEquivalent() {
        let result = TargetDeduplicator.deduplicate(
            [target(0, dominantParent), target(1, dominantChild)],
            pressEquivalent: always
        )
        XCTAssertEqual(result.map(\.id), [1])
    }

    func testParentKeptWhenNotPressEquivalent() {
        let result = TargetDeduplicator.deduplicate(
            [target(0, dominantParent), target(1, dominantChild)],
            pressEquivalent: never
        )
        XCTAssertEqual(result.map(\.id), [0, 1])
    }

    func testTabWithSmallCloseButtonNeverCollapses() {
        let tab = CGRect(x: 0, y: 0, width: 160, height: 28)
        let closeButton = CGRect(x: 4, y: 6, width: 16, height: 16)
        let result = TargetDeduplicator.deduplicate(
            [target(0, tab), target(1, closeButton)],
            pressEquivalent: always
        )
        XCTAssertEqual(result.map(\.id), [0, 1], "area ratio gate must protect tab+close")
    }

    func testEmptyAndDistinctInputsPassThrough() {
        XCTAssertTrue(TargetDeduplicator.deduplicate([], pressEquivalent: never).isEmpty)
        let distinct = [
            target(0, CGRect(x: 0, y: 0, width: 50, height: 20)),
            target(1, CGRect(x: 100, y: 0, width: 50, height: 20)),
        ]
        XCTAssertEqual(
            TargetDeduplicator.deduplicate(distinct, pressEquivalent: never).map(\.id),
            [0, 1]
        )
    }
}
