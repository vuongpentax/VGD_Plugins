# VGD Image Importer — bàn giao

Ngày 08/10/2026, phiên bản 1.1.0-beta.3. Nguồn gốc: `%APPDATA%/SketchUp/SketchUp 2022/SketchUp/Plugins/vgd_image_importer.rb` và folder cùng tên (bản 1.0.0). Snapshot nguyên bản ở `reference/`.

Beta.2 sửa lỗi beta.1 coi `ImageRep.load_file` là Boolean. Phải gọi load_file rồi kiểm tra width/height; API có thể trả nil khi đọc thành công. Fixture cũ trả true đã che lỗi này; fixture mới trả nil và raise cho dữ liệu hỏng. Thêm hộp thoại Windows chọn nhiều file → Open và giải mã WebP/GIF/AVIF/ICO/SVG/JFIF thành PNG trong Chromium của HtmlDialog.

## Cấu trúc

- `runtime/vgd_image_importer.rb`: đăng ký extension, version, namespace cũ `VGD_ImageImporter`.
- `engine.rb`: validation, nguồn ảnh, tính kích thước theo inch nội bộ, tạo component/vật liệu, bố trí, operation và kết quả.
- `main.rb`: singleton HtmlDialog, callback `vgd_importer`, JSON settings, chọn file/folder, toolbar/menu.
- `file_picker.rb`: Fiddle gọi GetOpenFileNameW với OPENFILENAMEW đúng ABI x64 (152 bytes), Unicode, OFN_ALLOWMULTISELECT/EXPLORER; parse một/nhiều file và Cancel riêng, không lặp hộp thoại.
- `conversion.rb`: mỗi batch snapshot model/entities/files, token phản hồi, gửi một ảnh/lần tới CEF, ghi PNG cache rồi gọi engine. Xóa các file PNG được tạo sau kết quả/đóng dialog. `convert_image.ps1` là WIC fallback cho HEIC/HEIF khi codec Windows có sẵn; không tải dependency.
- `dialog.html/css/js`: UI tiếng Việt, màu và control theo VGD Scenes; CSS không dùng các tính năng Chromium mới như color-mix. Theme và settings được ghi qua Sketchup defaults; khóa localStorage `vgd.theme` dùng làm fallback lúc mở trang, không phải bus đồng bộ theme trực tiếp giữa plugin.
- `icon.svg`: toolbar VGD mới; `vgd_icon.png` giữ icon gốc để tương thích/snapshot và dùng làm dữ liệu test.
- `dev/`: fixture Ruby và kiểm tra UI, đóng gói RBZ/source ZIP, deploy chính xác file có backup.

## Quy tắc tiếp tục

Giữ đường dẫn loader và namespace để nâng cấp tại chỗ. Không sửa hoặc deploy các plugin VGD khác. Vật liệu nhập phải tạo mới, không đổi texture của material sẵn có. Số ảnh mỗi hàng tính theo ảnh nhập thành công. Khi tất cả ảnh lỗi, abort operation. Không thay model/selection để kiểm tra tự động trên file người dùng.

Tăng version ở loader và package.json trước release. Chạy `node dev/check_ruby.cjs`, `node dev/test_ui.cjs`, rồi `node dev/package.cjs`. UI screenshots nằm ở outputs, được tạo từ dữ liệu minh họa. Chạy `dev/deploy.ps1 -VerifyOnly` trước deploy. Kiểm tra report và hash sau deploy. Cần khởi động lại SketchUp sau cập nhật; bản 1.0.0 tự đăng ký toolbar không có file_loaded guard.

## Giới hạn đã biết

Đã qua kiểm tra Ruby WASM với fixture nil-return chính xác và UI/giải mã ảnh thật trên Edge. `check_native_codec.py` đã xác nhận SketchUpAPI.dll 2022 đọc JPG/PNG/BMP/TIFF/TGA và PNG chuyển từ WebP/GIF/AVIF/ICO/SVG/JFIF, Unicode/kích thước và alpha WebP/AVIF. Report ở outputs/native_codec_report.json. WIC conversion script qua test PNG; HEIC chưa kiểm chứng codec. Phiên SketchUp thử riêng khởi động nhưng không chạy được RubyStartup trong môi trường hiện tại, chưa xác nhận tạo hình/Undo và thao tác Ctrl/Shift thực tế. Giữ native_smoke.rb để tiếp tục kiểm chứng trên máy. Nạp ảnh/batch còn đồng bộ khi tạo geometry; chưa có nút hủy giữa lượt. TIFF/TGA/HEIC không preview bằng HTML. HEIC cần codec WIC của Windows; AVIF cần decoder của CEF. Các folder con không truy cập được sẽ báo lỗi quét và giữ queue cũ. Không tự đồng bộ theme trực tiếp hay hợp nhất toolbar/menu với các extension đang chạy khác; đây là Image Importer được chuẩn hóa để gia nhập bộ VGD.
