import Foundation

/// A message posted by `bridge.js` through the `mw` message handler.
///
/// The page is untrusted, so anything malformed decodes to nil: a body that is
/// not a dictionary, an unknown `type`, a missing required field, or a field of
/// the wrong type. Strings longer than `maxLength` characters are truncated.
public enum BridgeMessage: Equatable {
    /// `{ "type": "title", "title": string }`
    case title(String)
    /// `{ "type": "notification", "id": string, "title": string, "body": string?, "tag": string? }`
    case notification(id: String, title: String, body: String?, tag: String?)
    /// `{ "type": "unreadHint", "count": number }`
    case unreadHint(Int)

    /// The longest string kept, in characters (grapheme clusters).
    private static let maxLength = 500
    private static let maxIDLength = 64

    /// Decodes a message body as WebKit delivers it: `[String: Any]` holding
    /// `String`, `NSNumber` and `NSNull` values.
    public static func decode(_ body: Any) -> BridgeMessage? {
        guard let dictionary = body as? [String: Any],
              let type = dictionary["type"] as? String else {
            return nil
        }
        switch type {
        case "title":
            guard let title = string(dictionary["title"]) else {
                return nil
            }
            return .title(title)
        case "notification":
            guard let id = dictionary["id"] as? String, isValidID(id),
                  let title = string(dictionary["title"]),
                  let body = optionalString(dictionary["body"]),
                  let tag = optionalString(dictionary["tag"]) else {
                return nil
            }
            return .notification(id: id, title: title, body: body, tag: tag)
        case "unreadHint":
            guard let count = wholeNumber(dictionary["count"]) else {
                return nil
            }
            return .unreadHint(count)
        default:
            return nil
        }
    }

    /// True when `id` matches `^[A-Za-z0-9_-]{1,64}$`: safe to hand back to
    /// the page as a notification id.
    public static func isValidID(_ id: String) -> Bool {
        // Checked by hand rather than with a regex, whose `$` would also match
        // before a trailing newline.
        let scalars = id.unicodeScalars
        guard (1...maxIDLength).contains(scalars.count) else {
            return false
        }
        return scalars.allSatisfy { scalar in
            switch scalar {
            case "A"..."Z", "a"..."z", "0"..."9", "_", "-":
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Field decoding

    /// A string value, truncated to `maxLength` characters; nil otherwise.
    private static func string(_ value: Any?) -> String? {
        guard let string = value as? String else {
            return nil
        }
        return string.count > maxLength ? String(string.prefix(maxLength)) : string
    }

    /// `.some(nil)` when the field is missing, `.some(string)` when it is a
    /// string, and nil (reject the message) when it has any other type.
    private static func optionalString(_ value: Any?) -> String?? {
        guard let value else {
            return .some(nil)
        }
        guard let string = string(value) else {
            return nil
        }
        return .some(string)
    }

    /// A whole, non-negative number; nil for booleans, fractions, strings and
    /// anything else.
    ///
    /// On macOS every JavaScript number and boolean arrives as an `NSNumber`,
    /// and plain Swift `Int`, `Double` and `Bool` values bridge to one on both
    /// macOS and Linux, so a single `NSNumber` path covers all of them.
    private static func wholeNumber(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
              // Booleans are `NSNumber`s of type `char`, which no JavaScript
              // number produces.
              String(cString: number.objCType) != "c",
              // Succeeds only when the value is exactly representable as an
              // Int: fails for 3.5, NaN and infinities.
              let count = number as? Int,
              count >= 0 else {
            return nil
        }
        return count
    }
}
