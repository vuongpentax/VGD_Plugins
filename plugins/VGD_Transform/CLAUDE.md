# VGD_Transform

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây: xem `runtime/vgd_transform.rb`.

## Thông tin plugin

- Tên extension: `VGD Transform` (tên có dấu cách, tiếng Anh không dấu để khớp kiểm tra quy ước). Namespace: `VGD::Transform`. Thư mục nạp: `vgd_transform/`.
- Loader: `runtime/vgd_transform.rb` (đăng ký extension, nạp `vgd_transform/loader`). Menu: Extensions → VGD → VGD Transform (Mở bảng biến đổi, Tải lại code). Toolbar: `VGD TRF`, lệnh `VGD_TRANSFORM`.
- Phiên bản: hằng `VERSION` trong `runtime/vgd_transform.rb`. Đóng gói cần `RELEASE_NOTES_v<x.y.z>.md`.
- SketchUp tối thiểu: 2022. Không lưu dữ liệu vào model (không có dictionary riêng); mọi thay đổi là vị trí, góc hoặc tỉ lệ của group/component.

## Cấu trúc

- `runtime/vgd_transform.rb`: khai báo extension. `runtime/vgd_transform/loader.rb`: menu, toolbar, Tải lại code, danh sách file `FILES` (dùng chung cho lúc mở SketchUp và lúc tải lại; thứ tự nạp có ý nghĩa vì file sau dùng hằng của file trước).
- `core/units.rb`: đơn vị và ô nhập (số có đơn vị, số theo đơn vị của file, hiển thị). Không gọi SketchUp.
- `core/translate.rb`: dời tuyệt đối và tương đối (tạo bước `translate`). Không gọi SketchUp.
- `core/rotate_scale.rb`: xoay và scale theo trục thế giới, tâm xoay / scale. Không gọi SketchUp.
- `core/steps.rb`: định dạng bước biến đổi và công thức áp dụng bước lên điểm (`Steps.apply_steps`) để kiểm tra sau khi áp dụng. Không gọi SketchUp.
- `core/plan.rb`: ghép công cụ với chuỗi người dùng nhập (`Plan.build`) và tạo dòng mô tả để xem trước (`Plan.describe`). Không gọi SketchUp.
- `core/move.rb`: phần gọi SketchUp (đọc vị trí món trong ngữ cảnh group đang mở, đơn vị của file, áp dụng từng bước, kiểm tra sau khi áp dụng, một thao tác hoàn tác).
- `ui/panel.rb`: cửa sổ `UI::HtmlDialog` nối giao diện với các file trên. `html/`: giao diện (`index.html`, `app.js`, `style.css`), `vgd-theme/` là bản copy của `shared/vgd-theme` (đồng bộ bằng `tools/sync_vgd_theme.py`).
- `dev/`: test (`test_units.rb`, `test_transform.rb`, `test_move.rb`, `test_reload.rb`, `test_ui.cjs`), `run_tests.rb`, `package.py`, `stubs/` (giả lập để chạy test ngoài SketchUp).

## Kiểm thử

Chạy từ `plugins/VGD_Transform`:
- `ruby dev/run_tests.rb`: cú pháp mọi file Ruby, rồi test đơn vị, test logic (dời, xoay, scale, ghép công cụ), test biến đổi với SketchUp giả lập (ma trận 4×4 độc lập với công thức trong code), test tải lại / menu.
- `node dev/test_ui.cjs`: Playwright, giao diện (cần Playwright; `VGD_PLAYWRIGHT_MODULE` nếu không cài local).
- Phần chưa kiểm trong SketchUp thật: xem `VALIDATION.md`.

## Đóng gói

- Từ gốc repo: `python plugins/VGD_Transform/dev/package.py <phiên bản>`, ra `outputs/local_release_<phiên bản>/VGD_Transform_v<phiên bản>.rbz`, kèm SHA-256. Không ghi đè gói đã có.
- Khi thêm vào VGD Center (catalog), theo `shared/VGD_CENTER_ARCHITECTURE.md`: chưa làm ở bản thử.

## Tài liệu đọc trước khi sửa

- `README.md` (cách dùng, giới hạn), `VALIDATION.md` (đã kiểm gì, chưa kiểm gì), `shared/HUONG_DAN_THEME.md` (giao diện).

## Quy tắc riêng

- **Mọi biến đổi là đổi hình học model.** Chỉ đổi `transformation` của instance được chọn (group / component), không đổi định nghĩa, không đổi món khác. Đây là chỗ duy nhất của plugin đổi model.
- **Biến đổi = danh sách bước.** Mỗi món nhận các bước `translate` (dời), `rotate` (xoay quanh trục thế giới đi qua tâm), `scale` (nhân hệ số theo trục thế giới quanh tâm). `Move.apply` áp dụng từng bước rồi kiểm tra điểm gốc bằng `Steps.apply_steps`.
- **Xem trước rồi mới áp dụng.** Giao diện chỉ bật nút Áp dụng của khung sau khi xem trước đúng với các ô hiện tại; đổi ô thì khóa lại. Ruby luôn tính lại kế hoạch lúc áp dụng (không tin kết quả xem trước cũ).
- **Một thao tác hoàn tác cho cả đợt** (`start_operation` / `commit_operation`). Lỗi giữa chừng thì `abort_operation`, không để model dở.
- **Kiểm tra sau khi biến đổi.** Điểm gốc sau khi biến đổi phải khớp kế hoạch trong 0,01 mm; không khớp thì hủy cả đợt.
- **Món khóa và món trong group cha bị khóa:** nếu có trong lựa chọn thì cả đợt không chạy, báo tên món. Không bỏ qua âm thầm món nào, để nhóm không bị lệch.
- **Vị trí tính trong hệ thế giới** (mm). Biến đổi đổi sang hệ của group cha bằng `ctx.inverse * W * ctx` (`Move.context`). Không dùng `Model#edit_transform` (xem CLAUDE.md của BIM về lỗi SketchUp 2024).
- **Đơn vị:** số không có đơn vị theo đơn vị của file (`Move.length_unit`, đọc từ `model.options['UnitsOptions']['LengthUnit']`: 0 in, 1 ft, 2 mm, 3 cm, 4 m). Gõ thêm đơn vị (mm, cm, m, in, ft) thì số đó dùng đơn vị đã gõ. Mọi tính toán nội bộ dùng mm. Giới hạn ±1 km.
- **Nhiều món:** cả nhóm dời cùng một độ lệch, tính từ điểm gốc của món đầu tiên trong lựa chọn. Xoay và scale: tâm chọn được (`item`, `selection`, `world`).
- **Xoay:** các góc nhập được áp dụng theo thứ tự X, Y, Z trên trục thế giới. Chỉ có xoay tương đối (không có góc tuyệt đối, vì SketchUp không cho đọc góc "hiện tại" của group một cách rõ ràng).
- **Scale:** hệ số tương đối, phải dương (0,001 đến 1000). Hệ số 1 ở mọi trục bị từ chối. Không có scale tuyệt đối vì cùng lý do với xoay. Hệ số âm (lật món) không hỗ trợ.
- **Giao diện:** ô số có nút ▲▼ (giữ để lặp) và kéo lên xuống trên ô. Ô số không tự parse đơn vị; việc đó do Ruby (`Units`) làm.
- Giao diện chỉ tiếng Việt ở bản đầu. Chuỗi mới phải có bản dịch nếu sau này thêm tiếng Anh.
