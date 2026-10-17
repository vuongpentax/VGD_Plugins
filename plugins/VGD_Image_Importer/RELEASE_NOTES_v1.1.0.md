# VGD Image Importer 1.1.0

- Kéo ảnh từ trang web vào cửa sổ: plugin tải ảnh bằng SketchUp, không bị chặn bởi CORS như trước.
- Thử lần lượt các liên kết kéo vào (liên kết ảnh trực tiếp, ảnh trong HTML, rồi liên kết trang) và lấy ảnh hợp lệ đầu tiên.
- Nhận dạng định dạng ảnh theo nội dung file, không tin kiểu dữ liệu do máy chủ khai báo.
- Chỉ tải liên kết http/https; giới hạn 20 MiB; quá thời gian 20 giây thì báo lỗi.
- Thông báo lỗi và kết quả hiển thị ở thanh trạng thái trong cửa sổ.
