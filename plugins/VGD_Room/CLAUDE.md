# VGD Room

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây vì dễ lỗi thời: xem nơi giữ phiên bản ở mục "Thông tin plugin".

## Thông tin plugin

- Tên extension: VGD Room. Namespace: `VGD::Room`.
- Loader: `runtime/vgd_room.rb` (nạp `vgd_room/main`).
- Phiên bản: hằng `VERSION` trong `runtime/vgd_room.rb`. Đóng gói cần `RELEASE_NOTES_v<x.y.z>.md` (bản beta dùng chung ghi chú của bản chốt).
- SketchUp tối thiểu: 2022.
- Chưa có trong `shared/vgd-center/catalog.json` (thêm khi phát hành, theo quy trình ở `CLAUDE.md` gốc).

## Cấu trúc

- `runtime/vgd_room/`: `main.rb` (đăng ký cầu nối), `builder.rb` (dựng khối), `bridge_registry.rb` (bản sao GIỐNG HỆT `plugins/VGD_BIM/runtime/vgd_bim/core/bridge.rb`: sửa một nơi phải sửa nơi kia).
- `dev/`: `run_tests.rb`, `test_builder.rb`, `package.py`.

## Kiểm thử

Từ `plugins/VGD_Room`: `ruby dev/run_tests.rb`. Test dùng SketchUp giả lập; phần dựng hình thật chưa xác minh trong SketchUp (xem README).

## Đóng gói

Từ gốc repo: `python plugins/VGD_Room/dev/package.py <phiên bản>`. File `.rbz` và `outputs/` không đưa vào git.

## Quy tắc riêng

- Plugin KHÔNG có giao diện riêng và KHÔNG tính khối lượng: VGD_BIM quản lý dữ liệu và điều khiển (`docs/vgd_bim/ROADMAP.md` mục 1b, `docs/vgd_bim/BRIDGE.md`). Không thêm tính năng ngoài dựng khối phòng nếu chưa được yêu cầu.
- Dữ liệu phòng do VGD_BIM gửi luôn được kiểm tra lại (`Builder.validate!`). VGD ID do BIM cấp, plugin không tự sinh; dựng lại giữ ID cũ.
- Mỗi lần dựng là MỘT thao tác (`start_operation` ... `commit_operation`, hủy khi lỗi), không để lại thao tác dở.
- Chỉ ghi vào dictionary `VGD_BIM_ID` và `VGD_BIM_SOURCE` của khối do chính plugin dựng; không đụng `VGD_BIM` hay dictionary của plugin khác.
- Khối đang bị khóa thì không dựng lại (báo rõ), không tự mở khóa.
