# VGD Icon System — Quy tắc thiết kế HTML preview

Tài liệu này ghi lại các quy tắc cho bộ icon đang được duyệt trong [`VGD_ICON_SYSTEM_PREVIEW.html`](VGD_ICON_SYSTEM_PREVIEW.html). Đây là đặc tả cho preview; chưa tự động thay SVG hoặc icon trong runtime của các plugin.

## 1. Nguyên tắc chung

- Dùng SVG `viewBox="0 0 24 24"` cho icon lệnh.
- Giữ nét chính đồng nhất, stroke khoảng `1.8 px`, đầu nét và góc nối bo tròn (`stroke-linecap: round`, `stroke-linejoin: round`).
- Các đoạn tạo thành cùng một hình phải nối đúng điểm; tránh khe hở ngoài ý muốn, nét đè lên nhau và chi tiết quá nhỏ.
- Glyph không có nền hoặc khung trang trí. Chỉ vẽ hình vật thể hay dấu hiệu cần thiết để hiểu chức năng.
- Giữ hình đơn giản, vẫn nhận ra được ở cỡ 16–24 px. Một icon chỉ nên có một ý chính.
- Icon chính của mỗi plugin giữ hình đã chốt; icon lệnh có thể dùng modifier nhỏ để chỉ thao tác.

## 2. Màu và chế độ sáng/tối

Màu áp dụng cho icon trong preview, không thay thế toàn bộ token giao diện plugin.

| Vai trò | Nền sáng | Nền tối |
|---|---|---|
| Nét chính | `#292B2D` | `#F1EDE6` |
| Điểm nhấn | **Nâu đồng VGD** `#A67C58` | **Nâu đồng VGD** `#A67C58` |
| Nền toolbar xem trước | Xám sáng `#D8D7D4` | Xám than `#292B2D` |

- Điểm nhấn giữ nguyên `#A67C58` ở cả hai theme.
- Nét chính đổi từ than `#292B2D` sang trắng ngà `#F1EDE6` khi chuyển từ sáng sang tối.
- Các mảng của logo Center cũng đổi màu theo theme để giữ tương phản.

## 3. Quy tắc riêng đã chốt

- **VGD Dim:** chỉ một đường dim ngang, có hai chân gióng đi xuống và dấu endpoint; không vẽ box hoặc vật thể đo. Đường dim nằm phía trên.
- **Smart Dim:** giữ biểu tượng đo đơn giản và thêm tia sét nhỏ để gợi thao tác nhanh.
- **VGD Center:** dùng lại logo cũ đã chốt khi làm Center; bỏ nền vuông, chỉ đổi màu cho phù hợp theme. Không tự vẽ lại thành biểu tượng khác.
- **Dọn tag con:** dùng silhouette tag dễ nhận diện, có lỗ tag và dấu cập nhật bên trong.
- **Thư viện model:** dùng ghế ở phối cảnh isometric.
- **Xuất ảnh phụ:** thể hiện ba hình ảnh/texture xếp lớp.
- **Lưu/cập nhật view:** dùng hình camera chính của VGD Scenes, thêm dấu cập nhật nhỏ ở góc.
- **Library:** phương án icon vật liệu xếp lớp A đã được chọn; không đưa phương án B trở lại preview.

## 4. Thẻ và bố cục HTML preview

- Dùng cùng kích thước glyph và vùng đệm để các icon cân bằng khi đặt cạnh tên lệnh.
- Thẻ preview có thể có nền giao diện sáng/tối; quy tắc “không nền” áp dụng cho glyph bên trong, không áp dụng cho thẻ trình bày.
- Thanh toolbar mẫu phải dùng cùng bộ path với gallery và hàng thử kích thước để tránh các bản vẽ lệch nhau.
- Duy trì nút đổi theme để xem cả hai bảng màu.

## 5. Khi cập nhật bộ icon

1. Sửa đường dẫn SVG trong `paths` của file preview.
2. Xem icon trong gallery, toolbar và ở các cỡ 16/24/32 px.
3. Chuyển qua cả nền sáng và tối; kiểm tra tương phản, nét nối, nét chồng và khoảng cách.
4. Chỉ sau khi được duyệt mới xuất hoặc đồng bộ icon vào plugin runtime.
