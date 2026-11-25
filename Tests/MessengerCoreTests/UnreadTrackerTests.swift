import XCTest
import MessengerCore

final class UnreadTrackerTests: XCTestCase {
    // MARK: - Helpers

    private func assertState(
        _ state: UnreadState,
        count: Int,
        label: String?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(state.count, count, "count", file: file, line: line)
        XCTAssertEqual(state.label, label, "label", file: file, line: line)
    }

    // MARK: - update

    func testLeadingCount() {
        var tracker = UnreadTracker()
        assertState(tracker.update(title: "(3) Messenger | Facebook"), count: 3, label: "3")
    }

    func testPlusCount() {
        var tracker = UnreadTracker()
        assertState(tracker.update(title: "(20+) Messenger | Facebook"), count: 20, label: "20+")
    }

    func testNoCountFirstTitleIsZero() {
        var tracker = UnreadTracker()
        assertState(tracker.update(title: "Messenger | Facebook"), count: 0, label: nil)
    }

    func testFlashingKeepsPrevious() {
        var tracker = UnreadTracker()
        assertState(tracker.update(title: "(2) Messenger | Facebook"), count: 2, label: "2")
        assertState(tracker.update(title: "An đã gửi tin nhắn"), count: 2, label: "2")
        assertState(tracker.update(title: "(2) Messenger | Facebook"), count: 2, label: "2")
    }

    func testBackToBaseClears() {
        var tracker = UnreadTracker()
        assertState(tracker.update(title: "(2) Messenger | Facebook"), count: 2, label: "2")
        assertState(tracker.update(title: "Messenger | Facebook"), count: 0, label: nil)
    }

    func testZeroInParens() {
        var tracker = UnreadTracker()
        assertState(tracker.update(title: "(0) Messenger"), count: 0, label: nil)
    }

    func testNumberNotAtStartIgnored() {
        var tracker = UnreadTracker()
        assertState(tracker.update(title: "Chat (3)"), count: 0, label: nil)
        // "Chat (3)" became the base title, so seeing it again is not a flash.
        XCTAssertNil(tracker.flashText(for: "Chat (3)"))
    }

    // MARK: - flashText

    func testFlashText() {
        var tracker = UnreadTracker()
        _ = tracker.update(title: "(1) Messenger | Facebook")
        XCTAssertEqual(tracker.flashText(for: "An đã gửi tin nhắn"), "An đã gửi tin nhắn")
        XCTAssertNil(tracker.flashText(for: "Messenger | Facebook"))
        XCTAssertNil(tracker.flashText(for: "(1) Messenger | Facebook"))
    }

    // MARK: - reset

    func testResetForgetsBase() {
        var tracker = UnreadTracker()
        assertState(tracker.update(title: "(4) Messenger | Facebook"), count: 4, label: "4")
        XCTAssertEqual(tracker.flashText(for: "Other page"), "Other page")

        tracker.reset()

        // With no base, a title without a count is the new page's base title:
        // it is not a flash and does not keep the old count.
        XCTAssertNil(tracker.flashText(for: "Other page"))
        assertState(tracker.update(title: "Other page"), count: 0, label: nil)
        XCTAssertNil(tracker.flashText(for: "Other page"))
        XCTAssertEqual(tracker.flashText(for: "Messenger | Facebook"), "Messenger | Facebook")
    }
}
