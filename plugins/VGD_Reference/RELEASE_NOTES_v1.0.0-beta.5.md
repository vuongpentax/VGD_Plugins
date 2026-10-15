# VGD Reference 1.0.0-beta.5

## Sửa hiển thị ảnh

Đổi UV từ `Geom::Vector3d` sang mảng số `[u, v, 0.0]`. Phép thử trực tiếp của người dùng trên SketchUp **24.0.484**, Ruby **3.2.2**, bộ máy **graphics_engine_2024** cho kết quả:

| Cách vẽ | UV | Kết quả trên viewport |
| --- | --- | --- |
| GL_QUADS | Vector3d, z = 0 | Một màu phẳng |
| GL_QUADS | Mảng số, z = 0 | Đủ bốn màu ảnh gốc |
| GL_QUADS | Vector3d, z = 1 | Một màu phẳng |
| GL_QUADS | Mảng số, z = 1 | Đủ bốn màu ảnh gốc |
| GL_TRIANGLES | Vector3d, z = 0 | Một màu phẳng |
| GL_TRIANGLES | Mảng số, z = 0 | Đủ bốn màu ảnh gốc |
| GL_TRIANGLE_STRIP | Vector3d, z = 0 | Một màu phẳng |
| GL_QUADS, đảo thứ tự | Vector3d, z = 0 | Một màu phẳng |

Ảnh đã giải mã trong bộ nhớ có đầy đủ nội dung; texture ID hợp lệ; View của cache trùng View đang vẽ; UV ảnh đầu tiên là 0–1. Đổi Face Style sang Shaded with Textures vẫn không sửa lỗi. Thay dạng UV là thay đổi đã có bằng chứng trực tiếp.

## Sửa cập nhật viewport

Loại bỏ các lời gọi `View#valid?` trong cập nhật viewport, thoát công cụ và tắt overlay. `Sketchup::View` không có phương thức này trên phiên bản đã kiểm tra. Kiểm tra `Overlay#valid?` vẫn được giữ cho đối tượng overlay.

## Kiểm tra

- Biên dịch 19 file Ruby runtime và các script phát triển.
- Kiểm tra hồi quy ảnh đầy đủ và ảnh đã cắt: dạng UV, thứ tự góc ảnh và hướng V.
- Kiểm tra hồi quy redraw với View không có `valid?`.
- Kiểm tra store, z-order, chọn ảnh, zoom tại con trỏ, lia nội dung, cắt ảnh và cache texture.
- Phép thử native không làm thay đổi số entity hoặc trạng thái modified của model.
- Sau khi nạp bản sửa vào plugin đang chạy và bật hiện ảnh, người dùng xác nhận ảnh tham chiếu thật đã hiển thị đầy đủ.

`View#write_image` không chứa Ruby overlay trên máy đã thử; ảnh chụp viewport do người dùng cung cấp là bằng chứng hiển thị. Các phép kiểm tra về clipboard, DPI và các bản SketchUp khác vẫn theo `dev/MANUAL_VERIFICATION.md`.

## Cài đặt

Cài `VGD_Reference_v1.0.0-beta.5.rbz` bằng Extension Manager và khởi động lại SketchUp. Giao diện tiếng Việt được giữ nguyên.
