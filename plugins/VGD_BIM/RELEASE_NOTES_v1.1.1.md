# VGD_BIM 1.1.1

- **Sheet cho Bảng khối lượng, như Excel:** thanh sheet nằm dưới chân trang; bấm **+** để thêm sheet, bấm đúp hoặc F2 để đổi tên, bấm phải để Nhân đôi hoặc Xóa. Mỗi sheet có **cột, sắp xếp, nhóm theo, bộ lọc và tag loại trừ riêng**. Chuyển sang sheet có tag loại trừ khác thì số đo Rộng / Dài / Cao được tính lại (bảng lớn có thể mất vài giây). Sheet lưu cùng file SketchUp; file cũ tự có "Sheet1".
- **Gợi ý nhập kiểu Excel:** gõ vài chữ đầu vào ô Tên, Mô tả, Hãng, Cỡ hoặc cột chữ thêm tay thì phần còn lại hiện mờ; Enter / Tab nhận gợi ý. Gợi ý lấy từ giá trị đã nhập trước đó (nhớ trong file SketchUp) và giá trị đang có trong bảng.
- **Cài đặt và ảnh theo từng file SketchUp:** thư mục `<tên file>_VGD_BIM` nằm cạnh file SketchUp, chứa `settings.json` (cột, sheet, tag và từ khóa loại trừ, gợi ý nhập) và ảnh. Gửi file SketchUp kèm thư mục này là người nhận có đủ ảnh, cột và tag loại trừ. File mới bắt đầu từ mặc định (đường dẫn ảnh trống, cột và tag loại trừ mặc định), không lẫn với file khác. Sửa lỗi tag loại trừ của file này hiện sang file khác.
- **Phải lưu file SketchUp trước khi chụp ảnh** (báo "Chưa lưu file SketchUp" nếu chưa lưu). Thư mục ảnh tự tạo khi chụp ảnh đầu tiên; ô Thư mục ảnh chỉ hiện đường dẫn.
- **File cũ:** lần đầu mở, BIM hỏi một lần có chuyển ảnh và cài đặt về thư mục cạnh file không (ảnh cũ ở thư mục chung không bị xóa).
- Chưa có: gợi ý ở tab Thông tin và hộp Đổi tên hàng loạt; chưa quét sẵn giá trị của đối tượng cũ trong model.

Kiểm tra: tự động (test Ruby mới `dev/test_sheets.rb`, test giao diện mới `dev/test_ui_sheets.cjs`, các test cũ vẫn đạt). Chưa kiểm tra trong SketchUp thật: cần thử trên model có nhiều đối tượng (thời gian tính lại số đo khi chuyển sheet) và trên SketchUp 2022.
