# VGD Transform 0.1.0-beta.5

> Đổi tên từ **VGD Position**. Trong SketchUp, gỡ bản **VGD Position** cũ (Extension Manager) trước khi cài bản này để tránh hai menu trùng chức năng.

Plugin dời, xoay và scale món (group, component) trong SketchUp theo trục thế giới. Cài bằng Extension Manager, khởi động lại SketchUp. Plugin không tự kiểm tra cập nhật; VGD Center báo bản mới.

## Cách dùng

1. Chọn một hoặc nhiều group / component trong SketchUp.
2. Mở **Extensions → VGD → VGD Transform → Mở bảng biến đổi** (hoặc nút **VGD_TRANSFORM** trên thanh công cụ **VGD TRF**).
3. Chọn công cụ bằng ba tab: **Dời**, **Xoay**, **Scale**.
4. Nhập số rồi nhấn **Enter** (hoặc bấm **Áp dụng**). Biến đổi thực hiện ngay. Mỗi lần là một bước hoàn tác (Ctrl+Z).

Cửa sổ chỉ có ô nhập và nút; không có danh sách món và không có bảng kết quả.

### Dời

- **Tuyệt đối (thế giới):** nhập X, Y, Z để đưa điểm gốc tới đúng tọa độ.
  - Một món: điểm gốc của món đó tới đúng X, Y, Z.
  - Nhiều món: lấy **món đầu tiên** trong lựa chọn làm chuẩn, cả nhóm dời cùng độ lệch đó (khoảng cách giữa các món giữ nguyên).
- **Dời tương đối (thế giới):** nhập ΔX, ΔY, ΔZ. Mỗi món dời đúng độ dời đó theo trục thế giới.

### Xoay

- Nhập góc (độ) quanh X, Y, Z theo trục thế giới. Các góc áp dụng theo thứ tự **X, rồi Y, rồi Z**.
- Chỉ có xoay tương đối: góc nhập là góc xoay thêm, không đặt góc tuyệt đối.

### Scale

- **Đều:** một hệ số cho cả ba trục. Hệ số 1 là giữ nguyên, 2 là gấp đôi, 0,5 là một nửa.
- **Không đều:** mỗi trục một ô. Ô trống là giữ nguyên trục đó.
  - Số không có đơn vị là **hệ số**.
  - Số có đơn vị là **kích thước đích**: ví dụ `1000mm` hoặc `1m` làm món có kích thước theo trục đó đúng bằng số đó. Hệ số của từng món được tính từ kích thước hiện tại của món, nên dùng được cho món có số lẻ mà không cần tính hệ số tay.
- Hệ số phải nằm trong khoảng 0,001 đến 1000. Hệ số âm (lật món) không được hỗ trợ.

### Tâm xoay / scale

Dùng cho Xoay và Scale:
- **Điểm gốc từng món:** mỗi món xoay hoặc scale quanh điểm gốc của chính nó.
- **Tâm của cả lựa chọn:** cả nhóm quanh tâm hộp bao của các điểm gốc.
- **Gốc tọa độ thế giới (0, 0, 0):** cả nhóm quanh gốc của model.

### Đơn vị

- Số không có đơn vị được hiểu theo **đơn vị của file** đang mở (mm, cm, m, in hoặc ft). Dòng trên cùng cửa sổ hiển thị đơn vị đó.
- Có thể gõ thêm đơn vị sau số để đổi đơn vị cho riêng số đó, giống ô nhập VCB của SketchUp: `1m`, `250 mm`, `2in`, `1,5ft`.
- Ô nhập chấp nhận dấu chấm hoặc dấu phẩy. Giới hạn ±1 km (1 000 000 mm).

### Ô số

- Nút **▲ ▼** bên phải ô: bấm để đổi một bước; giữ nút để lặp liên tục.
- Giữ chuột trên ô rồi kéo lên (tăng) hoặc xuống (giảm) để đổi nhanh. Mỗi 2 px kéo là một bước.
- Bước: 1 đơn vị cho Dời, 1° cho Xoay, 0,1 cho hệ số Scale. Ô đã có đơn vị gõ thêm (ví dụ `5mm`) thì nút ▲ ▼ giữ đơn vị đó. Ô số chỉ đổi giá trị; muốn áp dụng thì nhấn Enter hoặc bấm Áp dụng.

## Giới hạn của bản thử

- Món khóa, hoặc món nằm trong group cha đang bị khóa, không được biến đổi. Nếu trong lựa chọn có món như vậy, **cả đợt không chạy** và cửa sổ báo tên món đó. Bỏ khóa hoặc bỏ chọn món đó rồi thử lại.
- Món trong group cha đang mở được biến đổi theo hệ thế giới.
- Không có scale tuyệt đối (SketchUp không lưu sẵn "kích thước hiện tại" của một group để đọc ra), nên Scale chỉ nhân với hệ số hoặc đặt kích thước đích.
- Scale đều chỉ nhận hệ số. Muốn đặt kích thước theo đơn vị, chọn Không đều.
- Vì áp dụng ngay, hãy kiểm tra số trước khi nhấn Enter. Ctrl+Z hoàn tác một đợt.
- Plugin không tự gán lại tầng / phòng của VGD BIM sau khi biến đổi. Sau khi biến đổi, bấm gán lại trong bảng khối lượng của VGD BIM nếu cần.
- Giao diện chỉ tiếng Việt.

## Tải lại code

**Extensions → VGD → VGD Transform → Tải lại code** nạp lại mã sau khi cài đè bản mới, không cần mở lại SketchUp. Menu và thanh công cụ có hiệu lực đầy đủ sau khi mở lại SketchUp.
