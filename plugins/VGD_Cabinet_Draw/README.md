# VGD_Cabinet Draw 1.0.0-beta.38

Trạng thái: beta.38 thêm sáu kiểu hậu theo DC (âm 4 cạnh, âm 2 hông, lùa trên, lùa đáy, phủ, không hậu). beta.35 mở rộng tự cập nhật tủ khi kéo Scale sang ngăn kéo, khoang, xà chặn, hộc tủ áo và cánh (giai đoạn 2). beta.34 là giai đoạn 1 (vỏ tủ và đợt/vách). Nền tảng từ beta.33 đã đưa vào repository, thay cho baseline beta.1 (lịch sử beta.1 vẫn còn trong git).

- Đã xác minh tự động: bộ test giả lập (`test/`), gồm `test_stretch.rb` cho tự cập nhật khi Scale.
- Chưa xác minh: chưa mở trong SketchUp thật; chưa kiểm tra tương thích Ruby 2.7 đầy đủ (chỉ kiểm cú pháp bằng `ruby -c`).

## Tự cập nhật khi kéo Scale (beta.34 giai đoạn 1, beta.35 giai đoạn 2, beta.36 liên kết)

- Kéo Scale tủ xong (thả chuột) thì tủ tự dựng lại theo kích thước mới. Không cần mở Box → Board.
- Mọi cấu kiện đã có được co giãn tại chỗ, không xóa tạo lại: vỏ tủ, đợt/vách, mặt và thùng ngăn kéo, khoang, xà chặn, hộc tủ áo, cánh. Khấu, cắt, bo, vật liệu, tên và tay nắm được giữ.
- Vân vật liệu được đặt lại theo kích thước thật, không bị kéo theo tấm.
- Cánh đang mở được đóng về 0 trước khi co giãn, rồi mở lại đúng góc cũ quanh bản lề mới. Ngăn kéo đang kéo ra được đóng lại.
- Tay nắm cách mép đã chọn một khoảng mm cố định (xem phần Liên kết bên dưới).
- Liên kết (module `links.rb`): cánh mở trái/phải bắt bản lề vào hông trái/phải, mở lên vào nóc, mở xuống vào đáy. Cánh mở lên/xuống được xử lý trước. Nếu bản lề không còn bắt được vào tấm vỏ tủ thì tủ giữ nguyên và báo lỗi.
- Kích thước cố định theo mm: khung, gờ và khe cánh, thùng và đáy ngăn kéo, hông khoang giữ nguyên độ dày. Cánh, mặt hộc, khoang, xà chặn và hộc tủ áo được dựng lại nội dung ở kích thước mới.
- Tay nắm cách mép đã chọn một khoảng mm cố định.
- Xóa (beta.37): Alt-click trong công cụ Đợt/vách xóa một tấm; Shift-click đánh dấu nhiều tấm rồi xóa qua chuột phải. Chuột phải lên đợt/vách, cánh, ngăn kéo cũng có mục xóa. Cánh: chuột phải → xóa cánh (vùng thành trống, không gộp vào cánh bên cạnh); Alt+G (hoặc G) gộp vùng cánh đã chọn. Xóa đợt làm các đợt còn lại đổi sang vị trí tuyệt đối trước, nên không dời theo.
- Quan hệ giữa công cụ và cấu kiện: xem `docs/QUAN_HE_CONG_CU.md`.
- Chưa làm: lỗ khấu, cắt, bo trên vỏ tủ vẫn co theo tỷ lệ; cam, chốt, lề chưa làm.
- Tắt/bật ở tab 5 · Setting chung. Mặc định bật.
- Một lần kéo Scale tạo hai bước Undo: bước Scale và bước tự cập nhật.

VGD_Cabinet Draw is a standalone SketchUp extension for a semi-automatic cabinet workflow. It keeps the user in control of face orientation, panel positions, door splits, openings, handles, drawers and finishing operations. Preview lives in the viewport; a tool commits model geometry only when the user presses Enter.

The extension is registered independently from VGD_Cabinet. It uses its own `VGD_Cabinet_Draw` model dictionary and `%APPDATA%/VGD/SketchUp/VGD_Cabinet_Draw` data folder. It does not import old cabinet model dictionaries or preset files. The old extension sources remain untouched beside this project.

## Workflow

Mô tả dưới đây viết cho beta.1 và chưa đối chiếu lại với beta.33. Khi kiểm thử thủ công beta.33, cần cập nhật lại.

1. Select a rough box and use **Box → Cabinet**. Click its front face to confirm local orientation.
2. Add shelves/partitions with the viewport tool. Enter a distance or `/n` in SketchUp's Measurements box to place or divide evenly.
3. Draw door splits on the cabinet face, set the opening direction, and place drawer fronts and boxes.
4. Add handles and blockers, then use cut, round and notch tools for manual finishing.
5. Save settings to a grouped preset for the next model.

## Development and validation

- Runtime entry point: `main.rb` → `runtime/VGD_Cabinet_Draw/main.rb`.
- Native target: SketchUp 2022, Ruby 2.7.
- Tests: chạy từ thư mục `test/`, ví dụ `ruby test_build.rb`. Có 15 file `test_*.rb`. Mặc định các bài test trỏ tới `../runtime/VGD_Cabinet_Draw`.
- Package builder: `dev/build_release.py`. Tạo `outputs/` (đã bị `.gitignore` bỏ qua). Gói `.rbz` gồm `VGD_Cabinet_Draw.rb`, `VGD_Cabinet_Draw/main.rb` và toàn bộ `runtime/`.
- Native acceptance script: `dev/native_smoke.rb` (từ beta.1, chưa đối chiếu với beta.33, không chạy trong đợt chuyển repository).

## Điều chưa kiểm chứng

- Toàn bộ test là giả lập. Click chọn, preview, Undo, chiều pushpull và hiệu năng chưa kiểm trong SketchUp thật.
- `runtime/VGD_Cabinet_Draw/vgd-theme/` đang khác `shared/vgd-theme/`, nên `tools/sync_vgd_theme.py --check` báo lệch. Chưa đồng bộ vì việc đó sẽ đổi giao diện.
- Tương thích Ruby 2.7 chưa kiểm (môi trường kiểm thử là Ruby 3.3).
