# VGD Dim 4.0.2-beta.3

- Gom menu: các lệnh nằm trong **Extensions → VGD → VGD Dim** (trước đây là bốn mục lẻ trong Extensions).
- Thanh công cụ đổi tên rút gọn thành **VGD DIM**; mục menu "Hiện toolbar" ghi theo tên mới.
- Thư mục mã đổi thành chữ thường `vgd_dim/` (trước đây `VGD_Dim/`), cùng loader `vgd_dim.rb`. Tên gói RBZ và tên dictionary dữ liệu trong file SketchUp không đổi.
- Ngoài mục Tải lại code, không đổi chức năng khác.
- **Tải lại code:** menu **Extensions → VGD → VGD Dim → Tải lại code** nạp lại mã sau khi cài đè bản mới mà không cần mở lại SketchUp (đổi tên nút từ "Nạp lại VGD Dim"). Menu và toolbar mới chỉ có tác dụng sau khi mở lại SketchUp.

Kiểm tra: tự động bằng mô phỏng (`dev/check_ruby.cjs`). Chưa kiểm thử thủ công trong SketchUp cho bản này.
