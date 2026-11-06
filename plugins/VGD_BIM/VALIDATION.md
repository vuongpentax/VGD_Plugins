# Kiểm thử

Tóm tắt trạng thái kiểm chứng của VGD_BIM. Mọi kết quả dưới đây là **mô phỏng ngoài SketchUp**; chưa có kiểm chứng nào của bản 1.1.0 trong SketchUp thật.

## Bản 1.1.0-beta.4: đã kiểm tra tự động

Chạy từ `plugins/VGD_BIM`: `ruby dev/run_tests.rb` (cú pháp 20 file Ruby và 9 bộ test) và `dev/test_ui.cjs` (Playwright).

- Cú pháp Ruby của mọi file runtime. Runtime viết theo cú pháp Ruby 2.7 để target SketchUp 2022; phần kiểm tra cú pháp chạy bằng Ruby của máy thử, không phải Ruby 2.7.
- `test_legacy.rb`: schema/enum/boolean, trường `status`, cập nhật từng phần, xóa, trường bắt buộc, UNCLASSIFIED, ưu tiên nguồn, quy tắc JSON, đóng gói một operation và abort khi lỗi; hình học nested (mirror, xoay, scale không đều), quét bỏ qua cạnh, báo cáo không có dữ liệu cạnh, 2.000 cấp lồng nhau, chống đệ quy; xuất CSV (tiêu đề tiếng Việt, UTF-8 BOM, dấu chấm phẩy, an toàn công thức Excel); cửa sổ (một cửa sổ cho mọi menu, điều hướng trước khi HTML sẵn sàng, hủy thế hệ quét cũ, tháo observer, đóng/mở lại).
- `test_table.rb`, `test_build.rb`: dựng bảng khối lượng, preset (kể cả tên có ngoặc kép), lưu và đọc lại trạng thái bảng, chế độ chọn nông và chọn sâu.
- `test_dialog_logic.rb`: bấm vùng trống giữ nguyên bảng, chọn lại thì đọc lại.
- `test_preview.rb`: khung đánh dấu (vị trí chữ, tự tắt khi đối tượng bị xóa).
- `test_tags.rb`, `test_tags_io.rb`: bộ tag, xuất / nhập CSV và JSON, gộp tag trùng tên.
- `test_loader_menu.rb`, `test_load.rb`: menu VGD_BIM và Tải lại code, phiên bản đúng chuẩn, nạp được mọi file.
- `dev/test_ui.cjs`: nhãn tiếng Việt, sửa nhiều đối tượng chỉ ghi trường được bật, tên đối tượng không chèn HTML, xem trước và xác nhận chuyển đổi, chọn dòng kiểm tra, quy tắc, tùy chọn quét và xuất, bấm ô bảng gửi đúng dòng và cột, sáng/tối, cửa sổ nhỏ không tràn.
- Kiểm tra đột biến: đổi thử một nhánh của khung đánh dấu thì `run_tests.rb` báo lỗi đúng chỗ.

## Chưa được xác nhận trong SketchUp thật

Các điểm sau chỉ kiểm được trong SketchUp thật:

1. Nạp extension, menu, toolbar, context menu, HtmlDialog và Tải lại code; đổi tên extension từ "VGD BIM Lite" sang "VGD_BIM" khi cài đè lên 1.0.0.
2. Khung đánh dấu trong viewport: chữ trong khung tên có rõ và nằm đúng giữa không (chiều rộng khung ước lượng theo số ký tự); tọa độ 2D trên màn hình độ phân giải cao có lệch không; tô mặt có chậm với model lớn không; khung có tắt khi xóa đối tượng không; chọn trong SketchUp có hiện khung ngay không; kéo chọn nhiều và nhấp đúp vào group khi khung đang bật.
3. Lưu cài đặt: preset và cột còn sau khi tắt mở SketchUp (`%APPDATA%\VGD\VGD_BIM\`).
4. Thể tích chỉ tính cho group kín; khung bao theo bounding box chứ không theo cạnh thật.
5. Undo thật của sửa bảng và chuyển đổi; chọn dòng kiểm tra tới đúng đối tượng lồng nhau; lưu và mở lại metadata; model thật đang dùng.
6. `dev/native_smoke.rb` (chạy trong tiến trình SketchUp mới với model trống) chưa chạy cho bản 1.1.0 và chưa bao phủ bảng khối lượng, soạn tag, khung đánh dấu.

## Lịch sử

Bản 0.1.x từng được cài và xác minh hash trong Plugins của SketchUp 2022 và kiểm tra giao diện bằng Playwright, nhưng lần chạy `native_smoke.rb` thử trong một tiến trình SketchUp riêng không sinh được `native_report.json` do công cụ điều khiển cửa sổ lỗi, nên không coi là đã pass. Bản 1.0.0 chỉ được kiểm tra tự động (cú pháp Ruby, JSON, đóng gói RBZ).
