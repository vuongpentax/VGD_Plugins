# VGD Cabinet 4.5.4

- Gom menu: lệnh dựng hình và Reload nằm trong **Extensions → VGD → VGD Cabinet** (trước đây lệnh dựng hình là mục lẻ trong Extensions).
- Thanh công cụ đổi tên rút gọn thành **VGD CAB** (vị trí thanh có thể phải kéo lại một lần).
- Tên extension đổi từ `VGD_Cabinet v4.5.3` thành **VGD Cabinet** (số phiên bản không còn nằm trong tên).
- Thư mục mã đổi thành chữ thường `vgd_cabinet/` (loader `vgd_cabinet.rb` đã chữ thường từ trước). Tên dictionary dữ liệu trong file SketchUp (`VGD_Cabinet`), preset và thư viện trên máy giữ nguyên nên dữ liệu cũ vẫn dùng được.
- Ngoài mục Tải lại code, không đổi chức năng khác.
- **Tải lại code:** menu **Extensions → VGD → VGD Cabinet → Tải lại code** nạp lại mã sau khi cài đè bản mới mà không cần mở lại SketchUp (đổi tên nút từ "VGD — Nạp lại mã (Reload)"). Menu và toolbar mới chỉ có tác dụng sau khi mở lại SketchUp.
- **Bỏ `update_notice.rb`** (không còn tự kiểm tra cập nhật): VGD Center báo và cài cập nhật. Lời báo của Tải lại code thống nhất với các plugin khác.

Kiểm tra: tự động (test tải lại code, test giả lập menu/Reload, danh sách file đóng gói). Chưa kiểm thử thủ công trong SketchUp cho bản này.
