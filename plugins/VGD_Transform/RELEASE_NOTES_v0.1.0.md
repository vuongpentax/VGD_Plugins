# VGD Transform 0.1.0 (bản thử beta.13)

Dời, xoay và scale group / component bằng số, theo hộp Transform Type-In của 3ds Max.

- Thanh công cụ VGD TRF có ba nút Dời, Xoay, Scale với icon như 3ds Max; mỗi nút mở cửa sổ ở đúng công cụ.
- Cửa sổ gọn (khoảng 320 × 250) để đặt cạnh màn hình; chọn công cụ bằng icon.
- Ghi chú và thông báo ở đáy bảng (rê chuột để xem giải thích), không có chữ mặc định.
- Nút khóa / mở khóa group, component đang chọn như Lock của SketchUp, hoàn tác được.
- Kéo mũi tên ▲▼ xem trực tiếp trong SketchUp mượt hơn: cả lần kéo là một thao tác mở suốt (không ghi bước hoàn tác và không báo mọi plugin khác mỗi nhịp); giá trị đầu tiên áp dụng ngay, các giá trị đến dồn lại chỉ giữ giá trị mới nhất; mỗi nhịp đọc ít thông tin từ SketchUp hơn và chỉ kiểm lại ma trận ở lần cuối. Kéo xong có dòng báo số nhịp và thời gian trung bình (để chỉnh tiếp độ mượt). Chưa đo được độ mượt ngoài SketchUp.
- Ctrl+Z / Ctrl+Y bấm trong cửa sổ VGD Transform giờ hoàn tác / làm lại trong SketchUp ngay (không cần bấm ra khung nhìn trước). Ô đang gõ dở thì Ctrl+Z vẫn hoàn tác chữ.
- Gõ số, Enter, rồi gõ số khác thì số mới thay hẳn số cũ (200 Enter, gõ 300 Enter ra 300, không phải 200300). Bấm chuột vào ô hoặc dùng phím mũi tên, Home, End thì giữ số cũ để sửa tiếp.
- Xoay có thêm ô Tuyệt đối: hiện góc X, Y, Z hiện tại của món; gõ 0 (hoặc bấm chuột phải ▲▼) rồi Enter để quay món về hướng gốc (trục song song trục thế giới), điểm gốc đứng yên.
- Nhấn Enter là chạy ngay (không có nút Áp dụng), mỗi lần là một bước hoàn tác.
- Ô Tuyệt đối hiện sẵn giá trị hiện tại và tự cập nhật (đổi lựa chọn, model đổi, Ctrl+Z); chỉ ô đã sửa được áp dụng.
- Ô Tương đối tự về 0 sau khi áp dụng.
- Tâm biến đổi: điểm gốc từng món, tâm hộp bao cả lựa chọn, gốc thế giới. Dời tuyệt đối theo tâm (không còn dựa vào "món đầu tiên").
- Hệ trục Thế giới hoặc Riêng của món (Local) cho Dời tương đối, Xoay, Scale tương đối.
- Scale tuyệt đối theo trục riêng (tỉ lệ so với definition); Scale tương đối nhận hệ số hoặc kích thước đích có đơn vị (1000mm, 1m).
- Nút ▲▼: bấm, giữ để lặp, kéo lên xuống, Ctrl ×10, Alt ×0,1, chuột phải về mặc định. Xem trực tiếp khi kéo (gộp thành một bước Ctrl+Z).
- Đơn vị theo file (mm, cm, m, in, ft, yd); gõ đơn vị sau số để dùng đơn vị khác.
- Báo số cạnh / mặt bị bỏ qua; món khóa làm cả đợt không chạy.
- Kiểm tra sau khi biến đổi bằng cả ma trận và điểm gốc; sai thì hủy cả đợt.
- Đổi tên từ VGD Position sang VGD Transform. Gỡ bản VGD Position cũ trước khi cài.
- Chưa có: xoay tuyệt đối, hệ số âm, chọn tâm bằng cách bấm trong model, tiếng Anh.
