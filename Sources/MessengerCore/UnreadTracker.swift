import Foundation

/// The unread count shown on the Dock badge.
public struct UnreadState: Equatable {
    /// The number of unread items; 0 when there are none.
    public let count: Int
    /// The badge text, e.g. `"3"` or `"20+"`; nil when `count` is 0.
    public let label: String?

    static let zero = UnreadState(count: 0, label: nil)
}

/// Follows the page title and derives the unread count from it.
///
/// Facebook shows the count as a prefix, `(3) Messenger | Facebook` or
/// `(20+) Messenger | Facebook`. The text after the prefix is the *base title*.
/// While a new message arrives the page flashes titles such as
/// `An đã gửi tin nhắn`; those carry no count, so the previous count is kept.
/// The count only drops to 0 when the title is the base title without a count.
public struct UnreadTracker {
    // ^\((\d+)(\+?)\)\s*(.*)$ : count, optional "+", rest of the title.
    private static let countPattern = try! NSRegularExpression(pattern: #"^\((\d+)(\+?)\)\s*(.*)$"#)

    private var baseTitle: String?
    private var state = UnreadState.zero

    public init() {}

    /// Records a new page title and returns the resulting unread state.
    public mutating func update(title: String) -> UnreadState {
        if let counted = Self.parse(title) {
            baseTitle = counted.rest
            state = counted.state
            return state
        }
        guard let baseTitle else {
            // The first title without a count is the page's base title.
            self.baseTitle = title
            state = .zero
            return state
        }
        if title == baseTitle {
            state = .zero
        }
        // Otherwise the title is flashing: keep the previous state.
        return state
    }

    /// The flashing title, for use as fallback notification text: `title` when
    /// it has no count and differs from the base title, nil otherwise. Also nil
    /// before any base title is known, since `update` would record `title` as
    /// the base.
    public func flashText(for title: String) -> String? {
        guard let baseTitle, Self.parse(title) == nil, title != baseTitle else {
            return nil
        }
        return title
    }

    /// Forgets the base title and the count. Call when a new page starts loading.
    public mutating func reset() {
        baseTitle = nil
        state = .zero
    }

    /// The state and base title of a title with a count prefix, or nil when
    /// `title` has none.
    private static func parse(_ title: String) -> (state: UnreadState, rest: String)? {
        let range = NSRange(title.startIndex..., in: title)
        guard let match = countPattern.firstMatch(in: title, range: range),
              let digitsRange = Range(match.range(at: 1), in: title),
              let plusRange = Range(match.range(at: 2), in: title),
              let restRange = Range(match.range(at: 3), in: title),
              // Fails for non-ASCII digits and for counts too large for Int;
              // such titles are treated as having no count.
              let count = Int(title[digitsRange]) else {
            return nil
        }
        let label = count > 0 ? "\(count)\(title[plusRange])" : nil
        return (UnreadState(count: count, label: label), String(title[restRange]))
    }
}
