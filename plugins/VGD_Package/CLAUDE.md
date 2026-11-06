# VGD_Package

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây vì dễ lỗi thời: xem nơi giữ phiên bản ở mục "Thông tin plugin".

## Thông tin plugin

- Tên extension: VGD_Package. Namespace: `VGD::Pack`.
- Loader: `VGD_Package.rb` ở gốc plugin (nạp `VGD_Package/vgd_pack`).
- Phiên bản: `extension.version` trong `VGD_Package.rb`; `README` nằm trong `VGD_Package/README.md` và cũng ghi số phiên bản.
- SketchUp tối thiểu: 2022.
- Trạng thái: bản nghiên cứu. Trong catalog của VGD Center plugin này ở trạng thái `in_development`, chưa phát hành.

## Cấu trúc

- `VGD_Package/`: `vgd_pack.rb`, `asset.rb`, `scanner.rb`, `compatibility.rb`, `adapters/`, `ui/` (HtmlDialog), `research/` (kết quả khảo sát Enscape), `build_package.ps1`, `README.md`.

## Kiểm thử

- Chưa có test tự động trong repo. Theo `VGD_Package/README.md` đã kiểm tra cú pháp JavaScript, cấu trúc RBZ, tài nguyên giao diện và SHA-256; chưa chạy smoke test trong SketchUp.
- Khi thêm hoặc sửa chức năng, ghi rõ cách kiểm tra đã dùng và phần chưa xác minh.

## Đóng gói

- `VGD_Package/build_package.ps1` (PowerShell). File `.rbz` không đưa vào git.

## Tài liệu đọc trước khi sửa

- `VGD_Package/README.md`, `VGD_Package/research/PHASE0_ENSCAPE_FINDINGS.md`.

## Quy tắc riêng

- Quét dự án chỉ đọc, không ghi file. Kiểm tra Enscape hiện chỉ ở chế độ đọc; không relink khi chưa có báo cáo từ model Enscape thật.
- Báo cáo có thể chứa đường dẫn tuyệt đối và giá trị attribute: không đưa báo cáo thật của người dùng vào repo.
