# VGD Dim · 3.3.0-beta.8

Baseline source 3.3.0-beta.8: có RBZ beta.8 trong workspace nguồn, 29 mục runtime đã đối chiếu (version.rb chỉ khác kiểu xuống dòng). Không kèm artifact ở repo đích. Đợt chuyển repository chỉ đối chiếu source/checksum; chưa chạy lại test tự động hoặc kiểm thử native SketchUp. Các kết quả PASS bên dưới thuộc lịch sử workspace nguồn.

Tiếp tục từ **VGD_Dim_6.rbz (Claude 3.2.0)** theo yêu cầu 07/10/2026. Sidebar 6 mục và scope chung; giữ palette T+ / VGD, có theme sáng/tối. Đọc [DEVELOPMENT_NOTES.md](DEVELOPMENT_NOTES.md) cho rà soát/giới hạn/checklist native.

- **Dim thủ công và vùng**: tạo Dimension native bằng cách chọn hai điểm rồi chọn phía đặt đường dim. Đặt Boundary bằng hai góc đối diện; Smart Dim chỉ đo chi tiết nằm hoàn toàn trong vùng đang hoạt động. Tạo Detail Region có tên bên trong Boundary để giới hạn đo vào chi tiết nhỏ. Vùng được lưu trong model và có thể chọn/xóa từ giao diện.
- **Smart Dim**: chọn Group/Component tủ; đo ±X/±Y/±Z theo trục riêng của tủ, camera hoặc gần gốc; ngang/đứng, nối tiếp/tổng, offset và lọc theo mm. Hỗ trợ xoay Z tùy góc, mirror X/Y, scale theo trục. Chặn tủ nghiêng/shear/khối khác hệ trục. Dim native gom trong Group có metadata; chạy lại cùng tủ/mặt/Scene thay bộ cũ sau khi dựng thành công. Không xóa Group chỉ vì trùng tên; bộ V6 cũ không có metadata cần xóa thủ công một lần.
- **Mặt cắt / Scene**: ưu tiên một mặt cắt đang bật, song song trục tủ; Group/Tag `000_DIM_SEC_<tên mặt cắt>` riêng (ví dụ `000_DIM_SEC_A-A`); mặt thường dùng `000_DIM_<tên view>` (`000_DIM_TOP`, `000_DIM_FRONT`…). Dim bên trong Untagged; Group giữ Tag. Tùy chọn gắn Scene hiện tại cô lập riêng Tag này ở các Scene có lưu Tags, không ghi camera/style. Scene hiện tại chưa lưu Tags sẽ báo lỗi; bỏ tùy chọn để dùng Tag chung. Không có Scene thì bộ chưa gắn Scene.
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

Lịch sử files.zip 3.0 và các snapshot runtime V6 được giữ ở repo nguồn cũ. Bản chuyển này chỉ giữ dev/claude_v6_reference/VGD_Dim/dialog.html vì dev/build_ui.py còn đọc trực tiếp HTML này. Không nạp reference vào runtime; CSS/JS runtime được giữ nguyên.

## Cài / chạy

Gói tạo theo version trong runtime/VGD_Dim/version.rb; source ZIP cùng phiên bản. Extension/toolbar tên **VGD Dim**, loader vgd_dim.rb và namespace VGD::Dim tiếp tục dùng để tránh tạo plugin thứ hai. Cài bằng Extension Manager → Install Extension, rồi khởi động lại SketchUp để nhận toolbar mới.

dev/deploy.ps1 chỉ cài whitelist 29 file vào SU2022, sao lưu và kiểm tra SHA256. Trong app đang mở có thể dùng Extensions → Nạp lại VGD Dim/Text (menu cũ) hoặc Nạp lại VGD Dim (menu mới). Khởi động lại SketchUp để tên extension/toolbar cập nhật hoàn toàn.

Ruby Console:

```ruby
load File.join(Sketchup.find_support_file('Plugins'), 'VGD_Dim', 'reload.rb')
```

## Kiểm tra

check_ruby.cjs: cú pháp; scopes/filters/dedup; style/Units tách riêng; rebuild/metadata/failure; Smart yaw/mirror/scale/section/normals, ownership/replacement/Scene rollback, one-touch/persistence; preset/auto/animation và native bridge mô phỏng. test_store.rb: cấu hình SU2022/Unicode/kiểu JSON, khởi động khi dữ liệu hỏng. test_ui.cjs: 6 bảng, callback vùng và Dim thủ công, payload, keyboard, scope chung, busy, theme lưu lại, toàn bộ bảng ở 760/740/540/360px. test_deploy.py: whitelist 29 file/backup/cài lặp/guard/Cabinet; test_update_installer.ps1: cập nhật trong fixture, giữ file ngoài whitelist và bản sao cũ.

## Thay đổi 3.3.0-beta.8

Thanh điều hướng hiển thị icon, tên và mô tả khi panel rộng; ở 740 px trở xuống chỉ hiện icon và giữ tooltip. Phạm vi áp dụng chuyển vào vùng nội dung ở chế độ hẹp. Nhấn Esc hoặc hủy Dim thủ công luôn mở khóa lại giao diện; hot-reload nạp cả module Boundary và Dim thủ công.

## Cập nhật online pilot

Bản beta.6 thêm Dim thủ công và quản lý vùng đo. Người dùng beta.5 cài beta.6 một lần qua VGD Center hoặc Extension Manager; các bản sau có thể tải từ package của Center bằng updater. Updater xác minh kích thước và SHA-256; nếu người dùng đồng ý, helper chờ SketchUp đóng rồi thay file whitelist, lưu bản sao thư mục cũ và giữ file ngoài whitelist. Xem [HOW_TO_RELEASE.md](HOW_TO_RELEASE.md).

## Sửa lỗi khởi động 3.0.1-beta.1 — 05/10/2026

SketchUp 2022 có thể báo SyntaxError ngay trong read_default khi đọc chuỗi JSON chứa dấu nháy. Store chuyển sang key json2_* với JSON mã hóa Base64. Trên Windows, cấu hình Auto-Style, Smart Dim và preset cũ được khôi phục từ section VGDDim trong PrivatePreferences.json bằng JSON.parse, không eval hoặc sửa tệp cấu hình native. Không đọc cấu hình của plugin khác. Cấu hình lỗi dùng giá trị mặc định; Auto-Style mặc định tắt nên không chặn khởi động. Sau khi cập nhật, lưu bản vẽ, đóng tất cả cửa sổ SketchUp và mở lại.

Kết quả fixture không xác nhận font, liên kết hoặc Undo thực tế trong SketchUp. Kết quả fixture trước đây nằm trong outputs/VALIDATION.json của workspace nguồn, không được chuyển vào repo này. Các phần native vẫn beta cho đến khi kiểm chứng trong app.

Tài liệu chính thức: [DimensionLinear](https://ruby.sketchup.com/Sketchup/DimensionLinear.html), [Entities.add_dimension_linear](https://ruby.sketchup.com/Sketchup/Entities.html#add_dimension_linear-instance_method), [Entity.parent](https://ruby.sketchup.com/Sketchup/Entity.html#parent-instance_method), [Model Info fonts](https://help.sketchup.com/en/sketchup/adding-text-labels-and-dimensions-model).
