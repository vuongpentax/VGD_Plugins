# VGD Reference — icon và theme

Phiên bản: `1.0.0-beta.6`.

## Hình tượng

Một ảnh phong cảnh được ghim phía trên khung nhìn. Viền ảnh là hình vật thể, không có nền hay khung trang trí. Mép trên mở để chừa khoảng cho ghim; nét viền, phong cảnh và ghim không có đoạn trùng nhau. Các góc viền ảnh bo nhẹ 1,2 đơn vị.

- SVG `viewBox="0 0 24 24"`; nét `1.8`, đầu nét và góc nối `round`.
- Cùng ba path ở mọi kích thước và cả hai theme.
- Nền trong suốt; ghim dùng `#A67C58` ở cả hai theme.
- Nét chính sáng `#292B2D`; tối `#F1EDE6`.

Đồng bộ theo `shared/VGD_ICON_SYSTEM_RULES.md` và bản mẫu `shared/VGD_ICON_SYSTEM_PREVIEW.html` trong workspace VGD. Preview riêng của Reference đọc trực tiếp SVG runtime, không sao chép các path sang một bản vẽ khác.

## File và vai trò

| File | Vai trò |
| --- | --- |
| `runtime/vgd_reference/assets/toolbar/vgd_reference.svg` | SVG cho nền sáng, giữ đường dẫn cũ của toolbar |
| `runtime/vgd_reference/assets/toolbar/vgd_reference_dark.svg` | Cùng glyph với nét trắng ngà cho nền tối |
| `runtime/vgd_reference/assets/toolbar/icon_manifest.json` | Phiên bản, kích thước, màu, đường dẫn và chính sách chọn theme |
| `runtime/vgd_reference/ui/icons.rb` | Chọn SVG từ manifest cho `UI::Command` |
| `dev/build_icons.cjs` | Nguồn ba path; tạo lại hai SVG và manifest |
| `dev/icon_preview.html` | Gallery, toolbar và hàng thử 16/24/32 px trên cả hai nền |

## Theme trong runtime

Bảng quản lý dùng `prefers-color-scheme`. Các token nền, panel, chữ, viền, lựa chọn và thông báo đổi cùng theme; ảnh glyph ở header đổi qua `<picture>`. Các nút vẫn giữ tên tiếng Việt, callback và vị trí hiện có. Thao tác ẩn/hiện, khóa và xóa dùng SVG nét 1,8 thay ký tự; luôn hiện để dễ nhận biết.

`UI::Command` nhận một đường dẫn icon cho mỗi kích thước. SketchUp 2024 trên máy đã kiểm tra có toolbar sáng; runtime mặc định chọn SVG sáng. Không suy đoán màu toolbar native từ theme Windows.

Nhấn nút **Chọn màu icon thanh công cụ** ở header bảng quản lý, rồi chọn **Nền sáng · nét than** hoặc **Nền tối · nét trắng ngà**. Callback Ruby lưu `VGD.Reference / ToolbarTheme`, gán đúng SVG cho small/large icon của Command hiện có và khôi phục lựa chọn khi mở lại plugin. Manager vẫn theo `prefers-color-scheme`, độc lập với lựa chọn toolbar. Giá trị lưu không hợp lệ trở về sáng; callback từ chối giá trị ngoài hai lựa chọn.

Tài liệu API: [UI::Command#small_icon=](https://ruby.sketchup.com/UI/Command.html#small_icon=-instance_method).

## Kiểm tra đã thực hiện

- Xem trực tiếp ảnh render gallery, toolbar và kích thước thực 16/24/32 px ở hai nền.
- Kiểm tra cấu trúc SVG, path giống nhau giữa theme, màu chính xác, góc canvas trong suốt và ghim vẫn có pixel ở mỗi kích thước.
- Tương phản nét chính trên nền toolbar mẫu: sáng 9,87:1, tối 12,18:1.
- Edge headless render bảng quản lý sáng/tối ở 310×455 và kích thước tối thiểu 280×340; xác nhận trạng thái rỗng, nhãn và callback của tất cả nút hiện có.
- Ruby kiểm tra đường dẫn manifest, theme mặc định, lưu lựa chọn, cập nhật small/large icon của Command hiện có và xử lý giá trị không hợp lệ. HTML kiểm tra mở/đóng setting, callback và khôi phục lựa chọn từ Ruby.

Các ảnh kiểm tra nằm trong `outputs/icon-preview/` và `outputs/manager-preview/`. Những phép thử này xác nhận SVG và HTML; icon beta.6 chưa được kiểm tra trực tiếp trong toolbar SketchUp. Bản sửa UV beta.5 đã có xác nhận hiển thị ảnh thật trong SketchUp 24.0.484 và được giữ nguyên.

## Tạo lại và đóng gói

```text
node dev/build_icons.cjs
node dev/test_icons.cjs
node dev/test_manager.cjs
node dev/check_ruby.cjs
node dev/package.cjs
```

Chạy trong thư mục `VGD_Reference`. Bước đóng gói cũng tạo lại icon, đối chiếu phiên bản bộ nạp/constants/manifest và kiểm tra từng file giải nén trùng byte với nguồn. Cả RBZ và source ZIP có file SHA-256 riêng.
