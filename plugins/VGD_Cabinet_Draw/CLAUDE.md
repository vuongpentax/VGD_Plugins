# VGD_Cabinet Draw

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây vì dễ lỗi thời: xem nơi giữ phiên bản ở mục "Thông tin plugin".

## Thông tin plugin

- Tên extension: VGD_Cabinet Draw. Namespace: `VGD_Cabinet_Draw` (không có tiền tố `VGD::`).
- Loader: `VGD_Cabinet_Draw.rb` (nạp `VGD_Cabinet_Draw/main`); `main.rb` gọi `runtime/VGD_Cabinet_Draw/main.rb`.
- Phiên bản: `VERSION` trong `runtime/VGD_Cabinet_Draw/main.rb`. Phải khớp `extension.version` trong `VGD_Cabinet_Draw.rb` và số phiên bản trong `runtime/VGD_Cabinet_Draw/dialog.html`: đổi phiên bản thì sửa cả ba chỗ.
- SketchUp tối thiểu: 2022, dùng Ruby 2.7. Code phải chạy được trên Ruby 2.7 dù test chạy ở Ruby 3.x.
- Dữ liệu: dictionary model `VGD_Cabinet_Draw` và thư mục `%APPDATA%/VGD/SketchUp/VGD_Cabinet_Draw`. Không đọc dictionary hay preset của VGD_Cabinet cũ.

## Cấu trúc

- `runtime/VGD_Cabinet_Draw/`: các module nạp theo thứ tự trong `RUNTIME_FILES` của `main.rb`. Module mới phải khai báo thêm trong `RUNTIME_FILES` và `RUNTIME_CONSTANTS`.
- `test/`: các file `test_*.rb` và giả lập SketchUp (`mock_su.rb`, `sketchup.rb`).
- `dev/`: `build_release.py`, `native_smoke.rb`. `icon.svg` ở gốc plugin.

## Kiểm thử

- Chạy từng file từ `plugins/VGD_Cabinet_Draw/test`, ví dụ `ruby test_build.rb`. Mặc định các test trỏ tới `../runtime/VGD_Cabinet_Draw`. Chạy đủ mọi `test_*.rb` trước khi đóng gói.
- Test dùng giả lập SketchUp, không phải SketchUp thật. Không ghi là đã test trong SketchUp khi chỉ chạy các test này.
- `dev/native_smoke.rb` có thao tác hình học, chỉ chạy trong SketchUp thật; chưa đối chiếu với bản hiện tại.
- Phần chưa xác minh: xem `README.md`.

## Đóng gói

- `python3 dev/build_release.py` tạo `outputs/` (git bỏ qua). Gói `.rbz` gồm `VGD_Cabinet_Draw.rb`, `VGD_Cabinet_Draw/main.rb` và toàn bộ `runtime/`; script tự quét thư mục `runtime/`, không có danh sách file cứng.

## Tài liệu đọc trước khi sửa

- `README.md`.

## Quy tắc riêng

- Mọi cấu kiện là group, không dùng component (`Geometry::SHARE_COMPONENTS = false`). Đổi group thành component trong cùng một operation xóa các group vừa tạo, làm plugin khác nghe `onElementAdded` (ví dụ VGD_Dim) lỗi "reference to deleted Group". Không tạo rồi xóa group trong cùng một operation.
- Nếu sửa mã Ruby, kiểm tra cú pháp bằng `ruby -c` cho từng file; chưa có kiểm tra tương thích Ruby 2.7 đầy đủ.
