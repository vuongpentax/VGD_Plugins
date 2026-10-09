# VGD Center 1.0.1

VGD Center quản lý các plugin VGD trong SketchUp. Danh mục hiển thị phiên bản mới nhất đã được chọn, bao gồm cả beta và alpha. Cài `VGD_Center_v1.0.1.rbz` qua Extension Manager, mở bằng nút VGD Center trên toolbar hoặc menu Extensions.

## Tính năng

- Kho plugin lấy từ catalog GitHub, có nhãn stable, beta hoặc alpha cho từng plugin.
- Đọc phiên bản extension đang cài trong SketchUp.
- Tải RBZ, xác minh dung lượng và SHA-256 trước khi cài.
- Chỉ ghi các đường dẫn plugin VGD đã được cho phép trong mã nguồn.
- Sao lưu file bị thay và khôi phục nếu SketchUp cài gói thất bại.
- Nhắc lưu model và khởi động lại SketchUp sau khi cài hoặc cập nhật.
- Giao diện tối mặc định, có thể chuyển sang sáng.

Catalog hiện gồm phiên bản mới nhất của sáu plugin VGD; các bản beta và alpha được ghi nhãn rõ ràng để người dùng nhận biết.

## Cài đặt

1. Trong SketchUp, mở Extension Manager.
2. Chọn Install Extension và chọn file RBZ.
3. Mở VGD Center từ toolbar hoặc menu Extensions.
4. Chọn plugin cần cài hoặc cập nhật và xem nhãn kênh phát hành trên thẻ plugin.
5. Lưu model và khởi động lại SketchUp khi Center báo hoàn tất.

## Build

Chạy `build_release.ps1` trong thư mục này để tạo RBZ cài đặt, source zip và SHA-256. Script lấy catalog chuẩn từ `shared/vgd-center/catalog.json`.
