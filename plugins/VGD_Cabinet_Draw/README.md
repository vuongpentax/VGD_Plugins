# VGD_Cabinet Draw 1.0.0-beta.33

Trạng thái: mã nguồn beta.33 từ bộ bàn giao đã được đưa vào repository, thay cho baseline beta.1 (lịch sử beta.1 vẫn còn trong git).

- Đã xác minh tự động: 15 bộ test giả lập (`test/`), chạy trên Ruby 3.3, hai lượt đều đạt.
- Chưa xác minh: chưa mở trong SketchUp thật; chưa kiểm tra tương thích Ruby 2.7 đầy đủ (chỉ kiểm cú pháp bằng `ruby -c`).

VGD_Cabinet Draw is a standalone SketchUp extension for a semi-automatic cabinet workflow. It keeps the user in control of face orientation, panel positions, door splits, openings, handles, drawers and finishing operations. Preview lives in the viewport; a tool commits model geometry only when the user presses Enter.

The extension is registered independently from VGD_Cabinet. It uses its own `VGD_Cabinet_Draw` model dictionary and `%APPDATA%/VGD/SketchUp/VGD_Cabinet_Draw` data folder. It does not import old cabinet model dictionaries or preset files. VGD_Cabinet remains a separate plugin in `plugins/VGD_Cabinet`.

## Công cụ và menu

Theo `TOOLBAR_BUTTONS` và menu trong `runtime/VGD_Cabinet_Draw/main.rb` (menu **Extensions → VGD Cabinet Draw** và thanh công cụ cùng tên):

1. **Box → Board**: chọn box rồi click mặt trước để chuyển thành thùng tủ, hoặc chọn face để tạo ván.
2. **Chia đợt / vách**: chia đợt (nóc/đáy) hoặc vách (hông); rê chuột xem trước, click để đặt.
3. **Cánh tủ**: chia vùng cánh trên mặt tủ.
4. **Ngăn kéo**: tạo mặt và thùng kéo.
5. **VGD Chọn**: bật công cụ rồi chuột phải lên tủ, cánh hoặc mặt hộc để hiện thanh nút tròn tại con trỏ.
6. **Setting**: mở bảng điều khiển để chỉnh, lưu, xuất và nhập setting cho từng công cụ.
7. Chỉ có trong menu: **Đóng tất cả cánh của tủ đang chọn**, **Tìm tấm bị trùng**, **Chuẩn hóa tên ván (vai trò + số)**, **Tải lại VGD Cabinet Draw (nạp code mới)**.

Mô tả này lấy từ mã của beta.33; hành vi chi tiết của từng công cụ chưa được kiểm thử thủ công trong SketchUp.

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
