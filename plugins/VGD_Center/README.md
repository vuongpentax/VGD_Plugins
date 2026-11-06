# VGD Center 1.2.4-beta.1

VGD Center quản lý các plugin VGD trong SketchUp. Danh mục hiển thị phiên bản mới nhất đã được chọn, bao gồm cả beta và alpha. Cài gói phát hành VGD Center 1.2.4-beta.1 (bản thử; bản ổn định gần nhất là 1.2.3) qua Extension Manager; RBZ không được lưu trong thư mục source này. Mở VGD Center bằng nút trên toolbar hoặc menu Extensions.

## Tính năng

- Kho plugin có nhãn stable, beta hoặc alpha cho từng plugin.
- Đọc phiên bản extension đang cài trong SketchUp (nhận cả plugin đăng ký tên khác catalog: Cabinet, Library, và BIM đăng ký là `VGD_BIM` từ 1.2.4).
- Tải RBZ, xác minh dung lượng và SHA-256 trước khi cài.
- Chỉ ghi đúng hai đường dẫn của từng plugin VGD (loader và thư mục cùng tên). Plugin có sẵn dùng danh sách trong mã nguồn; plugin mới theo quy tắc ở mục "Thêm plugin mới vào kho".
- Sao lưu file bị thay và khôi phục nếu SketchUp cài gói thất bại.
- Nhắc lưu model và khởi động lại SketchUp sau khi cài hoặc cập nhật.
- Cài nhanh tất cả plugin VGD còn thiếu từ mục Tổng quan.
- Kiểm tra và tự cập nhật VGD Center từ bản stable đã phát hành; gói được xác minh bằng SHA-256.
- Gỡ từng plugin đã cài, kèm xác nhận và nhắc khởi động lại SketchUp.
- Mỗi thẻ plugin có nút **Hướng dẫn**; các trang HTML tiếng Việt, giao diện tối/sáng và nút in PDF. Từ 1.2.2, bấm nút sẽ tải trang mới nhất từ kho (`shared/vgd-center/guides/<id>.html`), kiểm tra rồi mở; không có mạng hoặc trang lỗi thì dùng bản đi kèm gói. Thêm hoặc sửa hướng dẫn không cần phát hành Center mới (xem "Hướng dẫn cho plugin").
- Tab **Quản lý** (từ 1.2.1, thay VGD Plugin Manager): bật/tắt plugin (có hiệu lực sau khi khởi động lại SketchUp; plugin vừa bật có nút **Nạp ngay** để dùng luôn mà không cần khởi động lại), bộ plugin, chuyển plugin giữa SketchUp 2022 và 2024 (từ 1.2.3 có ô tìm kiếm theo tên, hai tab Bật/tắt và Chuyển plugin cùng bố cục), xuất gói .rbz tổng (chỉ chứa file của plugin, không thêm tệp nào khác), cho mọi plugin trong thư mục Plugins. Có tiếng Anh đầy đủ. VGD Center không bao giờ bị tắt hay chuyển. Plugin đã tắt và bộ plugin nằm trong `Plugins/VGD_Center/data`; dữ liệu cũ của Plugin Manager được tự chuyển sang đây. Mã nằm trong `VGD_Center/manager/`.
- Từ 1.2.3: bấm logo ở thanh đầu để mở trang web VGD (`WEBSITE_URL` trong `main.rb`); khung Center cao bằng cửa sổ, thanh bên và mã QR đứng yên khi chuyển trang.
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

Thư mục này chứa mã nguồn và tài nguyên VGD Center 1.2.4-beta.1, không kèm RBZ hoặc source ZIP tạo sẵn. Ghi chú phát hành được giữ trong các file RELEASE_NOTES_v*.md. Đóng gói bằng `python plugins/VGD_Center/dev/package.py <phiên bản>` (từ thư mục gốc repo; nhận cả bản thử `x.y.z-beta.N`). Test (chạy từ thư mục `plugins/VGD_Center`, dùng stub SketchUp trong `dev/stub`): `ruby dev/test_center.rb` (catalog, cài/gỡ), `ruby dev/test_manager_toggle.rb`, `ruby dev/test_manager_linker.rb`, `ruby dev/test_manager_dialog.rb`, `ruby dev/test_manager_bundle.rb`, `ruby dev/test_manager_i18n.rb` (tab Quản lý, gồm tiếng Anh), `ruby dev/test_manager_load.rb` (nút Nạp ngay), `ruby dev/test_guides.rb` (tải trang hướng dẫn).

## Thêm plugin mới vào kho

Từ 1.2.0, plugin mới không cần cập nhật Center. Cần: (1) GitHub Release có file `.rbz`; (2) một mục trong `shared/vgd-center/catalog.json` với `id` dạng `ten_plugin`, `extension_name` bắt đầu bằng `VGD `, `allowed_paths` gồm đúng hai đường dẫn `["VGD_Ten.rb", "VGD_Ten/"]` (hoặc `vgd_ten.rb`), cùng URL, dung lượng và SHA-256 của file. Đường dẫn không được trùng plugin khác. Mục tùy chọn `uninstall_note` hiện ghi chú khi gỡ. Plugin mới dùng icon hộp mặc định; muốn icon riêng thì cần cập nhật Center. Trang hướng dẫn thì không cần: xem mục bên dưới.

## Hướng dẫn cho plugin

Từ 1.2.2, trang hướng dẫn không cần phát hành Center mới:

1. Viết trang `shared/vgd-center/guides/<id>.html` (id trùng `id` trong catalog), theo kiểu các trang có sẵn: HTML tĩnh, dùng `../vgd-theme/vgd-theme.css` và `../icon.svg`.
2. Với plugin chưa có trang trong gói Center, thêm `"guide": true` vào mục catalog để hiện nút **Hướng dẫn**.
3. Chép đúng nội dung sang `plugins/VGD_Center/VGD_Center/guides/` (bản đi kèm gói, dùng khi không có mạng; `package.py` tự chép khi đóng gói và `dev/test_guides.rb` kiểm tra hai nơi giống nhau).
4. Đưa lên `main`: người dùng thấy bản mới ngay lần bấm Hướng dẫn kế tiếp.

Trang phải là tài liệu tĩnh: không `<script>`, khung nhúng, form, `<base>`, `meta refresh`, tài nguyên hay liên kết ra ngoài (`http:`, `//`, `javascript:`, `data:`); liên kết chỉ tới trang `.html` khác trong thư mục guides hoặc `#mục`; dung lượng 200 byte đến 300 KB. Trang không đạt bị bỏ qua và Center dùng bản đang có.
