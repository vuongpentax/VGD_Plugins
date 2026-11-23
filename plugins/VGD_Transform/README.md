# VGD Transform 0.1.0-beta.11

> Đổi tên từ **VGD Position**. Trong SketchUp, gỡ bản **VGD Position** cũ (Extension Manager) trước khi cài bản này để tránh hai menu trùng chức năng.

Plugin dời, xoay và scale món (group, component) trong SketchUp bằng số, theo cách của hộp **Transform Type-In** trong 3ds Max. Cài bằng Extension Manager, khởi động lại SketchUp. Plugin không tự kiểm tra cập nhật; VGD Center báo bản mới.

## Cách dùng

1. Chọn một hoặc nhiều group / component trong SketchUp.
2. Bấm một trong ba nút **Dời**, **Xoay**, **Scale** trên thanh công cụ **VGD TRF** (icon như 3ds Max): cửa sổ mở ra ở đúng công cụ đó. Hoặc mở **Extensions → VGD → VGD Transform → Mở bảng biến đổi**.
   Muốn mở bằng phím như F12 của 3ds Max: **Window → Preferences → Shortcuts**, tìm "Mở bảng biến đổi" và gán phím.
3. Cửa sổ gọn (khoảng 320 × 250, cỡ hộp Transform Type-In của 3ds Max) để đặt cạnh màn hình. Hàng trên cùng: ba icon công cụ, nút **khóa**, nút gạt **Trực tiếp**, nút đổi theme. Đáy bảng: dòng trạng thái (đơn vị file · số món · số đối tượng bị bỏ qua) và dòng **ghi chú / thông báo**.
4. Chọn công cụ bằng ba icon; chọn **Tâm** và **Trục** (dùng chung cho mọi công cụ). Rê chuột lên nút, khung hoặc ô chọn: ghi chú giải thích hiện ở đáy bảng. Sau khi nhấn Enter, đáy bảng báo kết quả hoặc lỗi.
5. Nhập số rồi nhấn **Enter**. Biến đổi chạy ngay (không có nút Áp dụng); mỗi lần là một bước hoàn tác (Ctrl+Z).

### Khóa (như Lock của SketchUp)

- Nút ổ khóa khóa / mở khóa các group / component đang chọn, giống **Lock / Unlock** trong menu chuột phải của SketchUp (đúng thuộc tính khóa của SketchUp, Ctrl+Z hoàn tác được).
- Ổ khóa cho biết trạng thái lựa chọn: **mở** (không món nào khóa), **đóng, tô màu** (khóa hết), **đóng, tô nhạt** (lẫn lộn).
- Bấm khi đã khóa hết thì mở khóa hết; còn lại (chưa khóa hoặc lẫn lộn) thì khóa hết.
- Món khóa không dời / xoay / scale được (cả bằng plugin này lẫn công cụ của SketchUp).

### Ô Tuyệt đối và Tương đối (như 3ds Max)

- **Tuyệt đối** hiện sẵn giá trị hiện tại của món đang chọn và tự cập nhật khi đổi lựa chọn, khi model thay đổi, khi Ctrl+Z. Sửa ô nào thì chỉ ô đó được áp dụng; trục mà các món khác nhau ghi "khác nhau".
- **Tương đối** là độ dời / góc / hệ số thêm vào. Áp dụng xong ô tự về 0, nên nhấn Enter lần nữa không bị dời thêm.

### Dời

- **Tuyệt đối (thế giới):** đưa tâm biến đổi tới đúng X, Y, Z.
  - Tâm *Gốc món*: điểm gốc của từng món tới đúng tọa độ (nhiều món thì thẳng hàng trên trục đã nhập).
  - Tâm *Tâm chọn* hoặc *Gốc 0,0,0*: tâm hộp bao của cả lựa chọn tới tọa độ, cả nhóm dời cùng độ lệch.
- **Tương đối:** ΔX, ΔY, ΔZ theo hệ trục đã chọn (thế giới, hoặc trục riêng của từng món).

### Xoay

- Nhập góc (độ) quanh X, Y, Z theo hệ trục đã chọn, quanh tâm đã chọn. Các góc áp dụng theo thứ tự **X, rồi Y, rồi Z**; hệ trục riêng lấy theo hướng của món lúc bắt đầu.
- Chỉ có xoay tương đối (góc xoay "hiện tại" của một group không xác định duy nhất).

### Scale

- **Tuyệt đối (riêng):** tỉ lệ của món so với definition theo trục riêng (1 = kích thước gốc). Ô hiện tỉ lệ hiện tại.
- **Tương đối:** tick **Đều** (một ô hệ số cho cả ba trục), bỏ tick để có ba ô X, Y, Z (trống là giữ).
  - Số không có đơn vị là **hệ số** (1 = giữ, 2 = gấp đôi).
  - Khi bỏ Đều, số có đơn vị là **kích thước đích**: `1000mm`, `1m`… làm món có kích thước đúng bằng số đó theo trục (hệ thế giới đo hộp bao thế giới, hệ riêng đo theo trục của món). Hệ số được tính riêng cho từng món.
- Hệ số phải nằm trong khoảng 0,001 đến 1000. Hệ số âm (lật món) không được hỗ trợ.

### Tâm và hệ trục

- **Tâm** (như *Use Center* của 3ds Max): *Gốc món* (điểm gốc từng món), *Tâm chọn* (tâm hộp bao hình của cả lựa chọn), *Gốc 0,0,0* (gốc tọa độ thế giới).
- **Trục:** *World* (trục thế giới) hoặc *Local* (trục riêng của từng món). Dùng cho Dời tương đối, Xoay và Scale tương đối.

### Đơn vị

- Số không có đơn vị theo **đơn vị của file** (mm, cm, m, in, ft, yd). Nếu SketchUp trả đơn vị lạ, dòng trên cùng báo và plugin tạm dùng mm.
- Gõ thêm đơn vị sau số để dùng đơn vị khác cho riêng số đó, như ô VCB của SketchUp: `1m`, `250 mm`, `2in`, `1,5ft`, `1yd`. Chấp nhận dấu chấm hoặc phẩy. Giới hạn ±1 km.

### Ô số (spinner) và xem trực tiếp

- Nút **▲ ▼**: bấm một bước; giữ để lặp; **giữ chuột trên nút rồi kéo lên / xuống** để đổi nhanh (mỗi 2 px một bước). Giữ **Ctrl** để bước ×10, **Alt** để bước ×0,1. **Chuột phải** vào nút: về mặc định (0, hoặc 1 với tỉ lệ).
- Bước: khoảng 1 mm cho ô độ dài (theo đơn vị file), 1° cho góc, 0,01 cho hệ số.
- Nút gạt **Trực tiếp** (bật sẵn): món chạy theo khi bấm, giữ hoặc kéo ▲▼; thả chuột là xong, cả lần kéo là **một** bước Ctrl+Z. Tắt đi thì ▲▼ chỉ đổi số, nhấn Enter mới áp dụng.

## Giới hạn của bản thử

- Món khóa, hoặc món nằm trong group cha đang bị khóa: **cả đợt không chạy** và đáy bảng báo tên món đó. Bấm nút khóa để mở khóa.
- Cạnh, mặt rời trong lựa chọn không được biến đổi (chỉ group / component); số lượng được báo.
- Không có xoay tuyệt đối. Không hỗ trợ hệ số âm (lật món). Chưa có chọn tâm bằng cách bấm vào model.
- Món bị méo (trục không vuông góc) dùng hệ trục riêng có thể bị từ chối khi kiểm tra sau biến đổi.
- Chọn hơn 500 món: ô Tuyệt đối không hiện giá trị (để không chậm); vẫn dời / xoay / scale được.
- Vì áp dụng ngay, hãy kiểm tra số trước khi nhấn Enter. Ctrl+Z hoàn tác một đợt.
- Plugin không tự gán lại tầng / phòng của VGD BIM sau khi biến đổi.
- Giao diện chỉ tiếng Việt.

## Tải lại code

**Extensions → VGD → VGD Transform → Tải lại code** nạp lại mã sau khi cài đè bản mới, không cần mở lại SketchUp (không tải lại được khi đang kéo ▲▼). Menu và thanh công cụ có hiệu lực đầy đủ sau khi mở lại SketchUp.
