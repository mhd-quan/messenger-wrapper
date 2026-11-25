import XCTest
import MessengerCore

final class BridgeMessageTests: XCTestCase {
    // MARK: - title

    func testTitle() {
        let body: [String: Any] = ["type": "title", "title": "(3) Messenger | Facebook"]
        XCTAssertEqual(BridgeMessage.decode(body), .title("(3) Messenger | Facebook"))
    }

    // MARK: - notification

    func testNotificationFull() {
        let body: [String: Any] = [
            "type": "notification",
            "id": "n_1-A",
            "title": "An",
            "body": "Xin chào",
            "tag": "thread-42",
        ]
        XCTAssertEqual(
            BridgeMessage.decode(body),
            .notification(id: "n_1-A", title: "An", body: "Xin chào", tag: "thread-42")
        )
    }

    func testNotificationOptionalFieldsMissing() {
        let body: [String: Any] = ["type": "notification", "id": "n1", "title": "An"]
        XCTAssertEqual(BridgeMessage.decode(body), .notification(id: "n1", title: "An", body: nil, tag: nil))
    }

    func testNotificationBadID() {
        let badIDs = [
            "a b",
            "'); alert(1)//",
            String(repeating: "a", count: 65),
            "",
            "abc\n",
        ]
        for id in badIDs {
            XCTAssertFalse(BridgeMessage.isValidID(id), "isValidID(\(id.debugDescription))")
            let body: [String: Any] = ["type": "notification", "id": id, "title": "An"]
            XCTAssertNil(BridgeMessage.decode(body), "id \(id.debugDescription)")
        }

        XCTAssertTrue(BridgeMessage.isValidID(String(repeating: "a", count: 64)))
        XCTAssertTrue(BridgeMessage.isValidID("Az09_-"))
    }

    // MARK: - unreadHint

    func testUnreadHint() {
        XCTAssertEqual(BridgeMessage.decode(["type": "unreadHint", "count": 3] as [String: Any]), .unreadHint(3))
        XCTAssertEqual(BridgeMessage.decode(["type": "unreadHint", "count": 0] as [String: Any]), .unreadHint(0))
        // JavaScript numbers are doubles; a whole double is a valid count.
        XCTAssertEqual(BridgeMessage.decode(["type": "unreadHint", "count": 3.0] as [String: Any]), .unreadHint(3))

        let badCounts: [Any] = [-1, "3", 3.5, true, false, Double.nan, Double.infinity, NSNull()]
        for count in badCounts {
            let body: [String: Any] = ["type": "unreadHint", "count": count]
            XCTAssertNil(BridgeMessage.decode(body), "count \(count)")
        }
        XCTAssertNil(BridgeMessage.decode(["type": "unreadHint"] as [String: Any]))
    }

    // MARK: - Rejected input

    func testUnknownType() {
        XCTAssertNil(BridgeMessage.decode(["type": "sw", "title": "x"] as [String: Any]))
        XCTAssertNil(BridgeMessage.decode(["title": "x"] as [String: Any]))
    }

    func testNotADictionary() {
        let bodies: [Any] = ["x", 42, NSNull()]
        for body in bodies {
            XCTAssertNil(BridgeMessage.decode(body), "body \(body)")
        }
    }

    func testWrongFieldType() {
        XCTAssertNil(BridgeMessage.decode(["type": "title", "title": 5] as [String: Any]))
        XCTAssertNil(BridgeMessage.decode(["type": 5, "title": "x"] as [String: Any]))
        XCTAssertNil(BridgeMessage.decode(["type": "notification", "id": "n1", "title": 5] as [String: Any]))
        XCTAssertNil(BridgeMessage.decode(["type": "notification", "id": 1, "title": "An"] as [String: Any]))
        XCTAssertNil(BridgeMessage.decode(["type": "notification", "id": "n1"] as [String: Any]))
        XCTAssertNil(BridgeMessage.decode(["type": "notification", "id": "n1", "title": "An", "body": 5] as [String: Any]))
        XCTAssertNil(BridgeMessage.decode(["type": "notification", "id": "n1", "title": "An", "tag": 5] as [String: Any]))
    }

    // MARK: - Truncation

    func testLongStringsTruncated() {
        let long = String(repeating: "a", count: 600)
        let truncated = String(repeating: "a", count: 500)

        XCTAssertEqual(BridgeMessage.decode(["type": "title", "title": long] as [String: Any]), .title(truncated))

        let body: [String: Any] = ["type": "notification", "id": "n1", "title": long, "body": long, "tag": long]
        XCTAssertEqual(
            BridgeMessage.decode(body),
            .notification(id: "n1", title: truncated, body: truncated, tag: truncated)
        )

        // Exactly 500 characters is kept as is.
        XCTAssertEqual(BridgeMessage.decode(["type": "title", "title": truncated] as [String: Any]), .title(truncated))

        // Truncation counts characters, never splitting a grapheme cluster.
        let thumb = "👍🏽"  // two scalars, one character
        let accented = "e\u{301}"  // two scalars, one character
        XCTAssertEqual(
            BridgeMessage.decode(["type": "title", "title": String(repeating: thumb, count: 600)] as [String: Any]),
            .title(String(repeating: thumb, count: 500))
        )
        XCTAssertEqual(
            BridgeMessage.decode(["type": "title", "title": String(repeating: accented, count: 600)] as [String: Any]),
            .title(String(repeating: accented, count: 500))
        )
    }
}
