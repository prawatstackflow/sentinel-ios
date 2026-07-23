import XCTest

@testable import Sentinel

final class LiveChatRequestTests: XCTestCase {
    func testDecodesFullBody() throws {
        let body: [String: Any] = [
            "type": "live_chat",
            "license": "17433519",
            "group": 5,
            "forwardPii": true,
            "sessionVariables": ["session_id": "s1", "tenant_id": "t1"],
            "customerName": "Ravi Kumar",
            "customerEmail": "ravi@example.com",
        ]
        let request = try XCTUnwrap(LiveChatRequest(body: body))
        XCTAssertEqual(request.license, "17433519")
        XCTAssertEqual(request.group, 5)
        XCTAssertTrue(request.forwardPii)
        XCTAssertEqual(request.sessionVariables, ["session_id": "s1", "tenant_id": "t1"])
        XCTAssertEqual(request.customerName, "Ravi Kumar")
        XCTAssertEqual(request.customerEmail, "ravi@example.com")
    }

    func testDefaultsGroupAndPii() throws {
        let request = try XCTUnwrap(LiveChatRequest(body: ["license": "13017213"]))
        XCTAssertEqual(request.license, "13017213")
        XCTAssertEqual(request.group, 0)
        XCTAssertFalse(request.forwardPii)
        XCTAssertTrue(request.sessionVariables.isEmpty)
        XCTAssertNil(request.customerName)
        XCTAssertNil(request.customerEmail)
    }

    func testGroupFromNumericString() throws {
        let request = try XCTUnwrap(LiveChatRequest(body: ["license": "1", "group": "7"]))
        XCTAssertEqual(request.group, 7)
    }

    func testNilWhenLicenseMissingOrBlank() {
        XCTAssertNil(LiveChatRequest(body: ["group": 5]))
        XCTAssertNil(LiveChatRequest(body: ["license": ""]))
    }

    func testDropsNonStringSessionVariableValues() throws {
        let body: [String: Any] = [
            "license": "1",
            "sessionVariables": ["ok": "yes", "num": 3],
        ]
        let request = try XCTUnwrap(LiveChatRequest(body: body))
        XCTAssertEqual(request.sessionVariables, ["ok": "yes"])
    }
}
