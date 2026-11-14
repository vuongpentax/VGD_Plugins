# VGD Reference 1.0.3-beta.4

- Gom menu: các lệnh nằm trong **Extensions → VGD → VGD Reference**.
- Thanh công cụ đổi tên rút gọn thành **VGD REF** (tên extension vẫn là VGD Reference). Vị trí thanh công cụ có thể phải kéo lại một lần.
- **Sửa Zoom Extents:** ảnh tham chiếu không còn làm Zoom Extents tính cả đối tượng đã ẩn (trước đây lớp phủ báo hộp bao của cả model, gồm đối tượng ẩn hoặc tắt tag, nên khung nhìn vẫn mở rộng ra vùng đã ẩn).
- Không đổi chức năng khác; SketchUp tối thiểu vẫn 2023.

Kiểm tra: tự động (cú pháp Ruby, test `dev/overlay_extents_fixture.rb` cho Zoom Extents, đóng gói RBZ). Chưa kiểm thử thủ công trong SketchUp cho bản này.
