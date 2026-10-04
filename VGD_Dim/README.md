# VGD Dim · 3.0.0-beta.1

Gộp bộ Dim/Info trong files.zip vào VGD ANOT và đổi tên thành **VGD Dim**. Theo yêu cầu ngày 2026-10-05, bản này có đầy đủ chức năng trong giao diện Claude, giữ palette T+ sáng/nâu đồng.

- **Smart Dim**: chọn Group/Component tủ; tạo Dim ngang/đứng, dim nối tiếp và tổng trên mặt -X/+X/-Y/+Y, theo camera hoặc gần trục. Offset và bộ lọc dùng mm. Tạo trong context đang mở, tag 000 DIM, một operation. Hộp bao được tính tại thời điểm chạy; bấm lại tạo thêm bộ Dim. Dim không tự liên kết vào hình học của tủ. Hình xoay nghiêng được chiếu theo các trục mặt đứng này.
- **Quét/Áp style**: Đang chọn (mặc định), Group đang mở, Toàn model. Bộ lọc nested/component/ẩn/khóa. Definition dùng chung sửa một lần và ảnh hưởng các bản sao; Make Unique nếu muốn sửa riêng.
- **Dimension**: màu tùy bật, endpoint, hướng chữ song song/theo màn hình, Above/Center/Outside. Đưa vào 000 DIM.
- **Text/Label**: màu riêng, kiểu leader và endpoint Label. Đưa vào 000 TEXT.
- **Model Info**: mở bảng Dimensions/Text. **Làm mới size** tạo lại Dim tuyến tính với font/size/Height mặc định của Model Info và sao chép điểm đo, liên kết, text override, màu, tag, endpoint, vị trí chữ và attributes. Dim bán kính bỏ qua; lỗi sao chép giữ bản cũ. Persistent ID của Dim làm mới thay đổi.
- **APPLY mẫu Model Info**: cầu nối nút Update selected trên Windows English cho Dim/Text chọn trực tiếp; tách khỏi phạm vi quét và không ghi đè màu bằng form. Native font/Height/Undo chưa xác minh trực tiếp.
- **Preset/Auto-Style**: lưu cục bộ trên máy. Preset hệ thống không ghi đè/xóa. Auto-Style tắt mặc định, áp màu/endpoint/leader/tag cho annotation mới bằng observer trì hoãn; annotation mới dùng mẫu chữ Model Info. Không mang preset/Auto-Style theo SKP.
- **Animation**: ghi ShowTransition/TransitionTime/SlideTime/LoopSlideshow trong model. Không chạy slideshow và không có Undo.
- **Đơn vị model**: chỉ ghi khi bật ô Áp dụng; ảnh hưởng toàn model.

Không có popup hoàn tất; kết quả/lỗi trong dòng trạng thái của dialog. Thay font trong Model Info rồi lưu SKP để mẫu đi cùng file. APPLY style không tự đổi font; dùng Làm mới size hoặc APPLY mẫu Model Info.

## Mã nhập

ZIP có 5 file; thiếu 6 dependencies: store, core, presets, autostyle, animation, probe. Các module thiếu đã được bổ sung; không phải bản nguyên vẹn đã chạy của Claude. Bản gốc và SHA256 lưu ở dev/claude_reference (chỉ tham khảo, không nạp runtime). HTML/JS/CSS xây từ giao diện gốc bằng dev/import_claude_ui.py; Smart Dim sửa để bỏ hidden/locked/tag tắt, kiểm tra dữ liệu, xử lý transform và dùng core mới.

## Cài / chạy

Gói outputs/VGD_Dim_v3.0.0-beta.1.rbz; source ZIP cùng phiên bản. Extension/toolbar tên **VGD Dim**, loader vgd_dim.rb và namespace VGD::Dim tiếp tục dùng để tránh tạo plugin thứ hai.

dev/deploy.ps1 chỉ cài whitelist 18 file vào SU2022, sao lưu và kiểm tra SHA256. Trong app đang mở có thể dùng Extensions → Nạp lại VGD Dim/Text (menu cũ) hoặc Nạp lại VGD Dim (menu mới). Khởi động lại SketchUp để tên extension/toolbar cập nhật hoàn toàn.

Ruby Console:

```ruby
load File.join(Sketchup.find_support_file('Plugins'), 'VGD_Dim', 'reload.rb')
```

## Kiểm tra

check_ruby.cjs: cú pháp; scopes/filters/dedup, style/units, mô phỏng rebuild/metadata/failure, Smart Dim chain/tổng/transform, preset/auto/animation, callbacks và cầu nối native. test_ui.cjs: các chức năng UI, payload, mặc định selection, lỗi inline/no popup và footer ở 540/360px. test_deploy.py: whitelist/backup/cài lặp/guard/Cabinet.

Kết quả fixture không xác nhận font, liên kết hoặc Undo thực tế trong SketchUp. Xem outputs/VALIDATION.json. Các phần native vẫn beta cho đến khi kiểm chứng trong app.

Tài liệu chính thức: [DimensionLinear](https://ruby.sketchup.com/Sketchup/DimensionLinear.html), [Entities.add_dimension_linear](https://ruby.sketchup.com/Sketchup/Entities.html#add_dimension_linear-instance_method), [Entity.parent](https://ruby.sketchup.com/Sketchup/Entity.html#parent-instance_method), [Model Info fonts](https://help.sketchup.com/en/sketchup/adding-text-labels-and-dimensions-model).
