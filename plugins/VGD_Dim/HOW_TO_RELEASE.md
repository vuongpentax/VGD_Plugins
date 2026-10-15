# VGD Dim — phát hành bản cập nhật

Quy trình này dành cho pilot updater online của VGD Dim. Hiện updater được bật riêng cho VGD Dim; các plugin VGD khác chưa được chỉnh sửa.

## Tạo gói

1. Cập nhật version trong runtime/VGD_Dim/version.rb và changelog trong VGD_UPDATE_MANIFEST.json.
2. Chạy python dev/package.py.
3. Kiểm tra RBZ, source ZIP, outputs/PACKAGES_SHA256.json và manifest vừa sinh. Script xác minh đủ 29 mục RBZ, CRC, và byte khớp source runtime.
4. Chạy các fixture local. Trước khi phát hành, kiểm thử thủ công trong SketchUp/Windows bằng bản cài riêng.

## Đưa lên GitHub theo thứ tự an toàn

1. Đưa RBZ vào shared/vgd-center/packages và cập nhật VGD_UPDATE_MANIFEST.json cùng hai bản catalog của VGD Center trong một commit. Catalog và updater cùng dùng URL raw.githubusercontent.com trong thư mục package.
2. Tạo tag theo phiên bản và GitHub Release nếu cần cung cấp trang tải thủ công; gắn đúng RBZ và source ZIP đã tạo.
3. Xác minh file package trên GitHub có cùng kích thước và SHA-256 với outputs/PACKAGES_SHA256.json.
4. Không cần GitHub Actions, server, domain riêng, dịch vụ trả phí hay license server.

dev/package.py cập nhật manifest ở local khi build. Chỉ commit manifest/catalog cùng lúc với RBZ trong shared/vgd-center/packages để URL tải có sẵn ngay khi commit lên main.

## Trải nghiệm người dùng và giới hạn beta

- VGD Dim kiểm tra tự động tối đa một lần mỗi 24 giờ và có mục Extensions → Kiểm tra cập nhật VGD Dim.
- Gói tải về phải khớp dung lượng và SHA-256 trong manifest. Manifest chỉ chấp nhận ID vgd_dim, tên gói, cùng URL GitHub Release hoặc đường dẫn package raw đã định trong repository.
- Người dùng chọn cập nhật; helper chờ SketchUp đóng tối đa 8 giờ, không buộc đóng chương trình. Sau đó helper giữ file ngoài whitelist, thay file được quản lý, kiểm tra hash và lưu bản sao thư mục cũ cạnh Plugins.
- Cần khởi động lại SketchUp sau cài đặt. Pilot không cài/reload trong phiên đang chạy, không cập nhật plugin khác và không tự xóa bản sao lưu.
- Pilot hiện chỉ hỗ trợ Windows. HTTP thật và quy trình đóng/mở lại cần được thử trong SketchUp trước khi phát hành.
