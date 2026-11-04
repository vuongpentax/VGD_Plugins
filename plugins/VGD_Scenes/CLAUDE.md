# VGD Scenes

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây vì dễ lỗi thời: xem nơi giữ phiên bản ở mục "Thông tin plugin".

## Thông tin plugin

- Tên extension: VGD Scenes. Namespace: `VGD::Scenes`.
- Loader: `runtime/vgd_scenes.rb` (nạp `vgd_scenes/main`).
- Phiên bản: hằng `VERSION` trong `runtime/vgd_scenes.rb` và trong `runtime/vgd_scenes/main.rb`; hai chỗ phải khớp.
- SketchUp tối thiểu: 2022 (Ruby 2.7). SketchUp 2022 không có Overlay API; dùng Tool.
- Dữ liệu: `%APPDATA%/VGD/Scenes/scene_clipboard_v1.json`.

## Cấu trúc

- `runtime/`: loader và thư mục `vgd_scenes/`.
- `dev/`: test, `package.py`, `deploy.ps1`, `native_smoke.rb`, `check_ruby27.py`, `package.json`.
- `research/`: tư liệu nghiên cứu.

## Kiểm thử

- Từ `plugins/VGD_Scenes/dev`: `npm install` một lần, rồi `npm test` (cần Node 20+ và Chrome). Có thể chạy riêng `npm run test:ruby`. Thư viện Node chỉ phục vụ kiểm tra, không cần cho runtime.
- Từ gốc repo, nếu có SketchUp 2022 và Python 3.8+: `python plugins/VGD_Scenes/dev/check_ruby27.py` để kiểm tra thêm bằng Ruby 2.7.2 của SketchUp 2022 (đường dẫn khác đặt qua biến môi trường, xem README).
- Chưa xác minh native: tạo scene và export trong SketchUp thật, LayOut API; xem `HANDOFF.md` mục "Kiểm tra và việc cần tiếp tục".

## Đóng gói

- `python dev/package.py` tạo RBZ. RBZ là ZIP của **nội dung** `runtime/` (loader và thư mục ngang hàng), không bọc thêm thư mục `runtime`. Khi runtime đổi thì tạo lại RBZ.
- `dev/deploy.ps1` mặc định cài vào SketchUp 2022 (allowlist file, có backup/rollback); dùng `-PluginRoot` cho bản khác.
- Không đưa `node_modules`, file xuất thử hay bản sao cài đặt lên git.

## Tài liệu đọc trước khi sửa

- `README.md`, `HANDOFF.md` (yêu cầu người dùng, phạm vi bảo vệ khi cài, lịch sử thay đổi).

## Quy tắc riêng

- Không dùng `SectionPlane.deactivate` hoặc `Entities.bounds`. Cẩn thận `Styles.selected_style=` với `active_style` trên SketchUp trước 2025.
- Không xóa definition, attribute, scene cũ hay mặt cắt thuộc plugin khác. Chỉ thao tác scene không do VGD tạo khi người dùng chọn.
- Preview mặt cắt dùng operation thường, không dùng transparent operation. Chưa có observer chặn Save khi đang preview, nên tắt preview trước khi lưu SKP. Native Undo/Redo trong lúc preview chưa được kiểm chứng; không khẳng định đã loại bỏ mọi crash.
- `dev/native_smoke.rb` chỉ chạy với model rỗng; guard từ chối model có geometry hoặc scene. Không bỏ guard để chạy trong bản vẽ đang làm.
