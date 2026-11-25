# Messenger Wrapper v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Một `.app` macOS bọc `facebook.com/messages` bằng WKWebView, có badge Dock, thông báo macOS, chế độ tối giản bằng CSS và phím tắt toàn cục.

**Architecture:** Swift Package hai target. `MessengerCore` chứa logic thuần (chỉ import Foundation, test được bằng `swift test`, kể cả trên Linux). `MessengerWrapper` là executable AppKit + WebKit, gọi vào Core cho mọi quyết định. Một script dựng `.app` và ký ad-hoc.

**Tech Stack:** Swift 5.9+, AppKit, WebKit, UserNotifications, Carbon (hot key), XCTest, GitHub Actions (runner macOS). Không có thư viện bên thứ ba.

**Spec:** `docs/superpowers/specs/2026-11-25-messenger-wrapper-design.md`

## Global Constraints

- macOS tối thiểu 13.0 (`platforms: [.macOS(.v13)]`, `LSMinimumSystemVersion` 13.0). API 13.3+ (`isInspectable`) bọc trong `if #available`.
- Không thư viện bên thứ ba.
- `MessengerCore` không import AppKit, WebKit, UserNotifications, Carbon.
- Bundle id `local.messenger-wrapper`; tên hiển thị `Messenger`; tên binary `MessengerWrapper`.
- URL khởi động `https://www.facebook.com/messages/`.
- `applicationNameForUserAgent = "Version/17.6 Safari/605.1.15"`.
- Message handler tên `mw`; đối tượng JS toàn cục `window.__mw`.
- Thư mục dữ liệu: `~/Library/Application Support/MessengerWrapper/`.
- Tài nguyên đọc qua `Bundle.main`, không dùng `Bundle.module`.
- CSS: không dùng class băm, không dùng `aria-label` có chữ. Mọi rule trong `style.css` phải bắt đầu bằng `html[data-mw-route="messages"]`.
- Swift → JS chỉ gọi hàm cố định của `window.__mw` với tham số đã mã hoá JSON. Không `evaluateJavaScript` chuỗi do trang cung cấp.
- Phiên phát triển chạy trên Linux: không chạy được app. Mỗi task Core kết thúc bằng `swift test`; mỗi task app kết thúc bằng CI xanh (`swift build` trên runner macOS) và mục checklist thủ công tương ứng do người dùng chạy.

## Review Focus

1. **Mất mạng lúc mở app:** phải thấy trang lỗi có nút "Thử lại", không phải cửa sổ trắng. → Task 7, bước kiểm thủ công.
2. **Hết phiên đăng nhập / trang login:** CSS tối giản không được che form đăng nhập. → mọi rule gắn với `data-mw-route="messages"`; test `RouteTests` ở Task 2.
3. **`user.css` chứa ký tự đặc biệt** (backtick, `</style>`, dấu nháy, U+2028): phải được chèn nguyên văn, không vỡ script. → test `StyleScriptTests` ở Task 5.
4. **Tên file tải về độc hại hoặc trùng** (`../../x`, tên rỗng, đã tồn tại): file phải nằm trong `~/Downloads`, không ghi đè. → test `DownloadNamerTests` ở Task 5.
5. **Từ chối quyền thông báo:** app vẫn chạy, badge vẫn cập nhật, không hỏi lại, không crash. → Task 9, bước kiểm thủ công.

## File Structure

```
Package.swift
Sources/MessengerCore/
  NavigationPolicy.swift     # quyết định allow / mở ngoài / huỷ; Route; LinkUnwrapper
  UnreadTracker.swift        # tiêu đề → số chưa đọc
  BridgeMessage.swift        # giải mã message từ JS
  NotificationDeduper.swift  # điều phối nguồn A (trang) và B (dự phòng)
  HotKeySpec.swift           # chuỗi "ctrl+opt+m" → key code + modifier
  StyleScript.swift          # sinh lời gọi __mw.setStyles an toàn
  DownloadNamer.swift        # tên file đích an toàn, không trùng
Sources/MessengerWrapper/
  main.swift  AppDelegate.swift  MainMenu.swift  MainWindowController.swift
  WebViewFactory.swift  WebViewCoordinator.swift  Bridge.swift
  NotificationService.swift  HotKey.swift  UserStyles.swift  Features.swift
  SpikeLog.swift             # chỉ dùng cho bước kiểm chứng, xoá ở Task 11
Resources/  bridge.js  style.css  error.html  AppIcon.png
Support/Info.plist
Tests/MessengerCoreTests/    # một file test cho mỗi file Core
scripts/build-app.sh
.github/workflows/build.yml
```

---

### Task 1: Khung dự án, CI và bản dựng kiểm chứng

Kết quả: một app tối thiểu người dùng chạy được trên Mac để trả lời K1–K5 trong spec mục 10.

**Files:**
- Create: `Package.swift`, `Sources/MessengerCore/Placeholder.swift`, `Tests/MessengerCoreTests/SmokeTests.swift`
- Create: `Sources/MessengerWrapper/main.swift`, `AppDelegate.swift`, `SpikeLog.swift`
- Create: `Resources/spike.js`, `Support/Info.plist`, `scripts/build-app.sh`, `.github/workflows/build.yml`, `.gitignore`

**Interfaces:**
- Produces: target `MessengerCore` (library), `MessengerWrapper` (executable, chỉ khai báo khi `#if os(macOS)` trong `Package.swift` để `swift test` chạy được trên Linux), `MessengerCoreTests`.
- Produces: `scripts/build-app.sh [--install]` → `build/Messenger.app`.

- [ ] **Step 1:** Viết `Package.swift` (swift-tools-version 5.9) theo Interfaces. Viết `SmokeTests.testCoreBuilds` (một assert đúng). Chạy `swift test` nếu có toolchain; nếu không, để CI chạy.
- [ ] **Step 2:** Viết `.github/workflows/build.yml`: `on: [push]`, `runs-on: macos-14`, các bước `swift build -c release` và `swift test`.
- [ ] **Step 3:** Viết `Support/Info.plist` với: `CFBundleIdentifier` `local.messenger-wrapper`, `CFBundleName` và `CFBundleDisplayName` `Messenger`, `CFBundleExecutable` `MessengerWrapper`, `CFBundleIconFile` `AppIcon`, `CFBundlePackageType` `APPL`, `CFBundleShortVersionString` `0.1.0`, `LSMinimumSystemVersion` `13.0`, `LSApplicationCategoryType` `public.app-category.social-networking`, `NSPrincipalClass` `NSApplication`, `NSHighResolutionCapable` true.
- [ ] **Step 4:** Viết `scripts/build-app.sh` (`set -euo pipefail`): `swift build -c release` → tạo `build/Messenger.app/Contents/{MacOS,Resources}` → copy binary, `Info.plist`, toàn bộ `Resources/` → nếu có `Resources/AppIcon.png` thì sinh `AppIcon.icns` bằng `sips` + `iconutil` → `codesign --force --sign - build/Messenger.app` → với `--install`: `osascript -e 'quit app "Messenger"'` (bỏ qua lỗi), `rm -rf /Applications/Messenger.app`, `cp -R`.
- [ ] **Step 5:** Viết app tối thiểu. `main.swift`: tạo `NSApplication.shared`, gán `AppDelegate`, `setActivationPolicy(.regular)`, `run()`. `AppDelegate`: một `NSWindow` 1100×750 chứa `WKWebView` (data store mặc định, UA theo Global Constraints, `isInspectable = true`), menu tối thiểu App (Quit) + Edit (Cut/Copy/Paste/Select All), load URL khởi động, ⌘W ẩn cửa sổ, click Dock hiện lại.
- [ ] **Step 6:** Viết `Resources/spike.js` (chèn `documentStart`, main frame) và `SpikeLog.swift` ghi từng dòng có timestamp ISO-8601 vào `~/Library/Logs/MessengerWrapper/spike.log`. Script gửi qua handler `mw`:
  - `title`: mỗi lần `document.title` đổi, kèm `document.visibilityState`.
  - `notification`: mỗi lần trang gọi `new Notification(t, o)` (lớp giả, `permission` là `"granted"`), ghi `t`, `o.body`, `o.tag`.
  - `sw`: một lần, `"serviceWorker" in navigator` và `"PushManager" in window`.
  - `layout`: 5 giây sau `load` và mỗi 60 giây: có `[role="banner"]` không, `offsetHeight` của nó, và mọi custom property trên `:root` có tên chứa `header` cùng giá trị.
  - `heartbeat`: mỗi 30 giây, kèm `visibilityState` (để đo việc bóp timer khi ẩn).
- [ ] **Step 7:** Commit, push, xác nhận CI xanh.
- [ ] **Step 8 (người dùng, trên Mac):** `./scripts/build-app.sh --install`, mở app, rồi:
  1. Đăng nhập (K1). Thoát, mở lại, kiểm tra còn đăng nhập.
  2. Nhờ người khác gửi 2 tin khi cửa sổ đang hiện nhưng app không ở trước (K2, K3).
  3. ⌘W, đợi 10 phút, nhận thêm 1 tin (K4).
  4. Gửi lại file `spike.log` (xoá nội dung tin nhắn nếu muốn) và cho biết Facebook đang có bao nhiêu thông báo không phải tin nhắn lúc thử (để phân biệt ở K2).
- [ ] **Step 9:** Đọc log, ghi câu trả lời K1–K5 vào spec mục 10, sửa các task sau nếu kết quả khác giả định. **K1 thất bại thì dừng và báo người dùng.**

### Task 2: NavigationPolicy, Route, LinkUnwrapper

**Files:**
- Create: `Sources/MessengerCore/NavigationPolicy.swift`, `Tests/MessengerCoreTests/NavigationPolicyTests.swift`
- Delete: `Sources/MessengerCore/Placeholder.swift`, `SmokeTests.swift`

**Interfaces — Produces:**

```swift
public enum NavigationKind { case linkActivated, other }
public struct NavigationRequest {
    public init(url: URL, kind: NavigationKind, isMainFrame: Bool, opensNewWindow: Bool)
}
public enum NavigationDecision: Equatable { case allow, openExternally(URL), cancel }
public enum NavigationPolicy {
    public static func decide(_ request: NavigationRequest) -> NavigationDecision
    public static func isFacebookHost(_ host: String?) -> Bool
    public static func shouldDownload(canShowMIMEType: Bool, contentDisposition: String?) -> Bool
}
public enum LinkUnwrapper { public static func unwrap(_ url: URL) -> URL? }
public enum Route { public static func isMessages(path: String) -> Bool }
```

- [ ] **Step 1: Viết test thất bại.** Mỗi dòng của bảng spec 6.3 là một test. Các giá trị cụ thể:

| Test | Đầu vào | Kỳ vọng |
|---|---|---|
| `testSubframeAllowed` | `https://ads.example.com/x`, other, sub-frame | `.allow` |
| `testFacebookNonClickAllowed` | `https://www.facebook.com/checkpoint/?next`, other, main | `.allow` |
| `testMessengerHostNonClickAllowed` | `https://www.messenger.com/t/1`, other, main | `.allow` |
| `testMessagesLinkAllowed` | `https://www.facebook.com/messages/t/123`, link, main | `.allow` |
| `testWrappedLinkUnwrapped` | `https://l.facebook.com/l.php?u=https%3A%2F%2Fexample.com%2Fa%3Fb%3D1&h=x`, link | `.openExternally(https://example.com/a?b=1)` |
| `testWrappedLinkWithoutU` | `https://l.facebook.com/l.php?h=x`, link | `.openExternally(url gốc)` |
| `testWrappedLinkNonHTTPTarget` | `l.php?u=javascript%3Aalert(1)`, link | `.cancel` |
| `testOtherFacebookLinkExternal` | `https://www.facebook.com/some.profile`, link, main | `.openExternally(url)` |
| `testForeignHostExternal` | `https://example.com/`, other, main | `.openExternally(url)` |
| `testLookalikeHosts` | `facebook.com.evil.com`, `notfacebook.com`, `xfacebook.com` | `isFacebookHost` false; `decide` → `.openExternally` |
| `testRealHosts` | `facebook.com`, `www.facebook.com`, `web.facebook.com`, `FACEBOOK.COM`, `messenger.com` | `isFacebookHost` true |
| `testMailtoExternal` | `mailto:a@b.c` | `.openExternally(url)` |
| `testJavascriptSchemeCancelled` | `javascript:void(0)` | `.cancel` |
| `testBlobDataAboutAllowed` | `about:blank`, `blob:https://www.facebook.com/x`, `data:text/plain,hi`, không mở cửa sổ mới | `.allow` |
| `testNewWindowMessagesLoadsInPlace` | `/messages/t/1`, `opensNewWindow: true` | `.allow` |
| `testNewWindowBlankCancelled` | `about:blank`, `opensNewWindow: true` | `.cancel` |
| `testNewWindowFacebookNonMessagesExternal` | `https://www.facebook.com/groupcall/ROOM:1/`, other, `opensNewWindow: true` | `.openExternally(url)` |
| `testShouldDownload` | `(false, nil)` → true; `(true, "attachment; filename=a.pdf")` → true; `(true, "inline")` → false; `(true, nil)` → false | |
| `testRouteIsMessages` | `/messages`, `/messages/`, `/messages/t/1`, `/messages/e2ee/t/1` → true; `/`, `/login`, `/messagesfoo`, `/checkpoint/` → false | |

- [ ] **Step 2:** `swift test --filter NavigationPolicyTests` → FAIL (chưa có kiểu).
- [ ] **Step 3:** Hiện thực. Thứ tự xét trong `decide`: scheme `javascript` → cancel; scheme ngoài http/https/about/blob/data → openExternally; `opensNewWindow` với about/blob/data → cancel; sub-frame → allow; about/blob/data → allow; host không phải Facebook → openExternally; link bọc (`LinkUnwrapper`) → theo bảng; `Route.isMessages` → allow; `opensNewWindow` hoặc `linkActivated` → openExternally; còn lại → allow.
- [ ] **Step 4:** `swift test --filter NavigationPolicyTests` → PASS.
- [ ] **Step 5:** Commit `feat(core): navigation policy`.

### Task 3: UnreadTracker

**Files:** Create `Sources/MessengerCore/UnreadTracker.swift`, `Tests/MessengerCoreTests/UnreadTrackerTests.swift`

**Interfaces — Produces:**

```swift
public struct UnreadState: Equatable {
    public let count: Int        // 0 nếu không có
    public let label: String?    // "3", "20+"; nil khi count == 0
}
public struct UnreadTracker {
    public init()
    public mutating func update(title: String) -> UnreadState
    public func flashText(for title: String) -> String?   // tiêu đề nhấp nháy, dùng làm nội dung thông báo dự phòng
    public mutating func reset()                          // gọi khi bắt đầu tải trang mới
}
```

Quy tắc: tiêu đề khớp `^\((\d+)(\+?)\)\s*(.*)$` → số đó, và phần còn lại trở thành *tiêu đề gốc*. Tiêu đề không số: nếu chưa có tiêu đề gốc → ghi nhận làm gốc, trả 0; nếu bằng gốc → 0; nếu khác gốc (đang nhấp nháy) → giữ trạng thái trước. `flashText` trả tiêu đề khi nó không số và khác gốc, ngược lại nil.

- [ ] **Step 1: Test thất bại:**
  - `testLeadingCount`: `"(3) Messenger | Facebook"` → `count 3, label "3"`.
  - `testPlusCount`: `"(20+) Messenger | Facebook"` → `count 20, label "20+"`.
  - `testNoCountFirstTitleIsZero`: `"Messenger | Facebook"` → 0, nil.
  - `testFlashingKeepsPrevious`: chuỗi `"(2) Messenger | Facebook"`, `"An đã gửi tin nhắn"`, `"(2) Messenger | Facebook"` → 2, 2, 2.
  - `testBackToBaseClears`: `"(2) Messenger | Facebook"`, `"Messenger | Facebook"` → 2, 0.
  - `testFlashText`: sau `"(1) Messenger | Facebook"`, `flashText(for: "An đã gửi tin nhắn")` == `"An đã gửi tin nhắn"`; `flashText(for: "Messenger | Facebook")` nil; `flashText(for: "(1) Messenger | Facebook")` nil.
  - `testZeroInParens`: `"(0) Messenger"` → 0, nil.
  - `testNumberNotAtStartIgnored`: gốc `"Chat (3)"` → 0.
  - `testResetForgetsBase`.
- [ ] **Step 2:** chạy → FAIL. **Step 3:** hiện thực. **Step 4:** chạy → PASS. **Step 5:** commit `feat(core): unread tracker`.

### Task 4: BridgeMessage

**Files:** Create `Sources/MessengerCore/BridgeMessage.swift`, `Tests/MessengerCoreTests/BridgeMessageTests.swift`

**Interfaces — Produces:**

```swift
public enum BridgeMessage: Equatable {
    case title(String)
    case notification(id: String, title: String, body: String?, tag: String?)
    case unreadHint(Int)
    public static func decode(_ body: Any) -> BridgeMessage?
    public static func isValidID(_ id: String) -> Bool   // ^[A-Za-z0-9_-]{1,64}$
}
```

`body` là `[String: Any]` như WebKit trả về. Chuỗi dài hơn 500 ký tự bị cắt còn 500.

- [ ] **Step 1: Test thất bại:** `testTitle`; `testNotificationFull`; `testNotificationOptionalFieldsMissing` (body, tag nil); `testNotificationBadID` (`"a b"`, `"'); alert(1)//"`, chuỗi 65 ký tự, rỗng → nil); `testUnreadHint` (3 → `.unreadHint(3)`; `-1`, `"3"`, `3.5` → nil); `testUnknownType` → nil; `testNotADictionary` (`"x"`, `42`, `NSNull()`) → nil; `testWrongFieldType` (`title: 5`) → nil; `testLongStringsTruncated` (600 ký tự → 500).
- [ ] **Step 2–5:** chạy FAIL → hiện thực → PASS → commit `feat(core): bridge message decoding`.

### Task 5: NotificationDeduper, HotKeySpec, StyleScript, DownloadNamer

Bốn đơn vị nhỏ độc lập, cùng một vòng review.

**Files:** Create `NotificationDeduper.swift`, `HotKeySpec.swift`, `StyleScript.swift`, `DownloadNamer.swift` trong `Sources/MessengerCore/` và file test tương ứng.

**Interfaces — Produces:**

```swift
public struct NotificationDeduper {
    public static let fallbackDelay: TimeInterval = 3
    public init()
    public mutating func pageNotificationArrived()            // nguồn A
    public mutating func fallbackRequested(at now: Date) -> Bool   // true: hãy hẹn kiểm tra sau fallbackDelay
    public mutating func fallbackDue() -> Bool                // true: phát thông báo dự phòng
}

public struct HotKeySpec: Equatable {
    public struct Modifiers: OptionSet { control, option, shift, command }
    public let keyCode: UInt32      // mã phím ảo ANSI
    public let modifiers: Modifiers
    public static let `default`     // ctrl+opt+m, keyCode 46
    public enum Parsed: Equatable { case spec(HotKeySpec), disabled, invalid }
    public static func parse(_ string: String) -> Parsed
}

public enum StyleScript {
    public static func make(base: String, user: String, enabled: Bool) -> String
    // → "window.__mw && window.__mw.setStyles(<json>,<json>,<bool>);"
    public static func notificationClicked(id: String) -> String?   // nil nếu id không hợp lệ
}

public enum DownloadNamer {
    public static func destination(suggested: String, in directory: URL,
                                   exists: (URL) -> Bool) -> URL
}
```

Quy tắc:
- **Deduper:** `fallbackRequested` trả false nếu nguồn A đã từng đến, hoặc đang có một yêu cầu chờ. `fallbackDue` xoá trạng thái chờ và trả true chỉ khi nguồn A chưa từng đến.
- **HotKeySpec:** phân tách bằng `+`, không phân biệt hoa thường, bỏ khoảng trắng. Modifier: `ctrl|control`, `opt|option|alt`, `shift`, `cmd|command`. Phím: `a`–`z`, `0`–`9`, `space`. Cần đúng một phím và ít nhất một modifier. `"none"` → `.disabled`.
- **StyleScript:** mã hoá bằng `JSONEncoder`, sau đó thay U+2028 và U+2029 bằng ` `, ` `.
- **DownloadNamer:** lấy `lastPathComponent` của `suggested`, bỏ ký tự điều khiển và `/`, `:`; rỗng hoặc `.`/`..` → `download`; tên bắt đầu bằng `.` thì thêm tiền tố `download`. Trùng → `name (1).ext`, `name (2).ext`…

- [ ] **Step 1: Test thất bại:**
  - Deduper: `testFallbackAloneDelivers` (requested → true, due → true); `testPageDuringWindowSuppresses` (requested, page, due → false); `testFallbackDisabledAfterPage` (page, requested → false); `testCoalescesWhilePending` (requested true, requested false, due true, requested true).
  - HotKeySpec: `"ctrl+opt+m"` == `.spec(.default)`; `"Cmd + Shift + K"` → keyCode 40, `[.command, .shift]`; `"alt+space"` → keyCode 49; `"none"` → `.disabled`; `"m"`, `"ctrl+"`, `"ctrl+opt"`, `"ctrl+m+k"`, `"hyper+m"`, `""` → `.invalid`.
  - StyleScript: với `user` lần lượt là `` a`b ``, `</style><script>x</script>`, `"quote" 'single'`, chuỗi nhiều dòng, chuỗi chứa U+2028: kết quả không chứa xuống dòng thô hay U+2028 thô, và phần JSON giải mã lại đúng nguyên văn; `enabled: false` → kết thúc bằng `,false);`. `notificationClicked(id: "n_1-a")` == `"window.__mw && window.__mw.notificationClicked(\"n_1-a\");"`; id `"x'); alert(1)//"` → nil.
  - DownloadNamer (với `/tmp/dl`): `"a.pdf"` → `/tmp/dl/a.pdf`; trùng một lần → `a (1).pdf`; trùng hai → `a (2).pdf`; `"../../etc/passwd"` → `/tmp/dl/passwd`; `""`, `".."`, `"/"` → `/tmp/dl/download`; `".bashrc"` → `/tmp/dl/download.bashrc`; `"a:b\u{0}.txt"` → `/tmp/dl/ab.txt`; không đuôi trùng → `name (1)`.
- [ ] **Step 2–5:** chạy FAIL → hiện thực → PASS → commit `feat(core): deduper, hotkey spec, style script, download namer`.

### Task 6: Vỏ app: cửa sổ, menu, WebViewFactory

**Files:**
- Create: `Sources/MessengerWrapper/MainMenu.swift`, `MainWindowController.swift`, `WebViewFactory.swift`, `Features.swift`
- Modify: `AppDelegate.swift` (bỏ phần dựng cửa sổ tạm của Task 1)

**Interfaces — Produces:**

```swift
enum Features { static let calls = false }

final class WebViewFactory {
    init(bridge: WKScriptMessageHandler, userScripts: [WKUserScript])
    func makeConfiguration() -> WKWebViewConfiguration   // dùng lại được cho webview thứ hai
    func makeWebView() -> WKWebView
    static let startURL: URL
}

final class MainWindowController: NSWindowController, NSWindowDelegate {
    init(webView: WKWebView)
    func showAndActivate()
    var isFrontmost: Bool { get }     // NSApp.isActive && window.isKeyWindow
    var isVisibleToUser: Bool { get } // NSApp.isActive && window.isVisible && !window.isMiniaturized
}

enum MainMenu { static func build(target: AppDelegate) -> NSMenu }
```

Các action trên `AppDelegate` mà menu trỏ tới: `reloadPage`, `goToMessages`, `toggleMinimalMode`, `reloadStyles`, `openStylesFolder`, `zoomIn`, `zoomOut`, `zoomReset`, `showMainWindow`.

- [ ] **Step 1:** `MainWindowController`: tiêu đề `Messenger`, 1100×750, tối thiểu 480×400, `setFrameAutosaveName("MainWindow")`, `windowShouldClose` → `orderOut` và trả false. `applicationShouldHandleReopen` → `showAndActivate`. `applicationShouldTerminateAfterLastWindowClosed` → false.
- [ ] **Step 2:** `MainMenu` theo spec 6.1, đúng phím tắt: ⌘R, ⌘⇧M, ⌘⇧L, ⌘⌥R, ⌘+, ⌘-, ⌘0. Edit menu có Undo/Redo/Cut/Copy/Paste/Select All.
- [ ] **Step 3:** `WebViewFactory` theo spec 6.2. Zoom: `webView.pageZoom`, bước 0.1, giới hạn 0.5–3.0, lưu `UserDefaults` khoá `pageZoom`.
- [ ] **Step 4:** Push, CI xanh. Commit `feat(app): window, menu, web view factory`.

### Task 7: WebViewCoordinator: điều hướng, file, lỗi

**Files:** Create `Sources/MessengerWrapper/WebViewCoordinator.swift`, `Resources/error.html`

**Interfaces:**
- Consumes: `NavigationPolicy`, `NavigationRequest`, `DownloadNamer`, `Features.calls`.
- Produces: `final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate` với `var onPageStarted: (() -> Void)?` và `var onPageFinished: (() -> Void)?`.

- [ ] **Step 1:** `decidePolicyFor navigationAction`: `shouldPerformDownload` → `.download`; ngược lại dựng `NavigationRequest` (`kind` là `.linkActivated` khi `navigationType == .linkActivated`, `isMainFrame` từ `targetFrame?.isMainFrame ?? true`) và làm theo `NavigationPolicy.decide`. `.openExternally` → `NSWorkspace.shared.open` rồi `.cancel`.
- [ ] **Step 2:** `decidePolicyFor navigationResponse`: `NavigationPolicy.shouldDownload(canShowMIMEType:contentDisposition:)` → `.download`.
- [ ] **Step 3:** `createWebViewWith`: dựng request với `opensNewWindow: true`; `.allow` → `webView.load(navigationAction.request)`; luôn trả nil. Ghi chú trong code: đây là điểm mở rộng cho cửa sổ cuộc gọi (spec mục 9.3).
- [ ] **Step 4:** Download: đích là `DownloadNamer.destination(suggested:in: ~/Downloads, exists: FileManager.fileExists)`; xong thì post `com.apple.DownloadFileFinished` qua `DistributedNotificationCenter` với object là đường dẫn file; lỗi → `NSAlert`.
- [ ] **Step 5:** `runOpenPanelWith` → `NSOpenPanel` theo `allowsMultipleSelection` và `allowsDirectories`. `runJavaScriptAlertPanel` / `ConfirmPanel` → `NSAlert`. `requestMediaCapturePermissionFor` → `Features.calls ? .grant : .deny`.
- [ ] **Step 6:** `didFailProvisionalNavigation` (bỏ qua `NSURLErrorCancelled` và lỗi 102 "Frame load interrupted") → load `error.html` từ bundle; trang hiện mô tả lỗi và nút "Thử lại" dẫn tới `WebViewFactory.startURL`. `webViewWebContentProcessDidTerminate` → `reload()`.
- [ ] **Step 7:** Push, CI xanh. Commit `feat(app): navigation, downloads, uploads, error page`.
- [ ] **Step 8 (người dùng):** checklist spec mục 7, điểm 1–4. Thêm: tắt Wi-Fi rồi mở app → thấy trang lỗi; bật lại, bấm "Thử lại" → vào được.

### Task 8: bridge.js, Bridge, badge

**Files:**
- Create: `Resources/bridge.js`, `Sources/MessengerWrapper/Bridge.swift`
- Delete: `Resources/spike.js`, `SpikeLog.swift`
- Modify: `AppDelegate.swift`

**Interfaces:**
- Consumes: `BridgeMessage.decode`, `UnreadTracker`, `NavigationPolicy.isFacebookHost`.
- Produces:

```swift
final class Bridge: NSObject, WKScriptMessageHandler {
    static let handlerName = "mw"
    var onUnreadChanged: ((UnreadState, _ flashText: String?) -> Void)?
    var onPageNotification: ((_ id: String, _ title: String, _ body: String?) -> Void)?
    func pageStarted()   // reset tracker
}
```

- JS toàn cục: `window.__mw = { setStyles(base, user, enabled), notificationClicked(id) }`.

- [ ] **Step 1:** `bridge.js` (IIFE, chạy một lần, chỉ khi `window.top === window`):
  - Tiêu đề: `MutationObserver` trên `document.head` (childList + subtree + characterData), gửi `{type:"title"}` khi giá trị đổi và ở `DOMContentLoaded`, `load`.
  - Route: đặt `document.documentElement.dataset.mwRoute = "messages"` khi `location.pathname` khớp `^/messages(/|$)`, xoá khi không; cập nhật khi bọc `history.pushState` / `replaceState` và ở `popstate`.
  - Notification giả theo spec 6.5: id dạng `n_<bộ đếm>_<random base36>`; giữ tối đa 50 instance gần nhất; `notificationClicked(id)` gọi `onclick` và phát event `click`.
  - Style: hai thẻ `<style id="mw-base">`, `<style id="mw-user">` gắn vào `documentElement`, nội dung đặt qua `textContent`; `enabled` false thì đặt `media="not all"`.
- [ ] **Step 2:** `Bridge.userContentController(_:didReceive:)`: bỏ qua nếu `!message.frameInfo.isMainFrame` hoặc host của `frameInfo.securityOrigin` không qua `isFacebookHost`; giải mã; `.title` → `tracker.update` rồi `onUnreadChanged`; `.notification` → `onPageNotification`; `.unreadHint` → theo kết quả K2 (mặc định: bỏ qua).
- [ ] **Step 3:** `AppDelegate`: `onUnreadChanged` → `NSApp.dockTile.badgeLabel = state.label`. `coordinator.onPageStarted` → `bridge.pageStarted()`.
- [ ] **Step 4:** Push, CI xanh. Commit `feat(app): js bridge and dock badge`.
- [ ] **Step 5 (người dùng):** checklist điểm 6 và phần badge của điểm 5.

### Task 9: NotificationService

**Files:** Create `Sources/MessengerWrapper/NotificationService.swift`; Modify `AppDelegate.swift`

**Interfaces:**
- Consumes: `NotificationDeduper`, `StyleScript.notificationClicked(id:)`, `Bridge.onPageNotification`, `Bridge.onUnreadChanged`, `MainWindowController.isVisibleToUser`.
- Produces:

```swift
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    init(isVisibleToUser: @escaping () -> Bool, onClick: @escaping (_ pageNotificationID: String?) -> Void)
    func requestAuthorizationIfNeeded()
    func pageNotification(id: String, title: String, body: String?)
    func unreadChanged(from old: Int, to new: Int, flashText: String?)
    func clearDelivered()
}
```

- [ ] **Step 1:** `requestAuthorizationIfNeeded`: chỉ gọi `requestAuthorization(options: [.alert, .sound])` khi trạng thái là `.notDetermined`. Mọi lỗi và trạng thái `.denied` đều bị nuốt, chỉ ghi log.
- [ ] **Step 2:** `pageNotification`: báo deduper; nếu `isVisibleToUser()` thì thôi; ngược lại phát thông báo với `userInfo["pageID"] = id`.
- [ ] **Step 3:** `unreadChanged`: chỉ xử lý khi `new > old`; `fallbackRequested(at:)` true → hẹn `DispatchQueue.main.asyncAfter(NotificationDeduper.fallbackDelay)`; khi đến hạn, `fallbackDue()` true và `!isVisibleToUser()` → phát thông báo tiêu đề `Messenger`, nội dung là `flashText ?? "Tin nhắn mới"`.
- [ ] **Step 4:** Delegate: `willPresent` → `[.banner, .sound]`; `didReceive` → `onClick(pageID)`. `AppDelegate.onClick`: `showAndActivate()`, rồi nếu có id và `StyleScript.notificationClicked(id:)` khác nil thì `evaluateJavaScript`. `windowDidBecomeKey` → `clearDelivered()`.
- [ ] **Step 5:** Push, CI xanh. Commit `feat(app): notifications`.
- [ ] **Step 6 (người dùng):** checklist điểm 5 và 7. Thêm: vào System Settings tắt quyền thông báo của app, mở lại → app chạy bình thường, badge vẫn lên, không bị hỏi lại.

### Task 10: Chế độ tối giản và user.css

**Files:** Create `Sources/MessengerWrapper/UserStyles.swift`, `Resources/style.css`; Modify `AppDelegate.swift`, `WebViewFactory.swift`

**Interfaces:**
- Consumes: `StyleScript.make(base:user:enabled:)`.
- Produces:

```swift
final class UserStyles {
    static let directory: URL    // ~/Library/Application Support/MessengerWrapper
    static let userCSSURL: URL   // …/user.css
    var isEnabled: Bool          // UserDefaults "minimalMode", mặc định true
    func ensureUserFileExists()
    func currentScript() -> String        // StyleScript.make với nội dung hiện tại của hai file
    func makeUserScript() -> WKUserScript // currentScript, documentStart, main frame, chèn sau bridge.js
}
```

- [ ] **Step 1:** `UserStyles`: `user.css` không đọc được hoặc lớn hơn 1 MB → coi như rỗng và ghi log. File tạo lần đầu chứa một khối chú thích hướng dẫn: cách nạp lại (⌘⌥R), cách tắt (⌘⇧L), và quy ước tiền tố `html[data-mw-route="messages"]`.
- [ ] **Step 2:** `reloadStyles` → `evaluateJavaScript(currentScript())` và thay user script trong `userContentController` để lần tải trang sau dùng bản mới. `toggleMinimalMode` → đảo `isEnabled`, rồi như `reloadStyles`; mục menu hiện dấu tick theo trạng thái. `openStylesFolder` → `NSWorkspace.shared.activateFileViewerSelecting([userCSSURL])`.
- [ ] **Step 3:** `style.css` bản đầu, dựa trên kết quả K5: ẩn `[role="banner"]` và thu hồi khoảng trống của nó. Mọi rule theo Global Constraints.
- [ ] **Step 4:** Push, CI xanh. Commit `feat(app): minimal mode and user css`.
- [ ] **Step 5 (người dùng):** checklist điểm 8. Thêm: đăng xuất → form đăng nhập hiện đầy đủ dù chế độ tối giản đang bật. Người dùng gửi ảnh chụp màn hình và danh sách những phần còn muốn ẩn; lặp lại Step 3 cho tới khi ưng.

### Task 11: Phím tắt toàn cục, icon, dọn dẹp

**Files:** Create `Sources/MessengerWrapper/HotKey.swift`, `Resources/AppIcon.png`; Modify `AppDelegate.swift`, `README.md`

**Interfaces:**
- Consumes: `HotKeySpec.parse`, `HotKeySpec.default`, `MainWindowController.isFrontmost`, `showAndActivate()`.
- Produces: `final class HotKey { init?(spec: HotKeySpec, handler: @escaping () -> Void) }` (nil khi `RegisterEventHotKey` thất bại; `deinit` huỷ đăng ký).

- [ ] **Step 1:** `HotKey` bằng Carbon: `InstallEventHandler` cho `kEventClassKeyboard` / `kEventHotKeyPressed`, `RegisterEventHotKey` với signature `'MWHK'`, id 1. Ánh xạ `Modifiers` → `controlKey`, `optionKey`, `shiftKey`, `cmdKey`.
- [ ] **Step 2:** `AppDelegate`: đọc `UserDefaults` khoá `hotkey`; không có → `.default`; `.invalid` → `.default` và ghi log; `.disabled` → không đăng ký; `HotKey` trả nil → ghi log, tiếp tục chạy. Handler: `isFrontmost` → `NSApp.hide(nil)`; ngược lại → `showAndActivate()`.
- [ ] **Step 3:** `AppIcon.png` 1024×1024: vẽ bằng một script nhỏ (bong bóng chat trắng trên nền bo góc chuyển màu), không dùng logo Meta. Người dùng thay file này bằng ảnh khác nếu muốn.
- [ ] **Step 4:** Cập nhật `README.md`: cách build và cài, bảng phím tắt, cách đổi phím tắt toàn cục (`defaults write local.messenger-wrapper hotkey "…"`), vị trí `user.css`, giới hạn đã biết (thông báo chỉ khi app chạy; cuộc gọi mở sang browser).
- [ ] **Step 5:** Push, CI xanh. Commit `feat(app): global hotkey, icon, docs`.
- [ ] **Step 6 (người dùng):** chạy lại toàn bộ checklist spec mục 7 (điểm 1–10) trên bản cài từ `./scripts/build-app.sh --install`.

---

## Ghi chú thực thi

- **Hai điểm dừng cần người dùng:** sau Task 1 (kiểm chứng K1–K5) và sau Task 10 (tinh chỉnh CSS). Task 2–5 không phụ thuộc kết quả kiểm chứng nên làm được trong lúc chờ.
- **CI tốn phút macOS** nếu repo là private (GitHub tính hệ số 10 cho runner macOS). Mỗi lần chạy ước chừng 2–4 phút.
- Nếu container có Swift toolchain cho Linux thì Task 2–5 chạy `swift test` tại chỗ; nếu không thì dựa vào CI.
