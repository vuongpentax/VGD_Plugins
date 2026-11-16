# VGD_BIM 1.1.1

- **Sheet cho Bảng khối lượng, như Excel:** thanh sheet nằm dưới chân trang; bấm **+** để thêm sheet, bấm đúp hoặc F2 để đổi tên, bấm phải để Nhân đôi hoặc Xóa. Mỗi sheet có **cột, sắp xếp, nhóm theo, bộ lọc và tag loại trừ riêng**. Chuyển sang sheet có tag loại trừ khác thì số đo Rộng / Dài / Cao được tính lại (bảng lớn có thể mất vài giây). Sheet lưu cùng file SketchUp; file cũ tự có "Sheet1".
- **Gợi ý nhập kiểu Excel:** gõ vài chữ đầu vào ô Tên, Mô tả, Hãng, Cỡ hoặc cột chữ thêm tay thì phần còn lại hiện mờ; Enter / Tab nhận gợi ý. Gợi ý lấy từ giá trị đã nhập trước đó (nhớ trong file SketchUp) và giá trị đang có trong bảng.
- Chưa có: gợi ý ở tab Thông tin và hộp Đổi tên hàng loạt; chưa quét sẵn giá trị của đối tượng cũ trong model.

Kiểm tra: tự động (test Ruby mới `dev/test_sheets.rb`, test giao diện mới `dev/test_ui_sheets.cjs`, các test cũ vẫn đạt). Chưa kiểm tra trong SketchUp thật: cần thử trên model có nhiều đối tượng (thời gian tính lại số đo khi chuyển sheet) và trên SketchUp 2022.
