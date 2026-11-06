# VGD Center 1.2.2

- **Hướng dẫn tải từ kho:** bấm **Hướng dẫn** sẽ tải trang mới nhất từ `shared/vgd-center/guides/<id>.html` trên GitHub, kiểm tra rồi mở. Thêm hoặc sửa hướng dẫn từ nay không cần phát hành Center mới. Không có mạng, tải lỗi hoặc trang không hợp lệ thì dùng bản đi kèm gói (hoặc bản tải lần trước).
- Trang tải về chỉ được là tài liệu tĩnh: không script, khung nhúng, form, tài nguyên hay liên kết ra ngoài; trang không đạt bị bỏ qua.
- Plugin mới chưa có trang trong gói hiện nút Hướng dẫn nếu mục catalog khai báo `"guide": true`.
- Thêm trang hướng dẫn cho **VGD Cabinet Draw**.
- Hướng dẫn cho plugin mới viết theo mục "Hướng dẫn cho plugin" trong `README.md`.

Kiểm tra: tự động (test của Center, 46 kiểm tra mới cho việc tải/kiểm tra/lưu hướng dẫn, kiểm tra mọi trang trong repo). Chưa kiểm thử thủ công trong SketchUp: việc tải trang qua `Sketchup::Http::Request` và ghi file vào thư mục guides chưa chạy trong SketchUp thật.
