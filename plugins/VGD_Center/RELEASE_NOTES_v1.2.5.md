# VGD Center 1.2.5

- **Đặt lại tên theo chuẩn VGD:** loader `vgd_center.rb` và thư mục `vgd_center/` viết thường (trước đây `VGD_Center.rb`, `VGD_Center/`). Thư mục dữ liệu tab Quản lý nay là `Plugins/vgd_center/data`; trên Windows vẫn là cùng một thư mục nên dữ liệu cũ dùng tiếp.
- **Menu và thanh công cụ:** lệnh nằm trong **Extensions → VGD → VGD Center**; thanh công cụ tên rút gọn **VGD CEN**.
- **Nhận tên mới của các plugin:** Center nhận Dim, Cabinet (thư mục `vgd_dim/`, `vgd_cabinet/`) và BIM (extension "VGD BIM"). Cấu trúc cũ vẫn được chấp nhận trong lúc chuyển tiếp.
- **Lưu ý khi nâng cấp:** Center 1.2.4 trở về trước không tự cập nhật lên bản này được (kiểm tra đường dẫn trong gói phân biệt hoa thường). Gỡ Center cũ và cài tay file RBZ này một lần.
- **Tải lại code:** menu **Extensions → VGD → VGD Center → Tải lại code** nạp lại mã sau khi cài đè bản mới mà không cần mở lại SketchUp (không cho tải lại khi đang tải hoặc cài plugin; lỗi file thì giữ bản đang chạy). Menu và toolbar mới chỉ có tác dụng sau khi mở lại SketchUp.

Kiểm tra: tự động (test tải lại code, các test của Center, test hướng dẫn, catalog đi kèm). Chưa kiểm thử thủ công trong SketchUp cho bản này.
