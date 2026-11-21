# Kiểm tra VGD Position

Mọi kết quả dưới đây là **mô phỏng ngoài SketchUp**, trừ khi ghi khác.

## Bản 0.1.0-beta.2: đã kiểm tra tự động

- `dev/test_position.rb`: đọc ô nhập mm (số, dấu phẩy, trống, sai định dạng, vượt giới hạn); một món (giữ trục trống, đã đúng vị trí); nhiều món (cùng độ lệch tính từ món đầu tiên); chặn khi có món khóa hoặc không đo được vị trí; báo lỗi khi không nhập gì hoặc chưa chọn món.
- `dev/test_move.rb` (SketchUp giả lập): đọc vị trí món ở gốc và trong group cha; dời ở gốc; dời trong group cha (độ dời tính trong hệ thế giới); nhiều món cùng độ dời trong một thao tác; món khóa và group cha khóa; một thao tác hoàn tác; hủy cả thao tác khi vị trí sau dời không khớp.
- `dev/test_reload.rb`: menu đúng hai mục; tải lại 3 lần không nhân đôi mục; đang bận thì không nạp lại và báo đúng; lỗi cú pháp giữ nguyên bản đang chạy.
- `dev/test_ui.cjs` (Playwright): món và món khóa hiển thị; không còn ô chọn chế độ; nút Áp dụng chỉ bật sau khi xem trước và tắt lại khi đổi ô; lệnh gửi xuống Ruby đúng ô nhập; báo lỗi đỏ; không có lỗi JavaScript.
- `tests/test_vgd_conventions.rb` (repo): tên extension, toolbar `VGD POS`, mục menu "Tải lại code", chữ chuẩn khi tải lại.

## Chưa xác minh trong SketchUp thật

- Mở cửa sổ, danh sách món cập nhật khi đổi lựa chọn (observer thật).
- Dời món thật: đúng vị trí, Ctrl+Z hoàn tác đúng một bước, không ảnh hưởng món khác.
- Nhiều món thật: món đầu tiên trong danh sách có đúng là món được chọn trước không (thứ tự lấy từ `Selection`); cả nhóm giữ nguyên khoảng cách.
- Dời món trong group đang mở (nhấp đúp để mở group) và trong group lồng nhiều cấp.
- Ô nhập số trong HtmlDialog thật (dấu phẩy, dán số).
- Tải lại code khi cửa sổ đang mở.
- Icon trên thanh công cụ.
