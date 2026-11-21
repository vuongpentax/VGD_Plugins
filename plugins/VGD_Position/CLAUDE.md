# VGD_Position

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây: xem `runtime/vgd_position.rb`.

## Thông tin plugin

- Tên extension: `VGD Position` (tên có dấu cách, tiếng Anh không dấu để khớp kiểm tra quy ước). Namespace: `VGD::Position`. Thư mục nạp: `vgd_position/`.
- Loader: `runtime/vgd_position.rb` (đăng ký extension, nạp `vgd_position/loader`). Menu: Extensions → VGD → VGD Position (Mở bảng vị trí, Tải lại code). Toolbar: `VGD POS`, lệnh `VGD_POSITION`.
- Phiên bản: hằng `VERSION` trong `runtime/vgd_position.rb`. Đóng gói cần `RELEASE_NOTES_v<x.y.z>.md`.
- SketchUp tối thiểu: 2022. Không lưu dữ liệu vào model (không có dictionary riêng); mọi thay đổi là vị trí của group/component.

## Cấu trúc

- `runtime/vgd_position.rb`: khai báo extension. `runtime/vgd_position/loader.rb`: menu, toolbar, Tải lại code, danh sách file `FILES` (dùng chung cho lúc mở SketchUp và lúc tải lại).
- `core/position.rb`: logic thuần (đọc ô nhập mm, tính độ dời, bỏ món khóa / không đo được). Không gọi SketchUp.
- `core/move.rb`: phần gọi SketchUp (đọc vị trí món trong ngữ cảnh group đang mở, dời món, kiểm tra sau khi dời, một thao tác hoàn tác).
- `ui/panel.rb`: cửa sổ `UI::HtmlDialog` nối giao diện với hai file trên. `html/`: giao diện (`index.html`, `app.js`, `style.css`), `vgd-theme/` là bản copy của `shared/vgd-theme` (đồng bộ bằng `tools/sync_vgd_theme.py`).
- `dev/`: test (`test_position.rb`, `test_move.rb`, `test_reload.rb`, `test_ui.cjs`), `run_tests.rb`, `package.py`, `stubs/` (giả lập để chạy test ngoài SketchUp).

## Kiểm thử

Chạy từ `plugins/VGD_Position`:
- `ruby dev/run_tests.rb`: cú pháp mọi file Ruby, rồi test logic, test dời (SketchUp giả lập), test tải lại / menu.
- `node dev/test_ui.cjs`: Playwright, giao diện (cần Playwright; `VGD_PLAYWRIGHT_MODULE` nếu không cài local).
- Phần chưa kiểm trong SketchUp thật: xem `VALIDATION.md`.

## Đóng gói

- Từ gốc repo: `python plugins/VGD_Position/dev/package.py <phiên bản>`, ra `outputs/local_release_<phiên bản>/VGD_Position_v<phiên bản>.rbz`, kèm SHA-256. Không ghi đè gói đã có.
- Khi thêm vào VGD Center (catalog), theo `shared/VGD_CENTER_ARCHITECTURE.md`: chưa làm ở bản thử.

## Tài liệu đọc trước khi sửa

- `README.md` (cách dùng, giới hạn), `VALIDATION.md` (đã kiểm gì, chưa kiểm gì), `shared/HUONG_DAN_THEME.md` (giao diện).

## Quy tắc riêng

- **Dời món là đổi hình học model.** Chỉ đổi `transformation` của instance được chọn (group / component), không đổi định nghĩa, không đổi món khác. Đây là chỗ duy nhất của plugin đổi model.
- **Xem trước rồi mới áp dụng.** Giao diện chỉ bật nút Áp dụng sau khi xem trước đúng với các ô hiện tại; đổi ô thì khóa lại. Ruby luôn tính lại kế hoạch lúc áp dụng (không tin kết quả xem trước cũ).
- **Một thao tác hoàn tác cho cả đợt** (`start_operation` / `commit_operation`). Lỗi giữa chừng thì `abort_operation`, không để model dở.
- **Kiểm tra sau khi dời.** Vị trí sau khi dời phải khớp kế hoạch trong 0,01 mm; không khớp thì hủy cả đợt.
- **Món khóa và món trong group cha bị khóa:** nếu có trong lựa chọn thì cả đợt không dời, báo tên món. Không bỏ qua âm thầm món nào, để nhóm không bị lệch.
- **Vị trí tính trong hệ thế giới** (mm). Độ dời đổi sang hệ của group cha bằng nghịch đảo biến đổi ngữ cảnh (`Move.context`). Không dùng `Model#edit_transform` (xem CLAUDE.md của BIM về lỗi SketchUp 2024).
- **Ô nhập (mm):** chấp nhận dấu chấm hoặc phẩy; để trống nghĩa là giữ nguyên trục đó. Giới hạn ±1 km.
- **Nhiều món:** cả nhóm dời cùng một độ lệch, tính từ điểm gốc của món đầu tiên trong lựa chọn (`Position.plan`). Không còn chế độ riêng; số món quyết định cách dời.
- Phạm vi bản đầu: điểm gốc của món, không xoay. Chưa có lựa chọn "điểm dời" khác (hộp bao, góc).
- Giao diện chỉ tiếng Việt ở bản đầu. Chuỗi mới phải có bản dịch nếu sau này thêm tiếng Anh.
