import XCTest
import MessengerCore

final class StyleScriptTests: XCTestCase {
    // MARK: - Helpers

    private static let prefix = "window.__mw && window.__mw.setStyles("

    /// Checks the shape of a `make` result and decodes its two string
    /// arguments back, by reading `<json>,<json>` as a JSON array.
    private func decodeArguments(
        _ script: String,
        enabled: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> [String]? {
        let suffix = enabled ? ",true);" : ",false);"
        XCTAssertTrue(script.hasPrefix(Self.prefix), "prefix of \(script.debugDescription)", file: file, line: line)
        XCTAssertTrue(script.hasSuffix(suffix), "suffix of \(script.debugDescription)", file: file, line: line)
        for raw in ["\n", "\r", "\u{2028}", "\u{2029}"] {
            XCTAssertFalse(script.contains(raw), "raw \(raw.debugDescription) in \(script.debugDescription)", file: file, line: line)
        }
        guard script.hasPrefix(Self.prefix), script.hasSuffix(suffix) else {
            return nil
        }
        let arguments = script.dropFirst(Self.prefix.count).dropLast(suffix.count)
        let array = "[" + arguments + "]"
        do {
            return try JSONDecoder().decode([String].self, from: Data(array.utf8))
        } catch {
            XCTFail("arguments do not decode: \(error)", file: file, line: line)
            return nil
        }
    }

    // MARK: - make

    func testUserCSSRoundTrips() {
        let userCSSes = [
            "a`b",
            "</style><script>x</script>",
            "\"quote\" 'single'",
            "body {\n  color: red;\r\n}\n",
            "a\u{2028}b\u{2029}c",
            "back\\slash ${x} \u{0}",
        ]
        for user in userCSSes {
            let script = StyleScript.make(base: "html { margin: 0 }", user: user, enabled: true)
            XCTAssertEqual(decodeArguments(script, enabled: true), ["html { margin: 0 }", user], user.debugDescription)
        }
    }

    func testBaseCSSRoundTrips() {
        let base = "a\nb\u{2028}</style>`"
        let script = StyleScript.make(base: base, user: "", enabled: true)
        XCTAssertEqual(decodeArguments(script, enabled: true), [base, ""])
    }

    func testDisabled() {
        let script = StyleScript.make(base: "a", user: "b", enabled: false)
        XCTAssertTrue(script.hasSuffix(",false);"))
        XCTAssertEqual(decodeArguments(script, enabled: false), ["a", "b"])
    }

    func testExactOutputForPlainStrings() {
        XCTAssertEqual(
            StyleScript.make(base: "a", user: "b", enabled: true),
            "window.__mw && window.__mw.setStyles(\"a\",\"b\",true);"
        )
    }

    // MARK: - notificationClicked

    func testNotificationClicked() {
        XCTAssertEqual(
            StyleScript.notificationClicked(id: "n_1-a"),
            "window.__mw && window.__mw.notificationClicked(\"n_1-a\");"
        )
    }

    func testNotificationClickedRejectsBadID() {
        XCTAssertNil(StyleScript.notificationClicked(id: "x'); alert(1)//"))
        XCTAssertNil(StyleScript.notificationClicked(id: ""))
        XCTAssertNil(StyleScript.notificationClicked(id: "a\""))
    }
}
