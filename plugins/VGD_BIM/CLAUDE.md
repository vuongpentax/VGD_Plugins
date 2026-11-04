# VGD BIM Lite

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây vì dễ lỗi thời: xem nơi giữ phiên bản ở mục "Thông tin plugin".

## Thông tin plugin

- Tên extension: VGD BIM Lite. Namespace: `VGD::BIM`.
- Loader: `runtime/vgd_bim_lite.rb` (nạp `vgd_bim_lite/loader`).
- Phiên bản: hằng `VERSION` trong `runtime/vgd_bim_lite.rb`. Tiêu đề README có thể ghi số cũ hơn; lấy số trong loader.
- SketchUp tối thiểu: 2022. Windows là môi trường chính.
- Dữ liệu trong model: dictionary `VGD_BIM` (Group/ComponentInstance) và `VGD_BIM_RULES` (quy tắc, lưu JSON).

## Cấu trúc

- `runtime/`: mã chạy (loader và thư mục `vgd_bim_lite/`).
- `dev/`: test, fixture, `package.py`, `deploy.ps1`, `native_smoke.rb`.
- Gốc plugin: README, SPECIFICATION, VALIDATION, HUONG_DAN_SU_DUNG, RELEASE_NOTES_*.

## Kiểm thử

Chạy từ `plugins/VGD_BIM`, theo README:
- `node dev/check_ruby.cjs`: compile Ruby và chạy test Core, hình học affine, scanner bằng Ruby WASM 3.2. Đây là mô phỏng, không thay SketchUp.
- `dev/test_ui.cjs`: Playwright + Edge headless; đặt `VGD_PLAYWRIGHT_MODULE` nếu Playwright không cài local.
- `dev/native_smoke.rb`: chỉ chạy trong một tiến trình SketchUp mới với model trống. Không chạy trên model của người dùng.
- Phần chưa xác minh trong SketchUp thật: xem `VALIDATION.md`.

## Đóng gói

- `python dev/package.py` tạo gói. `dev/deploy.ps1` cài nguồn vào SketchUp 2022: `-VerifyOnly` để kiểm tra trước, `-PluginRoot` chọn bản SketchUp khác. Script chỉ copy file của plugin này, có sao lưu và kiểm tra SHA-256.
- File `.rbz` và `outputs/` không đưa vào git.

## Tài liệu đọc trước khi sửa

- `README.md` (cách dùng, ý nghĩa dữ liệu, giới hạn), `SPECIFICATION.md`, `VALIDATION.md`.

## Quy tắc riêng

- Số liệu hình học thô (faces, edges, diện tích vật liệu) là RAW QUANTITY / RAW GEOMETRY, chưa phải BOQ. Mặt trước và mặt sau tách riêng, không cộng thành một khối lượng.
- Báo cáo CSV là dữ liệu và khối lượng gốc, không tính đơn giá hay thành tiền.
- Mã schema giữ nguyên để các plugin VGD dùng chung; bản dịch chỉ áp dụng ở giao diện và báo cáo.
- Nguồn dữ liệu (`VGD`, `MAPPED`, `RAW`, `MANUAL`) lưu trong metadata `_source`, tách khỏi schema nghiệp vụ v1.
- "Chuyển đổi lựa chọn": mỗi batch chỉ có một bước hoàn tác và không sửa hình học, tên, thẻ hoặc vật liệu.
