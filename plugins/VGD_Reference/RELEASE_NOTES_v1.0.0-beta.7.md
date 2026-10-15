# VGD Reference 1.0.0-beta.7

## Thay đổi

- Kéo trực tiếp ảnh từ Pinterest và các website vào bảng VGD Reference; nhận file ảnh, nguồn ảnh trong HTML, URL ảnh và link trang công khai có metadata ảnh.
- Ưu tiên ảnh gốc Pinterest khi có thể, giữ URL ảnh đã kéo làm phương án tiếp theo.
- Mở rộng bộ giải mã: thử SketchUp trước, chuyển qua trình duyệt HtmlDialog và codec Windows khi cần. Bổ sung WebP, GIF, AVIF, SVG, ICO, HEIC/HEIF và các định dạng máy có codec phù hợp.
- Chuyển ảnh cần thiết sang PNG tạm để hình thu nhỏ và lớp phủ cùng hiển thị được. Giữ tên gốc, giữ alpha khi bộ giải mã hỗ trợ; ảnh động lấy một khung hình tĩnh.
- Truyền dữ liệu theo từng gói có xác nhận, tải web/chuyển đổi Windows ở nền, hủy lượt nhập khi đổi model hoặc đóng bảng và dọn các file tạm do plugin tạo.
- Nút chính khi bảng hẹp chỉ hiện icon kèm chú thích rê chuột; khi rộng từ 420 px hiện tên và mô tả ngắn.
- Giữ bản sửa hiển thị ảnh đầy đủ bằng UV dạng mảng, giao diện tiếng Việt và icon/theme beta.6.

## Giới hạn và cài đặt

- SketchUp 2023 trở lên trên Windows; SketchUp 2022 chưa được hỗ trợ.
- Tối đa 20 MiB mỗi ảnh đầu vào, 32 triệu pixel và 64 MiB PNG sau chuyển đổi.
- HEIC/HEIF và định dạng riêng cần codec phù hợp. Không cam kết mọi file PSD/RAW hoặc mọi định dạng ảnh trên mọi máy.
- Link trang yêu cầu đăng nhập hoặc chặn tải có thể không dùng được; hãy kéo trực tiếp ảnh hoặc tải file rồi thả.
- Cài `VGD_Reference_v1.0.0-beta.7.rbz` bằng Extension Manager và khởi động lại SketchUp. Script nạp bản sửa UV cũ không cập nhật đầy đủ tính năng beta.7.

## Bằng chứng hiện có

Đã rà mã nguồn, biên dịch cú pháp Ruby/JavaScript/PowerShell và đối chiếu từng file trong RBZ/source ZIP với nguồn. Chưa chạy phép thử tính năng mới hoặc thử kéo ảnh trong SketchUp. Xác nhận của người dùng về ảnh hiển thị đầy đủ trong SU2024 áp dụng cho bản sửa UV beta.5; kiểm tra icon/giao diện beta.6 là kết quả lịch sử.
