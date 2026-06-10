import XCTest
@testable import PounceCore

final class TargetClassifierTests: XCTestCase {
    func testWhitelistedRoleQualifiesWithoutPress() {
        XCTAssertTrue(TargetClassifier.qualifies(
            role: "AXButton", hasPressAction: false,
            clickableRoles: ["AXButton"], probeRoles: []
        ))
    }

    func testProbeRoleNeedsPressAction() {
        XCTAssertTrue(TargetClassifier.qualifies(
            role: "AXGroup", hasPressAction: true,
            clickableRoles: [], probeRoles: ["AXGroup"]
        ))
        XCTAssertFalse(TargetClassifier.qualifies(
            role: "AXGroup", hasPressAction: false,
            clickableRoles: [], probeRoles: ["AXGroup"]
        ))
    }

    func testUnlistedRoleNeverQualifies() {
        XCTAssertFalse(TargetClassifier.qualifies(
            role: "AXSplitter", hasPressAction: true,
            clickableRoles: ["AXButton"], probeRoles: ["AXGroup"]
        ))
    }

    func testPressActionNotEvaluatedForWhitelistedRole() {
        var evaluated = false
        _ = TargetClassifier.qualifies(
            role: "AXButton",
            hasPressAction: { evaluated = true; return true }(),
            clickableRoles: ["AXButton"], probeRoles: []
        )
        XCTAssertFalse(evaluated, "action query must stay lazy for whitelist roles")
    }
}
