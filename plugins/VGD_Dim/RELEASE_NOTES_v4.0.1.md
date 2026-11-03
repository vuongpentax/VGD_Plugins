# VGD Dim 4.0.1

Bản sửa lỗi cho 4.0.0.

- Sửa gói cài đặt thiếu thư mục `vgd-theme/`: giao diện sai màu/font và dialog không nhận dữ liệu khi cài từ RBZ hoặc cập nhật tự động. Danh sách file của gói và của trình cập nhật khớp nhau.
- Auto-Style: không còn lỗi `reference to deleted Group/ComponentDefinition` khi lệnh khác (ví dụ Offset) tạo rồi xóa nhóm tạm; bỏ lag do quét lại toàn bộ component; chỉnh form không gắn lại observer trên cả model; tắt Auto-Style luôn được dù form đang có giá trị không hợp lệ.
- Dim thủ công không bị Auto-Style ghi đè style.
- Dialog được mở khóa khi đổi sang công cụ khác lúc đang Dim thủ công hoặc chọn Boundary/Detail.
- Trình cập nhật: kiểm tra năm SketchUp tối thiểu bằng `Sketchup.version`; không mất thông báo lỗi mạng/timeout; yêu cầu thứ hai không làm mất cờ bận của yêu cầu đang chạy; helper xóa thư mục tạm chứa RBZ đã tải.
- Làm mới font/size báo lý do lỗi đầu tiên khi có Dim không làm mới được.
- Xóa nhánh code không bao giờ chạy trong Smart Dim.

Kiểm tra: tự động bằng mô phỏng (cú pháp Ruby, các test trong dev/ chạy với SketchUp giả lập). Chưa kiểm thử trong SketchUp thật; helper PowerShell sửa ở bản này chưa chạy được ngoài Windows.
