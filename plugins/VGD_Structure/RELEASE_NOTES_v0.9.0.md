# VGD Structure 0.9.0 (beta)

Cột mốc 8: **cửa đi và cửa sổ** (giai đoạn 2, theo cấu trúc tính năng VTBim).

- Loại cửa (cửa đi / cửa sổ: rộng, cao, cao ngưỡng) và tab **Cửa**: bấm tường, thêm cửa, sửa vị trí tâm, đổi mặt cánh, xóa; sao chép cửa từ tầng khác.
- **Tường tự khoét lỗ cửa** khi dựng tường; cửa sai (vượt tường, quá cao, chồng nhau) bị bỏ và báo.
- Dựng cửa: khung và cánh đơn giản theo tham số (cửa đi: khung chữ U + cánh; cửa sổ: khung vòng + kính), tag A. DOOR / A. WINDOW theo bộ tag mẫu BIM; cửa là một phần của "Dựng tất cả" và kiểm tra kết cấu.
- VGD BIM (1.1.1-beta.7): cửa đếm theo cái; diện tích và thể tích tường trừ lỗ cửa.
- Dữ liệu các cột mốc trước vẫn mở được. Chưa xác minh trong SketchUp thật (đùn mặt có lỗ, khung và cánh).
