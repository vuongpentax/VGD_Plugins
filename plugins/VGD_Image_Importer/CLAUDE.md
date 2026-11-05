# VGD Image Importer

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây vì dễ lỗi thời: xem nơi giữ phiên bản ở mục "Thông tin plugin".

## Thông tin plugin

- Tên extension: VGD Image Importer. Namespace cũ `VGD_ImageImporter` (giữ nguyên để nâng cấp tại chỗ).
- Loader: `runtime/vgd_image_importer.rb` (nạp `vgd_image_importer/main`).
- Phiên bản: hằng `VERSION` trong `runtime/vgd_image_importer.rb`, khớp `version` trong `dev/package.json`. Tăng cả hai trước khi phát hành.
- SketchUp tối thiểu: 2022. Windows (có mã Windows riêng: chọn file, WIC).

## Cấu trúc

- `runtime/`: loader và thư mục `vgd_image_importer/` (`engine.rb`, `main.rb`, `file_picker.rb`, `conversion.rb`, `dialog.html/css/js`, `convert_image.ps1`).
- `dev/`: test, `package.cjs`, `deploy.ps1`, `native_smoke.rb`, `check_native_codec.py`.

## Kiểm thử

- Từ `plugins/VGD_Image_Importer/dev`: `npm test` (chạy `node check_ruby.cjs && node test_ui.cjs`).
- Test khác trong `dev/`: `test_engine.rb`, `test_drop.rb`, `check_native_codec.py`.
- Không thay model hay selection để kiểm tra tự động trên file của người dùng.
- Chưa xác minh: codec HEIC; xem `HANDOFF.md` mục "Giới hạn đã biết".

## Đóng gói

- `npm run package` trong `dev/` (chạy `node package.cjs`). Chạy `dev/deploy.ps1 -VerifyOnly` trước khi deploy; kiểm tra report và hash sau deploy. Cần khởi động lại SketchUp sau cập nhật.
- File `.rbz` và `outputs/` không đưa vào git.

## Tài liệu đọc trước khi sửa

- `README.md`, `HANDOFF.md` (cấu trúc, quy tắc tiếp tục, giới hạn đã biết).

## Quy tắc riêng

- Giữ đường dẫn loader và namespace để nâng cấp tại chỗ.
- Không sửa hoặc deploy các plugin VGD khác.
- Vật liệu nhập phải tạo mới, không đổi texture của vật liệu có sẵn.
- Số ảnh mỗi hàng tính theo ảnh nhập thành công. Khi tất cả ảnh lỗi, abort operation.
