# Kiểm tra VGD Transform

Mọi kết quả dưới đây là **mô phỏng ngoài SketchUp**, trừ khi ghi khác.

## Bản 0.1.0-beta.7: đã kiểm tra tự động

- Bản này: icon Dời / Xoay / Scale (thanh công cụ ba nút, icon trong cửa sổ), bỏ nút Áp dụng, cửa sổ gọn 320 × 230. `dev/test_reload.rb` kiểm tra thanh công cụ có đúng ba nút, icon là file có thật, tải lại không thêm thanh công cụ. `dev/test_ui.cjs` (42) kiểm tra icon công cụ, Ruby chọn sẵn công cụ, không còn nút Áp dụng, dòng trạng thái ngắn, ô Đều. Đã chụp ảnh cửa sổ ở 320 × 230 (ba công cụ, theme sáng và tối: không tràn, không thanh cuộn) và icon ở 16 / 24 / 32 px trên nền thanh công cụ sáng.

Các mục còn lại giữ như bản beta.6:

- `dev/test_units.rb` (21): số có đơn vị (mm, cm, m, in, ft, yd), số theo đơn vị file, dấu phẩy, sai định dạng, giới hạn ±1 km; chỉ số đơn vị SketchUp 0–5 và chỉ số lạ (nil); ô scale (hệ số / kích thước đích, đích 0 hoặc âm bị từ chối).
- `dev/test_transform.rb` (42): tâm hộp bao hình (không phải tâm các điểm gốc); tâm theo chế độ; giá trị chung; chặn món khóa / không đo được / lựa chọn rỗng; dời tuyệt đối theo tâm điểm gốc (thẳng hàng) và tâm cả lựa chọn; dời tương đối World và Local (món xoay 90°); xoay quanh các tâm, local, thứ tự X-Y-Z; scale đều / không đều / local / kích thước đích (world đo hộp bao, local đo trục riêng) / riêng từng món; scale tuyệt đối theo tỉ lệ hiện tại và trục riêng; `NothingToDo` cho trường hợp không có gì để làm; ghép công cụ với ô nhập (tâm, hệ trục, giá trị sai).
- `dev/test_model_ops.rb` (22, SketchUp giả lập, ma trận 4×4 độc lập với công thức trong code): đọc điểm gốc, trục riêng, tỉ lệ, hộp bao, kích thước; đếm cạnh / mặt bị bỏ qua; đơn vị yd và đơn vị lạ; dời ở gốc và trong group cha; xoay ba trục đặt biến đổi đúng **một** lần; xoay quanh tâm hộp bao; scale đến kích thước đích; scale local trên món đã xoay; scale tuyệt đối về 1; món khóa lúc áp dụng; SketchUp không đổi được vị trí → hủy; SketchUp bỏ mất phần xoay (điểm gốc vẫn đúng) → kiểm tra ma trận bắt được, hủy; kéo trực tiếp tính lại từ trạng thái đầu, gộp bước (transparent), kéo về 0 thì trở lại vị trí đầu.
- `dev/test_reload.rb`: menu đúng hai mục; tải lại 3 lần không nhân đôi; đang bận thì không nạp lại; lỗi cú pháp giữ nguyên bản đang chạy.
- `dev/test_ui.cjs` (Playwright): dòng trạng thái (số món, đơn vị, bỏ qua, đơn vị lạ); ô Tuyệt đối hiện giá trị theo tâm, "khác nhau", chỉ gửi ô đã sửa, cập nhật sau khi áp dụng; ô Tương đối về 0 sau Enter và sau khi kéo; hệ trục trong tiêu đề và lệnh gửi; ▲▼ (bước theo đơn vị file, Ctrl ×10, Alt ×0,1, giữ đơn vị đã gõ, kéo trên nút, kéo trên ô chữ không đổi, chuột phải về mặc định); xem trực tiếp bật / tắt (live_start, live, live_end); ô "khác nhau" không cho kéo; xoay, scale tuyệt đối / tương đối; thông báo thường và lỗi; không lỗi JavaScript. Đã chụp ảnh tab Dời và Scale ở 440 px.
- `tests/test_vgd_conventions.rb` (repo): tên extension, toolbar `VGD TRF`, mục "Tải lại code", chữ chuẩn khi tải lại.
- Quét cú pháp code chạy thật: không có cú pháp chỉ có từ Ruby 3 (SketchUp 2022 dùng Ruby 2.7). Chưa chạy bằng Ruby 2.7 thật.

## Chưa xác minh trong SketchUp thật

- **Kéo trực tiếp:** món chạy mượt khi kéo ▲▼; cả lần kéo là một bước Ctrl+Z (`start_operation` với `transparent`); tốc độ khi chọn nhiều món.
- **Ô Tuyệt đối tự cập nhật:** sau Ctrl+Z, sau khi dùng công cụ Move của SketchUp (`ModelObserver#onTransactionCommit/Undo/Redo`); không làm chậm SketchUp khi vẽ.
- **Đọc ma trận:** `Transformation#to_a` theo cột (trục X ở 0..2, gốc ở 12..14); trục riêng và tỉ lệ đọc đúng với món đã xoay / scale / lồng nhiều cấp.
- **Đơn vị:** chỉ số `LengthUnit` 0–5 (đặc biệt yd) trong SketchUp thật.
- **Xoay / scale thật:** `Geom::Transformation.rotation`, `.scaling(x, y, z)`, `.axes(origin, x, y, z)` cho kết quả giống ma trận giả lập.
- **Hệ trục riêng:** dời / xoay / scale theo trục của món đã xoay; món bị méo.
- **Spinner trong HtmlDialog thật:** kéo trên ▲▼ (pointer capture), Ctrl / Alt khi kéo, chuột phải không bật menu của trình duyệt.
- Biến đổi trong group đang mở và lồng nhiều cấp; Ctrl+Z đúng một bước; không ảnh hưởng món khác.
- Tải lại code khi cửa sổ đang mở và khi đang kéo (phải bị chặn).
- Icon trên thanh công cụ thật (SVG, cả cỡ nhỏ và lớn), bấm từng nút mở đúng công cụ.
- Cửa sổ 320 × 230 trong SketchUp thật trên màn FHD 24" (cỡ HtmlDialog có tính thanh tiêu đề hay không, chữ có rõ không).
