# VGD DC Exporter

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây vì dễ lỗi thời: xem nơi giữ phiên bản ở mục "Thông tin plugin".

## Thông tin plugin

- Tên extension: VGD DC Exporter. Namespace: `VGD_DC_Exporter`.
- Loader: `vgd_dc_exporter.rb` (nạp `vgd_dc_exporter/main`); mã nằm trong `vgd_dc_exporter/` (`main.rb`, `params.rb`, `walker.rb`).
- Phiên bản: `extension.version` trong `vgd_dc_exporter.rb`. Phải khớp `VERSION` trong `vgd_dc_exporter/main.rb` và `VERSION` trong `dev/build_release.py`: đổi phiên bản thì sửa cả ba chỗ và `README.md`.
- Công cụ chỉ đọc: không sửa thuộc tính, không redraw DC, không explode, không lưu SKP, không gửi mạng.

## Cấu trúc

- `vgd_dc_exporter/`: `main.rb` (menu và xuất file), `params.rb` (tham số DC), `walker.rb` (duyệt cấu trúc component).
- `dev/build_release.py`: đóng gói. `test/test_exporter.rb`: kiểm thử.

## Kiểm thử

- Tải lại code: `ruby test/test_reload.rb` (chạy từ `plugins/VGD_DC_Exporter`; giả lập SketchUp, kiểm tra mục menu, không nhân đôi giao diện, lỗi file giữ bản đang chạy).
- Chạy từ thư mục gốc plugin: `ruby test/test_exporter.rb`.
- Test dùng đối tượng giả lập, không phải SketchUp thật. Không ghi là đã test trong SketchUp khi chỉ chạy test này.

## Đóng gói

- `python3 dev/build_release.py` tạo `outputs/VGD_DC_Exporter_<phiên bản>.rbz` (git bỏ qua `outputs/`). Gói gồm đúng bốn file trong danh sách `FILES` của script: thêm file mã mới thì thêm vào `FILES`.

## Tài liệu đọc trước khi sửa

- `README.md` (nội dung JSON xuất ra, giới hạn đã biết).

## Quy tắc riêng

- Chỉ xuất trạng thái và công thức đang lưu, không tính lại kết quả DC. Giữ giá trị mặc định và giá trị instance tách bạch trong JSON (schema `vgd.dc_snapshot`).
- Thông tin mô tả của tham số DC `x` nằm ở các khóa có gạch dưới ở đầu (`_x_formula`, `_x_label`, `_x_units`, `_x_access`, `_x_options`...), còn giá trị ở khóa `x`: không bỏ dấu gạch dưới khi đọc (xem chú thích đầu `params.rb`).
