# VGD Dim 3.3.0-beta.8

- Thanh điều hướng có icon, tên và mô tả ngắn khi panel rộng; khi panel từ 740 px trở xuống, chỉ hiện icon với tooltip đầy đủ.
- Phạm vi áp dụng tự chuyển vào nội dung ở chế độ hẹp để không chiếm chỗ thanh bên.
- Hủy Dim thủ công bằng Esc mở khóa giao diện ngay; callback kết thúc được bảo vệ để không chạy hai lần.
- Hot-reload nạp cả Boundary và công cụ Dim thủ công.

Kiểm tra: bộ fixture Ruby, kiểm thử giao diện Edge headless ở 760/740/540/360 px, hai theme và sáu tab đều PASS. Kiểm thử fixture không thay thế kiểm tra native trong SketchUp.
