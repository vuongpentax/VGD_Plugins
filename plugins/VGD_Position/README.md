# VGD Position 0.1.0-beta.3

Plugin dời, xoay và scale món (group, component) trong SketchUp theo trục thế giới. Cài bằng Extension Manager, khởi động lại SketchUp. Plugin không tự kiểm tra cập nhật; VGD Center báo bản mới.

## Cách dùng

1. Chọn một hoặc nhiều group / component trong SketchUp.
2. Mở **Extensions → VGD → VGD Position → Mở bảng vị trí** (hoặc nút **VGD_POSITION** trên thanh công cụ **VGD POS**).
3. Cửa sổ liệt kê món đang chọn, kèm điểm gốc hiện tại theo đơn vị của file. Món khóa được đánh dấu.
4. Chọn công cụ bằng ba tab: **Dời**, **Xoay**, **Scale**.
5. Nhập số rồi bấm **Xem trước** để thấy độ dời hoặc góc, và vị trí đích của từng món. Sau đó bấm **Áp dụng**. Nút này chỉ bật khi xem trước đúng với các ô hiện tại. Mỗi đợt biến đổi là một bước hoàn tác (Ctrl+Z).

### Dời

- **Tuyệt đối (thế giới):** nhập X, Y, Z để đưa điểm gốc của món tới đúng tọa độ.
  - Một món: điểm gốc của món đó tới đúng X, Y, Z.
  - Nhiều món: lấy **món đầu tiên** trong danh sách làm chuẩn, cả nhóm dời cùng độ lệch đó (khoảng cách giữa các món giữ nguyên).
- **Dời tương đối (thế giới):** nhập ΔX, ΔY, ΔZ. Mỗi món dời đúng độ dời đó theo trục thế giới.

### Xoay

- Nhập góc (độ) quanh X, Y, Z theo trục thế giới. Các góc được áp dụng theo thứ tự **X, rồi Y, rồi Z**.
- Chỉ có xoay tương đối: góc nhập là góc xoay thêm, không đặt góc tuyệt đối.

### Scale

- Chọn **Đều** (một hệ số cho cả ba trục) hoặc **Không đều** (hệ số riêng cho X, Y, Z).
- Hệ số tương đối: **1 = giữ nguyên**, 2 = gấp đôi, 0,5 = một nửa. Hệ số phải nằm trong khoảng 0,001 đến 1000. Hệ số âm (lật món) không được hỗ trợ.

### Tâm xoay / scale

Dùng cho Xoay và Scale:
- **Điểm gốc từng món:** mỗi món xoay hoặc scale quanh điểm gốc của chính nó.
- **Tâm của cả lựa chọn:** cả nhóm quanh tâm hộp bao của các điểm gốc.
- **Gốc tọa độ thế giới (0, 0, 0):** cả nhóm quanh gốc của model.

### Đơn vị

- Số không có đơn vị được hiểu theo **đơn vị của file** đang mở (mm, cm, m, in hoặc ft). Cửa sổ hiển thị đơn vị đó.
- Có thể gõ thêm đơn vị sau số để đổi đơn vị cho riêng số đó, giống ô nhập VCB của SketchUp: `1m`, `250 mm`, `2in`, `1,5ft`.
- Ô nhập chấp nhận dấu chấm hoặc dấu phẩy. Giới hạn ±1 km (1 000 000 mm).

### Ô số

- Nút **▲ ▼** bên phải ô: bấm để đổi một bước; giữ nút để lặp liên tục.
- Giữ chuột trên ô rồi kéo lên (tăng) hoặc xuống (giảm) để đổi nhanh. Mỗi 2 px kéo là một bước.
- Bước: 1 đơn vị cho Dời, 1° cho Xoay, 0,1 cho hệ số Scale. Nếu ô đã có đơn vị gõ thêm (ví dụ `5mm`), nút ▲ ▼ giữ đơn vị đó.

## Giới hạn của bản thử

- Món khóa, hoặc món nằm trong group cha đang bị khóa, không được biến đổi. Nếu trong lựa chọn có món như vậy, **cả đợt không chạy** và cửa sổ báo tên món đó. Bỏ khóa hoặc bỏ chọn món đó rồi thử lại.
- Món trong group cha đang mở được biến đổi theo hệ thế giới.
- Không có scale tuyệt đối (SketchUp không lưu sẵn "kích thước hiện tại" của một group để đọc ra), nên Scale chỉ nhân với hệ số.
- Plugin không tự gán lại tầng / phòng của VGD BIM sau khi biến đổi. Sau khi biến đổi, bấm gán lại trong bảng khối lượng của VGD BIM nếu cần.
- Giao diện chỉ tiếng Việt.

## Tải lại code

**Extensions → VGD → VGD Position → Tải lại code** nạp lại mã sau khi cài đè bản mới, không cần mở lại SketchUp. Menu và thanh công cụ có hiệu lực đầy đủ sau khi mở lại SketchUp.
