# Hướng dẫn kiểm tra VGD BIM trên SketchUp (bản 1.1.1-beta.24)

Tài liệu này dành cho người kiểm tra không cần biết lập trình. Làm theo đúng thứ tự, mỗi bước ghi **Đạt**, **Lỗi** hoặc **Không làm được** (kèm lý do). Các bước đã được tự động hóa trong máy (test Ruby và Playwright) nhưng **chưa được chạy trong SketchUp thật**, nên phần này là bước xác nhận cuối.

Thời gian ước tính: khoảng 2 đến 3 giờ cho toàn bộ. Có thể làm theo từng phần, ghi kết quả vào mục 9.

---

## 0. Chuẩn bị (làm một lần)

1. **Dùng bản sao.** Không kiểm tra trên file công trình thật. Sao chép file đó, rồi mở bản sao.
2. **Cài đúng bản.** Lấy file `VGD_BIM_v1.1.1-beta.24.rbz` (kèm mã SHA-256 đã gửi). Trong SketchUp: **Window → Extension Manager → Install Extension**, chọn file. Khởi động lại SketchUp.
3. **Kiểm tra file cài.** Mở `Extensions → VGD → VGD BIM`. Phải thấy hai mục: **Mở bảng khối lượng** và **Tải lại code**.
4. **Bật Ruby Console** để xem thông báo chi tiết: **Window → Ruby Console**. Khi có lỗi, dòng bắt đầu bằng `[VGD BIM]` là thông tin cần gửi lại.
5. **Chuẩn bị model thử** (file SketchUp riêng, lưu thành `kiem_tra_bim.skp` trong một thư mục mới):
   - 3 group tủ, tên khác nhau (ví dụ "Tủ A", "Tủ B", "Bàn C"), gán 3 tag khác nhau.
   - 1 group cha chứa 2 group con (dùng để kiểm tra group lồng nhau).
   - 1 mặt sàn phẳng hình chữ nhật (dùng để tạo phòng).
   - Ít nhất 30 group nhỏ (dùng để kiểm tra cuộn bảng; có thể copy nhanh).
   - Lưu file (Ctrl+S) trước khi kiểm tra. Nhiều tính năng cần file đã lưu.
6. **Thư mục dữ liệu.** Khi kiểm tra ảnh và cài đặt, file phụ được ghi vào thư mục cạnh file `.skp` có đuôi `_VGD_BIM`. Nhớ vị trí này.

**Quy ước ghi kết quả:** Mỗi bước có **Kết quả đúng** để so sánh. Không đạt thì ghi mã bước, chụp màn hình, và ghi lại thông báo đỏ hoặc chữ thấy được.

---

## 1. Cài đặt và cơ bản (ưu tiên cao)

**1.1 Mở bảng.** Chọn một group "Tủ A" trong SketchUp. Mở `Extensions → VGD → VGD BIM → Mở bảng khối lượng`.
- Kết quả đúng: cửa sổ mở, bảng có dòng "Tủ A", không có lỗi đỏ.

**1.2 Chọn đối tượng.** Chọn cả 3 tủ trong SketchUp.
- Kết quả đúng: bảng có 3 dòng, dòng được đánh dấu khớp với lựa chọn.

**1.3 Đổi tên bằng bảng.** Nhấp đúp ô Tên của "Tủ A", đổi thành "Tủ A2", Enter.
- Kết quả đúng: tên đổi trên bảng và trong SketchUp (nhìn bảng tên). Ctrl+Z hoàn tác được một bước.

**1.4 Tải lại code.** Mở `Extensions → VGD → VGD BIM → Tải lại code`.
- Kết quả đúng: hộp thoại "Đã tải lại VGD BIM 1.1.1-beta.24." Không có mục menu nào bị nhân đôi.

---

## 2. Bảng khối lượng: sửa dữ liệu và tìm kiếm

**2.1 Mã đối tượng không trùng (beta.22).** Dùng cột Mã đối tượng (bật trong Chọn cột nếu chưa có).
- Đặt "Tủ A" thành `TB01`, rồi "Tủ B" thành `TB01`.
- Kết quả đúng: lần thứ hai báo lỗi "Mã TB01 đã có ở món khác trong bảng". "Tủ B" không đổi mã.
- Thử đặt "tb01" (chữ thường) cho "Tủ B": cũng phải báo lỗi.

**2.2 Tìm không phân biệt dấu (beta.18).** Ô "Tìm trong bảng": gõ `ban` (không dấu).
- Kết quả đúng: thấy dòng "Bàn C". Gõ `BAN` cũng thấy.

**2.3 Chọn cột và loại trừ tag (beta.18).** Mở **Chọn cột**, gõ `mo ta` (không dấu) rồi thử ngăn **Loại trừ tag**, gõ tên tag không dấu.
- Kết quả đúng: danh sách lọc đúng, không cần gõ dấu.

**2.4 Cuộn bảng giữ vị trí (beta.15).** Với bảng có 30 dòng trở lên: cuộn xuống dòng 25, sửa tên một dòng.
- Kết quả đúng: bảng không nhảy về đầu.

**2.5 Thu gọn và gộp dòng (beta.8).** Bật Nhóm theo tên, gộp dòng.
- Kết quả đúng: bấm **Mở tất cả nhóm** và **Thu gọn tất cả** đều chạy đúng.

---

## 3. Sheet: thêm, kéo đổi chỗ, khóa (ưu tiên cao)

**3.1 Thêm sheet.** Bấm nút **+** trên thanh sheet ở chân bảng.
- Kết quả đúng: sheet mới "Sheet2" xuất hiện, bảng giữ nguyên các cột.

**3.2 Kéo đổi chỗ (beta.20).** Kéo tab "Sheet2" sang trái tab "Sheet1".
- Kết quả đúng: tab đổi chỗ; các tab khác trượt nhẹ; sheet đang mở vẫn là sheet vừa kéo. Đóng và mở lại file: thứ tự vẫn giữ.

**3.3 Khóa sheet (beta.21). Đây là bước quan trọng nhất.**
1. Trong Sheet1, chọn đúng 2 group "Tủ A" và "Tủ B" trong SketchUp. Bảng hiện 2 dòng.
2. Bấm nút **🔓** cạnh nút **+**.
3. Kết quả đúng: nút đổi thành **🔒**, tab Sheet1 có dấu khóa, tên tab không đổi.
4. Chọn **"Bàn C"** trong SketchUp (chọn món khác).
5. Kết quả đúng: bảng của Sheet1 **vẫn là 2 dòng "Tủ A" và "Tủ B"**, không đổi sang "Bàn C".

**3.4 Chuyển qua lại sheet khóa.**
1. Bấm tab **Sheet2** (sheet thường), rồi chọn "Bàn C" trong SketchUp.
2. Kết quả đúng: Sheet2 hiện "Bàn C" (theo lựa chọn).
3. Bấm lại tab **Sheet1**.
4. Kết quả đúng: Sheet1 vẫn hiện "Tủ A" và "Tủ B".

**3.5 Mở khóa.** Ở Sheet1, bấm nút **🔒**.
- Kết quả đúng: nút về 🔓; sheet theo lựa chọn trở lại.

**3.6 Khóa qua lần mở file (beta.21).** Khóa Sheet1 lại (làm như 3.3). Lưu file, đóng SketchUp, mở lại file, mở bảng.
- Kết quả đúng: Sheet1 vẫn là các món đã khóa, nút vẫn 🔒.

**3.7 Món đã xóa khỏi model.** Khi Sheet1 đang khóa "Tủ A" và "Tủ B": xóa "Tủ B" trong SketchUp.
- Kết quả đúng: bảng còn 1 dòng và thông báo "Có 1 đối tượng đã khóa không còn trong model". Không báo lỗi đỏ.

**3.8 Sao chép sheet không kế thừa khóa.** Khi Sheet1 đang khóa, bấm **+**.
- Kết quả đúng: sheet mới KHÔNG có dấu khóa.

---

## 4. Xuất Excel và PDF (ưu tiên cao)

**4.1 Xuất một sheet (beta.9).** Có ít nhất 3 dòng. Bấm **Công cụ → Xuất Excel**, lưu file.
- Kết quả đúng: hiện hộp thoại "Đã xuất file" với hai nút **Xem ngay** và **Mở thư mục chứa file**, và nút **Đóng**. Bấm **Xem ngay**: file mở trong Excel.

**4.2 Xuất PDF không hiện hộp này (beta.9).** Bấm **In PDF**.
- Kết quả đúng: trang báo cáo mở trong trình duyệt; không xuất hiện hộp "Đã xuất file".

**4.3 Xuất nhiều sheet có sheet khóa (beta.21).** Có Sheet1 (đang khóa "Tủ A", "Tủ B") và Sheet2 (theo lựa chọn). Bấm **Xuất Excel**.
- Kết quả đúng: file Excel có 2 trang tính. Trang Sheet1 có đúng "Tủ A" và "Tủ B". Trang Sheet2 có các món đang chọn.

**4.4 Gộp dòng vẫn xuất đủ món (beta.8).** Gộp một nhóm dòng rồi xuất Excel.
- Kết quả đúng: file xuất có đủ mọi món, kể cả món đang gộp.

**4.5 Chiều cao hàng và ảnh.** Chỉnh chiều cao hàng (Ctrl + lăn chuột), xuất Excel.
- Kết quả đúng: hàng và ảnh trong Excel cao gần bằng trên bảng (xem bằng mắt, không cần đo).

---

## 5. Preset (ưu tiên trung bình)

**5.1 Tạo preset.** Bấm nút **Preset** trên thanh đầu. Gõ "Thử 1" vào ô "Tạo mới...", bấm **+**.
- Kết quả đúng: "Thử 1" có trong danh sách và được chọn.

**5.2 Cột tự cập nhật.** Ở "Thử 1", bật thêm một cột (Chọn cột).
- Kết quả đúng: preset tự cập nhật (mở lại preset, cột vẫn có).

**5.3 Cập nhật từ bảng hiện tại (beta.19).** Ở "Thử 1", bỏ bớt một cột, rồi bấm **Cập nhật từ bảng hiện tại** trong khối **Đang chọn**.
- Kết quả đúng: thông báo "Đã lưu preset", cột đúng như bảng hiện tại.

**5.4 Xóa preset (beta.19).** Bấm **Xóa preset này**.
- Kết quả đúng: "Thử 1" biến mất khỏi danh sách; bảng chuyển sang preset khác.

**5.5 Preset có sẵn (beta.19).** Chọn một preset có sẵn (ví dụ "Tất cả").
- Kết quả đúng: khối "Đang chọn" chỉ hiện ghi chú "Preset có sẵn không sửa hay xóa được"; không có nút Cập nhật / Xóa.

**5.6 Cột thêm tay qua file JSON (beta.17).** Có một cột thêm tay (kiểu Thuộc tính hoặc Cột tự nhập). Xuất preset JSON. Mở file khác, nhập preset.
- Kết quả đúng: cột thêm tay có trong bảng file mới với đúng tên.

---

## 6. Ảnh (ưu tiên trung bình)

**6.1 Chụp ảnh Iso.** Chọn "Tủ A", bấm **Cập nhật ảnh** rồi xác nhận.
- Kết quả đúng: ảnh xuất hiện trong cột Ảnh. Trong thư mục `_VGD_BIM` có file PNG của món.

**6.2 Chụp không làm đổi model.** Trước và sau khi chụp, kiểm tra không có bước hoàn tác mới và model không đổi vị trí món.
- Kết quả đúng: không có món nào bị dời hay ẩn sau khi chụp.

**6.3 Dán ảnh (beta.16).** Copy một ảnh PNG (chụp màn hình), bấm **Dán ảnh từ clipboard** ở ô ảnh.
- Kết quả đúng: ảnh được dán, hoặc thông báo rõ lý do (đã ghi chi tiết lỗi của trình duyệt). Không thấy thông báo "lỗi chung chung".

**6.4 Ảnh 3 và Ảnh 4 (beta.73).** Bật cột Ảnh 3 trong Chọn cột, bấm chụp.
- Kết quả đúng: ảnh thứ 3 chụp theo góc khác; ảnh chính không đổi.

**6.5 Tải lại khi đang chụp (beta.22).** Chọn 10 món, bấm **Cập nhật ảnh** rồi xác nhận. Ngay khi đang chụp, vào `Extensions → VGD → VGD BIM → Tải lại code`.
- Kết quả đúng: hộp thoại báo "Tải lại thất bại: VGD BIM đang chụp ảnh. Hãy chờ xong rồi tải lại code." Không tải lại. Sau khi chụp xong, bấm lại thì tải lại được.

---

## 7. Group lồng nhau và vị trí (ưu tiên cao, beta.22)

**7.1 Mở group cha, chọn món con.** Nhấp đúp vào group cha chứa 2 group con (đang mở sửa). Chọn một group con.
- Kết quả đúng: bảng hiện đúng dòng món con; khung đánh dấu bao đúng món (xem bằng mắt, không lệch xa món).

**7.2 Tab Thông tin trong group.** Với món con đang chọn, mở tab **Thông tin**.
- Kết quả đúng: thông tin đúng món đó (tên, kích thước) và không báo lỗi.

**7.3 Kiểm tra trong group.** Mở tab **Kiểm tra**, chọn món con.
- Kết quả đúng: kết quả kiểm tra đúng món con, không lẫn món khác.

**7.4 Quét theo lựa chọn trong group.** Ở tab **Quét & xuất** (chế độ theo lựa chọn), chọn món con rồi quét.
- Kết quả đúng: số dòng và vị trí đúng. Không báo lỗi.

Ghi chú: mục này cần kiểm tra trên SketchUp 2024 hoặc 2025 (nơi lỗi cũ xảy ra), nếu bạn có.

---

## 8. Tag, phòng và khối lượng (ưu tiên trung bình)

**8.1 Tô màu theo tag (beta.23).** Ở tab **Soạn tag → Trong model**, bấm **Tô màu theo tag** (bật) rồi tắt lại.
- Kết quả đúng: SketchUp đổi màu theo tag khi bật. Bấm **Ctrl+Z** một lần: quay về trạng thái trước đó, chỉ một bước.

**8.2 Tạo phòng.** Chọn mặt sàn phẳng, mở **Quản lý phòng**, bấm **Tạo phòng từ mặt đang chọn**.
- Kết quả đúng: phòng có tên, diện tích, chu vi, thể tích. Dòng "Tường (chưa trừ cửa) … m²" hiện đúng nhãn (beta.23).

**8.3 Dựng khối (beta.13).** Bấm **Dựng khối** cho phòng.
- Kết quả đúng: khối 3D xuất hiện trên tag `VGD_ROOMS`. Ctrl+Z hoàn tác được một bước.

**8.4 Cập nhật viền từ mặt (beta.14).** Vẽ thêm mặt sàn khác, chọn nó, bấm **Cập nhật viền từ mặt đang chọn** cho phòng.
- Kết quả đúng: viền phòng đổi theo mặt mới; tên, mã giữ nguyên; khối 3D cũ KHÔNG đổi cho đến khi bấm **Dựng lại khối**.

**8.5 Khối phòng trong group lồng (beta.23).** Đưa khối phòng vào một group (cắt và dán vào group), rồi bấm **Dựng lại khối**.
- Kết quả đúng: chỉ có một khối cho phòng đó (không có bản trùng).

**8.6 Khối lượng ước tính (beta.23).** Chọn một tường vẽ đơn giản (không có VGD Structure), xem cột ghi chú khối lượng.
- Kết quả đúng: diện tích tường có ghi chú "ước tính theo khối bao".

---

## 9. Kiểm tra, luật, so sánh phiên bản (ưu tiên thấp)

**9.1 Luật kiểm tra theo nhóm (beta.11).** Đặt một luật chỉ áp dụng cho một nhóm hạng mục, chạy kiểm tra.
- Kết quả đúng: chỉ món đúng nhóm bị kiểm tra.

**9.2 So sánh phiên bản theo file (beta.12, beta.72).** Chụp một mốc trong file A. Mở file B, mở **So sánh phiên bản**.
- Kết quả đúng: không thấy mốc của file A trong file B.

**9.3 Cài đặt riêng theo file (beta.72).** Đổi thư mục ảnh hoặc loại trừ tag ở file A, mở file B.
- Kết quả đúng: file B dùng cài đặt mặc định, không dính cài đặt của file A.

---

## 10. Kết thúc: sao lưu và ghi lại

1. **Lưu và đóng** file thử, mở lại, kiểm tra một lần nữa bảng và sheet.
2. Nếu có lỗi nào, gửi kèm:
   - Mã bước (ví dụ "3.3").
   - Ảnh màn hình.
   - Nội dung Ruby Console các dòng bắt đầu bằng `[VGD BIM]`.
   - File nhật ký chụp ảnh: `%APPDATA%\VGD\VGD_BIM\capture.log` (nếu có lỗi chụp).
3. Điền bảng dưới đây, rồi gửi lại.

---

## Bảng kết quả

| Mã | Nội dung ngắn | Kết quả (Đạt / Lỗi / Không làm được) | Ghi chú |
|---|---|---|---|
| 1.1–1.4 | Cài đặt, mở bảng, chọn, đổi tên, tải lại | | |
| 2.1 | Mã đối tượng không trùng | | |
| 2.2–2.3 | Tìm không dấu, Chọn cột | | |
| 2.4 | Cuộn giữ vị trí | | |
| 2.5 | Nhóm / thu gọn | | |
| 3.1–3.2 | Thêm sheet, kéo đổi chỗ | | |
| 3.3–3.5 | Khóa sheet, chuyển qua lại, mở khóa | | |
| 3.6–3.8 | Khóa qua lần mở file, món đã xóa, sao chép | | |
| 4.1–4.5 | Xuất Excel, PDF, nhiều sheet, gộp dòng | | |
| 5.1–5.6 | Preset (tạo, cập nhật, xóa, cột thêm tay) | | |
| 6.1–6.5 | Ảnh (chụp, dán, Ảnh 3, tải lại khi chụp) | | |
| 7.1–7.4 | Group lồng nhau, vị trí | | |
| 8.1–8.6 | Tô màu tag, phòng, khối, khối lượng | | |
| 9.1–9.3 | Luật, so sánh, cài đặt riêng file | | |
