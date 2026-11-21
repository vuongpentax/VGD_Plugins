# VGD Transform 0.1.0-beta.6

> Đổi tên từ **VGD Position**. Trong SketchUp, gỡ bản **VGD Position** cũ (Extension Manager) trước khi cài bản này để tránh hai menu trùng chức năng.

Plugin dời, xoay và scale món (group, component) trong SketchUp bằng số, theo cách của hộp **Transform Type-In** trong 3ds Max. Cài bằng Extension Manager, khởi động lại SketchUp. Plugin không tự kiểm tra cập nhật; VGD Center báo bản mới.

## Cách dùng

1. Chọn một hoặc nhiều group / component trong SketchUp.
2. Mở **Extensions → VGD → VGD Transform → Mở bảng biến đổi** (hoặc nút **VGD_TRANSFORM** trên thanh công cụ **VGD TRF**).
   Muốn mở bằng phím như F12 của 3ds Max: **Window → Preferences → Shortcuts**, tìm "Mở bảng biến đổi" và gán phím.
3. Dòng trên cùng cho biết số món, đơn vị của file, và số đối tượng bị bỏ qua (cạnh, mặt không phải group / component).
4. Chọn công cụ bằng ba tab **Dời**, **Xoay**, **Scale**; chọn **Tâm** và **Hệ trục** (dùng chung cho mọi công cụ).
5. Nhập số rồi nhấn **Enter** (hoặc bấm **Áp dụng**). Biến đổi chạy ngay; mỗi lần là một bước hoàn tác (Ctrl+Z).

### Ô Tuyệt đối và Tương đối (như 3ds Max)

- **Tuyệt đối** hiện sẵn giá trị hiện tại của món đang chọn và tự cập nhật khi đổi lựa chọn, khi model thay đổi, khi Ctrl+Z. Sửa ô nào thì chỉ ô đó được áp dụng; trục mà các món khác nhau ghi "khác nhau".
- **Tương đối** là độ dời / góc / hệ số thêm vào. Áp dụng xong ô tự về 0, nên nhấn Enter lần nữa không bị dời thêm.

### Dời

- **Tuyệt đối (thế giới):** đưa tâm biến đổi tới đúng X, Y, Z.
  - Tâm *Điểm gốc từng món*: điểm gốc của từng món tới đúng tọa độ (nhiều món thì thẳng hàng trên trục đã nhập).
  - Tâm *Tâm cả lựa chọn* hoặc *Gốc thế giới*: tâm hộp bao của cả lựa chọn tới tọa độ, cả nhóm dời cùng độ lệch.
- **Tương đối:** ΔX, ΔY, ΔZ theo hệ trục đã chọn (thế giới, hoặc trục riêng của từng món).

### Xoay

- Nhập góc (độ) quanh X, Y, Z theo hệ trục đã chọn, quanh tâm đã chọn. Các góc áp dụng theo thứ tự **X, rồi Y, rồi Z**; hệ trục riêng lấy theo hướng của món lúc bắt đầu.
- Chỉ có xoay tương đối (góc xoay "hiện tại" của một group không xác định duy nhất).

### Scale

- **Tuyệt đối (riêng):** tỉ lệ của món so với definition theo trục riêng (1 = kích thước gốc). Ô hiện tỉ lệ hiện tại.
- **Tương đối:** *Đều* (một hệ số cho cả ba trục) hoặc *Không đều* (mỗi trục một ô, trống là giữ).
  - Số không có đơn vị là **hệ số** (1 = giữ, 2 = gấp đôi).
  - Ở Không đều, số có đơn vị là **kích thước đích**: `1000mm`, `1m`… làm món có kích thước đúng bằng số đó theo trục (hệ thế giới đo hộp bao thế giới, hệ riêng đo theo trục của món). Hệ số được tính riêng cho từng món.
- Hệ số phải nằm trong khoảng 0,001 đến 1000. Hệ số âm (lật món) không được hỗ trợ.

### Tâm và hệ trục

- **Tâm** (như *Use Center* của 3ds Max): *Điểm gốc từng món*, *Tâm cả lựa chọn* (tâm hộp bao hình), *Gốc thế giới (0, 0, 0)*.
- **Hệ trục:** *Thế giới (World)* hoặc *Riêng của món (Local)*. Dùng cho Dời tương đối, Xoay và Scale tương đối.

### Đơn vị

- Số không có đơn vị theo **đơn vị của file** (mm, cm, m, in, ft, yd). Nếu SketchUp trả đơn vị lạ, dòng trên cùng báo và plugin tạm dùng mm.
- Gõ thêm đơn vị sau số để dùng đơn vị khác cho riêng số đó, như ô VCB của SketchUp: `1m`, `250 mm`, `2in`, `1,5ft`, `1yd`. Chấp nhận dấu chấm hoặc phẩy. Giới hạn ±1 km.

### Ô số (spinner) và xem trực tiếp

- Nút **▲ ▼**: bấm một bước; giữ để lặp; **giữ chuột trên nút rồi kéo lên / xuống** để đổi nhanh (mỗi 2 px một bước). Giữ **Ctrl** để bước ×10, **Alt** để bước ×0,1. **Chuột phải** vào nút: về mặc định (0, hoặc 1 với tỉ lệ).
- Bước: khoảng 1 mm cho ô độ dài (theo đơn vị file), 1° cho góc, 0,01 cho hệ số.
- Nút gạt **Xem trực tiếp khi kéo ▲▼** (bật sẵn): món chạy theo khi bấm, giữ hoặc kéo ▲▼; thả chuột là xong, cả lần kéo là **một** bước Ctrl+Z. Tắt đi thì ▲▼ chỉ đổi số, nhấn Enter mới áp dụng.

## Giới hạn của bản thử

- Món khóa, hoặc món nằm trong group cha đang bị khóa: **cả đợt không chạy** và cửa sổ báo tên món đó.
- Cạnh, mặt rời trong lựa chọn không được biến đổi (chỉ group / component); số lượng được báo.
- Không có xoay tuyệt đối. Không hỗ trợ hệ số âm (lật món). Chưa có chọn tâm bằng cách bấm vào model.
- Món bị méo (trục không vuông góc) dùng hệ trục riêng có thể bị từ chối khi kiểm tra sau biến đổi.
- Chọn hơn 500 món: ô Tuyệt đối không hiện giá trị (để không chậm); vẫn dời / xoay / scale được.
- Vì áp dụng ngay, hãy kiểm tra số trước khi nhấn Enter. Ctrl+Z hoàn tác một đợt.
- Plugin không tự gán lại tầng / phòng của VGD BIM sau khi biến đổi.
- Giao diện chỉ tiếng Việt.

## Tải lại code

**Extensions → VGD → VGD Transform → Tải lại code** nạp lại mã sau khi cài đè bản mới, không cần mở lại SketchUp (không tải lại được khi đang kéo ▲▼). Menu và thanh công cụ có hiệu lực đầy đủ sau khi mở lại SketchUp.
