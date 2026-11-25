# Messenger Wrapper

Ứng dụng macOS riêng cho việc nhắn tin Messenger: một cửa sổ Swift + WKWebView bọc `facebook.com/messages`, có icon Dock, badge số tin chưa đọc, thông báo macOS, giao diện tối giản bằng CSS và phím tắt toàn cục. Dùng cá nhân.

**Trạng thái:** đang ở giai đoạn thiết kế, chưa có code.

## Tài liệu

- [Design & spec v1](docs/superpowers/specs/2026-11-25-messenger-wrapper-design.md)

## Tính khả thi (tóm tắt)

Khả thi với Swift + AppKit + WKWebView, không cần thư viện ngoài, build chỉ cần Xcode Command Line Tools.

| Tính năng | Đánh giá | Ghi chú |
|---|---|---|
| `.app` độc lập, icon Dock | Chắc chắn | Swift Package + script đóng gói, ký ad-hoc |
| Giữ đăng nhập | Chắc chắn | Data store mặc định của WebKit |
| Badge Dock | Khả thi, cần kiểm chứng nguồn số | Đọc `document.title`; có phương án dự phòng |
| Thông báo macOS | Khả thi, chỉ khi app đang chạy | WKWebView không có Web Push; giả lập `window.Notification` |
| CSS tối giản | Khả thi, cần bảo trì | Meta đổi giao diện thì phải chỉnh selector |
| Phím tắt toàn cục | Chắc chắn | Carbon hot key, không cần quyền Accessibility |
| Gọi thoại/video | Để sau | Spec đã chừa điểm mở rộng |

Lưu ý: messenger.com đã ngừng từ 4/2026 và redirect về `facebook.com/messages`, nên app load trang Facebook và dựa vào CSS để ẩn phần thừa.

## Yêu cầu

- macOS 13 trở lên
- Xcode Command Line Tools (`xcode-select --install`)
