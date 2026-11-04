# VGD Dim

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây vì dễ lỗi thời: xem nơi giữ phiên bản ở mục "Thông tin plugin".

## Thông tin plugin

- Tên extension: VGD Dim. Namespace: `VGD::Dim`.
- Loader: `runtime/vgd_dim.rb`; thư mục mã `runtime/VGD_Dim/`.
- Phiên bản: `runtime/VGD_Dim/version.rb`. Khi đổi phiên bản, cập nhật cả changelog trong `VGD_UPDATE_MANIFEST.json`.
- SketchUp tối thiểu: 2022.

## Cấu trúc

- `runtime/`: mã chạy.
- `dev/`: `package.py`, `deploy.ps1`, `native_smoke.rb`, `build_ui.py`, các file `test_*` và `check_ruby.cjs`.

## Kiểm thử

- Test nằm trong `dev/`: `test_core.rb`, `test_engine.rb`, `test_smartdim.rb`, `test_store.rb`, `test_regression.rb`, `test_fixture.rb`, `test_native_style.rb`, `test_ui.cjs`, `test_deploy.py`, `test_update_installer.ps1`, `check_ruby.cjs`. Tài liệu không ghi lệnh chạy riêng từng file; xem đầu mỗi file.
- Trạng thái chức năng và phần chưa xác minh native: `FEATURE_STATUS.md`, `DEVELOPMENT_NOTES.md`.

## Đóng gói

- `python dev/package.py` tạo RBZ, source ZIP, `outputs/PACKAGES_SHA256.json` và manifest.
- Quy trình ở `HOW_TO_RELEASE.md` còn nói đưa RBZ vào `shared/vgd-center/packages`, trong khi catalog hiện trỏ GitHub Release. Đối chiếu với `shared/VGD_CENTER_ARCHITECTURE.md` trước khi làm theo.

## Tài liệu đọc trước khi sửa

- `README.md`, `DEVELOPMENT_NOTES.md`, `FEATURE_STATUS.md`, `HOW_TO_RELEASE.md`, `ANNOTATION_REQUIREMENTS.md`, `SELECTION_REQUIREMENTS.md`.

## Quy tắc riêng

Yêu cầu mới ngày 2026-10-07: tiếp tục VGD_Dim_6.rbz, sidebar, mặt cắt/Scene/Tag, thay bộ Dim trùng, one-touch, giới hạn xoay và tách Units. Chỉ phát triển Dim; không sửa Cabinet/Scenes/Importer/Library.

- Tên VGD Dim; loader vgd_dim.rb, namespace VGD::Dim, thư mục VGD_Dim. Style T+ sáng/nâu đồng.
- Phạm vi selected/context/model, mặc định selected; bộ lọc nested/components/hidden/locked. Definition dùng chung dedup, ảnh hưởng các bản sao và giải thích trên UI.
- Smart Dim: trục riêng của tủ, upright yaw/mirror/axis scale; không gắn nhãn projected size cho tilt/shear/khác hệ trục. Group owned metadata, thay bộ cùng nguồn/mặt/Scene sau khi dựng xong; không xóa trùng tên hoặc Group có nội dung thêm tay. Tag mặt cắt riêng, Dim nội bộ Untagged; giữ selection. Không tạo edge/mesh.
- Scene: chỉ riêng Tag bộ Smart và các Scene lưu Tags; không update camera/style hay tự bật flag Scene. Tủ/Group cũ V6 không có metadata không tự xóa. Xem DEVELOPMENT_NOTES.md.
- UI 6 tab, scope chung và theme sáng/tối. Builder mới build_ui.py; import_claude_ui.py là lịch sử.
- Core style: màu tùy bật; Dim endpoint/orientation/position; Label endpoint/leader; Text/Label tag 000 TEXT.
- Rebuild Dim tuyến tính theo mẫu Model Info. Giữ điểm/liên kết/text override/style/attributes; tạo xong mới xóa Dim cũ; lỗi giữ bản cũ, radial skip, cập nhật selection sang replacement. Không hứa giữ persistent ID.
- APPLY mẫu Model Info chỉ Dim/Text chọn trực tiếp trên Windows English. Native Undo riêng, lỗi một phần báo rõ; không nói đã xác minh native nếu chưa chạy.
- Preset và Auto-Style lưu cục bộ. Auto mặc định tắt, observers phải trì hoãn setters, suspend khi thao tác manual, tắt/reload dọn observers/timers, không cản Undo.
- Units tách hoàn toàn khỏi STYLE/Core.run/preset, chỉ apply_units_model từ nút riêng. Mở numeric text mặc định tắt. Animation không có Undo; không hứa Undo Scene/Options nếu chưa kiểm chứng native.
- Không popup hoàn tất; lỗi/kết quả inline. Không nạp dev/claude_reference vào runtime.
- Kiểm thử có ý nghĩa geometry/scopes/rebuild/error/services/UI. Deploy whitelist 34 file, backup/hash, không tác động plugin khác.

- Updater pilot beta.2 chỉ áp dụng cho VGD Dim; kiểm tra manifest và RBZ qua HTTPS, cài sau khi SketchUp đóng. Pilot chỉ hỗ trợ Windows; native acceptance vẫn cần kiểm tra riêng.
