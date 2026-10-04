> Lịch sử: đặc tả này đã được thay thế bởi DIMENSION_TEXT_REFERENCE.rb ngày 2026-10-02. Không dùng để mở rộng bản đơn giản hiện tại.

# VGD ANNOTATION MANAGER

Plugin quản lý và chuẩn hóa toàn bộ **Dimension – Text – Label** trong SketchUp.

Mục tiêu là thay thế các thao tác liên quan đến Dim/Text trong **Model Info**, đồng thời giải quyết tình trạng file nhận từ người khác có Dim, Text và Label bị lộn xộn về font, kích thước, màu sắc và cách hiển thị.

## 1. DIMENSION SETTINGS

Cho phép thiết lập nhanh định dạng Dimension theo tiêu chuẩn mong muốn:

- Font chữ.
- Size chữ.
- Cho phép nhập size theo `pt` hoặc `mm`.
- Màu chữ / màu Dimension.
- Kiểu đầu mũi tên.
- Kích thước đầu mũi tên.
- Khoảng cách chữ với đường Dim.
- Hiển thị đơn vị.
- Precision / số chữ số thập phân.
- Cách hiển thị đơn vị:
  - mm
  - cm
  - m
  - inch
  - theo Units hiện tại của model.
- Căn chỉnh chữ Dimension.
- Các thiết lập cơ bản tương đương phần Dimension trong Model Info.

Có nút:

**Apply Dimension Style**

để áp toàn bộ setting hiện tại cho Dimension trong phạm vi được chọn.

---

# 2. TEXT SETTINGS

Cho phép quản lý Text thông thường:

- Font.
- Font size.
- Size theo `pt` hoặc `mm`.
- Màu chữ.
- Kiểu hiển thị chữ.
- Căn chỉnh cơ bản nếu SketchUp hỗ trợ.
- Thiết lập chiều cao chữ thống nhất.

Có nút:

**Apply Text Style**

để chuẩn hóa toàn bộ Text.

---

# 3. LABEL SETTINGS

Label được hiểu là Text có Leader.

Cho phép chỉnh:

- Font.
- Size.
- Màu.
- Kiểu Leader.
- Kiểu đầu mũi tên.
- Kích thước đầu mũi tên.
- Cách hiển thị Label.

Có nút:

**Apply Label Style**

để chuẩn hóa toàn bộ Label.

---

# 4. NORMALIZE ANNOTATIONS

Đây là chức năng quan trọng nhất của plugin.

Khi nhận file SketchUp từ người khác, trong model có thể tồn tại rất nhiều loại:

- Dim font khác nhau.
- Dim size khác nhau.
- Text lớn nhỏ không đồng nhất.
- Label dùng nhiều kiểu Leader.
- Dim nằm sâu trong Group.
- Dim nằm trong Component.
- Annotation copy từ nhiều file khác nhau.
- Annotation sử dụng setting cũ của model khác.

Plugin có nút:

**NORMALIZE**

Plugin sẽ quét toàn bộ:

`Model → Group → Component → Nested Group / Component`

và tìm:

- Dimension
- Text
- Label

Sau đó chuyển chúng về **một Style chuẩn do người dùng thiết lập**.

Ví dụ:

File nhận về đang có:

`Arial 8pt`  
`Tahoma 10pt`  
`Calibri 12pt`  
`Arial 2.5mm`  
Dim đỏ  
Dim xanh  
Label nhiều loại arrow khác nhau

Sau khi chạy:

**NORMALIZE → VGD STANDARD**

toàn bộ được chuyển thành:

`Arial`  
`2.5 mm`  
`Black`  
`Arrow Closed`  
`Precision 0 mm`

mà không cần chỉnh từng đối tượng.

---

# 5. PHẠM VI ÁP DỤNG

Cho phép chọn phạm vi:

**Selected**

Chỉ xử lý các đối tượng đang chọn.

**Current Context**

Xử lý toàn bộ Annotation trong Group / Component đang mở.

**Entire Model**

Quét toàn bộ model, kể cả Dimension/Text nằm sâu trong Group và Component.

Có thêm tùy chọn:

☑ Include Nested Groups  
☑ Include Components  
☑ Include Hidden Objects  
☑ Include Locked Objects

Mặc định:

`Include Nested Groups = ON`

---

# 6. PRESET STYLE

Cho phép lưu các bộ Setting.

Ví dụ:

**VGD Working**

Dim:
- Arial
- 10 pt
- Black

Text:
- Arial
- 10 pt

Label:
- Arial
- 10 pt

**VGD Layout**

Dim:
- Arial
- 2.5 mm

Text:
- Arial
- 2.5 mm

Người dùng có thể:

`Save Preset`

`Load Preset`

`Update Preset`

`Delete Preset`

---

# 7. QUICK FIX

Có một khu vực dành cho xử lý nhanh file nhận từ bên ngoài.

### FIX ALL DIMENSIONS

Chỉ chuẩn hóa Dimension.

### FIX ALL TEXT

Chỉ chuẩn hóa Text.

### FIX ALL LABELS

Chỉ chuẩn hóa Label.

### FIX ALL

Chuẩn hóa toàn bộ Dimension + Text + Label.

---

# 8. SCAN MODEL

Trước khi chỉnh sửa, plugin có thể Scan model và báo:

**DIMENSION**

Found: 326

**TEXT**

Found: 147

**LABEL**

Found: 82

**Nested annotations**

Found: 194

Sau đó người dùng mới quyết định Apply.

Không cần liệt kê từng entity để giao diện luôn nhẹ.

---

# 9. GIAO DIỆN

Giao diện dạng một cửa sổ nhỏ:

### DIMENSION
Font  
Size  
Color  
Arrow  
Units  
Precision

### TEXT
Font  
Size  
Color

### LABEL
Font  
Size  
Color  
Leader  
Arrow

### SCOPE
○ Selected  
○ Current Context  
● Entire Model

☑ Nested Groups  
☑ Components

### PRESET
`VGD STANDARD ▼`

### ACTION

`SCAN`

`APPLY`

`NORMALIZE ALL`

Giao diện ưu tiên nhanh, gọn, không cần mô phỏng toàn bộ Model Info của SketchUp.

---

# 10. NGUYÊN TẮC XỬ LÝ

Plugin chỉ thay đổi **thuộc tính hiển thị Annotation**.

Không:

- Move Dimension.
- Xóa Dimension.
- Thay đổi vị trí điểm đo.
- Thay đổi nội dung Text.
- Move Label.
- Explode Group.
- Explode Component.
- Thay đổi Geometry.
- Thay đổi Tag của đối tượng nếu người dùng không yêu cầu.

Mục tiêu là:

**GIỮ NGUYÊN NỘI DUNG + VỊ TRÍ → CHỈ CHUẨN HÓA FORMAT**

---

# 11. UNDO

Mọi thao tác Apply hoặc Normalize phải nằm trong **một Undo Operation** của SketchUp.

Ví dụ:

`Ctrl + Z → Undo VGD Annotation Normalize`

Toàn bộ thay đổi quay lại trạng thái trước khi chạy.

---

# 12. MỤC TIÊU CUỐI

Plugin này không cần thay thế toàn bộ Model Info.

Nó chỉ tập trung vào workflow:

**NHẬN FILE → SCAN → CHỌN STYLE VGD → NORMALIZE → XONG**

Đặc biệt phù hợp khi nhận SketchUp từ:

- Kiến trúc sư khác.
- Outsource.
- File khách hàng.
- File SketchUp cũ.
- File copy từ nhiều dự án.

Thay vì phải vào Model Info và xử lý thủ công từng loại Annotation, toàn bộ Dim – Text – Label của file sẽ được đưa về đúng tiêu chuẩn của VGD chỉ bằng một thao tác.