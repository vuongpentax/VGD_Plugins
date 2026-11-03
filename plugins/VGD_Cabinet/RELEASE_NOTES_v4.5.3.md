# VGD_Cabinet 4.5.3

- Tách lại một phần logic dựng tủ dùng chung (khoang, cánh, kệ, viền) để dễ bảo trì (refactor, chưa kiểm thử lại trong SketchUp).
- Thêm kiểm tra tự động: bốn danh sách file runtime phải khớp nhau.
- Xóa mã không còn dùng trong engine.
- Gỡ đường dẫn loader có đuôi `.rb` khi đăng ký extension.
- File cài đặt thêm BOM UTF-8 để PowerShell 5.1 đọc đúng tiếng Việt.
- Cập nhật số phiên bản trong giao diện và công cụ kiểm thử lên 4.5.3.
- Giao diện Cabinet giữ nguyên diện mạo hiện tại (chưa áp theme chung).
- Trình cập nhật không hiện popup khi khởi động; VGD Center báo bản mới.

Kiểm tra: tự động (cú pháp Ruby, JSON, đóng gói RBZ và source ZIP). Chưa chạy lại trong SketchUp 2022 với gói 4.5.3; Native Undo, đóng/mở lại model và tương tác UI batch chưa được xác minh.
