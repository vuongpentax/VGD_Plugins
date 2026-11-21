# VGD_Transform

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây: xem `runtime/vgd_transform.rb`.

## Thông tin plugin

- Tên extension: `VGD Transform` (trước đây là VGD Position). Namespace: `VGD::Transform`. Thư mục nạp: `vgd_transform/`.
- Loader: `runtime/vgd_transform.rb` (đăng ký extension, nạp `vgd_transform/loader`). Menu: Extensions → VGD → VGD Transform (Mở bảng biến đổi, Tải lại code). Toolbar: `VGD TRF`, ba lệnh `VGD_TRANSFORM_MOVE` / `_ROTATE` / `_SCALE` (icon `assets/icons/move.svg`, `rotate.svg`, `scale.svg`), mỗi lệnh gọi `open_panel(tool)` để mở cửa sổ ở đúng công cụ.
- Phiên bản: hằng `VERSION` trong `runtime/vgd_transform.rb`. Đóng gói cần `RELEASE_NOTES_v<x.y.z>.md`.
- SketchUp tối thiểu: 2022 (Ruby 2.7: không dùng cú pháp chỉ có từ Ruby 3, ví dụ `def f(x) = ...`). Không lưu dữ liệu vào model; mọi thay đổi là `transformation` của group/component.
- Mục tiêu: giống hộp Transform Type-In của 3ds Max (Absolute / Offset, Use Center, hệ World / Local, spinner).

## Cấu trúc

- `runtime/vgd_transform.rb`: khai báo extension. `runtime/vgd_transform/loader.rb`: menu, toolbar, Tải lại code, danh sách file `FILES` (dùng chung cho lúc mở SketchUp và lúc tải lại; thứ tự nạp có ý nghĩa vì file sau dùng hằng của file trước).
- `core/units.rb`: đơn vị (mm, cm, m, in, ft, yd) và ô nhập: số có đơn vị, số theo đơn vị của file, ô scale (hệ số hoặc kích thước đích).
- `core/items.rb`: món đang chọn (kiểm tra khóa, tâm biến đổi, hệ trục, giá trị chung), lỗi `NothingToDo`.
- `core/steps.rb`: định dạng bước biến đổi và công thức áp dụng bước lên điểm (`Steps.apply_steps`).
- `core/translate.rb`: dời tuyệt đối (theo tâm) và tương đối (World / Local).
- `core/rotate_scale.rb`: xoay, scale tương đối, scale tuyệt đối (local).
- `core/plan.rb`: ghép công cụ với chuỗi người dùng nhập (`Plan.build`).
- `core/model_ops.rb`: phần gọi SketchUp duy nhất (đọc món từ ma trận, áp dụng, kiểm tra, kéo trực tiếp). Các file core khác không gọi SketchUp.
- `ui/panel.rb`: cửa sổ `UI::HtmlDialog`, observer lựa chọn và model, kéo trực tiếp. `html/`: giao diện (`index.html`, `app.js`, `style.css`), `vgd-theme/` là bản copy của `shared/vgd-theme` (đồng bộ bằng `tools/sync_vgd_theme.py`; dùng `vgd-theme.css` và `vgd-controls.css`).
- `dev/`: test (`test_units.rb`, `test_transform.rb`, `test_model_ops.rb`, `test_reload.rb`, `test_ui.cjs`), `run_tests.rb`, `package.py`, `stubs/`.

## Kiểm thử

Chạy từ `plugins/VGD_Transform`:
- `ruby dev/run_tests.rb`: cú pháp mọi file Ruby, rồi test đơn vị, test logic (dời, xoay, scale, tâm, hệ trục, ghép công cụ), test phần SketchUp với SketchUp giả lập (ma trận 4×4 độc lập với công thức trong code), test tải lại / menu.
- `node dev/test_ui.cjs`: Playwright, giao diện (cần Playwright; `VGD_PLAYWRIGHT_MODULE` nếu không cài local).
- Phần chưa kiểm trong SketchUp thật: xem `VALIDATION.md`.

## Đóng gói

- Từ gốc repo: `python plugins/VGD_Transform/dev/package.py <phiên bản>`, ra `outputs/local_release_<phiên bản>/VGD_Transform_v<phiên bản>.rbz`, kèm SHA-256. Không ghi đè gói đã có.
- Khi thêm vào VGD Center (catalog), theo `shared/VGD_CENTER_ARCHITECTURE.md`: chưa làm ở bản thử.

## Tài liệu đọc trước khi sửa

- `README.md` (cách dùng, giới hạn), `VALIDATION.md` (đã kiểm gì, chưa kiểm gì), `shared/HUONG_DAN_THEME.md` (giao diện).

## Quy tắc riêng

- **Mọi biến đổi là đổi hình học model.** Chỉ đổi `transformation` của instance được chọn (group / component), không đổi định nghĩa, không đổi món khác. Cạnh, mặt rời trong lựa chọn không biến đổi; số lượng được báo (`ModelOps.skipped_count`), không bỏ qua âm thầm.
- **Biến đổi = danh sách bước.** Bước `translate`, `rotate` (trục bất kỳ qua tâm), `scale` (hệ số theo ba trục vuông góc qua tâm). `ModelOps.apply` gộp các bước của một món thành một ma trận và đặt `transformation` đúng một lần.
- **Kiểm tra sau khi biến đổi, hai cách:** ma trận thế giới phải khớp ma trận đã tính (bắt lỗi xoay / scale), và điểm gốc phải khớp công thức thuần `Steps.apply_steps` (0,01 mm). Sai thì hủy cả đợt.
- **Một thao tác hoàn tác cho cả đợt.** Kéo trực tiếp: lần cập nhật đầu là thao tác mới, các lần sau `start_operation(..., transparent = true)` để gộp; mỗi lần đặt lại biến đổi lúc bắt đầu kéo rồi tính lại từ đó. `NothingToDo` khi kéo nghĩa là đưa món về trạng thái đầu.
- **Áp dụng ngay bằng Enter.** Không có nút Áp dụng, không xem trước, không danh sách món, không bảng kết quả.
- **Cửa sổ gọn** cỡ Transform Type-In của 3ds Max: 320 × 250 (tối thiểu 300 × 220), chữ 12 px (11 px cho phụ), ô cao 22 px.
- **Ghi chú ở đáy bảng:** giải thích để trong `data-note` (không dùng `title`), hiện ở dòng `#note` khi rê chuột. Thông báo mới (kết quả, lỗi) được ưu tiên cho tới khi chuột rê sang chỗ khác. Không có chữ mặc định. Dòng trạng thái (đơn vị, số món) cũng ở đáy. `preferences_key` là `VGD_Transform_Compact` (đổi khóa để không giữ cỡ to của bản cũ). Kiểm tra bằng ảnh chụp ở đúng cỡ này, cả theme sáng và tối.
- **Icon** theo `shared/VGD_ICON_SYSTEM_RULES.md` (24 × 24, nét 1,8, `#292B2D` + điểm nhấn `#B48963`). Icon trong cửa sổ cùng hình với file SVG của thanh công cụ nhưng dùng màu theme (`currentColor`, `--vgd-accent`); sửa một bên thì sửa cả hai.
- **Ô Tuyệt đối hiện giá trị hiện tại** (Ruby gửi sự kiện `state` khi lựa chọn đổi và khi model đổi, kể cả Ctrl+Z). Giao diện chỉ gửi ô người dùng đã sửa (cờ `dirty`); ô không sửa gửi trống = giữ, để số làm tròn khi hiển thị không dời món. Chọn hơn 500 món thì không đọc giá trị (tránh chậm).
- **Ô Tương đối về 0 sau khi áp dụng** (kể cả sau khi kéo trực tiếp), như Offset của 3ds Max.
- **Tâm biến đổi (Use Center):** `item` điểm gốc từng món, `selection` tâm hộp bao hình của cả lựa chọn, `world` gốc thế giới. Dời tuyệt đối: `item` đưa điểm gốc từng món tới tọa độ; `selection` và `world` đưa tâm hộp bao tới tọa độ. Không dùng thứ tự lựa chọn của SketchUp (không đảm bảo là thứ tự bấm chọn).
- **Hệ trục:** `world` hoặc `local` (trục riêng của từng món, đọc từ ma trận thế giới, chuẩn hóa). Dùng cho Dời tương đối, Xoay, Scale tương đối. Dời tuyệt đối luôn theo thế giới; Scale tuyệt đối luôn theo trục riêng.
- **Xoay:** góc X, Y, Z áp dụng theo thứ tự; hệ local lấy trục theo hướng món lúc bắt đầu. Không có xoay tuyệt đối (góc Euler của group không duy nhất).
- **Scale:** tương đối là hệ số (0,001 đến 1000) hoặc kích thước đích có đơn vị (chỉ ở Không đều; world đo hộp bao thế giới, local đo kích thước theo trục riêng). Tuyệt đối: tỉ lệ so với definition = độ dài trục của ma trận thế giới. Không hỗ trợ hệ số âm.
- **Đơn vị:** `ModelOps.length_unit` đọc `model.options['UnitsOptions']['LengthUnit']` (0 in, 1 ft, 2 mm, 3 cm, 4 m, 5 yd). Chỉ số lạ: báo trên giao diện và dùng mm. Gõ thêm đơn vị sau số thì số đó dùng đơn vị đã gõ. Giới hạn ±1 km.
- **Ô số (spinner):** ▲▼ bấm một bước, giữ để lặp, kéo lên xuống trên nút để đổi nhanh (Ctrl ×10, Alt ×0,1), chuột phải về mặc định. Kéo trên ô chữ không đổi số. Bước ô độ dài khoảng 1 mm theo đơn vị file.
- **Khóa như Lock của SketchUp:** `ModelOps.set_locked` đặt `Entity#locked=` cho mọi group / component đang chọn, một bước hoàn tác (`VGD Transform · Khóa` / `Mở khóa`). Nút khóa: khóa hết thì mở, còn lại thì khóa hết; trạng thái `lock` (`all` / `none` / `mixed`) gửi trong `state`. Không đổi khóa khi group cha đang mở bị khóa. Nút khóa không phải nút công cụ: chỉ `.tabs .tab` chuyển công cụ.
- **Tải lại code** bị chặn khi đang kéo trực tiếp (`busy_reason`).
- Giao diện chỉ tiếng Việt ở bản đầu. Chuỗi mới phải có bản dịch nếu sau này thêm tiếng Anh.
