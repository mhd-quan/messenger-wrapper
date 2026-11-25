# Messenger Wrapper — Design & Spec (v1)

Ngày: 2026-11-25 · Trạng thái: chờ duyệt

## 1. Mục đích

Một ứng dụng macOS riêng cho việc nhắn tin Messenger, dùng cá nhân.

**Vì sao:** Messenger hiện chỉ còn là một tab trong browser (app chính thức cho Mac dừng 12/2025, messenger.com dừng 4/2026). Tab thì lẫn giữa các tab khác, không có icon Dock, không có badge, khó gọi lên nhanh. Cần một cửa sổ riêng, dễ nhận ra, tối ưu cho nhắn tin.

**Thành công nghĩa là:** mở app từ Dock hoặc phím tắt, thấy ngay danh sách chat và khung chat, không có giao diện Facebook thừa; có tin mới thì Dock hiện số và macOS hiện thông báo.

## 2. Phạm vi

### Mục tiêu (v1)

1. File `.app` độc lập trong `/Applications`, icon riêng trên Dock.
2. Một cửa sổ hiển thị `https://www.facebook.com/messages/`, giữ đăng nhập giữa các lần mở.
3. Badge số tin chưa đọc trên icon Dock.
4. Thông báo qua macOS Notification Center khi có tin mới và app không ở phía trước.
5. Chế độ tối giản: CSS ẩn các thành phần Facebook không liên quan đến nhắn tin; người dùng tự thêm CSS riêng được.
6. Phím tắt toàn cục để gọi/ẩn cửa sổ.
7. Các thao tác nhắn tin cơ bản hoạt động: gõ, copy/paste (kể cả ảnh), đính kèm file, tải file, mở link ngoài bằng browser mặc định.

### Ngoài phạm vi (v1)

- Gọi thoại/video trong app (xem mục 9: đường mở rộng).
- Thông báo khi app đã thoát hẳn (WKWebView không có Web Push).
- Nhiều tài khoản, nhiều cửa sổ, tab.
- Giao diện Settings. Cấu hình v1 qua file và `defaults write`.
- Phân phối cho người khác: notarization, auto-update, App Store.
- Đăng nhập bằng passkey / khoá bảo mật (WebAuthn trong WKWebView của app bên thứ ba không dùng được cho facebook.com).

### Điều phải tránh

- Không tự động hoá hay can thiệp vào dữ liệu tin nhắn: app chỉ là trình duyệt một trang. JS chèn vào chỉ đọc tiêu đề trang, bắt lời gọi Notification và chèn CSS.
- Không dùng thư viện bên thứ ba. Chỉ framework hệ thống.
- CSS hỏng không được làm app không dùng được: luôn có cách tắt chế độ tối giản.

## 3. Ràng buộc

| Ràng buộc | Hệ quả |
|---|---|
| messenger.com redirect về facebook.com/messages | Phải load trang Facebook đầy đủ; CSS ẩn giao diện là phần cốt lõi |
| Class name của Meta bị xáo trộn và đổi thường xuyên | Chỉ dùng selector theo `role`, cấu trúc, biến CSS; không dùng class băm; không dùng `aria-label` có chữ (phụ thuộc ngôn ngữ) |
| WKWebView không hỗ trợ Web Push và Notification API | Tự giả lập `window.Notification` + phương án dự phòng theo số chưa đọc |
| Phiên phát triển chạy trên Linux | Không build/chạy thử được ở đây. Logic thuần phải tách ra để unit test; phần còn lại kiểm bằng checklist trên Mac |
| Ký ad-hoc, không có Developer ID | Build trên chính máy dùng. Quyền thông báo có thể bị hỏi lại sau mỗi lần build lại |

## 4. Các hướng đã cân nhắc

| Hướng | Ưu | Nhược | Kết luận |
|---|---|---|---|
| **A. Swift + AppKit + WKWebView, Swift Package + script đóng gói** | Nhẹ (~vài MB), dùng WebKit có sẵn, build chỉ cần Command Line Tools, logic thuần test được bằng `swift test` | Phải tự giả lập Notification; không build được trên Linux | **Chọn** |
| B. Electron (kiểu Caprine) | Chromium: Notification và cuộc gọi chạy sẵn | ~200MB, ngốn RAM, trái với mong muốn ban đầu | Loại |
| C. Safari "Add to Dock" | Không cần code, có Web Push thật | Không chèn được CSS, không có phím tắt toàn cục, không tuỳ biến | Loại, nhưng là phương án lùi nếu A thất bại ở bước kiểm chứng |
| D. Xcode project + SwiftUI | Quen thuộc với dân iOS | File `.xcodeproj` khó sinh/sửa bằng tay; SwiftUI không thêm giá trị cho app một WKWebView | Loại |

Người dùng đã chọn hướng native wrapper (A). Các chi tiết bên dưới là quyết định của người viết spec, trừ khi ghi khác.

## 5. Kiến trúc

```
┌────────────────────────── MessengerWrapper.app ──────────────────────────┐
│ AppDelegate ── MainWindowController ── WKWebView (facebook.com/messages) │
│      │                 │                        │                        │
│      │           WebViewFactory          user scripts: bridge.js,        │
│      │        (config, UA, scripts)      style.css, user.css             │
│      │                 │                        │ postMessage            │
│   HotKey         WebViewCoordinator ◄──── Bridge (WKScriptMessageHandler)│
│  (Carbon)     (navigation/UI/download)          │                        │
│                        │                 ┌──────┴───────┐                │
│                 NavigationPolicy    UnreadCount   NotificationService    │
│                   (thuần)            (thuần)     (UNUserNotificationCenter)
│                                          │                               │
│                                     Dock badge                           │
└──────────────────────────────────────────────────────────────────────────┘
```

### Cấu trúc repo

```
Package.swift                    # macOS 13+, 2 target + test
Sources/
  MessengerCore/                 # thư viện: logic thuần, không import WebKit/AppKit
    NavigationPolicy.swift
    LinkUnwrapper.swift
    UnreadCount.swift
    BridgeMessage.swift
    NotificationDeduper.swift
    HotKeySpec.swift
  MessengerWrapper/              # executable: AppKit + WebKit
    main.swift
    AppDelegate.swift
    MainMenu.swift
    MainWindowController.swift
    WebViewFactory.swift
    WebViewCoordinator.swift
    Bridge.swift
    NotificationService.swift
    HotKey.swift
    UserStyles.swift
    Features.swift
Resources/                       # script build copy vào Contents/Resources
  bridge.js
  style.css
  AppIcon.png                    # 1024×1024, icon tự vẽ, không dùng logo Meta
Support/Info.plist
Tests/MessengerCoreTests/
scripts/build-app.sh             # build → .app → ký ad-hoc → (tuỳ chọn) cài vào /Applications
.github/workflows/build.yml      # macOS runner: swift build + swift test
```

Tài nguyên được đọc qua `Bundle.main` (script build copy vào), không dùng `Bundle.module` của SwiftPM, để tránh phải kéo theo bundle phụ.

## 6. Hành vi chi tiết

### 6.1 Cửa sổ và vòng đời

- Một `NSWindow` tiêu chuẩn (có title bar), tiêu đề "Messenger", kích thước mặc định 1100×750, tối thiểu 480×400. Vị trí và kích thước được nhớ (`setFrameAutosaveName`).
- **Đóng cửa sổ (⌘W, nút đỏ) = ẩn**, không huỷ WKWebView, để trang tiếp tục nhận tin. Click icon Dock hiện lại. ⌘Q mới thoát.
- `NSApplication.ActivationPolicy.regular`: có icon Dock và menu bar.
- Menu bar tối thiểu:
  - **App:** About, Hide, Quit.
  - **Edit:** Undo/Redo/Cut/Copy/Paste/Select All (bắt buộc, nếu thiếu thì ⌘C/⌘V không chạy trong WKWebView).
  - **View:** Reload (⌘R), Về trang tin nhắn (⌘⇧M), Bật/tắt chế độ tối giản (⌘⇧L), Nạp lại CSS (⌘⌥R), Mở thư mục CSS, Zoom In/Out/Actual (⌘+ / ⌘- / ⌘0, nhớ mức zoom).
  - **Window:** Minimize, Zoom, Hiện cửa sổ chính.

### 6.2 WebView

- `WKWebsiteDataStore.default()` (lưu bền): giữ cookie đăng nhập và IndexedDB (khoá mã hoá đầu cuối).
- `applicationNameForUserAgent = "Version/17.6 Safari/605.1.15"` để Facebook nhận là Safari. Không ghi đè toàn bộ UA, để phần phiên bản hệ điều hành vẫn đúng.
- `isInspectable = true` (macOS 13.3+): dùng Safari Web Inspector để chỉnh CSS.
- `allowsBackForwardNavigationGestures = false`.
- URL khởi động: `https://www.facebook.com/messages/`.
- Lỗi tải trang (mất mạng): hiện trang lỗi nội bộ đơn giản với nút "Thử lại"; tự thử lại khi mạng có trở lại là tuỳ chọn.
- WebContent process bị kill (`webViewWebContentProcessDidTerminate`): tự reload.

### 6.3 Chính sách điều hướng (`NavigationPolicy`, thuần)

Đầu vào: URL, loại điều hướng (link click / khác), có phải main frame, có phải yêu cầu mở cửa sổ mới. Đầu ra: `.allow` | `.openExternally(URL)` | `.download` | `.cancel`.

| Trường hợp | Kết quả |
|---|---|
| Sub-frame, bất kỳ host | allow |
| Main frame, host thuộc `facebook.com`, `*.facebook.com`, `messenger.com`, `*.messenger.com`, không phải link click | allow (bao gồm luồng đăng nhập, checkpoint, 2FA, redirect) |
| Link click tới `facebook.com/messages/*` | allow |
| Link click tới `l.facebook.com/l.php?u=…` hoặc `lm.facebook.com` | giải mã tham số `u` → openExternally |
| Link click tới đường dẫn Facebook khác (profile, bài viết…) | openExternally |
| Main frame tới host ngoài | openExternally |
| Yêu cầu cửa sổ mới (`target=_blank`, `window.open`) | áp dụng cùng bảng; nếu allow thì load vào webview chính; không tạo cửa sổ thứ hai (v1) |
| Scheme không phải http/https (`mailto:`, `tel:`…) | openExternally |
| `about:blank`, `blob:`, `data:` | allow |
| Response có `Content-Disposition: attachment` hoặc MIME không hiển thị được, hoặc `shouldPerformDownload` | download |

Facebook là SPA nên việc đổi route trong trang không đi qua bảng này. Lệnh **Về trang tin nhắn (⌘⇧M)** là lối thoát khi bị lạc khỏi `/messages`.

### 6.4 File

- **Đính kèm:** `runOpenPanelWith` → `NSOpenPanel` (tôn trọng `allowsMultipleSelection`).
- **Tải về:** `WKDownloadDelegate`, lưu vào `~/Downloads`, tự thêm hậu tố nếu trùng tên; xong thì nảy icon thư mục Downloads trên Dock (`DistributedNotificationCenter` `com.apple.DownloadFileFinished`).
- **Hộp thoại JS:** `alert` / `confirm` hiện bằng `NSAlert`.
- **Camera/micro:** `requestMediaCapturePermissionFor` trả `.deny` khi `Features.calls == false`.

### 6.5 Cầu nối JS ↔ Swift

Một message handler tên `mw`. `bridge.js` chèn ở `documentStart`, chỉ main frame. Swift bỏ qua mọi message không đến từ main frame hoặc từ host không thuộc `facebook.com`.

Message (JSON, giải mã bằng `BridgeMessage`, thuần):

```
{ "type": "title", "title": string }
{ "type": "notification", "id": string, "title": string, "body": string?, "tag": string? }
{ "type": "unreadHint", "count": number }          // dự phòng, xem 6.6
```

Swift → JS chỉ gọi hàm cố định với tham số là id đã escape: `window.__mw.notificationClicked(id)`. Không bao giờ `evaluateJavaScript` chuỗi do trang cung cấp.

`bridge.js` làm ba việc:

1. Theo dõi `<title>` bằng `MutationObserver` (gắn lại nếu thẻ `<title>` bị thay), gửi `title` mỗi khi đổi và một lần khi tải xong.
2. Thay `window.Notification` bằng lớp giả: `permission = "granted"`, `requestPermission()` trả `"granted"`, constructor gửi message `notification` và giữ instance theo `id` để gọi `onclick` sau; có `close()`, `addEventListener`.
3. Chèn `<style id="mw-base">` và `<style id="mw-user">` (xem 6.8), cung cấp `window.__mw.setStyles(base, user, enabled)`.

### 6.6 Số chưa đọc và badge

- `UnreadCount.parse(title:)` (thuần): lấy số ở đầu tiêu đề theo dạng `(3) …`, `(20+) …`; không có thì 0. Tiêu đề nhấp nháy kiểu "Tên đã gửi tin nhắn" không có số → **giữ nguyên giá trị trước đó**, không về 0. Chỉ về 0 khi tiêu đề là tiêu đề gốc không có số (tiêu đề gốc được ghi nhận lúc tải xong trang).
- Badge: `NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil` (giữ nguyên `20+` nếu có).
- **Rủi ro cần kiểm chứng (mục 10, K2):** trên facebook.com, số trong tiêu đề có thể gộp cả thông báo Facebook chứ không riêng tin nhắn. Nếu đúng vậy, chuyển sang nguồn dự phòng: `bridge.js` đếm số dòng chưa đọc trong danh sách chat và gửi `unreadHint`. Giao diện nguồn số là một protocol `UnreadSource` để đổi mà không sửa phần còn lại.

### 6.7 Thông báo

- Lần chạy đầu: xin quyền `UNUserNotificationCenter` (alert + sound). Bị từ chối thì app vẫn chạy bình thường, chỉ còn badge.
- Hai nguồn, đi qua `NotificationDeduper` (thuần):
  - **Nguồn A, polyfill:** mỗi message `notification` từ trang → một thông báo với đúng tiêu đề/nội dung trang đưa.
  - **Nguồn B, dự phòng:** số chưa đọc tăng → thông báo "Tin nhắn mới"; nếu tiêu đề nhấp nháy có tên người gửi thì dùng làm nội dung.
  - Khử trùng: nếu A đã phát trong vòng 3 giây quanh thời điểm số tăng thì B không phát. Nếu trong phiên chạy A từng phát ít nhất một lần, B bị tắt hẳn cho phiên đó.
- **Không phát** khi app đang active và cửa sổ đang hiện.
- Click thông báo: kích hoạt app, hiện cửa sổ; nếu là nguồn A thì gọi `__mw.notificationClicked(id)` để trang tự mở đúng cuộc trò chuyện.
- Khi cửa sổ thành key: xoá các thông báo đã giao của app.

### 6.8 Chế độ tối giản và CSS người dùng

- `Resources/style.css` (đi kèm app): ẩn thanh điều hướng trên cùng của Facebook (`[role="banner"]`), thu hồi khoảng trống nó để lại, ẩn các khối không thuộc nhắn tin. Selector cụ thể do người build tinh chỉnh trên trang thật bằng Web Inspector, tuân theo quy tắc ở mục 3.
- `~/Library/Application Support/MessengerWrapper/user.css`: CSS của người dùng, nạp sau CSS gốc. File được tạo rỗng (kèm chú thích hướng dẫn) ở lần chạy đầu.
- **Nạp lại CSS (⌘⌥R):** đọc lại hai file và áp dụng ngay, không reload trang.
- **Bật/tắt chế độ tối giản (⌘⇧L):** gỡ/gắn cả hai khối style; trạng thái được nhớ. Đây là lối thoát khi Meta đổi giao diện làm CSS hỏng.
- CSS được chèn ở `documentStart` để không nháy giao diện gốc.

### 6.9 Phím tắt toàn cục

- Mặc định **⌃⌥M**. Đăng ký bằng Carbon `RegisterEventHotKey` (không cần quyền Accessibility).
- Hành vi bật/tắt: app đang ở trước và cửa sổ đang key → ẩn app (`NSApp.hide`); ngược lại → kích hoạt app và đưa cửa sổ lên trước.
- Đổi phím: `defaults write local.messenger-wrapper hotkey "ctrl+opt+m"`; `HotKeySpec.parse` (thuần) chuyển chuỗi thành key code + modifier. Chuỗi sai → dùng mặc định và ghi log. Chuỗi `"none"` → tắt.
- Đăng ký thất bại (phím đã bị app khác chiếm) → ghi log, app vẫn chạy.

### 6.10 Đóng gói

- Bundle id: `local.messenger-wrapper`. Tên hiển thị: `Messenger`. `LSMinimumSystemVersion` 13.0. `LSApplicationCategoryType` social-networking.
- `scripts/build-app.sh`: `swift build -c release` → dựng `build/Messenger.app` (binary, `Info.plist`, Resources) → sinh `AppIcon.icns` từ `AppIcon.png` bằng `sips` + `iconutil` → `codesign --force --sign -` → với cờ `--install` thì copy vào `/Applications` (thoát app đang chạy trước).
- Không bật App Sandbox và Hardened Runtime ở v1 (ký ad-hoc, dùng cá nhân). Nội dung web vẫn chạy trong sandbox riêng của WebKit.
- CI (`.github/workflows/build.yml`): `swift build` + `swift test` trên runner macOS, để mỗi commit đều được biên dịch dù phiên phát triển chạy trên Linux. Không phát hành artifact: app tải từ browser sẽ bị Gatekeeper chặn, nên luôn build trên máy dùng.

## 7. Kiểm thử

**Unit test (`swift test`, chạy trên CI):**

- `NavigationPolicy`: từng dòng trong bảng 6.3, cả trường hợp host giả dạng (`facebook.com.evil.com`, `notfacebook.com`).
- `LinkUnwrapper`: `l.php?u=` có/không mã hoá, thiếu `u`, `u` không phải http(s).
- `UnreadCount`: `(3) Messenger`, `(20+) …`, không số, tiêu đề nhấp nháy giữ giá trị cũ, về 0 khi quay lại tiêu đề gốc.
- `BridgeMessage`: giải mã hợp lệ, thiếu trường, type lạ, kiểu sai.
- `NotificationDeduper`: A rồi B trong cửa sổ 3 giây, B đơn lẻ, B bị tắt sau khi A từng phát.
- `HotKeySpec`: chuỗi hợp lệ, sai, `none`.

**Checklist thủ công trên Mac (tiêu chí nghiệm thu):**

1. `./scripts/build-app.sh --install` chạy xong; app xuất hiện trong `/Applications` với icon riêng.
2. Đăng nhập Facebook (kể cả 2FA bằng mã) thành công; thoát rồi mở lại vẫn còn đăng nhập.
3. Gửi/nhận tin, dán ảnh từ clipboard, đính kèm file, tải file về `~/Downloads`.
4. Click link ngoài trong chat → mở bằng browser mặc định, app vẫn ở trang chat.
5. Nhận tin khi app ẩn → trong vòng 10 giây Dock hiện badge và có thông báo macOS. Click thông báo → app hiện lên.
6. Đọc tin → badge biến mất.
7. Đóng cửa sổ bằng ⌘W, đợi 10 phút, nhận tin → vẫn có badge và thông báo.
8. Chế độ tối giản: không còn thanh điều hướng Facebook; ⌘⇧L bật/tắt được; sửa `user.css` rồi ⌘⌥R có hiệu lực ngay.
9. ⌃⌥M từ app khác → cửa sổ hiện lên; bấm lần nữa → ẩn.
10. Trong app dùng mã hoá đầu cuối: lịch sử chat còn sau khi thoát và mở lại.

## 8. Thứ tự thực hiện

| Bước | Nội dung | Xong khi |
|---|---|---|
| 0 | **Kiểm chứng** trên Mac bằng bản dựng tối thiểu (cửa sổ + WKWebView + inspector): trả lời K1–K5 ở mục 10 | Có câu trả lời cho cả 5; cập nhật spec nếu cần |
| 1 | Vỏ app: cửa sổ, menu, WebView, điều hướng, file, đóng gói | Checklist 1–4 |
| 2 | Cầu nối, badge, thông báo | Checklist 5–7 |
| 3 | Chế độ tối giản, `user.css` | Checklist 8 |
| 4 | Phím tắt, icon, CI | Checklist 9–10 |

Bước 0 cần người dùng chạy trên Mac và báo lại kết quả, vì nó cần tài khoản Facebook thật.

## 9. Đường mở rộng: gọi thoại/video

Không làm ở v1, nhưng v1 phải giữ các điểm sau để thêm sau không cần viết lại:

1. **`Features.calls`** (hằng `false`): mọi nhánh liên quan cuộc gọi rẽ theo cờ này.
2. **Quyền thiết bị ở một chỗ:** `requestMediaCapturePermissionFor` trong `WebViewCoordinator` là điểm duy nhất quyết định camera/micro. Bật tính năng = đổi `.deny` thành `.grant` cho origin facebook.com.
3. **Cửa sổ popup ở một chỗ:** `createWebViewWith` gọi `NavigationPolicy` với cờ "cửa sổ mới". Facebook mở cuộc gọi bằng `window.open`; sau này thêm kết quả `.openCallWindow` và một `CallWindowController` tạo WKWebView thứ hai **từ đúng `configuration` WebKit truyền vào** (bắt buộc để giữ `window.opener`), xử lý `webViewDidClose`.
4. **`WebViewFactory` không giả định chỉ có một webview:** cấu hình, data store, user script dùng chung được cho webview thứ hai. `Bridge` nhận biết message đến từ webview nào.
5. **Việc cần thêm khi làm:** `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` trong `Info.plist`; entitlement camera/micro nếu bật Hardened Runtime; thông báo cuộc gọi đến (có âm thanh, không bị chặn khi app active); kiểm tra chia sẻ màn hình (`getDisplayMedia`) trên WKWebView.
6. **v1:** URL cuộc gọi đi qua bảng 6.3 như link Facebook thường → mở bằng browser mặc định, nên vẫn gọi được, chỉ là không trong app.

## 10. Điểm chưa chắc, cần kiểm chứng ở bước 0

| # | Câu hỏi | Nếu kết quả xấu |
|---|---|---|
| K1 | Facebook có cho đăng nhập và dùng `/messages` trong WKWebView với UA Safari không? | Thử UA Safari đầy đủ. Vẫn không được → dừng, lùi về phương án C |
| K2 | Số trong tiêu đề ở `/messages` là số tin nhắn chưa đọc hay gộp cả thông báo Facebook? | Dùng nguồn dự phòng đếm trong danh sách chat (6.6) |
| K3 | Trang có gọi `new Notification(...)` khi có tin mới không (sau khi polyfill báo `granted`)? | Chỉ dùng nguồn B (6.7); thông báo sẽ ít chi tiết hơn |
| K4 | Khi cửa sổ ẩn lâu, trang còn cập nhật tiêu đề không, hay bị WebKit bóp timer/treo? | Thay "ẩn" bằng đưa cửa sổ ra ngoài màn hình, hoặc tắt phát hiện che khuất cho webview |
| K5 | Ẩn `[role="banner"]` có để lại khoảng trống không, và biến CSS nào điều khiển chiều cao đó? | Tinh chỉnh `style.css` theo cấu trúc thực tế |

## 11. Để người build quyết định

- Selector cụ thể trong `style.css` (theo quy tắc mục 3).
- Hình icon (tự vẽ, không dùng logo Meta).
- Nội dung trang lỗi mạng.
- Tổ chức nội bộ các file trong `MessengerWrapper/`, miễn giữ ranh giới: logic thuần ở `MessengerCore`, không import AppKit/WebKit.
