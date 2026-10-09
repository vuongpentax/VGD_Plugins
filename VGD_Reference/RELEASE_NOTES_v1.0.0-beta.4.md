# VGD Reference 1.0.0-beta.4

- Nạp lại texture ảnh cho đúng `Sketchup::View` được SketchUp truyền vào khi overlay vẽ, tránh dùng texture ID của view khác.
- Giữ nguyên texture ảnh đang dùng khi đổi view, bao gồm cả trạng thái xem trước độ mờ.
- Gọi `View#draw2d` bằng cú pháp từ khóa trực tiếp theo tài liệu SketchUp Ruby API.
- Toàn bộ giao diện người dùng vẫn bằng tiếng Việt.

Cần cài bản beta.4 và xác nhận trực quan trong SketchUp 2024 rằng ảnh JPG/PNG hiển thị đầy đủ trong viewport.
