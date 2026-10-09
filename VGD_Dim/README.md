# VGD Dim · 3.3.0-beta.4

Tiếp tục từ **VGD_Dim_6.rbz (Claude 3.2.0)** theo yêu cầu 07/10/2026. Sidebar 6 mục và scope chung; giữ palette T+ / VGD, có theme sáng/tối. Đọc [UI_DESIGN.md](UI_DESIGN.md) cho cấu trúc bảng và [DEVELOPMENT_NOTES.md](DEVELOPMENT_NOTES.md) cho rà soát/giới hạn/checklist native.

- **Smart Dim**: chọn Group/Component tủ; đo ±X/±Y/±Z theo trục riêng của tủ, camera hoặc gần gốc; ngang/đứng, nối tiếp/tổng, offset và lọc theo mm. Hỗ trợ xoay Z tùy góc, mirror X/Y, scale theo trục. Chặn tủ nghiêng/shear/khối khác hệ trục. Dim native gom trong Group có metadata; chạy lại cùng tủ/mặt/Scene thay bộ cũ sau khi dựng thành công. Không xóa Group chỉ vì trùng tên; bộ V6 cũ không có metadata cần xóa thủ công một lần.
- **Mặt cắt / Scene**: ưu tiên một mặt cắt đang bật, song song trục tủ; Group/Tag `000_DIM_SECTION…` riêng. Dim bên trong Untagged; Group giữ Tag. Tùy chọn gắn Scene hiện tại cô lập riêng Tag này ở các Scene có lưu Tags, không ghi camera/style. Scene hiện tại chưa lưu Tags sẽ báo lỗi; bỏ tùy chọn để dùng Tag chung. Không có Scene thì bộ chưa gắn Scene.
- **Một chạm**: nút Smart Dim riêng trên toolbar/menu dùng options và style của lần đo thành công cuối. Cấu hình lưu JSON Base64 an toàn trên máy; không lưu khi validation hoặc tạo Dim thất bại.
- **Quét/Áp style**: Đang chọn (mặc định), Group đang mở, Toàn model. Bộ lọc nested/component/ẩn/khóa. Definition dùng chung sửa một lần và ảnh hưởng các bản sao; Make Unique nếu muốn sửa riêng.
- **Dimension**: màu tùy bật, endpoint, hướng chữ song song/theo màn hình, Above/Center/Outside. Dim thường vào 000 DIM; Dim Smart mới giữ Untagged để Group/Scene quản lý hiển thị.
- **Text/Label**: màu riêng, kiểu leader và endpoint Label. Đưa vào 000 TEXT.
- **Model Info**: mở bảng Dimensions/Text. **Làm mới size** tạo lại Dim tuyến tính với font/size/Height mặc định của Model Info và sao chép điểm đo, liên kết, text override, màu, tag, endpoint, vị trí chữ và attributes. Dim bán kính bỏ qua; lỗi sao chép giữ bản cũ. Persistent ID của Dim làm mới thay đổi.
- **APPLY mẫu Model Info**: cầu nối nút Update selected trên Windows English cho Dim/Text chọn trực tiếp; tách khỏi phạm vi quét và không ghi đè màu bằng form. Native font/Height/Undo chưa xác minh trực tiếp.
- **Preset/Auto-Style**: lưu cục bộ trên máy. Preset hệ thống không ghi đè/xóa. Auto-Style tắt mặc định, áp màu/endpoint/leader/tag cho annotation mới bằng observer trì hoãn; annotation mới dùng mẫu chữ Model Info. Không mang preset/Auto-Style theo SKP.
- **Animation**: ghi ShowTransition/TransitionTime/SlideTime/LoopSlideshow trong model. Không chạy slideshow và không có Undo.
- **Đơn vị model**: nút riêng “Áp đơn vị cho toàn model”, có readback/rollback; APPLY style và preset không ghi đơn vị. Tùy chọn mở chữ Dim dạng số mặc định tắt, giữ chữ có lời mô tả và bỏ nhóm khóa.

Các lệnh Dim không có popup hoàn tất; kết quả/lỗi của thao tác Dim nằm trong dòng trạng thái dialog. Updater hiển thị xác nhận và trạng thái cập nhật riêng. Thay font trong Model Info rồi lưu SKP để mẫu đi cùng file. APPLY style không tự đổi font; dùng Làm mới size hoặc APPLY mẫu Model Info.

## Mã nhập

Lịch sử files.zip 3.0: 5 file, thiếu 6 module đã được bổ sung; snapshot ở dev/claude_reference. Bản V6 mới có 15 file; snapshot và SHA256 ở dev/claude_v6_reference. Không nạp code tham khảo vào runtime. dev/build_ui.py xây HTML sidebar từ các control V6 đã rà soát; CSS/JS runtime chỉnh riêng. Không chạy builder cũ import_claude_ui.py để ghi đè giao diện mới.

## Cài / chạy

Gói tạo theo version trong runtime/VGD_Dim/version.rb; source ZIP cùng phiên bản. Extension/toolbar tên **VGD Dim**, loader vgd_dim.rb và namespace VGD::Dim tiếp tục dùng để tránh tạo plugin thứ hai. Cài bằng Extension Manager → Install Extension, rồi khởi động lại SketchUp để nhận toolbar mới.

dev/deploy.ps1 chỉ cài whitelist 27 file vào SU2022, sao lưu và kiểm tra SHA256. Trong app đang mở có thể dùng Extensions → Nạp lại VGD Dim/Text (menu cũ) hoặc Nạp lại VGD Dim (menu mới). Khởi động lại SketchUp để tên extension/toolbar cập nhật hoàn toàn.

Ruby Console:

```ruby
load File.join(Sketchup.find_support_file('Plugins'), 'VGD_Dim', 'reload.rb')
```

## Kiểm tra

check_ruby.cjs: cú pháp; scopes/filters/dedup; style/Units tách riêng; rebuild/metadata/failure; Smart yaw/mirror/scale/section/normals, ownership/replacement/Scene rollback, one-touch/persistence; preset/auto/animation và native bridge mô phỏng. test_store.rb: cấu hình SU2022/Unicode/kiểu JSON, khởi động khi dữ liệu hỏng. test_ui.cjs: 6 bảng, payload, keyboard, scope chung, busy, theme lưu lại, toàn bộ bảng ở 760/540/360px. test_deploy.py: whitelist 27 file/backup/cài lặp/guard/Cabinet; test_update_installer.ps1: cập nhật trong fixture, giữ file ngoài whitelist và bản sao cũ.

## Cập nhật online pilot

Bản 3.3.0-beta.4 sửa tùy chọn tạo process group trên Windows để helper cài đặt được khởi chạy. Updater kiểm tra manifest GitHub cho riêng VGD Dim; có thể kiểm tra thủ công ở Extensions → Kiểm tra cập nhật VGD Dim, hoặc tự động tối đa mỗi 24 giờ. Gói tải về được kiểm tra kích thước và SHA-256. Nếu người dùng đồng ý, helper chờ SketchUp đóng rồi thay file whitelist, lưu bản sao thư mục cũ và giữ file ngoài whitelist. Xem [HOW_TO_RELEASE.md](HOW_TO_RELEASE.md).

## Sửa lỗi khởi động 3.0.1-beta.1 — 05/10/2026

SketchUp 2022 có thể báo SyntaxError ngay trong read_default khi đọc chuỗi JSON chứa dấu nháy. Store chuyển sang key json2_* với JSON mã hóa Base64. Trên Windows, cấu hình Auto-Style, Smart Dim và preset cũ được khôi phục từ section VGDDim trong PrivatePreferences.json bằng JSON.parse, không eval hoặc sửa tệp cấu hình native. Không đọc cấu hình của plugin khác. Cấu hình lỗi dùng giá trị mặc định; Auto-Style mặc định tắt nên không chặn khởi động. Sau khi cập nhật, lưu bản vẽ, đóng tất cả cửa sổ SketchUp và mở lại.

Kết quả fixture không xác nhận font, liên kết hoặc Undo thực tế trong SketchUp. Xem outputs/VALIDATION.json. Các phần native vẫn beta cho đến khi kiểm chứng trong app.

Tài liệu chính thức: [DimensionLinear](https://ruby.sketchup.com/Sketchup/DimensionLinear.html), [Entities.add_dimension_linear](https://ruby.sketchup.com/Sketchup/Entities.html#add_dimension_linear-instance_method), [Entity.parent](https://ruby.sketchup.com/Sketchup/Entity.html#parent-instance_method), [Model Info fonts](https://help.sketchup.com/en/sketchup/adding-text-labels-and-dimensions-model).
