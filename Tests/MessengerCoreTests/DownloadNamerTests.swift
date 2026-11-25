import XCTest
import MessengerCore

final class DownloadNamerTests: XCTestCase {
    // MARK: - Helpers

    private let directory = URL(fileURLWithPath: "/tmp/dl", isDirectory: true)

    /// The destination path for `suggested` when exactly `existing` (file
    /// names in the directory) exist.
    private func destination(_ suggested: String, existing: Set<String> = []) -> String {
        let existingPaths = Set(existing.map { "/tmp/dl/" + $0 })
        return DownloadNamer.destination(suggested: suggested, in: directory) { url in
            existingPaths.contains(url.path)
        }.path
    }

    // MARK: - destination

    func testPlainName() {
        XCTAssertEqual(destination("a.pdf"), "/tmp/dl/a.pdf")
    }

    func testCollisionOnce() {
        XCTAssertEqual(destination("a.pdf", existing: ["a.pdf"]), "/tmp/dl/a (1).pdf")
    }

    func testCollisionTwice() {
        XCTAssertEqual(destination("a.pdf", existing: ["a.pdf", "a (1).pdf"]), "/tmp/dl/a (2).pdf")
    }

    func testPathTraversal() {
        XCTAssertEqual(destination("../../etc/passwd"), "/tmp/dl/passwd")
    }

    func testEmptyAndDotNames() {
        for suggested in ["", "..", "/", ".", "../", ":"] {
            XCTAssertEqual(destination(suggested), "/tmp/dl/download", suggested.debugDescription)
        }
    }

    func testHiddenName() {
        XCTAssertEqual(destination(".bashrc"), "/tmp/dl/download.bashrc")
    }

    func testStripsControlCharactersAndColons() {
        XCTAssertEqual(destination("a:b\u{0}.txt"), "/tmp/dl/ab.txt")
        XCTAssertEqual(destination("a\nb\u{7F}.txt"), "/tmp/dl/ab.txt")
    }

    func testCollisionWithoutExtension() {
        XCTAssertEqual(destination("name", existing: ["name"]), "/tmp/dl/name (1)")
    }

    func testCollisionOfDefaultName() {
        XCTAssertEqual(destination("", existing: ["download"]), "/tmp/dl/download (1)")
    }

    func testStaysInDirectory() {
        let url = DownloadNamer.destination(suggested: "../x", in: directory) { _ in false }
        XCTAssertEqual(url.deletingLastPathComponent().path, "/tmp/dl")
    }
}
