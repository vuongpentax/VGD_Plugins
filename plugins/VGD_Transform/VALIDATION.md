# Kiểm tra VGD Transform

Mọi kết quả dưới đây là **mô phỏng ngoài SketchUp**, trừ khi ghi khác.

## Bản 0.1.0-beta.5: đã kiểm tra tự động

- `dev/test_units.rb`: số có đơn vị (mm, cm, m, in, ft; không phân biệt hoa thường); số không đơn vị theo đơn vị của file; dấu phẩy; chữ, số mũ, đơn vị lạ bị từ chối; giới hạn ±1 km; chỉ số đơn vị của SketchUp (0 in, 1 ft, 2 mm, 3 cm, 4 m) và chỉ số lạ; ô scale: số không đơn vị là hệ số, số có đơn vị là kích thước đích, kích thước đích 0 hoặc âm bị từ chối.
- `dev/test_transform.rb`: dời tuyệt đối (giữ trục trống, đã đúng vị trí, nhiều món theo món đầu tiên); dời tương đối; chặn món khóa và món không đo được vị trí; xoay quanh Z với các tâm; thứ tự X-Y-Z; scale đều và không đều quanh các tâm; scale đến kích thước đích, riêng từng món (món kích thước 0 báo lỗi); ghép công cụ với ô nhập (có đơn vị, scale đều không nhận kích thước đích, scale không đổi gì thì báo lỗi).
- `dev/test_move.rb` (SketchUp giả lập, biến đổi bằng ma trận 4×4 độc lập với công thức trong code): đo kích thước món theo hộp bao; scale đến kích thước đích 1500 mm trên X; trong group cha xoay 90°, đặt X thế giới thành 1000 mm thì đúng; dời ở gốc và trong group cha; nhiều món cùng độ dời trong một thao tác; xoay; scale; món khóa và group cha khóa; một thao tác hoàn tác; hủy cả thao tác khi vị trí sau biến đổi không khớp.
- `dev/test_reload.rb`: menu đúng hai mục (Mở bảng biến đổi, Tải lại code); tải lại 3 lần không nhân đôi mục; đang bận thì không nạp lại và báo đúng; lỗi cú pháp giữ nguyên bản đang chạy.
- `dev/test_ui.cjs` (Playwright, 25 kiểm tra): không còn danh sách món, bảng kết quả hay nút Xem trước; Enter trong ô áp dụng ngay với đúng công cụ và ô; nút Áp dụng; ô có đơn vị gửi nguyên văn; nút ▲▼ và kéo lên xuống; xoay gửi góc và tâm; scale đều và không đều (kích thước đích có đơn vị); báo lỗi đỏ; không có lỗi JavaScript. Đã chụp ảnh bố cục ở 440 px: gọn, các ô X/Y/Z xếp dọc, một dòng hướng dẫn.
- `tests/test_vgd_conventions.rb` (repo): tên extension, toolbar `VGD TRF`, mục menu "Tải lại code", chữ chuẩn khi tải lại.

## Chưa xác minh trong SketchUp thật

- **Đơn vị của file:** chỉ số `LengthUnit` (0 in, 1 ft, 2 mm, 3 cm, 4 m) và `model.options['UnitsOptions']['LengthUnit']` có đúng trong SketchUp thật không. Kiểm tra bằng cách đổi đơn vị file (Model Info → Units) rồi mở bảng.
- **Kích thước món:** `definition.bounds` và `BoundingBox#corner` cho đúng kích thước món thật (kể cả món lồng nhiều cấp, món có nhiều thành phần). Kiểm tra: đặt X của một tủ có kích thước đã biết thành một giá trị đích, rồi đo lại bằng công cụ Tape Measure.
- Xoay và scale thật: `Geom::Transformation.rotation(point, vector, angle)` và `Geom::Transformation.scaling(x, y, z)` cho kết quả giống ma trận giả lập (chiều xoay dương, scale theo trục thế giới).
- Biến đổi thật: đúng vị trí và hướng, Ctrl+Z hoàn tác đúng một bước, không ảnh hưởng món khác.
- Nhiều món thật: món đầu tiên trong lựa chọn có đúng là món được chọn trước không (thứ tự lấy từ `Selection`); cả nhóm giữ nguyên khoảng cách.
- Biến đổi trong group đang mở (nhấp đúp để mở group) và trong group lồng nhiều cấp, kể cả xoay và scale.
- Ô nhập số và nút ▲▼ trong HtmlDialog thật: giữ chuột để lặp, kéo lên xuống, Enter trong ô, dấu phẩy, dán số.
- Tải lại code khi cửa sổ đang mở.
- Icon trên thanh công cụ và các icon tab Dời / Xoay / Scale.
