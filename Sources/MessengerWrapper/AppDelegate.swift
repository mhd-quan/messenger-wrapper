import AppKit
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static let startURL: URL = URL(string: "https://www.facebook.com/messages/")!
    private static let userAgentApplicationName: String = "Version/17.6 Safari/605.1.15"

    private var window: NSWindow?
    private var webView: WKWebView?
    private var spikeLog: SpikeLog?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let log: SpikeLog = SpikeLog()
        spikeLog = log
        log.write(event: "app", detail: "launched")

        NSApp.mainMenu = makeMainMenu()

        let configuration: WKWebViewConfiguration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.applicationNameForUserAgent = AppDelegate.userAgentApplicationName
        log.install(into: configuration.userContentController)

        let webView: WKWebView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1100, height: 750),
                                           configuration: configuration)
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        self.webView = webView

        let window: NSWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Messenger"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = webView
        window.center()
        self.window = window

        webView.load(URLRequest(url: AppDelegate.startURL))
        showWindow()
    }

    // Clicking the Dock icon brings the hidden window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        spikeLog?.write(event: "app", detail: "active")
    }

    func applicationDidResignActive(_ notification: Notification) {
        spikeLog?.write(event: "app", detail: "inactive")
    }

    func applicationWillTerminate(_ notification: Notification) {
        spikeLog?.write(event: "app", detail: "terminating")
    }

    // Closing (Cmd-W or the red button) only hides the window so the page keeps running.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        spikeLog?.write(event: "window", detail: "hidden")
        return false
    }

    private func showWindow() {
        guard let window: NSWindow = window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        spikeLog?.write(event: "window", detail: "shown")
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu: NSMenu = NSMenu()

        let appMenu: NSMenu = NSMenu(title: "Messenger")
        appMenu.addItem(withTitle: "Quit Messenger",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        addSubmenu(appMenu, to: mainMenu)

        let editMenu: NSMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        addSubmenu(editMenu, to: mainMenu)

        // Cmd-W needs a menu item to reach performClose(_:), which windowShouldClose turns into hide.
        let windowMenu: NSMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        addSubmenu(windowMenu, to: mainMenu)

        return mainMenu
    }

    private func addSubmenu(_ submenu: NSMenu, to mainMenu: NSMenu) {
        let item: NSMenuItem = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        mainMenu.addItem(item)
    }
}
