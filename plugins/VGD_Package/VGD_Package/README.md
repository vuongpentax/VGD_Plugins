# VGD_Package 0.1.3 — Bản nghiên cứu

Baseline nghiên cứu 0.1.3: source đã đối chiếu 15 entry trong RBZ local của repo nguồn; không suy ra phát hành công khai hoặc native validation. Layout giữ loader ở cấp trên thư mục VGD_Package để bảo toàn đường dẫn builder. Không kèm RBZ/ZIP. Đợt chuyển repository chỉ đối chiếu source/checksum; chưa chạy lại test tự động hoặc kiểm thử native SketchUp. Các kết quả PASS bên dưới thuộc lịch sử workspace nguồn.

Plugin độc lập cho SketchUp 2022 trở lên. Phiên bản này có lớp nhận diện API tương thích, quét texture vật liệu SketchUp và kiểm tra thuộc tính Enscape chỉ đọc. Chưa có chức năng đóng gói hoặc liên kết lại.

## Cài đặt

Cài gói RBZ 0.1.3 đã xác minh riêng qua Extension Manager; artifact không nằm trong thư mục source này. Mở tại Extensions → VGD → VGD_Package.

## Chức năng hiện tại

- **Quét dự án** đọc texture diffuse và các texture PBR mà SketchUp hiện tại expose qua API.
- `OK` nghĩa là đường dẫn texture đang tồn tại. `EMBEDDED` nghĩa là SketchUp trả về texture hợp lệ và API có phương thức xuất texture; thao tác quét không ghi file. `MISSING` là đường dẫn không tồn tại và texture không thể xuất theo API đang có. `UNKNOWN` là lỗi khi đọc API.
- **Kiểm tra Enscape** đọc attribute dictionaries của model, vật liệu, entity và component definition, sau đó xuất `VGD_Package_Enscape_Research.json`. Báo cáo giữ giá trị gốc và tìm đường dẫn trong XML/JSON đã tuần tự hóa. Plugin không sửa model.
- Báo cáo có thể chứa đường dẫn tuyệt đối và giá trị attribute; hãy xem lại trước khi chia sẻ.

## Tương thích API

Plugin chuyển phiên bản SketchUp dạng `22.x`, `23.x`, `24.x` thành năm tương ứng để kiểm tra yêu cầu 2022+. Texture diffuse dùng `Material#texture`, `Texture#filename` và `Texture#write`, các API đã có từ trước phiên bản tối thiểu. Getter PBR chỉ được gọi khi runtime phát hiện method tương ứng. SketchUp Ruby API tài liệu hóa texture normal, roughness, AO và metallic từ SketchUp 2025.

Enscape hiện chỉ được kiểm tra ở chế độ đọc. Cần báo cáo từ model có Enscape để xác định dictionary/key/channel thực tế trước khi cân nhắc relink.

## Kiểm thử

Đã kiểm tra cú pháp JavaScript, cấu trúc RBZ, tài nguyên giao diện và SHA-256. Chưa chạy smoke test bên trong SketchUp 2022 hoặc phiên bản mới hơn trong môi trường tạo gói này.
