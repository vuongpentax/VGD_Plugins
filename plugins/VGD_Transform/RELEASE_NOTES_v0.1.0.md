# VGD Transform 0.1.0 (bản thử beta.4)

- Đổi tên từ VGD Position sang VGD Transform (extension, menu, thanh công cụ VGD TRF, thư mục plugin). Hành vi không đổi. Gỡ bản VGD Position cũ trước khi cài.

- Dời, xoay và scale món (group, component) theo trục thế giới, trong một cửa sổ có ba tab: Dời, Xoay, Scale.
- Dời có hai khung: Tuyệt đối (đưa điểm gốc tới X, Y, Z) và Dời tương đối (ΔX, ΔY, ΔZ). Nhiều món thì cả nhóm dời cùng độ lệch tính từ món đầu tiên.
- Xoay quanh X, Y, Z (theo thứ tự X, Y, Z). Scale đều hoặc không đều, với hệ số (1 = giữ nguyên).
- Tâm xoay / scale: điểm gốc từng món, tâm cả lựa chọn, hoặc gốc tọa độ thế giới.
- Đơn vị theo file (mm, cm, m, in, ft). Có thể gõ đơn vị sau số, ví dụ 1m.
- Ô số có nút ▲▼ (giữ để lặp) và kéo lên xuống để đổi nhanh.
- Xem trước trước khi áp dụng; áp dụng là một bước hoàn tác.
- Món khóa, hoặc món trong group cha bị khóa, làm cả đợt không chạy và được báo tên; sau khi biến đổi vị trí được kiểm tra lại.
- Menu Extensions → VGD → VGD Transform, thanh công cụ VGD TRF, mục Tải lại code.
- Chưa có: góc tuyệt đối khi xoay, scale tuyệt đối, hệ số âm (lật món), điểm tâm chọn bằng cách bấm trong model, gán lại tầng / phòng tự động, tiếng Anh.
