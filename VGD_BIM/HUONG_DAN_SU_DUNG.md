# VGD BIM Lite — Hướng dẫn nhanh

## Bắt đầu với model của bạn

1. Chọn nhóm hoặc đối tượng nội thất trong SketchUp.
2. Mở **VGD → BIM Lite → Thông tin đối tượng**.
3. Chọn **Mẫu hạng mục**, ví dụ **Tủ áo**, **Tủ bếp dưới**, **Ổ cắm**. Mẫu điền nhóm, loại, đơn vị và cách đo; không tự sửa mô tả của bạn.
4. Đánh dấu **Mô tả tiếng Việt**, nhập tên dùng trong bảng báo giá, ví dụ `Tủ áo phòng ngủ chính`. Điền mã hạng mục, khu vực và tầng nếu cần.
5. Bấm **Áp dụng thông tin**. Chỉ các trường được đánh dấu mới đổi. Chọn nhiều đối tượng để nhập cùng lúc.
6. Mở **Kiểm tra**. Bấm dòng kết quả để tìm đúng đối tượng cần sửa.
7. Mở **Xuất báo cáo**, chọn báo cáo rồi chọn vị trí lưu file CSV. File mở bằng Excel, có tiêu đề và tên nhóm hạng mục bằng tiếng Việt.

## Với model của đối tác hoặc model cũ

1. **Quét mô hình** để xem số lượng thành phần và diện tích vật liệu đang có.
2. **Phân loại** để xem gợi ý theo tên. Gợi ý chưa tự ghi vào model.
3. Bấm **Chỉnh thông tin** ở dòng cần làm. Nhập mô tả, mã hạng mục và phân loại phù hợp.
4. Bấm **Xem trước chuyển đổi** để xem số đối tượng bị ảnh hưởng, rồi **Xác nhận chuyển đổi**.
5. Dữ liệu VGD đã có và đối tượng khóa được bảo vệ. Hình học, tên, thẻ và vật liệu giữ nguyên.
6. Chạy **Kiểm tra** rồi **Xuất báo cáo**.

## Có thể xuất gì?

| Báo cáo | Nội dung |
|---|---|
| Danh mục đối tượng | Mã, mô tả, nhóm, loại, đơn vị, cách đo, khu vực, tầng, nguồn dữ liệu và kích thước từng lần xuất hiện |
| Thống kê thành phần | Số lần xuất hiện theo định nghĩa, tên, thẻ, vật liệu và kích thước mẫu |
| Diện tích vật liệu gốc | Diện tích mặt trước và mặt sau có sơn, tính từ hình học hiện tại |
| Kết quả kiểm tra | Thông tin còn thiếu, lỗi đơn vị và cảnh báo |

Các báo cáo chưa tính đơn giá/thành tiền. Danh mục có cả đối tượng cha và con để kiểm tra dữ liệu; không cộng các dòng thành tổng khối lượng công việc. Diện tích gốc chưa trừ hao hụt hoặc phần bị che.

File CSV dùng UTF-8, dấu chấm phẩy tách cột và dấu phẩy thập phân. Nếu Excel mở chưa đúng, chọn **Dữ liệu → Từ văn bản/CSV**, chọn UTF-8 và dấu chấm phẩy.

## Một cửa sổ cho mọi tính năng

Các mục trên thanh chức năng và menu SketchUp đều chuyển nội dung trong cùng một cửa sổ. Khi đóng rồi mở lại, plugin tạo lại cửa sổ và kết nối thao tác. Nút **Sáng / Tối** lưu lựa chọn giao diện trên máy.

Trước khi dùng bản 0.1.1, lưu file đang làm và khởi động lại SketchUp để đóng các cửa sổ cũ của bản trước.

## Quy tắc phân loại

Chọn **Quy tắc → Thêm quy tắc**: chọn loại nguồn, nhập tên nguồn cần khớp, chọn mẫu hoặc nhập thông tin, rồi **Lưu quy tắc**. Xuất / Nhập bộ quy tắc để dùng ở model khác. Mục dữ liệu kỹ thuật được thu gọn, không cần dùng cho thao tác thông thường.
