import XCTest
@testable import MessengerCore

final class SmokeTests: XCTestCase {
    func testCoreBuilds() {
        XCTAssertTrue(CorePlaceholder.isAvailable)
    }
}
