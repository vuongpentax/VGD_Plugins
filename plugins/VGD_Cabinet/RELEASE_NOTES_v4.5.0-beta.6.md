# VGD Cabinet 4.5.0-beta.6

- Thu gọn cửa sổ dựng hình; chuyển sang khóa kích thước giao diện mới để không giữ kích thước dialog cũ.
- Sửa xác minh ghi chỉ mục preset/thư viện bằng cách kiểm tra nội dung đã ghi và giá trị JSON sau khi đọc lại.
- Đổi tên hai hồi ngoài của mỗi module thành `Hông Trái` và `Hông Phải`, kể cả module độc lập; các hồi chia tầng giữ thêm tên tầng và kiểu bo.
- Thêm lựa chọn liên kết xà chặn cánh và xà chặn ngăn kéo riêng: chỉ dừng giữa hông hoặc khấu hông. Mặc định dừng giữa hông; khấu hông hỗ trợ cả module độc lập.
- Kiểm thử Ruby/WASM, hình học, lưu thư viện, DOM và giao diện Edge headless. Chưa xác nhận trong SketchUp native.
