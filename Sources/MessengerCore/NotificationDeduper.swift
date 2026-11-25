import Foundation

/// Decides whether the fallback notification (source B, "unread count went
/// up") is shown, given the notifications the page posts itself (source A).
///
/// When the count goes up, call `fallbackRequested()`; if it returns true,
/// wait `fallbackDelay` seconds, then call `fallbackDue()` and show the
/// fallback only if that returns true. A page notification during the wait
/// suppresses the fallback, and once the page has posted a notification the
/// fallback stays off for the rest of the run: the page's own notifications
/// are then known to work.
public struct NotificationDeduper {
    /// Seconds to wait for a page notification before showing the fallback.
    public static let fallbackDelay: TimeInterval = 3

    private var pageNotificationSeen = false
    private var fallbackPending = false

    public init() {}

    /// Records a notification posted by the page (source A).
    public mutating func pageNotificationArrived() {
        pageNotificationSeen = true
    }

    /// Asks for a fallback notification. Returns true when the caller should
    /// check back with `fallbackDue()` after `fallbackDelay`; false when the
    /// page has already posted a notification this run, or when a request is
    /// already waiting (the two are coalesced into one).
    public mutating func fallbackRequested() -> Bool {
        guard !pageNotificationSeen, !fallbackPending else {
            return false
        }
        fallbackPending = true
        return true
    }

    /// Ends the wait started by `fallbackRequested()`. Returns true when the
    /// fallback notification should be shown, i.e. when the page has never
    /// posted a notification this run.
    public mutating func fallbackDue() -> Bool {
        fallbackPending = false
        return !pageNotificationSeen
    }
}
