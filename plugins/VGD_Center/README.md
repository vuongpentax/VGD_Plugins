# VGD Center 1.2.0

VGD Center quản lý các plugin VGD trong SketchUp. Danh mục hiển thị phiên bản mới nhất đã được chọn, bao gồm cả beta và alpha. Cài gói phát hành VGD Center 1.2.0 qua Extension Manager; RBZ không được lưu trong thư mục source này. Mở VGD Center bằng nút trên toolbar hoặc menu Extensions.

## Tính năng

- Kho plugin có nhãn stable, beta hoặc alpha cho từng plugin.
- Đọc phiên bản extension đang cài trong SketchUp.
- Tải RBZ, xác minh dung lượng và SHA-256 trước khi cài.
- Chỉ ghi đúng hai đường dẫn của từng plugin VGD (loader và thư mục cùng tên). Plugin có sẵn dùng danh sách trong mã nguồn; plugin mới theo quy tắc ở mục "Thêm plugin mới vào kho".
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

Thư mục này chứa mã nguồn và tài nguyên VGD Center 1.2.0, không kèm RBZ hoặc source ZIP tạo sẵn. Ghi chú phát hành được giữ trong các file RELEASE_NOTES_v*.md. Đóng gói bằng `python plugins/VGD_Center/dev/package.py` (từ thư mục gốc repo). Test: `ruby dev/test_center.rb` (chạy từ thư mục `plugins/VGD_Center`), dùng stub SketchUp trong `dev/stub`.

## Thêm plugin mới vào kho

Từ 1.2.0, plugin mới không cần cập nhật Center. Cần: (1) GitHub Release có file `.rbz`; (2) một mục trong `shared/vgd-center/catalog.json` với `id` dạng `ten_plugin`, `extension_name` bắt đầu bằng `VGD `, `allowed_paths` gồm đúng hai đường dẫn `["VGD_Ten.rb", "VGD_Ten/"]` (hoặc `vgd_ten.rb`), cùng URL, dung lượng và SHA-256 của file. Đường dẫn không được trùng plugin khác. Mục tùy chọn `uninstall_note` hiện ghi chú khi gỡ. Plugin mới dùng icon hộp mặc định và không có nút Hướng dẫn; muốn icon riêng hoặc trang hướng dẫn thì cần cập nhật Center.
