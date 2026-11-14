# VGD Reference

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây vì dễ lỗi thời: xem nơi giữ phiên bản ở mục "Thông tin plugin".

## Thông tin plugin

- Tên extension: VGD Reference. Namespace: `VGD::Reference`.
- Loader: `runtime/vgd_reference.rb` (nạp `vgd_reference/main`).
- Phiên bản: `extension.version` trong `runtime/vgd_reference.rb`.
- SketchUp tối thiểu: **2023**, theo `MIN_SKETCHUP_VERSION` trong `runtime/vgd_reference/core/constants.rb` (cần Overlay API). Đây là ngoại lệ so với mặc định 2022 của repo.
- Windows là môi trường chính (đọc clipboard bằng Fiddle chỉ có trên Windows).

## Cấu trúc

- `runtime/vgd_reference/`: `core/` (trạng thái, mục ảnh, store), `viewport/` (vẽ overlay, texture, hit test), `tools/`, `import/`, `ui/` (HtmlDialog), `observers/`.
- `dev/`: test, fixture, `package.cjs`, `build_icons.cjs`, `MANUAL_VERIFICATION.md`.

## Kiểm thử

- Test trong `dev/`: `check_ruby.cjs`, `test_manager.cjs`, `test_icons.cjs` và các `*_fixture.rb`. README không ghi lệnh chạy từng file; xem đầu mỗi file.
- Kiểm tra thủ công trong SketchUp: `dev/MANUAL_VERIFICATION.md`. Phần chưa xác minh trong SketchUp thật: xem `HANDOFF.md` mục "Current limitations".

## Đóng gói

- Từ gốc repo: `node plugins/VGD_Reference/dev/package.cjs` (tạo RBZ, source ZIP và SHA-256 riêng cho từng gói, tạo lại icon và manifest). File `.rbz` và `outputs/` không đưa vào git.

## Tài liệu đọc trước khi sửa

- `README.md`, `HANDOFF.md` (kiến trúc, giới hạn hiện tại), `dev/MANUAL_VERIFICATION.md`.

## Quy tắc riêng

- Không dùng model entity hay attribute dictionary. File ảnh gốc chỉ đọc.
- File tạm (clipboard, ảnh thả, ảnh tải, PNG đã chuyển) do plugin sở hữu và bị xóa khi mục, model hoặc phiên kết thúc. Chỉ xóa file đã theo dõi.
- Tải web và bộ chuyển đổi chạy trên worker thread; các thread này không bao giờ gọi API SketchUp, model hay HtmlDialog. Kết quả về timer chính qua Queue.
- Ảnh đầu vào tối đa 20 MiB và 32 triệu pixel.
- `ReferenceOverlay#getExtents` phải trả hộp rỗng (`Geom::BoundingBox.new`), không trả `model.bounds`: hộp bao của model gồm cả đối tượng đã ẩn nên Zoom Extents sẽ tính cả chúng. Test: `ruby dev/overlay_extents_fixture.rb` (chạy từ `plugins/VGD_Reference`).
