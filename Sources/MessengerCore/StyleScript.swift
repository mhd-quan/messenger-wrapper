import Foundation

/// Builds the only scripts Swift evaluates in the page: calls to fixed
/// `window.__mw` functions whose arguments are encoded, never spliced in raw.
public enum StyleScript {
    /// `window.__mw && window.__mw.setStyles(<base>,<user>,<enabled>);` with
    /// both CSS texts as JSON string literals, so any CSS, including quotes,
    /// backticks, `</style>` and line breaks, reaches the page verbatim.
    public static func make(base: String, user: String, enabled: Bool) -> String {
        "window.__mw && window.__mw.setStyles(\(literal(base)),\(literal(user)),\(enabled));"
    }

    /// `window.__mw && window.__mw.notificationClicked("<id>");`, or nil when
    /// `id` is not a valid notification id (see `BridgeMessage.isValidID`).
    public static func notificationClicked(id: String) -> String? {
        guard BridgeMessage.isValidID(id) else {
            return nil
        }
        // A valid id holds only letters, digits, `_` and `-`: nothing to escape.
        return "window.__mw && window.__mw.notificationClicked(\"\(id)\");"
    }

    /// `string` as a JavaScript string literal.
    ///
    /// JSON escapes quotes, backslashes and control characters, but leaves
    /// U+2028 and U+2029 raw. Those are line terminators in JavaScript before
    /// ES2019, so they are escaped as well.
    private static func literal(_ string: String) -> String {
        // Encoding a String cannot fail.
        let data = try! JSONEncoder().encode(string)
        let json = String(decoding: data, as: UTF8.self)
        return json
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
}
