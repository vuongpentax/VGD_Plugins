# VGD Position 0.1.0-beta.2

Plugin dời món (group, component) trong SketchUp tới tọa độ X, Y, Z (mm) của trục thế giới. Cài bằng Extension Manager, khởi động lại SketchUp. Plugin không tự kiểm tra cập nhật; VGD Center báo bản mới.

## Cách dùng

1. Chọn một hoặc nhiều group / component trong SketchUp. Số món đã chọn quyết định cách dời:
   - **Một món**: điểm gốc của món đó tới đúng X, Y, Z.
   - **Nhiều món**: lấy **món đầu tiên** trong danh sách làm chuẩn. Điểm gốc của món đó tới đúng X, Y, Z, và cả nhóm dời cùng độ lệch đó (khoảng cách giữa các món giữ nguyên).
2. Mở **Extensions → VGD → VGD Position → Mở bảng vị trí** (hoặc nút **VGD_POSITION** trên thanh công cụ **VGD POS**).
3. Cửa sổ liệt kê món đang chọn, kèm điểm gốc hiện tại (mm, hệ thế giới). Món khóa được đánh dấu.
4. Nhập X, Y, Z (mm). Ô để trống thì giữ nguyên trục đó (ví dụ chỉ điền X để chỉ đổi X).
5. Bấm **Xem trước** để thấy độ dời và vị trí đích của từng món.
6. Bấm **Áp dụng**. Nút này chỉ bật sau khi xem trước với đúng các ô hiện tại. Dời cả đợt là một bước hoàn tác (Ctrl+Z).

Ô nhập chấp nhận dấu chấm hoặc dấu phẩy (1200 hoặc 1200,5). Giới hạn ±1 000 000 mm.

## Giới hạn của bản thử

- Dời **điểm gốc** của món, không xoay món.
- Nếu trong lựa chọn có món khóa (hoặc món nằm trong group cha đang bị khóa), **cả đợt không dời** và cửa sổ báo tên món đó. Bỏ khóa hoặc bỏ chọn món đó rồi thử lại.
- Món trong group cha đang mở được dời theo hệ thế giới.
- Plugin không tự gán lại tầng / phòng của VGD BIM sau khi dời. Sau khi dời, bấm gán lại trong bảng khối lượng của VGD BIM nếu cần.
- Giao diện chỉ tiếng Việt.

## Tải lại code

**Extensions → VGD → VGD Position → Tải lại code** nạp lại mã sau khi cài đè bản mới, không cần mở lại SketchUp. Menu và thanh công cụ có hiệu lực đầy đủ sau khi mở lại SketchUp.
