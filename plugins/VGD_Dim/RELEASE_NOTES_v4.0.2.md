# VGD Dim 4.0.2

- **Menu gọn:** các lệnh nằm trong **Extensions → VGD → VGD Dim** (trước đây là mục lẻ trong Extensions).
- Thanh công cụ có tên rút gọn **VGD DIM** và **tự hiện ngay lần đầu cài** (trước đây bị ẩn). Các lần sau giữ trạng thái bạn đã chọn.
- Thư mục mã đổi thành chữ thường `vgd_dim/`. Tên gói RBZ và dữ liệu trong file SketchUp không đổi.
- **Tải lại code:** menu **Extensions → VGD → VGD Dim → Tải lại code** nạp lại mã sau khi cài đè bản mới mà không cần mở lại SketchUp (chỉ mở lại cửa sổ nếu trước đó đang mở; báo "Đã tải lại" hoặc lỗi rõ ràng). Menu và toolbar mới chỉ có tác dụng sau khi mở lại SketchUp.
- **Bỏ bộ tự cập nhật riêng của Dim** (kiểm tra, tải gói, cài bằng PowerShell, `VGD_UPDATE_MANIFEST.json`): VGD Center báo và cài cập nhật.

Kiểm tra: tự động bằng mô phỏng (test menu, tải lại code, toolbar; bộ `dev/check_ruby.cjs` không chạy ổn trong môi trường kiểm tra nên không dùng làm bằng chứng). Đã được người phát hành dùng thử trong SketchUp trước khi phát hành.
