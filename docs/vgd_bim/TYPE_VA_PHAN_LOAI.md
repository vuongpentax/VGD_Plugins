# VGD_BIM — Type và Phân loại (đặc tả bản nháp, cột mốc 5a và 5b)

Bản nháp để chủ dự án duyệt trước khi code. Chưa có dòng code nào cho phần này.

## 1. Type (cột mốc 5a)

**Type** là dữ liệu dùng chung cho mọi **Instance** (bản sao) của cùng một loại. Lấy cách làm của SketchUp: dữ liệu nằm ở **định nghĩa** (ComponentDefinition), nên sửa một lần thì mọi bản sao đọc được ngay.

- **Phạm vi:** chỉ **component**. Group không có định nghĩa dùng chung trong SketchUp, nên không có Type; dữ liệu của group vẫn là dữ liệu riêng như hiện nay.
- **Lưu ở đâu:** dictionary riêng `VGD_BIM_TYPE` trên định nghĩa component. Không ghi vào từng Instance.
- **Cách sửa:** sửa Type trong bảng (một thao tác hoàn tác được). Mọi Instance cùng định nghĩa đổi theo ngay.
- **Cột trong bảng:** cột Type (đọc từ định nghĩa) đứng cạnh các cột của Instance.
- **Ưu tiên khi trùng trường:** nếu một Instance có giá trị riêng cho một trường đã có ở Type, giá trị riêng đó được giữ (đề xuất; xem câu hỏi A2).

### Rủi ro

- **Tách bản (Make Unique):** khi người dùng tách một component, bản mới có định nghĩa riêng nên Type cũng tách theo. Cần ghi rõ cho người dùng.
- **Dùng chung nhiều nơi:** sửa Type ở một Instance sẽ đổi mọi Instance cùng định nghĩa. Cần xem trước số Instance bị ảnh hưởng.
- **Không ghi vào Instance:** Type không tự sao chép sang Instance, nên không làm phình file.

## 2. Phân loại mở (cột mốc 5b)

**Phân loại** là mã thuộc một **hệ phân loại** (ví dụ VGD, IFC, OmniClass, hoặc hệ tự đặt). Một món hoặc một Type có thể có nhiều mã, mỗi mã ở một hệ.

- **Hệ có sẵn:** VGD (dùng Category và mã đối tượng đã có). Hệ tùy chỉnh do người dùng tạo.
- **IFC và OmniClass:** chỉ làm **sau khi có file mã** do người dùng cung cấp. Không tự đưa mã chuẩn vào plugin khi chưa có nguồn đáng tin.
- **Nhập từ Excel:** file có cột Hệ, Mã, Tên. Xem trước rồi áp dụng trong một thao tác (cùng kiểu với nhập tag từ Excel).
- **Lưu:** danh sách hệ trong `VGD_BIM_MODEL` (khóa `classification_systems`, giới hạn số hệ). Mã của từng món hoặc Type lưu dạng `[{hệ, mã}]`.
- **Ánh xạ giữa các hệ:** bảng ánh xạ nhập từ file. Plugin không tự đoán ánh xạ.

## 3. Câu hỏi cần chủ dự án chốt

| Mã | Câu hỏi | Đề xuất |
|---|---|---|
| A1 | Type gồm những trường nào? | Tên Type, mã Type, mô tả. Thêm trường khác khi cần. |
| A2 | Instance và Type cùng có giá trị một trường thì lấy bên nào? | Giữ giá trị của Instance (đã đặt riêng); để trống thì lấy Type. |
| A3 | Component cũ chưa có Type thì xử lý thế nào? | Để trống, không tự sinh Type. |
| B1 | Danh sách hệ phân loại lưu trong từng file hay chung trên máy? | Trong từng file (giống Tầng và Phòng), để file gửi đi vẫn đúng. |
| B2 | Mã phân loại gắn ở Type hay ở Instance? | Ở Type khi có, không có thì ở Instance. |
| B3 | Bạn có file mã IFC hoặc OmniClass không? Nếu có, gửi để tôi xem cấu trúc. | Chưa có thì làm hệ tùy chỉnh trước. |

## 4. Kiểm chứng dự kiến

- Test Ruby: Type đọc được từ Instance cùng định nghĩa; sửa Type đổi mọi Instance; group không có Type; file cũ không có Type không lỗi; nhập Excel sai dữ liệu bị từ chối.
- Test Playwright: cột Type hiện đúng; nút sửa Type gọi đúng lệnh.
- **Chưa xác minh trong SketchUp thật:** định nghĩa dùng chung và Make Unique; hiệu năng với model có nhiều Instance.
