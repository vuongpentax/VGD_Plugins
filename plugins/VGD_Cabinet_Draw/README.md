# VGD_Cabinet Draw 1.0.0-beta.34

Trạng thái: beta.34 bổ sung tự cập nhật tủ khi kéo Scale (co giãn tại chỗ, giữ ván và chi tiết đã làm). Nền tảng từ beta.33 đã đưa vào repository, thay cho baseline beta.1 (lịch sử beta.1 vẫn còn trong git).

- Đã xác minh tự động: bộ test giả lập (`test/`), gồm `test_stretch.rb` cho tự cập nhật khi Scale.
- Chưa xác minh: chưa mở trong SketchUp thật; chưa kiểm tra tương thích Ruby 2.7 đầy đủ (chỉ kiểm cú pháp bằng `ruby -c`).

## Tự cập nhật khi kéo Scale (beta.34)

- Kéo Scale tủ xong (thả chuột) thì tủ tự dựng lại theo kích thước mới. Không cần mở Box → Board.
- Vỏ tủ và đợt/vách được co giãn tại chỗ, không xóa tạo lại: khấu, cắt, bo, vật liệu và tên được giữ.
- Vân vật liệu được đặt lại theo kích thước thật, không bị kéo theo tấm.
- Ngăn kéo, cánh, tay nắm, xà chặn và hộc tủ áo vẫn dựng lại từ công thức.
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
