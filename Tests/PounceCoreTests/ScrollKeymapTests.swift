import XCTest
@testable import PounceCore

final class ScrollKeymapTests: XCTestCase {
    func testVimLineKeys() {
        XCTAssertEqual(ScrollKeymap.command(for: "j"), .line(dx: 0, dy: -1))
        XCTAssertEqual(ScrollKeymap.command(for: "k"), .line(dx: 0, dy: 1))
        XCTAssertEqual(ScrollKeymap.command(for: "h"), .line(dx: 1, dy: 0))
        XCTAssertEqual(ScrollKeymap.command(for: "l"), .line(dx: -1, dy: 0))
    }

    func testHalfPageAndEdges() {
        XCTAssertEqual(ScrollKeymap.command(for: "d"), .halfPage(up: false))
        XCTAssertEqual(ScrollKeymap.command(for: "u"), .halfPage(up: true))
        XCTAssertEqual(ScrollKeymap.command(for: "g"), .edge(top: true))
        XCTAssertEqual(ScrollKeymap.command(for: "G"), .edge(top: false))
    }

    func testCaseSensitivity() {
        XCTAssertNotEqual(ScrollKeymap.command(for: "g"), ScrollKeymap.command(for: "G"))
    }

    func testUnknownKeysReturnNil() {
        XCTAssertNil(ScrollKeymap.command(for: "x"))
        XCTAssertNil(ScrollKeymap.command(for: "1"))
        XCTAssertNil(ScrollKeymap.command(for: ""))
    }
}
