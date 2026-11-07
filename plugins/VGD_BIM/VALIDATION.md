# Kiểm thử

Tóm tắt trạng thái kiểm chứng của VGD_BIM. Mọi kết quả dưới đây là **mô phỏng ngoài SketchUp**; chưa có kiểm chứng nào của bản 1.1.0 trong SketchUp thật.

## Bản 1.1.0-beta.12: đã kiểm tra tự động

Chạy từ `plugins/VGD_BIM`: `ruby dev/run_tests.rb` (cú pháp 25 file Ruby và 15 bộ test) và ba bộ Playwright `dev/test_ui.cjs`, `dev/test_ui_images.cjs`, `dev/test_ui_en.cjs`.

- Cú pháp Ruby của mọi file runtime. Runtime viết theo cú pháp Ruby 2.7 để target SketchUp 2022; phần kiểm tra cú pháp chạy bằng Ruby của máy thử, không phải Ruby 2.7.
- `test_bim.rb`: schema/enum/boolean, trường `status`, cập nhật từng phần, xóa, trường bắt buộc, UNCLASSIFIED, ưu tiên nguồn, quy tắc JSON, đóng gói một operation và abort khi lỗi; hình học nested (mirror, xoay, scale không đều), quét bỏ qua cạnh, báo cáo không có dữ liệu cạnh, 2.000 cấp lồng nhau, chống đệ quy; xuất CSV (tiêu đề tiếng Việt, UTF-8 BOM, dấu chấm phẩy, an toàn công thức Excel); cửa sổ (một cửa sổ cho mọi menu, điều hướng trước khi HTML sẵn sàng, hủy thế hệ quét cũ, tháo observer, đóng/mở lại).
- `test_table.rb`, `test_build.rb`: dựng bảng khối lượng, preset (kể cả tên có ngoặc kép), lưu và đọc lại trạng thái bảng, chế độ chọn nông và chọn sâu.
- `test_dialog_logic.rb`: bấm vùng trống giữ nguyên bảng, chọn lại thì đọc lại.
- `test_preview.rb`: khung đánh dấu (vị trí chữ, tự tắt khi đối tượng bị xóa).
- `test_dialog_logic.rb` và `dev/test_ui.cjs` còn kiểm tra chọn nhiều dòng (Ctrl, Shift, Ctrl+Shift, Ctrl+A, Esc, bấm ô sửa, SketchUp chọn theo, dòng khác cấp lồng, phạm vi đổi tên theo dòng đã chọn).
- `test_dialog_logic.rb`, `test_tags.rb`, `test_build.rb` và `dev/test_ui.cjs` còn kiểm tra sửa bằng nhấp đúp (tên, mô tả, tình trạng, tag, vật liệu; nhiều dòng; đối tượng khóa; tag mới; dữ liệu sai), danh sách chọn, dòng cha, nhóm theo, thu gọn / chọn cả nhóm và gộp dòng giống nhau.
- `test_rename.rb`, `test_dialog_logic.rb`: tính tên mới (mẫu, số thứ tự, thứ tự đánh số, tìm và thay nguyên văn, kiểu chữ có dấu tiếng Việt, đối tượng khóa, tên trống, quá dài, trùng, kiểm tra dữ liệu sai) và áp dụng đổi tên (một bước hoàn tác, bỏ qua đối tượng khóa, từ chối khi đối tượng không còn).
- `test_tags.rb`, `test_tags_io.rb`: bộ tag, xuất / nhập CSV và JSON, gộp tag trùng tên.
- `test_loader_menu.rb`, `test_load.rb`: menu VGD_BIM và Tải lại code, phiên bản đúng chuẩn, nạp được mọi file.
- `dev/test_ui.cjs`: nhãn tiếng Việt, sửa nhiều đối tượng chỉ ghi trường được bật, tên đối tượng không chèn HTML, xem trước và xác nhận chuyển đổi, chọn dòng kiểm tra, quy tắc, tùy chọn quét và xuất, bấm ô bảng gửi đúng dòng và cột, sáng/tối, cửa sổ nhỏ không tràn.
- `test_settings.rb`: cài đặt (mặc định, ghi từng phần, từ chối giá trị sai và không ghi nửa chừng, file sửa tay hỏng thì về mặc định).
- `test_images.rb`: đường dẫn ảnh theo model và mã đối tượng (không thoát khỏi thư mục ảnh), chỉ nhận PNG, giới hạn dung lượng, ghi qua file tạm, xóa.
- `test_capture.rb` (SketchUp giả lập): chụp cô lập (mở một thao tác rồi hủy, không commit), khung nhìn hiện tại, nền trắng; camera, lựa chọn, tuỳ chọn hiển thị và trạng thái ẩn luôn được trả lại kể cả khi chụp lỗi giữa chừng; ảnh cũ còn nguyên khi chụp lỗi; dọn file tạm.
- `test_image_actions.rb`: chụp theo lô bằng bộ hẹn giờ, nút Dừng, đóng cửa sổ giữa chừng, một đối tượng lỗi không dừng cả lô, giới hạn 200 đối tượng, bỏ qua sự kiện chọn khi đang chụp, ảnh dán / kéo thả (từ chối mã lạ và dữ liệu không phải PNG), ảnh nhỏ / ảnh lớn gửi về giao diện, lưu cài đặt (đổi ngôn ngữ vẽ lại cửa sổ).
- `dev/test_ui_images.cjs`: cột Ảnh và ảnh nhỏ (xin theo lô, dùng lại bộ nhớ đệm), ảnh không tự chụp khi mở bảng hay tab, nút Chụp ảnh / Dừng, kéo thả và dán (đúng đối tượng, không dán khi chọn nhiều dòng, từ chối file không phải ảnh, thu nhỏ về cỡ ảnh), tab Cài đặt, đơn vị mm / cm / m ở bảng và tab Thông tin, đổi ngôn ngữ thì tải lại.
- `dev/test_ui_en.cjs`: chế độ English không còn chữ tiếng Việt chưa dịch ở mọi tab, bảng chọn, thông báo (dùng dữ liệu thật do `dev/ui_fixture.rb` lấy từ Ruby); chế độ Tiếng Việt không bị dịch nhầm. Thông báo lỗi phát sinh từ Ruby ngoài danh sách đã liệt kê, và hộp thoại gốc của SketchUp (hộp chọn file, hỏi xác nhận) vẫn bằng tiếng Việt.
- Kiểm tra đột biến: đổi thử một nhánh của khung đánh dấu thì `run_tests.rb` báo lỗi đúng chỗ; bỏ khôi phục camera / lựa chọn / tuỳ chọn hiển thị / hủy thao tác / dọn file tạm trong `capture.rb`, bỏ kiểm tra mã đối tượng, nút Dừng, giới hạn lô, kiểm tra PNG trong phần ảnh thì test tương ứng báo lỗi.
- Rà soát mã (bug và tuân thủ CLAUDE.md) trên phần thay đổi: đã sửa lỗi khung đánh dấu pop nhầm công cụ của người dùng khi đổi công cụ (có test `đổi sang công cụ khác`). Các điểm còn lại ở mục dưới.

## Chưa được xác nhận trong SketchUp thật

Các điểm sau chỉ kiểm được trong SketchUp thật:

1. Nạp extension, menu, toolbar, context menu, HtmlDialog và Tải lại code.
2. Khung đánh dấu trong viewport: chữ trong khung tên có rõ, nằm đúng giữa và nằm trọn trong hộp không (hộp đo bằng `View#text_bounds`, có từ SketchUp 2020; nếu không đo được thì ước lượng theo số ký tự); tọa độ 2D trên màn hình độ phân giải cao có lệch không; chọn nhiều đối tượng của model lớn có còn lag không (từ beta.10 khung chỉ là hộp bao, đã bỏ tô từng mặt của đối tượng); khung có tắt khi xóa đối tượng không; chọn trong SketchUp có hiện khung ngay không; kéo chọn nhiều và nhấp đúp vào group khi khung đang bật.
3. Lưu cài đặt: preset và cột còn sau khi tắt mở SketchUp (`%APPDATA%\VGD\VGD_BIM\`).
4. Thể tích chỉ tính cho group kín; khung bao theo bounding box chứ không theo cạnh thật.
5. Chế độ **Cô lập**: ẩn / hiện đối tượng ngoài một bước hoàn tác riêng (`Table.isolate` / `Table.restore` không bọc `start_operation`); chưa biết Ctrl+Z xử lý thế nào, và file lưu khi đang cô lập mang các đối tượng ở trạng thái ẩn.
6. Khung đánh dấu khi đang mở sửa group / component: ảnh chụp từ SketchUp thật (bản beta.5) cho thấy khung và khung tên lệch khỏi đối tượng đúng bằng vị trí của ngữ cảnh đang mở. Từ beta.6 điểm vẽ được đổi sang tọa độ cục bộ của ngữ cảnh (`edit_transform.inverse`) theo suy luận từ ảnh đó; test chỉ dùng mô phỏng nên cần xem lại trong SketchUp thật (mở sửa component, chọn đối tượng con, ở nhiều cấp lồng).
7. Khung đánh dấu bằng lớp phủ (`Sketchup::Overlay`, SketchUp 2023+): chưa kiểm tra trong SketchUp thật việc đăng ký lớp phủ (`model.overlays.add`, `enabled=`), việc vẽ khung, và việc Shift/Ctrl, kéo chọn, nhấp đúp vào group hoạt động như mặc định; test dùng lớp `Sketchup::Overlay` mô phỏng đúng phần API được dùng (`new(id, name)`). Nếu lớp phủ báo lỗi, plugin quay về công cụ (cách của SketchUp 2022): với cách này chọn công cụ khác (Move, Tape) giữa chừng cần kiểm tra không làm hỏng thao tác của người dùng.
8. `VGD::BIM.reload` nạp lại `vgd_bim.rb` và `loader.rb` có `file_loaded?`: nếu đường dẫn nạp lại khác lần đầu thì menu và toolbar có thể bị đăng ký hai lần.
9. Sửa tag và vật liệu từ bảng: `entity.layer=` và `entity.material=` trên Group / ComponentInstance trong một operation (Ctrl+Z hoàn tác cả đợt); tag mới tạo bằng `model.layers.add`; danh sách vật liệu theo `display_name`; nhấp đúp trong HtmlDialog của SketchUp (hai lần bấm có bị SketchUp nuốt không).
10. Chọn nhiều dòng trong bảng: SketchUp chọn theo (`selection.add` nhiều đối tượng, đổi `active_path` về cấp chung), thu phóng tới nhiều đối tượng, khung đánh dấu nhiều đối tượng, và bảng không bị quét lại khi SketchUp báo đúng vùng chọn vừa đặt; phím Ctrl / Shift / Ctrl+A / Esc trong HtmlDialog của SketchUp.
11. Đổi tên hàng loạt trong SketchUp thật: gán `name` cho Group / ComponentInstance trong một operation (Ctrl+Z hoàn tác cả đợt), vị trí khi đánh số theo vị trí (góc nhỏ nhất của khung bao, tọa độ thế giới), giao diện panel trong cửa sổ thật.
12. Undo thật của sửa bảng và chuyển đổi; chọn dòng kiểm tra tới đúng đối tượng lồng nhau; lưu và mở lại metadata; model thật đang dùng.
13. **Chụp ảnh** (`View#write_image`): ảnh có thật sự đúng (cô lập, zoom vừa món đồ, nền trong suốt `transparent: true`, nền trắng bằng `BackgroundColor` / `DrawGround` / `DrawHorizon`), khung đánh dấu và đường viền chọn không lọt vào ảnh, `start_operation(..., true)` rồi `abort_operation` trả đúng trạng thái ẩn / hiện mà không để lại bước hoàn tác, camera và lựa chọn được trả lại, thời gian chụp nhiều đối tượng, thư mục lưu ảnh (tạo thư mục, ký tự có dấu trong đường dẫn), chế độ khung nhìn hiện tại.
14. **Tab Hình ảnh trong HtmlDialog thật**: kéo thả file ảnh vào ô, dán (Ctrl+V) từ clipboard, `createImageBitmap` / canvas, hiện ảnh bằng data URL, chọn file ảnh; hộp chọn thư mục `UI.select_directory`, mở thư mục bằng `UI.openURL("file:///…")`. Nếu kéo thả hoặc dán không hoạt động trong SketchUp, vẫn dùng được nút **Chọn ảnh…**.
15. **Ngôn ngữ English**: đổi ngôn ngữ làm cửa sổ tự tải lại (`location.reload`) rồi nhận cấu hình mới; cần kiểm tra trong HtmlDialog thật không bị treo hay mất trạng thái.
16. Đơn vị chiều dài cm / m trên nhãn khung đánh dấu trong viewport.
17. `dev/native_smoke.rb` (chạy trong tiến trình SketchUp mới với model trống) chưa chạy cho bản 1.1.0 và chưa bao phủ bảng khối lượng, soạn tag, khung đánh dấu.

## Lịch sử

Bản 0.1.x từng được cài và xác minh hash trong Plugins của SketchUp 2022 và kiểm tra giao diện bằng Playwright, nhưng lần chạy `native_smoke.rb` thử trong một tiến trình SketchUp riêng không sinh được `native_report.json` do công cụ điều khiển cửa sổ lỗi, nên không coi là đã pass. Bản 1.0.0 chỉ được kiểm tra tự động (cú pháp Ruby, JSON, đóng gói RBZ).
