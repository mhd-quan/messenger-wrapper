import XCTest
import MessengerCore

final class HotKeySpecTests: XCTestCase {
    func testDefault() {
        XCTAssertEqual(HotKeySpec.default.keyCode, 46)
        XCTAssertEqual(HotKeySpec.default.modifiers, [.control, .option])
    }

    func testDefaultString() {
        XCTAssertEqual(HotKeySpec.parse("ctrl+opt+m"), .spec(.default))
    }

    func testCaseAndWhitespaceInsensitive() {
        guard case .spec(let spec) = HotKeySpec.parse("Cmd + Shift + K") else {
            return XCTFail("expected a spec")
        }
        XCTAssertEqual(spec.keyCode, 40)
        XCTAssertEqual(spec.modifiers, [.command, .shift])
    }

    func testSpace() {
        guard case .spec(let spec) = HotKeySpec.parse("alt+space") else {
            return XCTFail("expected a spec")
        }
        XCTAssertEqual(spec.keyCode, 49)
        XCTAssertEqual(spec.modifiers, [.option])
    }

    func testModifierAliases() {
        XCTAssertEqual(HotKeySpec.parse("control+option+m"), .spec(.default))
        XCTAssertEqual(HotKeySpec.parse("m+alt+ctrl"), .spec(.default))
        guard case .spec(let spec) = HotKeySpec.parse("command+ctrl+shift+opt+0") else {
            return XCTFail("expected a spec")
        }
        XCTAssertEqual(spec.keyCode, 29)
        XCTAssertEqual(spec.modifiers, [.command, .control, .shift, .option])
    }

    func testNone() {
        XCTAssertEqual(HotKeySpec.parse("none"), .disabled)
        XCTAssertEqual(HotKeySpec.parse(" None "), .disabled)
    }

    func testInvalid() {
        for string in ["m", "ctrl+", "ctrl+opt", "ctrl+m+k", "hyper+m", "", "ctrl+f1", "+m", "ctrl++m"] {
            XCTAssertEqual(HotKeySpec.parse(string), .invalid, string.debugDescription)
        }
    }
}
