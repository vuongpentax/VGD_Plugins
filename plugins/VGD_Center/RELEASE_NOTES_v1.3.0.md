# VGD Center 1.3.0

- Thêm tab **Quản lý** trong VGD Center, chuyển từ VGD Plugin Manager 1.0.0-beta.17: bật/tắt plugin bằng nút gạt (plugin tắt được cất vào thư mục riêng, không bị xóa, có hiệu lực sau khi khởi động lại SketchUp), bộ plugin để bật/tắt cùng lúc, chuyển plugin giữa SketchUp 2022 và 2024 (có sao lưu thư mục đích), xuất gói `.rbz` tổng.
- Tab Quản lý áp dụng cho mọi plugin trong thư mục Plugins, không chỉ plugin VGD.
- VGD Center và VGD Plugin Manager không bao giờ bị tắt hay chuyển, kể cả khi tên thư mục khác hoa thường.
- Dùng chung dữ liệu với VGD Plugin Manager (`Plugins/VGD_PluginManager/data`): plugin đã tắt bằng Plugin Manager vẫn hiện ở tab Quản lý và ngược lại. Không gỡ Plugin Manager khi còn plugin đang tắt, vì thư mục dữ liệu sẽ bị xóa theo.
- Không đổi file trong Plugins khi VGD Center đang cài hoặc gỡ plugin.
- Nhật ký lỗi của tab Quản lý: `%APPDATA%\SketchUp\VGD_Center\manager.log`.

Kiểm tra: tự động (5 bộ test trong `dev/`, gồm 130 kiểm tra mới cho tab Quản lý; cú pháp Ruby và JavaScript; dựng giao diện trong trình duyệt ở hai theme). Chưa kiểm thử thủ công trong SketchUp: hộp thoại, hộp chọn file, mở thư mục và việc dời file plugin thật chưa chạy trong SketchUp.
