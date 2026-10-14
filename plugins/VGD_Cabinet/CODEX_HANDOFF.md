# VGD_Cabinet — bàn giao trạng thái 4.5.2

## Baseline và cấu trúc

Baseline hiện tại là **VGD_Cabinet 4.5.2**. Runtime triển khai nằm trong `cabinet_work/`; `cabinet_dev/` chứa kiểm thử, stub, fixture, nguồn giao diện, generator và công cụ đóng gói/triển khai. Loader `cabinet_work/vgd_cabinet.rb` đăng ký `VGD_Cabinet/main43.rb`; tên `main43.rb` là tên file hiện hành dù đã cũ.

Gói RBZ có whitelist 23 file và công cụ đồng bộ nhắm SketchUp 2022. `cabinet_work/VGD_Cabinet/VGD_Cabinet_UI.html` được sinh từ `cabinet_dev/redesign_ui.cjs`, `ui_beta1.html`, `menu.css` và `menu.js`; cần giữ các nguồn này đồng bộ khi sửa UI. Generator tạo thư mục output cục bộ, không có `outputs/` được lưu trong repository.

## Quy tắc dữ liệu và hình học

- Đọc nhận diện và tham số cũ từ dictionary `TPlus_Cabinet` để tương thích; cabinet mới/cập nhật ghi vào `VGD_Cabinet`. Không chuyển đổi đối tượng model không liên quan.
- Preset: `%APPDATA%/VGD/SketchUp/VGD_Cabinet/presets_v1.json`. Thư viện SKP, preview và index: `%APPDATA%/VGD/SketchUp/VGD_Cabinet/library/`. Giữ backup, ghi tạm và khóa file; không reset dữ liệu khi reload/cài lại. Chỉ đọc preset T+ khi chưa có kho mới.
- Create, update và rename preset/thư viện là thao tác riêng; chặn tên trùng không phân biệt hoa thường. `front_bevel`/`bevel_lip` dành cho cánh; `drawer_bevel`/`drawer_bevel_lip` dành riêng cho hộc.
- Giữ quy tắc thùng, hậu và cánh hiện có. Pano khung gỗ dùng thanh khung và rãnh thẳng thật, panel phẳng có phần ngậm trừ khe co giãn; không thuộc phạm vi CNC/BOM.
- Preview dựng vào sink trong bộ nhớ, không tạo entity tạm trong model. Batch front chỉ đổi cài đặt cánh/hộc; giữ kích thước và bố cục module từng cabinet.

## Hồ sơ xác minh

Các trạng thái dưới đây được chép từ `VALIDATION.json` và release notes; **không phải test chạy trong lượt đồng bộ tài liệu này**.

### Đã ghi nhận qua kiểm thử tự động

- Ruby 3.2 WASM, stub SketchUp, JSDOM và Edge headless ghi nhận PASS cho syntax, geometry/parameter, preset/library IO, mô tả, payload, preview fixture và các luồng UI đã có. Filesystem IO dùng host Windows qua WASI; `flock` bị mô phỏng trong WASI.
- Đóng gói ghi nhận PASS cho whitelist 23 file, source equality, CRC và SHA256.
- Lần Edge trước đó không chạy được kiểm tra UI mới thêm cho nút batch settings (`EPERM`). Không gộp kết quả UI cũ thành PASS cho nút này.

### Kế thừa từ native 4.5.1

`native_upgrade.rb` được ghi nhận đã chạy trên SketchUp 2022.0.316 / Ruby 2.7.2 với runtime model 4.5.1: geometry manifold được liệt kê, shared component và sửa tay, Box → Cabinet theo trục cục bộ, drawer overlay, preview không sửa model, library SKP/persistence/locking và batch giữ kích thước/module width. Tool preview báo một draw call. Không xem các kết quả này là xác minh runtime 4.5.2.

### Riêng 4.5.2 còn chờ native

Hồ sơ ghi nhận ngày 2026-10-12 đã triển khai đủ 23 file vào SketchUp 2022 và đối chiếu SHA256; T+ loader không có ở máy đó. Chưa khởi động lại/chạy SketchUp với gói 4.5.2 sạch. Native Undo trên model đang làm, đóng/mở lại model, tương tác UI batch mới và scaling cửa sổ vẫn chưa được xác minh.

## Phạm vi chưa triển khai và lưu ý triển khai

Chưa có UI chỉnh hướng/open-pose cho metadata cánh/hộc; chưa có editor viewport cho bố cục đợt/vách, từng opening, đặt tay nắm hay cut/notch. Không mô tả chúng như tính năng đã có.

Chênh lệch phạm vi deploy đã được xử lý: script chỉ backup/retire `tplus_cabinet.rb`. Nếu có sẵn, `utilities.rb`, `combine.svg`, `untag.svg` và `logo.svg` được giữ nguyên; `test_deploy.py` kiểm tra nội dung fixture của chúng sau deploy. `VALIDATION.json` vẫn giữ ghi nhận lịch sử về lần cài trực tiếp trước đây đã gỡ bốn file tiện ích; đó không phải hành vi của script hiện tại.

Xem `README.md` để dùng plugin, `TESTS.txt` để biết lệnh kiểm tra, và `VALIDATION.json` để đọc chi tiết từng hồ sơ PASS/chưa chạy.
