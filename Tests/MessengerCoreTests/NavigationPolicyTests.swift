import Foundation
import XCTest
import MessengerCore

final class NavigationPolicyTests: XCTestCase {
    // MARK: - Helpers

    private func url(_ string: String, file: StaticString = #filePath, line: UInt = #line) -> URL {
        guard let url = URL(string: string) else {
            XCTFail("Invalid test URL: \(string)", file: file, line: line)
            return URL(string: "about:invalid")!
        }
        return url
    }

    private func decide(
        _ string: String,
        kind: NavigationKind,
        isMainFrame: Bool = true,
        opensNewWindow: Bool = false
    ) -> NavigationDecision {
        NavigationPolicy.decide(
            NavigationRequest(url: url(string), kind: kind, isMainFrame: isMainFrame, opensNewWindow: opensNewWindow)
        )
    }

    // MARK: - decide

    func testSubframeAllowed() {
        XCTAssertEqual(decide("https://ads.example.com/x", kind: .other, isMainFrame: false), .allow)
    }

    func testFacebookNonClickAllowed() {
        XCTAssertEqual(decide("https://www.facebook.com/checkpoint/?next", kind: .other), .allow)
    }

    func testMessengerHostNonClickAllowed() {
        XCTAssertEqual(decide("https://www.messenger.com/t/1", kind: .other), .allow)
    }

    func testMessagesLinkAllowed() {
        XCTAssertEqual(decide("https://www.facebook.com/messages/t/123", kind: .linkActivated), .allow)
    }

    func testWrappedLinkUnwrapped() {
        let wrapped = "https://l.facebook.com/l.php?u=https%3A%2F%2Fexample.com%2Fa%3Fb%3D1&h=x"
        let target = url("https://example.com/a?b=1")
        XCTAssertEqual(decide(wrapped, kind: .linkActivated), .openExternally(target))
        XCTAssertEqual(LinkUnwrapper.unwrap(url(wrapped)), target)

        let mobileWrapped = "https://lm.facebook.com/l.php?u=https%3A%2F%2Fexample.com%2Fa%3Fb%3D1&h=x"
        XCTAssertEqual(decide(mobileWrapped, kind: .linkActivated), .openExternally(target))
        XCTAssertEqual(LinkUnwrapper.unwrap(url(mobileWrapped)), target)
    }

    func testWrappedLinkWithoutU() {
        let wrapped = "https://l.facebook.com/l.php?h=x"
        XCTAssertEqual(decide(wrapped, kind: .linkActivated), .openExternally(url(wrapped)))
        XCTAssertNil(LinkUnwrapper.unwrap(url(wrapped)))
    }

    func testWrappedLinkNonHTTPTarget() {
        let wrapped = "https://l.facebook.com/l.php?u=javascript%3Aalert(1)"
        XCTAssertEqual(decide(wrapped, kind: .linkActivated), .cancel)
        XCTAssertNil(LinkUnwrapper.unwrap(url(wrapped)))
    }

    func testOtherFacebookLinkExternal() {
        let profile = "https://www.facebook.com/some.profile"
        XCTAssertEqual(decide(profile, kind: .linkActivated), .openExternally(url(profile)))
        XCTAssertNil(LinkUnwrapper.unwrap(url(profile)))
    }

    func testForeignHostExternal() {
        XCTAssertEqual(decide("https://example.com/", kind: .other), .openExternally(url("https://example.com/")))
    }

    func testLookalikeHosts() {
        for host in ["facebook.com.evil.com", "notfacebook.com", "xfacebook.com"] {
            XCTAssertFalse(NavigationPolicy.isFacebookHost(host), host)
            let target = "https://\(host)/messages/t/1"
            XCTAssertEqual(decide(target, kind: .other), .openExternally(url(target)), host)
            XCTAssertEqual(decide(target, kind: .linkActivated), .openExternally(url(target)), host)
        }
        XCTAssertFalse(NavigationPolicy.isFacebookHost(nil))
        XCTAssertFalse(NavigationPolicy.isFacebookHost(""))
    }

    func testRealHosts() {
        for host in ["facebook.com", "www.facebook.com", "web.facebook.com", "FACEBOOK.COM", "messenger.com"] {
            XCTAssertTrue(NavigationPolicy.isFacebookHost(host), host)
        }
    }

    func testMailtoExternal() {
        XCTAssertEqual(decide("mailto:a@b.c", kind: .linkActivated), .openExternally(url("mailto:a@b.c")))
    }

    func testJavascriptSchemeCancelled() {
        XCTAssertEqual(decide("javascript:void(0)", kind: .linkActivated), .cancel)
        XCTAssertEqual(decide("JAVASCRIPT:void(0)", kind: .other), .cancel)
    }

    func testBlobDataAboutAllowed() {
        for target in ["about:blank", "blob:https://www.facebook.com/x", "data:text/plain,hi"] {
            XCTAssertEqual(decide(target, kind: .other), .allow, target)
            XCTAssertEqual(decide(target, kind: .linkActivated), .allow, target)
        }
    }

    func testNewWindowMessagesLoadsInPlace() {
        let messages = "https://www.facebook.com/messages/t/1"
        XCTAssertEqual(decide(messages, kind: .linkActivated, opensNewWindow: true), .allow)
        XCTAssertEqual(decide(messages, kind: .other, opensNewWindow: true), .allow)
    }

    func testNewWindowBlankCancelled() {
        for target in ["about:blank", "blob:https://www.facebook.com/x", "data:text/plain,hi"] {
            XCTAssertEqual(decide(target, kind: .other, opensNewWindow: true), .cancel, target)
        }
    }

    func testNewWindowFacebookNonMessagesExternal() {
        let call = "https://www.facebook.com/groupcall/ROOM:1/"
        XCTAssertEqual(decide(call, kind: .other, opensNewWindow: true), .openExternally(url(call)))
    }

    // MARK: - shouldDownload

    func testShouldDownload() {
        XCTAssertTrue(NavigationPolicy.shouldDownload(canShowMIMEType: false, contentDisposition: nil))
        XCTAssertTrue(NavigationPolicy.shouldDownload(canShowMIMEType: true, contentDisposition: "attachment; filename=a.pdf"))
        XCTAssertFalse(NavigationPolicy.shouldDownload(canShowMIMEType: true, contentDisposition: "inline"))
        XCTAssertFalse(NavigationPolicy.shouldDownload(canShowMIMEType: true, contentDisposition: nil))
        XCTAssertTrue(NavigationPolicy.shouldDownload(canShowMIMEType: true, contentDisposition: "Attachment"))
        XCTAssertFalse(NavigationPolicy.shouldDownload(canShowMIMEType: true, contentDisposition: "inline; filename=attachment.pdf"))
    }

    // MARK: - Route

    func testRouteIsMessages() {
        for path in ["/messages", "/messages/", "/messages/t/1", "/messages/e2ee/t/1"] {
            XCTAssertTrue(Route.isMessages(path: path), path)
        }
        for path in ["/", "/login", "/messagesfoo", "/checkpoint/"] {
            XCTAssertFalse(Route.isMessages(path: path), path)
        }
    }
}
