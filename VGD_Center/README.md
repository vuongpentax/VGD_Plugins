# VGD Center 1.0.0

VGD Center quản lý các plugin VGD stable trong SketchUp. Cài `VGD_Center_v1.0.0.rbz` qua Extension Manager, mở bằng nút VGD Center trên toolbar hoặc menu Extensions.

## Tính năng

- Kho plugin lấy từ catalog GitHub stable.
- Đọc phiên bản extension đang cài trong SketchUp.
- Tải RBZ, xác minh dung lượng và SHA-256 trước khi cài.
- Chỉ ghi các đường dẫn plugin VGD đã được cho phép trong mã nguồn.
- Sao lưu file bị thay và khôi phục nếu SketchUp cài gói thất bại.
- Nhắc lưu model và khởi động lại SketchUp sau khi cài hoặc cập nhật.
- Giao diện tối mặc định, có thể chuyển sang sáng.

Catalog khởi đầu gồm VGD Dim 3.1.0 và VGD Scenes 1.5.2. Các bản prerelease không xuất hiện trong catalog.

## Cài đặt

1. Trong SketchUp, mở Extension Manager.
2. Chọn Install Extension và chọn file RBZ.
3. Mở VGD Center từ toolbar hoặc menu Extensions.
4. Chọn plugin stable cần cài hoặc cập nhật.
5. Lưu model và khởi động lại SketchUp khi Center báo hoàn tất.

## Build

Chạy `build_release.ps1` trong thư mục này để tạo RBZ cài đặt, source zip và SHA-256. Script lấy catalog chuẩn từ `shared/vgd-center/catalog.json`.
