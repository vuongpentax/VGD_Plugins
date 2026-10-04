# Trạng thái · 2.3.0-beta.1

| Yêu cầu | Thực hiện |
|---|---|
| Mẫu font/size/Height từ Model Info → APPLY | Đã viết cầu nối Update selected Windows English; native chưa xác minh |
| Chỉ Dim/Text đang chọn | Lấy selection trực tiếp, tách Dim/Text rồi khôi phục selection |
| Endpoint Dim/Label, tag | Setter native; Dim → 000 DIM, Text/Label → 000 TEXT |
| Mẫu đi theo SKP | Chỉnh Model Info và lưu SKP; plugin không lưu file tự động |
| Không thông báo hoàn tất | Im lặng; lỗi inline/status |
| Undo | Native có thao tác riêng; màu/endpoint/tag một operation |
| Ngữ cảnh dùng chung | Dừng trước khi sửa; cần Make Unique |
| Kiểm thử | Ruby/bridge mô phỏng, UI Edge và bộ cài đạt; Win32/font/Height/Undo/save-reopen native chưa chạy |

Đọc accessibility được trên SU2022. Chụp/input trước đó lỗi capture timeout/coordinate geometry unavailable; lần thử bàn phím mới không mở được menu Window. Không coi đọc cây UI là bằng chứng font đã được áp.
