# VGD Center 1.2.0

- Nhận plugin mới từ catalog mà không cần cập nhật VGD Center. Plugin mới chỉ cần release trên GitHub và một mục trong `shared/vgd-center/catalog.json`.
- Quy tắc cho plugin mới: tên extension bắt đầu bằng `VGD `; hai đường dẫn cài đặt là loader `VGD_*.rb` hoặc `vgd_*.rb` và thư mục cùng tên; không được trùng đường dẫn hay tên extension của plugin khác. Dung lượng, SHA-256, nguồn tải và kênh phát hành vẫn bị kiểm tra như trước.
- Hỗ trợ VGD Plugin Manager: icon, trang hướng dẫn, cảnh báo khi gỡ nếu còn plugin đang tắt.
- Nút **Hướng dẫn** chỉ hiện khi Center có trang hướng dẫn của plugin đó; plugin mới chưa có trang thì không hiện nút.
- Catalog có thể thêm `uninstall_note` (tùy chọn) để hiện ghi chú trong hộp thoại gỡ cài đặt.
- Plugin mới dùng icon hộp mặc định cho đến khi Center có icon riêng.

Kiểm tra: tự động (54 kiểm tra trong `dev/test_center.rb`, cú pháp Ruby, kiểm tra catalog khi đóng gói). Chưa kiểm thử thủ công trong SketchUp cho bản này.
