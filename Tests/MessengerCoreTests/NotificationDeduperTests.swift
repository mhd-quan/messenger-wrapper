import XCTest
import MessengerCore

final class NotificationDeduperTests: XCTestCase {
    func testFallbackDelay() {
        XCTAssertEqual(NotificationDeduper.fallbackDelay, 3)
    }

    func testFallbackAloneDelivers() {
        var deduper = NotificationDeduper()
        XCTAssertTrue(deduper.fallbackRequested())
        XCTAssertTrue(deduper.fallbackDue())
    }

    func testPageDuringWindowSuppresses() {
        var deduper = NotificationDeduper()
        XCTAssertTrue(deduper.fallbackRequested())
        deduper.pageNotificationArrived()
        XCTAssertFalse(deduper.fallbackDue())
    }

    func testFallbackDisabledAfterPage() {
        var deduper = NotificationDeduper()
        deduper.pageNotificationArrived()
        XCTAssertFalse(deduper.fallbackRequested())
    }

    func testCoalescesWhilePending() {
        var deduper = NotificationDeduper()
        XCTAssertTrue(deduper.fallbackRequested())
        XCTAssertFalse(deduper.fallbackRequested())
        XCTAssertTrue(deduper.fallbackDue())
        XCTAssertTrue(deduper.fallbackRequested())
    }
}
