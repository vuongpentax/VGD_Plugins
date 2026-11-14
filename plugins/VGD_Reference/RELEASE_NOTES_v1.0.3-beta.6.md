# VGD Reference 1.0.3-beta.6

- Gom menu: các lệnh nằm trong **Extensions → VGD → VGD Reference**.
- Thanh công cụ đổi tên rút gọn thành **VGD REF** (tên extension vẫn là VGD Reference). Vị trí thanh công cụ có thể phải kéo lại một lần.
- **Sửa Zoom Extents:** ảnh tham chiếu không còn làm Zoom Extents tính cả đối tượng đã ẩn (trước đây lớp phủ báo hộp bao của cả model, gồm đối tượng ẩn hoặc tắt tag, nên khung nhìn vẫn mở rộng ra vùng đã ẩn).
- Ngoài mục Tải lại code, không đổi chức năng khác; SketchUp tối thiểu vẫn 2023.
- **Tải lại code:** menu **Extensions → VGD → VGD Reference → Tải lại code** nạp lại mã sau khi cài đè bản mới mà không cần mở lại SketchUp (không cho tải lại khi đang chỉnh sửa hoặc nhập ảnh; giữ nguyên ảnh đang có). Menu và toolbar mới chỉ có tác dụng sau khi mở lại SketchUp.
- Tải lại code: lời báo lỗi thống nhất với các plugin khác.

Kiểm tra: tự động (test tải lại code, cú pháp Ruby, test `dev/overlay_extents_fixture.rb` cho Zoom Extents, đóng gói RBZ). Chưa kiểm thử thủ công trong SketchUp cho bản này.
