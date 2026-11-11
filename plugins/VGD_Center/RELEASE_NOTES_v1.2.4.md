# VGD Center 1.2.4

- **Nhận ra VGD_BIM:** Center nhận plugin VGD_BIM (thư mục `vgd_bim/`, loader `vgd_bim.rb`, id `bim` trong catalog). Thẻ BIM trong Kho sẽ xuất hiện khi bản VGD_BIM đầu tiên được phát hành. Trang hướng dẫn BIM đổi tên thành `bim.html`.
- **Chuyển plugin an toàn hơn:** đích đã có plugin mà không tick Ghi đè thì bỏ qua cả plugin (trước đây có thể chép loader mà bỏ thư mục, gây lỗi "không tìm thấy file"); sau khi chép so lại từng file với bản gốc và báo rõ plugin thiếu file hoặc sai dung lượng; cảnh báo plugin có file mã hóa (.rbe), RubyEncoder hoặc thư viện nhị phân (.so/.dll) vì thường cần bản riêng cho SketchUp đích; chuyển thành công không tạo file nhật ký, `manager.log` chỉ ghi khi có lỗi.

Kiểm tra: tự động (các test của Center, thêm kiểm tra nhận tên extension và kiểm tra catalog). Chưa kiểm thử thủ công trong SketchUp.
