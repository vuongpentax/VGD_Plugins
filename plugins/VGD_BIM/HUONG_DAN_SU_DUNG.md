# VGD_BIM — Hướng dẫn nhanh

Mở bằng **Extensions → VGD → VGD_BIM**: cửa sổ mở thẳng tab **Bảng khối lượng**. Cửa sổ có 5 tab: Bảng khối lượng · Thông tin · Quét & xuất · Phân loại · Soạn tag. Mọi tab nằm trong cùng một cửa sổ.

## Bóc khối lượng nhanh (Bảng khối lượng)

1. Chọn group hoặc component trong SketchUp. Bảng tự đọc đối tượng đang chọn, không quét cả model.
2. Chọn **preset cột** (Tất cả, Phần thô, Hoàn thiện, Đồ rời) hoặc tự chọn cột, kéo đổi thứ tự, kéo giãn độ rộng cột. Lưu bộ cột của bạn thành preset riêng; bảng nhớ lại cột và thứ tự khi mở lại SketchUp.
3. Bấm một ô: đối tượng được đánh dấu trong SketchUp bằng khung nét đứt và khung tên. Bấm ô **Tên** thì khung hiện tên, bấm ô **Mô tả** thì hiện mô tả; bấm cả dòng thì hiện tên, mô tả, tình trạng và phân loại. Nhấn **Esc** để tắt khung. Khi khung đang bật, Shift/Ctrl-chọn nhiều, kéo chọn và nhấp đúp vào group không dùng được; nhấn Esc hoặc chọn công cụ khác rồi thao tác.
4. Sửa trực tiếp **Tên**, **Mô tả**, **Tình trạng** (Mới, Hiện hữu, Dùng lại, Tạm thời, Loại bỏ) ngay trong bảng. Đối tượng bị khóa không sửa được.
5. Tuỳ chọn ở thanh công cụ: **Thu phóng**, **Cô lập đối tượng chọn** (tạm ẩn các đối tượng khác; tắt tuỳ chọn hoặc đóng cửa sổ để hiện lại, và đừng lưu file khi đang cô lập), **Chọn sâu bên trong** (đọc cả group / component nằm bên trong), dòng **Tổng cộng**, **Tổng chỉ cấp cao nhất** (không cộng trùng group lồng nhau).

Lưu ý: diện tích (X*Z), (X*Y) tính theo khung bao của đối tượng; thể tích chỉ có cho group kín. Số liệu chưa trừ hao hụt hoặc phần bị che.

## Gắn dữ liệu hạng mục (Thông tin)

1. Chọn nhóm hoặc đối tượng nội thất trong SketchUp rồi mở tab **Thông tin**.
2. Chọn **Mẫu hạng mục**, ví dụ **Tủ áo**, **Tủ bếp dưới**, **Ổ cắm**. Mẫu điền nhóm, loại, đơn vị và cách đo; không tự sửa mô tả của bạn.
3. Đánh dấu **Mô tả tiếng Việt**, nhập tên dùng trong bảng báo giá, ví dụ `Tủ áo phòng ngủ chính`. Điền mã hạng mục, khu vực và tầng nếu cần.
4. Bấm **Áp dụng thông tin**. Chỉ các trường được đánh dấu mới đổi. Chọn nhiều đối tượng để nhập cùng lúc.

Chuột phải vào group hoặc component và chọn **VGD_BIM · Thông tin đối tượng** để mở nhanh tab này.

## Với model của đối tác hoặc model cũ

1. **Quét & xuất** để xem số lượng thành phần và diện tích vật liệu đang có. Có thể quét cả model hoặc chỉ đối tượng đang chọn, và bật / tắt quét mặt để quét nhanh hơn.
2. **Phân loại** để xem gợi ý theo tên. Gợi ý chưa tự ghi vào model.
3. Bấm **Chỉnh thông tin** ở dòng cần làm. Nhập mô tả, mã hạng mục và phân loại phù hợp.
4. Bấm **Xem trước chuyển đổi** để xem số đối tượng bị ảnh hưởng, rồi **Xác nhận chuyển đổi**.
5. Dữ liệu VGD đã có và đối tượng khóa được bảo vệ. Hình học, tên, thẻ và vật liệu giữ nguyên.
6. Trong tab **Phân loại**, mở **Kiểm tra** để xem thông tin còn thiếu. Bấm dòng kết quả để tìm đúng đối tượng cần sửa.

## Xuất báo cáo (Quét & xuất)

Chọn báo cáo rồi chọn vị trí lưu file CSV. File mở bằng Excel, có tiêu đề và tên nhóm hạng mục bằng tiếng Việt.

| Báo cáo | Nội dung |
|---|---|
| Danh mục đối tượng | Mã, mô tả, nhóm, loại, đơn vị, cách đo, khu vực, tầng, nguồn dữ liệu và kích thước từng lần xuất hiện |
| Thống kê thành phần | Số lần xuất hiện theo định nghĩa, tên, thẻ, vật liệu và kích thước mẫu |
| Diện tích vật liệu gốc | Diện tích mặt trước và mặt sau có sơn, tính từ hình học hiện tại |
| Kết quả kiểm tra | Thông tin còn thiếu, lỗi đơn vị và cảnh báo |

Các báo cáo chưa tính đơn giá/thành tiền. Danh mục có cả đối tượng cha và con để kiểm tra dữ liệu; không cộng các dòng thành tổng khối lượng công việc. Diện tích gốc chưa trừ hao hụt hoặc phần bị che. Plugin không đọc cạnh (edge) nên báo cáo không có số cạnh hay chiều dài cạnh.

File CSV dùng UTF-8, dấu chấm phẩy tách cột và dấu phẩy thập phân. Nếu Excel mở chưa đúng, chọn **Dữ liệu → Từ văn bản/CSV**, chọn UTF-8 và dấu chấm phẩy.

## Soạn tag

Tab **Soạn tag** để soạn bộ tag theo nhóm hạng mục (Phần thô, Hoàn thiện, Đồ rời, Thiết bị, Khác), gán tag cho group, component hoặc mặt đang chọn, và xuất / nhập bộ tag bằng CSV (mở được trong Excel) hoặc JSON. Khi nhập, chọn thay thế toàn bộ hoặc gộp vào bộ hiện có. Bộ tag lưu trên máy này.

## Quy tắc phân loại

Trong tab **Phân loại**, mở **Quy tắc → Thêm quy tắc**: chọn loại nguồn, nhập tên nguồn cần khớp, chọn mẫu hoặc nhập thông tin, rồi **Lưu quy tắc**. Xuất / Nhập bộ quy tắc để dùng ở model khác. Mục dữ liệu kỹ thuật được thu gọn, không cần dùng cho thao tác thông thường.

## Cửa sổ và cập nhật

Nút **Sáng / Tối** lưu lựa chọn giao diện trên máy. Sau khi cài đè bản mới, dùng **Extensions → VGD → VGD_BIM · Tải lại code** để nạp lại mã mà không cần mở lại SketchUp; menu và toolbar mới chỉ có tác dụng sau khi mở lại SketchUp. Lưu file đang làm trước khi tải lại.
