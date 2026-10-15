# VGD Center 1.0.10

VGD Center quản lý các plugin VGD trong SketchUp. Danh mục hiển thị phiên bản mới nhất đã được chọn, bao gồm cả beta và alpha. Cài gói phát hành VGD Center 1.0.10 qua Extension Manager; RBZ không được lưu trong thư mục source này. Mở VGD Center bằng nút trên toolbar hoặc menu Extensions.

## Tính năng

- Kho plugin có nhãn stable, beta hoặc alpha cho từng plugin.
- Đọc phiên bản extension đang cài trong SketchUp.
- Tải RBZ, xác minh dung lượng và SHA-256 trước khi cài.
- Chỉ ghi các đường dẫn plugin VGD đã được cho phép trong mã nguồn.
- Sao lưu file bị thay và khôi phục nếu SketchUp cài gói thất bại.
- Nhắc lưu model và khởi động lại SketchUp sau khi cài hoặc cập nhật.
- Cài nhanh tất cả plugin VGD còn thiếu từ mục Tổng quan.
- Kiểm tra và tự cập nhật VGD Center từ bản stable đã phát hành; gói được xác minh bằng SHA-256.
- Gỡ từng plugin đã cài, kèm xác nhận và nhắc khởi động lại SketchUp.
- Mỗi thẻ plugin có nút **Hướng dẫn**; các trang HTML tiếng Việt, giao diện tối/sáng và nút in PDF được đóng gói cùng Center để tự cập nhật chung với Center.
- Chọn ngôn ngữ giao diện và bật/tắt tự động cập nhật VGD Center khi khởi động SketchUp.
- Xem thời điểm kiểm tra cập nhật Center gần nhất.
- Giao diện tối mặc định, có thể chuyển sang sáng.

Catalog hiển thị các phiên bản VGD hiện hành; bản beta và alpha được ghi nhãn rõ để người dùng nhận biết.

## Cài đặt

1. Trong SketchUp, mở Extension Manager.
2. Chọn Install Extension và chọn file RBZ.
3. Mở VGD Center từ toolbar hoặc menu Extensions.
4. Chọn plugin cần cài hoặc cập nhật và xem nhãn kênh phát hành trên thẻ plugin.
5. Dùng **Cài tất cả** trong mục Tổng quan nếu muốn cài các plugin còn thiếu; các plugin đã cài có nút cập nhật và gỡ trong Kho plugin.
6. Kiểm tra hoặc cài bản cập nhật VGD Center trong mục Cài đặt.
7. Lưu model và khởi động lại SketchUp khi Center báo hoàn tất.
8. Mở hướng dẫn riêng của plugin bằng nút **Hướng dẫn** trên thẻ trong Kho plugin.

## Mã nguồn và phát hành

Thư mục này chứa mã nguồn và tài nguyên VGD Center 1.0.10, không kèm RBZ hoặc source ZIP tạo sẵn. Ghi chú phát hành từ 1.0.0 đến 1.0.10 được giữ trong các file RELEASE_NOTES_v*.md. Script đóng gói cũ phụ thuộc shared/vgd-center và các package của repo nguồn nên không được chuyển trong đợt này.
