# VGD Dim — phát hành bản cập nhật

Quy trình này dành cho pilot updater online của VGD Dim. Hiện updater được bật riêng cho VGD Dim; các plugin VGD khác chưa được chỉnh sửa.

## Tạo gói

1. Cập nhật version trong runtime/VGD_Dim/version.rb và changelog trong VGD_UPDATE_MANIFEST.json.
2. Chạy python dev/package.py.
3. Kiểm tra RBZ, source ZIP, outputs/PACKAGES_SHA256.json và manifest vừa sinh. Script xác minh đủ 27 mục RBZ, CRC, và byte khớp source runtime.
4. Chạy các fixture local. Trước khi phát hành, kiểm thử thủ công trong SketchUp/Windows bằng bản cài riêng.

## Đưa lên GitHub theo thứ tự an toàn

1. Tạo checkpoint source beta trên GitHub nhưng giữ VGD_UPDATE_MANIFEST.json ở bản hiện hành. Tạo tag dạng vgd-dim-v3.3.0-beta.3 từ commit đó.
2. Tạo và publish GitHub Release cho tag; đính kèm đúng RBZ đã tạo. Có thể đính kèm source ZIP để tham khảo.
3. Xác minh RBZ tải công khai và SHA-256 khớp outputs/PACKAGES_SHA256.json.
4. Sau khi asset đã công khai, cập nhật manifest beta mới lên nhánh main bằng checkpoint riêng. Máy người dùng chỉ thấy version mới sau bước này.
5. Không cần GitHub Actions, server, domain riêng, dịch vụ trả phí hay license server.

dev/package.py cập nhật manifest ở local khi build. Không đẩy manifest beta mới trước khi release asset sẵn sàng, nếu không người dùng sẽ nhận URL chưa tồn tại.

## Trải nghiệm người dùng và giới hạn beta

- VGD Dim kiểm tra tự động tối đa một lần mỗi 24 giờ và có mục Extensions → Kiểm tra cập nhật VGD Dim.
- Gói tải về phải khớp dung lượng và SHA-256 trong manifest. Manifest chỉ chấp nhận ID vgd_dim, tên gói và URL GitHub Release đã định.
- Người dùng chọn cập nhật; helper chờ SketchUp đóng tối đa 8 giờ, không buộc đóng chương trình. Sau đó helper giữ file ngoài whitelist, thay file được quản lý, kiểm tra hash và lưu bản sao thư mục cũ cạnh Plugins.
- Cần khởi động lại SketchUp sau cài đặt. Pilot không cài/reload trong phiên đang chạy, không cập nhật plugin khác và không tự xóa bản sao lưu.
- Pilot hiện chỉ hỗ trợ Windows. HTTP thật và quy trình đóng/mở lại cần được thử trong SketchUp trước khi phát hành.
