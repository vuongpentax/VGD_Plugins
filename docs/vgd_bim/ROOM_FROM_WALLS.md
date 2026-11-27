# VGD_BIM — Phòng: khối 3D và khoanh vùng từ tường (đặc tả, cột mốc 2)

Trạng thái: **đã chốt hướng ngày 19/11/2026** (chủ dự án: BIM làm cả khối 3D và dò vùng phòng từ tường; không giao VGD Structure). Mục 5 còn điểm mở cần chốt trước khi code phần dò.

## 1. Mục tiêu

Người dùng khoanh vùng một phòng theo hai cách:
- **Từ mặt sàn đã chọn** (đã có từ 1.1.1-beta.3): chọn mặt sàn, tạo phòng.
- **Từ tường** (mới): chọn các tường bao quanh, BIM tìm các vùng kín giữa tường, cho xem trước rồi mới tạo phòng.

Mỗi phòng có thể dựng **khối 3D** (đã có trong VGD_Room, nay nhập vào BIM): khung dây (chỉ cạnh) của viền phòng từ sàn lên trần (từ 1.1.1-beta.50, để mặt cắt SketchUp không bị ảnh hưởng).

## 2. Khối 3D của phòng (nhập từ VGD_Room)

- Khối là một **Group** trên tag `VGD_ROOMS`, vật liệu trong suốt, đặt tên theo nhãn phòng.
- Dựng lại thì thay khối cũ và **giữ VGD ID** cũ. Khối bị khóa thì báo và không dựng.
- Dựng một phòng hoặc nhiều phòng; mỗi lần dựng là **một bước hoàn tác**; lỗi thì hủy cả thao tác.
- Đánh dấu khối bằng dictionary `VGD_BIM_SOURCE` (`kind = room`, `ref` = mã phòng). Bảng khối lượng bỏ khối này (đã có).
- Không còn cầu nối `room_volume`: BIM gọi trực tiếp module `core/room_volume.rb`.

## 3. Dò vùng phòng từ tường (mới)

**Đầu vào:** các tường đang chọn trong SketchUp (group, component hoặc mặt đứng chứa tường). Chỉ đọc hình học.

**Các bước:**
1. **Lấy đoạn tường ở độ cao cắt.** Với mỗi mặt đứng, tính giao tuyến với mặt phẳng nằm ngang ở độ cao cắt. Mặc định **2400 mm** (trên đầu cửa đi), người dùng đổi được. Đây là phép tính toán học trên đỉnh và cạnh, không tạo hình trong model.
2. **Tìm vùng kín.** Gộp các đoạn giao tuyến thành đồ thị phẳng (tách đoạn tại các điểm giao), duyệt các mặt kín; bỏ mặt bao ngoài vô hạn.
3. **Loại khoảng trong tường.** Hai mặt của một bức tường tạo ra vùng hẹp giữa hai đường song song. Vùng có bề rộng nhỏ hơn ngưỡng **350 mm** (hằng số có chú thích) được coi là tường, không phải phòng.
4. **Xem trước.** Hiện danh sách vùng (diện tích, số đỉnh, lỗ nếu có) và các vùng bị bỏ kèm lý do. Người dùng bỏ tick vùng không cần rồi bấm **Tạo**.
5. **Tạo.** Ghi qua `Rooms.write` trong một thao tác. Tên và mã theo quy tắc đã có.

**Chốt:**
- **Vùng không kín (có chỗ hở tường):** bỏ qua và báo rõ; không tạo phòng từ vùng hở (chủ dự án đã chọn ngày 12/11 đến 19/11).
- **Tường chọn:** chỉ các tường đang chọn (không quét cả tầng), vì model lớn sẽ chậm và khó chọn đúng. Đây là phương án đề xuất; xem mục 5.

**Không làm:** không sửa tường, không thêm hình học vào model ở bước dò (chỉ tạo phòng khi bấm Tạo, và khối 3D khi bấm Dựng).

## 4. Hợp đồng dữ liệu và kiểm tra

- Thuật toán (đồ thị phẳng, duyệt mặt, loại khoảng trong tường) viết **thuần Ruby** trong `core/room_detect.rb`, không gọi SketchUp, để test bằng Ruby thường.
- Phần đọc SketchUp (tường đang chọn, giao tuyến, tọa độ thế giới qua `context_transform`) nằm trong `core/room_detect_probe.rb` và `ui/dialog.rb`.
- Viền ra đúng định dạng `Rooms.boundary!`; viền tự cắt hoặc quá nhỏ bị từ chối như cũ.

## 5. Điểm còn mở (cần chốt trước khi code phần dò)

| Mã | Câu hỏi | Đề xuất |
|---|---|---|
| D1 | Chọn tường: chỉ đang chọn, hay toàn bộ tường của tầng? | Đang chọn (nhẹ, dễ kiểm soát). |
| D2 | Độ cao cắt mặc định | 2400 mm, người dùng đổi trong hộp xem trước. |
| D3 | Ngưỡng độ dày tường để loại khoảng trong tường | 350 mm, chỉnh được trong hộp xem trước. |
| D4 | Cửa cao hơn độ cao cắt (cửa đi trần, cửa kính lớn) | Tường tại đó sẽ hở; cảnh báo khi có đoạn hở và đề nghị đổi độ cao cắt. |

## 6. Rủi ro

| Rủi ro | Cách giảm |
|---|---|
| Tường cong | Giao tuyến là đoạn thẳng gần đúng; ghi rõ trong xem trước. |
| Nhóm lồng nhau | Dùng `context_transform` có sẵn; test với model lồng. |
| Khoảng hở lớn | Vùng không kín bị loại và báo; không gộp với bên ngoài. |
| Phòng hẹp bị coi là tường | Ngưỡng D3 có chú thích, chỉnh được; test riêng cho hành lang hẹp. |
| Khối 3D chồng lên model người dùng | Chỉ dựng khi bấm, trên tag riêng, một bước hoàn tác, không đè khối bị khóa. |

## 7. Kiểm chứng dự kiến

- Test Ruby thuần: hình vuông; vách chia đôi; hai phòng thông nhau qua cửa (hở nhỏ, báo); khoảng hở lớn; hành lang hẹp; vùng lồng; vách chéo; tường cao hơn độ cao cắt.
- Test Ruby: dựng khối (tạo, dựng lại giữ VGD ID, khối khóa, nhiều phòng một bước hoàn tác, lỗi hủy cả đợt) với model giả lập.
- Test Playwright: hộp xem trước vùng, bỏ tick, nút Tạo và Dựng gọi đúng lệnh.
- **Chưa xác minh trong SketchUp thật:** giao tuyến trên model thật, nhóm lồng, hiệu năng, hoàn tác.
