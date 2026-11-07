# VGD Center 1.2.4

- **Nhận ra VGD BIM với tên mới `VGD_BIM`:** VGD BIM đổi tên extension từ "VGD BIM Lite" thành "VGD_BIM". Thẻ plugin trong Kho ghi tên mới; Center nhận cả bản đã cài tên cũ lẫn tên mới nên vẫn hiện đúng trạng thái đã cài và phiên bản, và nhận catalog dùng tên mới.
- Các trang hướng dẫn ghi tên VGD_BIM thay cho VGD BIM Lite.
- **Chuyển plugin an toàn hơn:** đích đã có plugin mà không tick Ghi đè thì bỏ qua cả plugin (trước đây có thể chép loader mà bỏ thư mục, gây lỗi "không tìm thấy file"); sau khi chép so lại từng file với bản gốc và báo rõ plugin thiếu file hoặc sai dung lượng; cảnh báo plugin có file mã hóa (.rbe), RubyEncoder hoặc thư viện nhị phân (.so/.dll) vì thường cần bản riêng cho SketchUp đích; mỗi lần chuyển ghi một dòng vào `manager.log` kể cả khi thành công.

Kiểm tra: tự động (các test của Center, thêm kiểm tra nhận tên extension và kiểm tra catalog). Chưa kiểm thử thủ công trong SketchUp.
