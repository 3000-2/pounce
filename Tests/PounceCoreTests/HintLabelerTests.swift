import XCTest
@testable import PounceCore

final class HintLabelerTests: XCTestCase {
    func testProducesRequestedCount() {
        for count in [0, 1, 5, 26, 27, 200] {
            XCTAssertEqual(HintLabeler.generate(count: count).count, count)
        }
    }

    func testHintsAreUnique() {
        let hints = HintLabeler.generate(count: 300)
        XCTAssertEqual(Set(hints).count, hints.count)
    }

    func testHintsArePrefixFree() {
        let hints = HintLabeler.generate(count: 300)
        for a in hints {
            for b in hints where a != b {
                XCTAssertFalse(b.hasPrefix(a), "\(a) is a prefix of \(b)")
            }
        }
    }

    func testSingleCharsWhenFewElements() {
        let keys: [Character] = Array("abcde")
        let hints = HintLabeler.generate(count: 5, keys: keys)
        XCTAssertTrue(hints.allSatisfy { $0.count == 1 })
    }

    func testDeterministic() {
        XCTAssertEqual(HintLabeler.generate(count: 50), HintLabeler.generate(count: 50))
    }
}
