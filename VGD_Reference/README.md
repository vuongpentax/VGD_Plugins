# VGD Reference

`VGD Reference` là tiện ích SketchUp để ghim ảnh JPG và PNG phía trên khung nhìn mô hình. Ảnh nằm trong lớp phủ theo màn hình và chỉ được giữ trong bộ nhớ của phiên SketchUp hiện tại; tiện ích không tạo entity và không ghi dữ liệu ảnh tham chiếu vào file `.skp`.

## Tính năng

- SketchUp 2023 trở lên trên Windows 10/11.
- Lớp phủ theo màn hình, có thể bật/tắt trong bảng **Overlays** của SketchUp.
- Thêm ảnh JPG, JPEG, PNG hoặc dán ảnh từ bộ nhớ tạm Windows.
- Quản lý nhiều ảnh bằng hình thu nhỏ; có chức năng ẩn/hiện, khóa và xóa.
- Bảng quản lý tiếng Việt với theme sáng/tối và icon ảnh ghim đồng bộ bộ icon VGD.
- Di chuyển, đổi kích thước giữ tỷ lệ, phóng to tại vị trí con trỏ, giữ Space và kéo để lia nội dung, khôi phục thu phóng, cắt ảnh và chỉnh mức hiển thị.
- Kéo thả ảnh từ File Explorer vào bảng quản lý (tối đa 20 MiB mỗi ảnh).
- Texture được lưu đệm và giải phóng khi xóa ảnh, đổi model, tắt lớp phủ hoặc thoát SketchUp.
- Tọa độ màn hình được chuyển đổi qua một bộ xử lý chung cho SketchUp 2023/2024 và 2025 trở lên.

## Cài đặt

Trong SketchUp, mở **Extension Manager → Install Extension** và chọn file `VGD_Reference_v1.0.0-beta.6.rbz`. Khởi động lại SketchUp sau khi cài. Mở **Extensions → VGD Reference → Mở bảng quản lý** hoặc nhấn nút **VGD Reference** trên thanh công cụ.

## Cách hoạt động

Ảnh chỉ tồn tại tạm thời trong phiên SketchUp. Đóng hoặc chuyển model sẽ xóa danh sách ảnh tham chiếu. Đóng bảng quản lý không làm ẩn ảnh. Có thể bật hoặc tắt lớp phủ trong bảng Overlays. Ảnh đã khóa ở trạng thái thụ động; chọn ảnh trong bảng quản lý để chỉnh sửa lại.

## Đóng gói

Chạy `node VGD_Reference/dev/package.cjs` từ thư mục workspace để tạo file RBZ, source ZIP và mã SHA-256 riêng cho mỗi archive. Script tạo lại icon/manifest, đối chiếu phiên bản và kiểm tra từng file giải nén trùng byte với nguồn. Gói cài đặt chỉ chứa bộ nạp và các file runtime của VGD Reference.

## Icon và theme

Beta.6 dùng SVG ảnh có ghim, nền trong suốt, nét 1,8 px. Nét chính sáng `#292B2D`, tối `#F1EDE6`; điểm nhấn cùng `#A67C58`. Bảng quản lý tự đổi theme theo hệ thống; toolbar SketchUp 2024 mặc định dùng icon sáng. Nhấn **Chọn màu icon thanh công cụ** ở header để chọn icon cho nền sáng/tối; lựa chọn được lưu và áp dụng cho toolbar. [Bản xem trước](dev/icon_preview.html) hiển thị cùng SVG runtime trên nền sáng/tối ở 16/24/32 px. Quy tắc chọn icon native và cách tạo lại nằm trong [tài liệu icon](dev/ICON_DESIGN.md).

## Trạng thái kiểm tra

Phép thử trực tiếp trên SketchUp 24.0.484 với bộ máy đồ họa mới đã xác nhận UV dạng mảng hiển thị đủ nội dung ảnh, trong khi UV dạng `Geom::Vector3d` chỉ hiện màu phẳng. Beta.5 dùng UV dạng mảng và sửa các lệnh cập nhật viewport gọi nhầm `View#valid?`. Người dùng đã xác nhận ảnh tham chiếu thật hiển thị đầy đủ sau khi nạp bản sửa. Kiểm tra Ruby và kiểm tra hồi quy cho UV ảnh đầy đủ, UV ảnh đã cắt, cập nhật viewport và các thao tác trong bộ nhớ đều đạt.

Cần kiểm tra tiếp độ trong suốt, bộ nhớ tạm, kéo thả, DPI và các bản SketchUp khác theo danh sách trong `dev/MANUAL_VERIFICATION.md`. Tính năng di chuyển bằng chuột phải đang tắt cho đến khi kiểm tra đạt và không gây xung đột menu ngữ cảnh.

SVG và bảng quản lý beta.6 đã được xem ảnh render và kiểm tra tự động bằng Edge ở cả hai theme, gồm setting icon toolbar, mọi callback nút và kích thước tối thiểu 280×340. Ruby kiểm tra 21 file runtime, đường dẫn icon và các fixture hồi quy đều đạt. Chưa kiểm tra icon/theme beta.6 trực tiếp trong SketchUp; xác nhận native ở trên áp dụng cho bản sửa hiển thị ảnh beta.5.

## SketchUp 2022

**Beta.6 chưa hỗ trợ SketchUp 2022; minimum vẫn là SketchUp 2023.** Overlay chỉ có từ SU2023. SU2022 giới hạn texture theo vòng đời Ruby Tool, nên fallback Tool chưa giữ được ảnh thụ động khi dùng các công cụ dựng hình như bản Overlay. Bộ nạp và runtime kiểm tra phiên bản/capability trước khi nạp lớp Overlay. Chi tiết và probe phát triển độc lập nằm trong [đánh giá SU2022](dev/SU2022_COMPATIBILITY.md).

## Chẩn đoán hiển thị

`dev/diagnose_rendering.rb` vẽ tám ô thử trong SketchUp và ghi báo cáo vào `outputs/render-diagnostics/`. Báo cáo kiểm tra dữ liệu ảnh đã giải mã, texture ID, View, UV, phiên bản và bộ máy đồ họa. Trên máy đã kiểm tra, `View#write_image` không chứa Ruby overlay; kết quả ảnh xuất được đánh dấu chưa đủ để kết luận và cần đối chiếu ảnh chụp màn hình.

`dev/apply_render_fix.rb` nạp bản sửa UV beta.5 vào phiên SketchUp đang chạy để kiểm tra, giữ danh sách ảnh hiện tại và gỡ các ô thử. Để dùng bản sửa cùng icon/giao diện mới sau khi khởi động lại, cài gói beta.6.
