# VGD_BIM 1.1.0

- **Bảng khối lượng** (mở đầu tiên): bảng tự đọc đối tượng đang chọn, 20 cột, chọn cột, kéo đổi thứ tự, co giãn cột, dòng tổng cộng, preset cột (Tất cả / Phần thô / Hoàn thiện / Đồ rời và preset tự tạo), sửa trực tiếp Tên, Mô tả, Tình trạng. Tuỳ chọn thu phóng, cô lập, chọn sâu và tổng cấp cao nhất.
- **Đổi tên hàng loạt** trong tab Bảng khối lượng (nút Đổi tên): mẫu tên ghép từ tên hiện tại, tên định nghĩa, phân loại, nhóm hạng mục và số thứ tự; tìm và thay, tiền tố / hậu tố, kiểu chữ; đánh số theo thứ tự trong bảng, vị trí hoặc tên; xem trước, báo đối tượng khóa và tên trùng; cả đợt một bước hoàn tác. Chỉ đổi tên đối tượng (instance), không đổi tên định nghĩa.
- **Khung đánh dấu trong SketchUp:** chọn đối tượng thì hiện khung nét đứt theo khung bao, tô mặt và khung tên; tự tắt khi đối tượng bị xóa. Từ SketchUp 2023 khung vẽ bằng lớp phủ (Overlay) nên cách chọn đối tượng giữ nguyên như mặc định (Shift/Ctrl, kéo chọn, nhấp đúp vào group); SketchUp 2022 dùng công cụ vẽ tạm với vài hạn chế khi chọn.
- Sửa khung đánh dấu bị lệch khỏi đối tượng khi đang mở sửa một group hoặc component.
- **Tình trạng** (Mới, Hiện hữu, Dùng lại, Tạm thời, Loại bỏ) là trường mới của dữ liệu hạng mục.
- **Soạn tag:** tab mới để soạn bộ tag theo nhóm hạng mục, gán tag cho đối tượng đang chọn, xuất / nhập CSV và JSON.
- **Điều hướng gọn còn 5 tab** trong cùng một cửa sổ (trước đây 6 mục): Bảng khối lượng · Thông tin · Quét & xuất · Phân loại (gồm Quy tắc, Kiểm tra) · Soạn tag. Mục "Quản lý Quy tắc", "Kiểm tra" nay nằm trong tab Phân loại; "Xuất báo cáo" nằm trong tab Quét & xuất.
- **Bỏ mục "Chuyển đổi lựa chọn"** trong tab Thông tin. Muốn chuyển đổi hàng loạt, dùng Xem trước chuyển đổi và Xác nhận chuyển đổi trong tab Phân loại.
- **Đổi tên extension thành VGD_BIM.** Menu gọn: Extensions → VGD → VGD_BIM (mở thẳng bảng khối lượng) và VGD_BIM · Tải lại code, thay cho submenu BIM Lite. Toolbar một nút. VGD Center 1.2.4 trở lên nhận đúng tên mới; Center cũ có thể hiện VGD BIM là "chưa cài".
- **Lưu cài đặt bằng file JSON** trong `%APPDATA%\VGD\VGD_BIM\` (bộ tag, preset cột, trạng thái bảng), tránh lỗi mất preset khi chuỗi có ngoặc kép hoặc dấu tiếng Việt.
- Quét nhanh hơn: không còn đọc cạnh (edge); báo cáo không còn số cạnh và chiều dài cạnh. Có thể tắt quét mặt khi chỉ cần group / component.
- Xóa các lớp bao hộp thoại cũ không còn dùng (`InformationDialog`, `MappingDialog`, `ScanDialog`, `ValidationDialog`).

Kiểm tra: tự động bằng mô phỏng (cú pháp Ruby, test lõi, bảng, lưu cài đặt, soạn tag, menu, khung đánh dấu, giao diện HTML). Chưa kiểm thử thủ công trong SketchUp thật.
