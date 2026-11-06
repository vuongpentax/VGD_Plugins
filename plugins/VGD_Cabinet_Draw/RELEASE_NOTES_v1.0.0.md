# VGD Cabinet Draw 1.0.0

Phát hành ổn định đầu tiên. Mã giống beta.70.

- **Đổi tên extension** từ "VGD_Cabinet Draw" thành **"VGD Cabinet Draw"** (có dấu cách) để khớp quy tắc catalog của VGD Center và không bị nhầm với plugin VGD_Cabinet. Namespace `VGD_Cabinet_Draw`, tên file loader, dictionary model và thư mục dữ liệu không đổi nên model và setting cũ vẫn dùng được. Người đã cài bản beta sẽ thấy tên mới trong Extension Manager.
- Công cụ: Box → Board, Chia đợt / vách, Cánh tủ, Ngăn kéo, Scale VGD, Quét & dời tấm, VGD Chọn, Setting.
- Tủ quá khổ tự tách, cài đặt xà trước/sau, sáu kiểu hậu theo DC, tủ tùy biến.
- Mọi cấu kiện co giãn tại chỗ khi Scale, giữ chi tiết nhỏ đúng mm.
- Giao diện, viewport và icon theo theme VGD (sáng/tối).
- Lịch sử chi tiết từng bản beta: bảng "Lịch sử phiên bản" trong `README.md`.

Kiểm tra: tự động bằng giả lập SketchUp (25 file test trong `test/`, cú pháp Ruby, đóng gói RBZ). Chưa kiểm thử thủ công đầy đủ trong SketchUp thật; các phần chưa kiểm chứng ghi trong mục "Điều chưa kiểm chứng" của `README.md`.
