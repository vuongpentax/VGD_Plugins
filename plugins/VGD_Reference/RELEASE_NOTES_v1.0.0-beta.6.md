# VGD Reference 1.0.0-beta.6

## Icon VGD và giao diện

- Thay icon nền vuông bằng ảnh được ghim, SVG nền trong suốt `viewBox 0 0 24 24`.
- Nét 1,8 px, đầu nét/góc nối bo tròn; viền ảnh bo nhẹ; cùng path cho theme sáng/tối.
- Nét chính `#292B2D` trên nền sáng và `#F1EDE6` trên nền tối; ghim giữ `#A67C58` ở cả hai theme, theo quy chuẩn icon VGD.
- Thêm SVG tối và `icon_manifest.json`; header bảng quản lý sử dụng cùng glyph với toolbar.
- Bảng quản lý đổi nền, chữ và các trạng thái theo `prefers-color-scheme`. Giữ tiếng Việt, vị trí và callback của các thao tác hiện có.
- Thay ký tự ẩn/hiện, khóa và xóa bằng SVG nét đồng nhất; các nút luôn hiện rõ.

Toolbar SketchUp 2024 mặc định sử dụng icon sáng. Nút **Chọn màu icon thanh công cụ** ở header mở setting **Nền sáng · nét than / Nền tối · nét trắng ngà**. Lựa chọn lưu trong `VGD.Reference / ToolbarTheme`, cập nhật small/large icon của Command hiện có và khôi phục lúc khởi động. Manager vẫn theo theme hệ thống; không suy đoán nền toolbar native từ HtmlDialog. Chi tiết trong `dev/ICON_DESIGN.md`.

## Hiển thị ảnh

Giữ bản sửa beta.5: UV dạng mảng số với hướng V chính xác và cập nhật viewport bằng API hợp lệ. Người dùng đã xác nhận ảnh tham chiếu thật hiển thị đầy đủ trên SketchUp 24.0.484. Bản beta.6 không thay đổi thuật toán vẽ ảnh, công cụ chỉnh sửa hay dữ liệu phiên.

## Kiểm tra

- SVG: hai theme có cùng path; đúng palette, viewBox, stroke, round caps/joins; nền trong suốt và ghim hiển thị ở 16/24/32 px.
- Xem ảnh render gallery, toolbar mẫu và hàng kích thước ở nền sáng/tối. Nét chính có tương phản 9,87:1 và 12,18:1 trên nền toolbar mẫu.
- Manager: theme sáng/tối, glyph runtime ở header, nhãn tiếng Việt, trạng thái rỗng, mọi callback nút, thanh mức hiển thị và bố cục 280×340 đều đạt trong Edge headless.
- Biên dịch 21 file Ruby runtime và script phát triển; kiểm tra setting icon lưu preference/cập nhật Command, store, cache, zoom, crop, redraw và UV đều đạt. Kiểm tra capability guard không chấp nhận SU2022.
- Icon/theme beta.6 chưa được xác nhận trực tiếp trong toolbar/HtmlDialog của SketchUp; các phép thử GUI ở trên chạy bằng Edge headless. Checklist native nằm trong `dev/MANUAL_VERIFICATION.md`.

## Đóng gói

**Minimum vẫn là SketchUp 2023; SU2022 chưa được hỗ trợ.** SU2022 không có Overlay và sẽ giải phóng texture khi Ruby Tool cuối cùng rời tool stack. Probe Tool độc lập trong source phục vụ phát triển tiếp; chưa được xác minh native hay đưa vào runtime. Máy có thư mục cài SketchUp 2022 nhưng chưa chạy kiểm tra trong ứng dụng. Cú pháp/fixture được kiểm tra bằng Ruby 3.2 WASM, không phải Ruby 2.7 của SU2022. Xem `dev/SU2022_COMPATIBILITY.md`.

`dev/package.cjs` tạo lại SVG/manifest, đối chiếu phiên bản và so sánh từng file giải nén với nguồn. RBZ chứa runtime; source ZIP chứa runtime, script phát triển và tài liệu. Cả hai archive có mã SHA-256 riêng.

Cài `VGD_Reference_v1.0.0-beta.6.rbz` bằng **Extension Manager → Install Extension**, rồi khởi động lại SketchUp.
