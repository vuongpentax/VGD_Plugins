# VGD_BIM

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây vì dễ lỗi thời: xem nơi giữ phiên bản ở mục "Thông tin plugin".

## Thông tin plugin

- Tên extension: VGD_BIM (trước 1.1.0 là "VGD BIM Lite"; VGD Center nhận cả hai tên qua `find_installed_extension`). Namespace: `VGD::BIM`. Id trong catalog của Center: `bim_lite`.
- Loader: `runtime/vgd_bim_lite.rb` (nạp `vgd_bim_lite/loader`). Thư mục và tên file giữ `vgd_bim_lite` vì Center khai báo đúng hai đường dẫn này.
- Phiên bản: hằng `VERSION` trong `runtime/vgd_bim_lite.rb` (dạng `x.y.z` hoặc `x.y.z-beta.N`, không có chữ `v`). Tiêu đề README phải khớp số này. Đóng gói cần có `RELEASE_NOTES_v<x.y.z>.md` (bản beta dùng chung ghi chú của bản chốt).
- SketchUp tối thiểu: 2022. Windows là môi trường chính.
- Dữ liệu trong model: dictionary `VGD_BIM` (Group/ComponentInstance) và `VGD_BIM_RULES` (quy tắc, lưu JSON).
- Dữ liệu trên máy: file JSON trong `%APPDATA%\VGD\VGD_BIM\` (`~/VGD/VGD_BIM` nếu không phải Windows; biến `VGD_BIM_DATA_DIR` đổi thư mục): `tag_set.json`, `table_presets.json`, `table_view.json` (xem `core/storage.rb`).

## Cấu trúc

- `runtime/`: mã chạy. `vgd_bim_lite/loader.rb` giữ danh sách `FILES` (thứ tự nạp, dùng chung cho lúc mở SketchUp và `VGD::BIM.reload`); thư mục con `core/`, `intake/`, `ui/` (`dialog.rb`, `bounds_preview.rb`), `html/` (giao diện), `config/`.
- `dev/`: `run_tests.rb`, các `test_*.rb`, `test_ui.cjs`, fixture và `stubs/`, `package.py`, `deploy.ps1`, `native_smoke.rb`, `make_preview.py`.
- Gốc plugin: README, SPECIFICATION (đặc tả gốc v0.1, có ghi chú cập nhật), VALIDATION, HUONG_DAN_SU_DUNG, RELEASE_NOTES_*.

## Kiểm thử

Chạy từ `plugins/VGD_BIM`:
- `ruby dev/run_tests.rb`: kiểm tra cú pháp mọi file Ruby và chạy các `dev/test_*.rb` bằng Ruby thường (mô phỏng, không thay SketchUp). Mỗi test cũng chạy riêng được, ví dụ `ruby dev/test_table.rb`.
- `dev/test_ui.cjs`: Playwright + trình duyệt headless; đặt `VGD_PLAYWRIGHT_MODULE` nếu Playwright không cài local, `VGD_BROWSER_CHANNEL=msedge` để dùng Edge.
- `dev/native_smoke.rb`: chỉ chạy trong một tiến trình SketchUp mới với model trống. Không chạy trên model của người dùng.
- Phần chưa xác minh trong SketchUp thật: xem `VALIDATION.md`.

## Đóng gói

- Từ gốc repo: `python plugins/VGD_BIM/dev/package.py <phiên bản>`, ra `outputs/local_release_<phiên bản>/VGD_BIM_v<phiên bản>.rbz`, kèm SHA-256. Script không ghi đè gói đã có.
- `dev/deploy.ps1` cài nguồn vào SketchUp 2022: `-VerifyOnly` để kiểm tra trước, `-PluginRoot` chọn bản SketchUp khác. Script chỉ copy file của plugin này, có sao lưu và kiểm tra SHA-256.
- File `.rbz` và `outputs/` không đưa vào git.

## Tài liệu đọc trước khi sửa

- `README.md` (cách dùng, ý nghĩa dữ liệu, giới hạn), `SPECIFICATION.md`, `VALIDATION.md`.

## Quy tắc riêng

- Số liệu hình học thô (faces, diện tích vật liệu) là RAW QUANTITY / RAW GEOMETRY, chưa phải BOQ. Mặt trước và mặt sau tách riêng, không cộng thành một khối lượng. Plugin không đọc cạnh (edge).
- Báo cáo CSV là dữ liệu và khối lượng gốc, không tính đơn giá hay thành tiền.
- Mã schema giữ nguyên để các plugin VGD dùng chung; bản dịch chỉ áp dụng ở giao diện và báo cáo.
- Nguồn dữ liệu (`VGD`, `MAPPED`, `RAW`, `MANUAL`) lưu trong metadata `_source`, tách khỏi schema nghiệp vụ v1.
- Chuyển đổi trong tab Phân loại: mỗi batch chỉ có một bước hoàn tác và không sửa hình học, tên, thẻ hoặc vật liệu.
- Chọn đối tượng không được quét toàn model: tab Bảng khối lượng chỉ đọc đối tượng đang chọn (quét sâu chỉ khi bật "Chọn sâu bên trong"); chỉ các tab Quét & xuất, Phân loại, Kiểm tra mới quét model.
- Không dùng `Sketchup.write_default` cho dữ liệu JSON (chuỗi có dấu ngoặc kép hoặc tiếng Việt bị hỏng khi đọc lại); dùng `core/storage.rb`.
- `Sketchup::Tool` không tồn tại: khung đánh dấu `UI::BoundsPreview` là lớp thường với các hàm `draw` / `onLButtonDown` / `onCancel`. Test không được thêm stub cho lớp không có trong API SketchUp, vì stub có thể che lỗi thật.
- Màu giao diện lấy từ theme VGD (`runtime/vgd_bim_lite/html/vgd-theme/`), không tự đặt màu riêng.
- `update_notice.rb` giữ nguyên để loader cũ vẫn gọi được; plugin không tự báo cập nhật, VGD Center báo bản mới.
- Đổi tên hoặc đường dẫn extension phải kiểm tra lại `find_installed_extension` và `PLUGIN_LAYOUTS` của VGD Center (`plugins/VGD_Center/VGD_Center/main.rb`).
