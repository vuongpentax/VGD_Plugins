# VGD Center 1.2.6

- **Hướng dẫn tương tác:** nút **Hướng dẫn** ở trang Tổng quan mở trang hướng dẫn có hoạt ảnh, chạy trực tiếp trên giao diện Center. Trang đặt trên GitHub Pages của kho nên cập nhật nội dung không cần phát hành Center mới.
- **Plugin cũng có thể có hướng dẫn tương tác:** catalog khai báo `guide_url`; Center chỉ nhận đúng địa chỉ của kho. Thêm hướng dẫn cho plugin mới không cần cập nhật Center.
- **Hướng dẫn có sẵn cho Center, Dim, Library, Image Importer, Scenes, BIM và Reference** (Cabinet và Cabinet Draw vẫn dùng trang chữ). Khung xem lớn, có nút tạm dừng và thanh tua thời gian.
- **Không có mạng hoặc trang lỗi:** mở trang hướng dẫn chữ như cũ.
- **An toàn:** cửa sổ hướng dẫn tương tác không nối với Ruby, nên trang trên mạng không điều khiển được SketchUp. Quy tắc kiểm tra trang hướng dẫn chữ giữ nguyên (không script).

Kiểm tra: tự động (các test của Center, test hướng dẫn gồm các trường hợp địa chỉ sai và mất mạng, test tải lại code). Đã thử thủ công trong SketchUp: hoạt ảnh hiện trong cửa sổ Hướng dẫn của Center (chưa ghi lại phiên bản SketchUp; chưa thử riêng trên SketchUp 2022).
