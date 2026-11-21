# VGD Position 0.1.0-beta.1

Plugin dời món (group, component) trong SketchUp tới tọa độ X, Y, Z (mm), hoặc dời tương đối. Cài bằng Extension Manager, khởi động lại SketchUp. Plugin không tự kiểm tra cập nhật; VGD Center báo bản mới.

## Cách dùng

1. Chọn một hoặc nhiều group / component trong SketchUp.
2. Mở **Extensions → VGD → VGD Position → Mở bảng vị trí** (hoặc nút **VGD_POSITION** trên thanh công cụ **VGD POS**).
3. Cửa sổ liệt kê món đang chọn, kèm điểm gốc hiện tại (mm, hệ thế giới). Món khóa được đánh dấu.
4. Chọn chế độ:
   - **Đặt điểm gốc tới X, Y, Z**: chỉ khi chọn đúng một món. Ô để trống thì giữ nguyên trục đó (ví dụ chỉ điền X để chỉ đổi X).
   - **Dời tương đối ΔX, ΔY, ΔZ**: một hoặc nhiều món, mỗi ô là độ dời (ô trống là 0). Số âm dời ngược chiều.
5. Bấm **Xem trước** để thấy món sẽ dời và món bị bỏ qua (kèm lý do).
6. Bấm **Áp dụng**. Nút này chỉ bật sau khi xem trước với đúng các ô hiện tại. Dời cả đợt là một bước hoàn tác (Ctrl+Z).

Ô nhập chấp nhận dấu chấm hoặc dấu phẩy (1200 hoặc 1200,5). Giới hạn ±1 000 000 mm.

## Giới hạn của bản thử

- Dời **điểm gốc** của món, không xoay món.
- Món khóa, hoặc món nằm trong group cha đang bị khóa, không được dời (được báo trong kết quả).
- Món trong group cha đang mở được dời theo hệ thế giới.
- Plugin không tự gán lại tầng / phòng của VGD BIM sau khi dời. Sau khi dời, bấm gán lại trong bảng khối lượng của VGD BIM nếu cần.
- Giao diện chỉ tiếng Việt.

## Tải lại code

**Extensions → VGD → VGD Position → Tải lại code** nạp lại mã sau khi cài đè bản mới, không cần mở lại SketchUp. Menu và thanh công cụ có hiệu lực đầy đủ sau khi mở lại SketchUp.
