import Foundation

/// How a navigation was started.
public enum NavigationKind {
    /// The user activated a link.
    case linkActivated
    /// Anything else: redirects, form submissions, script-driven loads, reloads.
    case other
}

/// The facts about a navigation that `NavigationPolicy` decides on.
public struct NavigationRequest {
    public let url: URL
    public let kind: NavigationKind
    /// Whether the navigation targets the main frame. Pass `true` for requests
    /// that would open a new window, since they would load as a main frame.
    public let isMainFrame: Bool
    /// Whether the page asked for a new window (`target=_blank`, `window.open`).
    public let opensNewWindow: Bool

    public init(url: URL, kind: NavigationKind, isMainFrame: Bool, opensNewWindow: Bool) {
        self.url = url
        self.kind = kind
        self.isMainFrame = isMainFrame
        self.opensNewWindow = opensNewWindow
    }
}

public enum NavigationDecision: Equatable {
    /// Load in the app's web view.
    case allow
    /// Hand the URL to the system (default browser, mail client, ...).
    case openExternally(URL)
    /// Do nothing.
    case cancel
}

/// Decides whether a navigation stays in the app, leaves it, or is dropped.
public enum NavigationPolicy {
    private static let localSchemes: Set<String> = ["about", "blob", "data"]
    private static let webSchemes: Set<String> = ["http", "https"]
    private static let facebookDomains = ["facebook.com", "messenger.com"]

    public static func decide(_ request: NavigationRequest) -> NavigationDecision {
        let url = request.url
        guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else {
            // Nothing the system could open either.
            return .cancel
        }

        if scheme == "javascript" {
            return .cancel
        }
        let isLocal = localSchemes.contains(scheme)
        if !isLocal && !webSchemes.contains(scheme) {
            return .openExternally(url)
        }
        if request.opensNewWindow && isLocal {
            return .cancel
        }
        if !request.isMainFrame {
            return .allow
        }
        if isLocal {
            return .allow
        }
        if !isFacebookHost(url.host) {
            return .openExternally(url)
        }
        if let wrapped = LinkUnwrapper.classify(url) {
            switch wrapped {
            case .target(let target):
                return .openExternally(target)
            case .noTarget:
                return .openExternally(url)
            case .unsafeTarget:
                return .cancel
            }
        }
        if Route.isMessages(path: url.path) {
            return .allow
        }
        if request.opensNewWindow || request.kind == .linkActivated {
            return .openExternally(url)
        }
        return .allow
    }

    /// True for `facebook.com`, `messenger.com` and any of their subdomains,
    /// ignoring case. Lookalikes such as `facebook.com.evil.com` or
    /// `notfacebook.com` are rejected.
    public static func isFacebookHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased(), !host.isEmpty else {
            return false
        }
        return facebookDomains.contains { domain in
            host == domain || host.hasSuffix("." + domain)
        }
    }

    /// True when a response should be downloaded instead of displayed: the web
    /// view cannot show its MIME type, or `Content-Disposition` is `attachment`.
    public static func shouldDownload(canShowMIMEType: Bool, contentDisposition: String?) -> Bool {
        if !canShowMIMEType {
            return true
        }
        guard let contentDisposition else {
            return false
        }
        let type = contentDisposition
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        return type == "attachment"
    }
}

/// Extracts the real destination from Facebook's outbound link wrapper
/// (`l.facebook.com/l.php?u=...`, `lm.facebook.com/l.php?u=...`).
public enum LinkUnwrapper {
    /// What a wrapper link points to.
    enum Wrapped: Equatable {
        /// An http(s) destination.
        case target(URL)
        /// No usable `u` parameter: missing, empty, unparseable, without a
        /// scheme, or http(s) without a host.
        case noTarget
        /// A `u` parameter with a scheme other than http(s), e.g. `javascript:`.
        case unsafeTarget
    }

    private static let wrapperHosts: Set<String> = ["l.facebook.com", "lm.facebook.com"]

    /// The http(s) destination of a wrapper link, or nil if `url` is not a
    /// wrapper link or has no http(s) destination.
    public static func unwrap(_ url: URL) -> URL? {
        if case .target(let target)? = classify(url) {
            return target
        }
        return nil
    }

    /// Nil when `url` is not a wrapper link.
    static func classify(_ url: URL) -> Wrapped? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host?.lowercased(), wrapperHosts.contains(host),
              url.path == "/l.php" else {
            return nil
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let value = components?.queryItems?.first(where: { $0.name == "u" })?.value,
              !value.isEmpty,
              let target = URL(string: value),
              let targetScheme = target.scheme?.lowercased() else {
            return .noTarget
        }
        guard targetScheme == "http" || targetScheme == "https" else {
            return .unsafeTarget
        }
        guard let targetHost = target.host, !targetHost.isEmpty else {
            return .noTarget
        }
        return .target(target)
    }
}

/// Facebook routes the app cares about.
public enum Route {
    /// True for `/messages` and anything under `/messages/`.
    public static func isMessages(path: String) -> Bool {
        path == "/messages" || path.hasPrefix("/messages/")
    }
}
