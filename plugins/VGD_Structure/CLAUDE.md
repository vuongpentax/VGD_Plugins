# VGD Structure

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây vì dễ lỗi thời: xem nơi giữ phiên bản ở mục "Thông tin plugin".

## Thông tin plugin

- Tên extension: VGD Structure. Namespace: `VGD::Structure`. Id dự kiến trong catalog của Center: `structure` (chưa thêm, thêm khi phát hành).
- Loader: `runtime/vgd_structure.rb` (nạp `vgd_structure/loader`).
- Phiên bản: hằng `VERSION` trong `runtime/vgd_structure.rb`. Tiêu đề README phải khớp. Đóng gói cần `RELEASE_NOTES_v<x.y.z>.md` (bản beta dùng chung ghi chú của bản chốt).
- SketchUp tối thiểu: 2022. Dữ liệu lưu mm.
- Dữ liệu trong model: dictionary `VGD_STRUCT` (dữ liệu nguồn của plugin và dữ liệu riêng trên khối dựng ra), cộng `VGD_BIM_ID` / `VGD_BIM_SOURCE` theo hợp đồng cầu nối (`docs/vgd_bim/BRIDGE.md`).

## Cấu trúc

- `runtime/vgd_structure/loader.rb` giữ danh sách `FILES` (thứ tự nạp, dùng chung cho lúc mở SketchUp và `VGD::Structure.reload`); `core/` logic thuần (hiện có `schema.rb`).
- `dev/`: `run_tests.rb`, `test_reload.rb`, `package.py`, `stubs/` (bản giả `sketchup.rb`, `extensions.rb`).
- Kế hoạch và đặc tả: `docs/vgd_structure/PLAN.md`, `docs/vgd_structure/SPEC.md`.

## Kiểm thử

Từ `plugins/VGD_Structure`: `ruby dev/run_tests.rb`. Test dùng SketchUp giả lập; phần dựng hình thật chưa xác minh trong SketchUp.

## Đóng gói

Từ gốc repo: `python plugins/VGD_Structure/dev/package.py <phiên bản>`. File `.rbz` và `outputs/` không đưa vào git.

## Tài liệu đọc trước khi sửa

- `docs/vgd_structure/PLAN.md` (kế hoạch, quyết định đã chốt), `docs/vgd_structure/SPEC.md` (dữ liệu và quy tắc hình học), `docs/vgd_bim/BRIDGE.md` (hợp đồng cầu nối).

## Quy tắc riêng

- Quy tắc hình học (vị trí cột lọt trong khung lưới: cột giữa tâm trên giao điểm, cột biên và cột góc tiếp giáp trục biên; dầm treo dưới sàn; không chồng khối) nằm ở `docs/vgd_structure/SPEC.md` mục 4 và 5; khi viết mã chỉ giữ ở MỘT bảng hằng số có giải thích, không rải trong nhiều chỗ.
- Mỗi tầng là riêng (cao độ, quy cách, phần đề xuất); không gom tầng giống nhau.
- Mỗi lần dựng là MỘT thao tác hoàn tác; kiểm tra lại mọi dữ liệu người dùng trước khi ghi vào model; không đụng dictionary của plugin khác; VGD ID do VGD_BIM cấp, plugin không tự sinh.
- Dữ liệu `VGD_STRUCT` là nguồn đúng; dựng lại thì hình theo dữ liệu, giữ VGD ID cũ.
