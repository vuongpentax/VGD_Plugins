# VGD DC Exporter 1.0.1

Công cụ chỉ đọc: xuất thuộc tính, công thức DC và cấu trúc component đang chọn thành file JSON để gửi cho VGD đối chiếu.
Viết lại từ tplus_dc_exporter để sửa lỗi đệ quy dictionary, tách tham số DC thành nhóm riêng và giữ giá trị mặc định/giá trị instance tách bạch.

## Cài và dùng
1. Extensions > Extension Manager > Install Extension: chọn `VGD_DC_Exporter_1.0.1.rbz`.
2. Chọn component hoặc group tủ (có thể nhiều mẫu cùng lúc).
3. Extensions > VGD DC Exporter — Xuất JSON đối tượng đang chọn. Chọn nơi lưu file.
4. Gửi file JSON lại trong cuộc trò chuyện, kèm ảnh tổng thể tủ nếu có.

## Nội dung JSON (schema `vgd.dc_snapshot`, version 2)
- `roots`: các đối tượng đã chọn. Mỗi đối tượng có `dc_parameters` (giá trị hiệu lực, giá trị instance, giá trị mặc định, công thức, nhãn, đơn vị, quyền truy cập), `dc_formulas`, `transformation_to_parent`, `bounds_parent_mm`, tag, vật liệu gán trực tiếp, trạng thái ẩn/khóa, và `attribute_dictionaries`.
- `definitions`: định nghĩa, xuất một lần dù có nhiều instance dùng chung. Có `children` lồng nhau và `other_entities_with_attributes`.
- `units`, `warnings`, `summary`.

## Giới hạn
- Chỉ đọc: không sửa thuộc tính, không redraw DC, không explode, không lưu SKP, không gửi mạng.
- Xuất trạng thái và công thức đang lưu, không tính lại kết quả khi đổi tham số.
- Không có lưới hình học hay ảnh texture.
- Giá trị độ dài DC lưu theo inch nội bộ SketchUp; `value_mm` chỉ có khi đơn vị của tham số là độ dài.
- Đã kiểm tra bằng Ruby (`test/test_exporter.rb`) với đối tượng giả lập. Chưa chạy trong SketchUp.

## Kiểm thử
`ruby test/test_exporter.rb` (16 kiểm tra).
