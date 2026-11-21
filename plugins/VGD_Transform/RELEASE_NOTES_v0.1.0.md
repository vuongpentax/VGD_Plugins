# VGD Transform 0.1.0 (bản thử beta.5)

- Dời, xoay và scale món (group, component) theo trục thế giới, trong một cửa sổ có ba tab: Dời, Xoay, Scale.
- Nhấn Enter trong ô hoặc bấm Áp dụng là biến đổi ngay; mỗi lần là một bước hoàn tác.
- Cửa sổ gọn: không có danh sách món và bảng kết quả.
- Dời có hai khung: Tuyệt đối (đưa điểm gốc tới X, Y, Z) và Dời tương đối (ΔX, ΔY, ΔZ). Nhiều món thì cả nhóm dời cùng độ lệch tính từ món đầu tiên.
- Xoay quanh X, Y, Z (theo thứ tự X, Y, Z). Scale đều hoặc không đều.
- Scale không đều nhận kích thước đích có đơn vị (ví dụ 1000mm): hệ số của từng món được tính để món đúng kích thước đó.
- Tâm xoay / scale: điểm gốc từng món, tâm cả lựa chọn, hoặc gốc tọa độ thế giới.
- Đơn vị theo file (mm, cm, m, in, ft). Có thể gõ đơn vị sau số, ví dụ 1m.
- Ô số có nút ▲▼ (giữ để lặp) và kéo lên xuống để đổi nhanh.
- Món khóa, hoặc món trong group cha bị khóa, làm cả đợt không chạy và được báo tên.
- Đổi tên từ VGD Position sang VGD Transform. Gỡ bản VGD Position cũ trước khi cài.
- Chưa có: góc tuyệt đối khi xoay, scale tuyệt đối, hệ số âm (lật món), chọn tâm bằng cách bấm trong model, gán lại tầng / phòng tự động, tiếng Anh.
