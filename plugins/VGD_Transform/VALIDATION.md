# Kiểm tra VGD Transform

Mọi kết quả dưới đây là **mô phỏng ngoài SketchUp**, trừ khi ghi khác.

## Bản 0.1.0-beta.4: đã kiểm tra tự động

Bản này đổi tên VGD Position thành VGD Transform; không đổi hành vi. Toàn bộ test chạy lại sau khi đổi tên.

- `dev/test_units.rb`: số có đơn vị (mm, cm, m, in, ft; có hoặc không khoảng trắng; không phân biệt hoa thường); số không đơn vị theo đơn vị của file; dấu phẩy; chữ, số mũ, đơn vị lạ bị từ chối; giới hạn ±1 km (cả khi gõ đơn vị); hiển thị số bỏ số 0 thừa; chỉ số đơn vị của SketchUp (0 in, 1 ft, 2 mm, 3 cm, 4 m) và chỉ số lạ.
- `dev/test_transform.rb`: tuyệt đối một món (giữ trục trống, đã đúng vị trí); tuyệt đối nhiều món (độ lệch tính từ món đầu tiên); tương đối; chặn món khóa và món không đo được vị trí; báo lỗi khi không nhập gì hoặc chưa chọn món. Xoay: quanh Z tâm gốc thế giới (1000,0,0 → 0,1000,0), quanh điểm gốc món (đứng yên), quanh tâm cả lựa chọn (hai món đổi chỗ), thứ tự X-Y-Z, góc trống / vượt giới hạn, tâm không hợp lệ. Scale: đều quanh gốc thế giới, quanh điểm gốc món (đứng yên), không đều quanh gốc, quanh tâm cả lựa chọn, hệ số 0 / âm / 1 / quá lớn bị từ chối. Ghép công cụ (`Plan.build`) và mô tả xem trước (`Plan.describe`) theo đơn vị của file.
- `dev/test_move.rb` (SketchUp giả lập, biến đổi bằng ma trận 4×4 độc lập với công thức trong code): đọc vị trí món ở gốc và trong group cha; dời ở gốc; dời trong group cha (độ dời tính trong hệ thế giới); nhiều món cùng độ dời trong một thao tác; xoay 90° quanh Z; xoay hai món 180° quanh tâm cả lựa chọn; scale đều ×2; scale không đều trong group cha; món khóa và group cha khóa; một thao tác hoàn tác; hủy cả thao tác khi vị trí sau biến đổi không khớp; đơn vị đọc từ model.
- `dev/test_reload.rb`: menu đúng hai mục; tải lại 3 lần không nhân đôi mục; đang bận thì không nạp lại và báo đúng; lỗi cú pháp giữ nguyên bản đang chạy.
- `dev/test_ui.cjs` (Playwright, 35 kiểm tra): ba tab và chỗ hiện tâm xoay; khung Dời tuyệt đối / tương đối; nút Áp dụng chỉ bật sau xem trước và tắt lại khi đổi ô hoặc tâm xoay; ô nhập có đơn vị gửi nguyên văn; nút ▲▼ tăng/giảm một bước và giữ đơn vị đã gõ; kéo lên xuống trên ô đổi giá trị theo số bước; xoay gửi góc và tâm; scale đều và không đều gửi đúng ô; báo lỗi đỏ; không có lỗi JavaScript. Đã chụp ảnh bố cục ở 440 px: hai khung cạnh nhau, ô số có nút, nút không xuống dòng.
- `tests/test_vgd_conventions.rb` (repo): tên extension, toolbar `VGD TRF`, mục menu "Tải lại code", chữ chuẩn khi tải lại.

## Chưa xác minh trong SketchUp thật

- Mở cửa sổ, danh sách món cập nhật khi đổi lựa chọn (observer thật).
- **Đơn vị của file:** chỉ số `LengthUnit` (0 in, 1 ft, 2 mm, 3 cm, 4 m) và `model.options['UnitsOptions']['LengthUnit']` có đúng trong SketchUp thật không. Kiểm tra bằng cách đổi đơn vị file (Model Info → Units) rồi mở bảng.
- Xoay và scale thật: `Geom::Transformation.rotation(point, vector, angle)` và `Geom::Transformation.scaling(x, y, z)` cho kết quả giống ma trận giả lập (chiều xoay dương, scale theo trục thế giới).
- Dời / xoay / scale món thật: đúng vị trí và hướng, Ctrl+Z hoàn tác đúng một bước, không ảnh hưởng món khác.
- Nhiều món thật: món đầu tiên trong danh sách có đúng là món được chọn trước không (thứ tự lấy từ `Selection`); cả nhóm giữ nguyên khoảng cách.
- Biến đổi món trong group đang mở (nhấp đúp để mở group) và trong group lồng nhiều cấp, kể cả xoay và scale.
- Ô nhập số và nút ▲▼ trong HtmlDialog thật: giữ chuột để lặp, kéo lên xuống, dấu phẩy, dán số.
- Tải lại code khi cửa sổ đang mở.
- Icon trên thanh công cụ và các icon tab Dời / Xoay / Scale.
