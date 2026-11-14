# VGD_Cabinet

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây vì dễ lỗi thời: xem nơi giữ phiên bản ở mục "Thông tin plugin".

## Thông tin plugin

- Tên extension: VGD Cabinet (bản đang phát hành trong catalog của VGD Center, khác VGD Cabinet Draw). Namespace: `VGD_Cabinet`.
- Loader: `cabinet_work/vgd_cabinet.rb`.
- Phiên bản: `VERSION` trong `cabinet_work/vgd_cabinet/main43.rb`.
- SketchUp tối thiểu: 2022. Chỉ deploy vào SketchUp 2022.

## Cấu trúc

- `cabinet_work/`: mã nguồn hiện hành (`vgd_cabinet.rb` và thư mục `vgd_cabinet/`).
- `cabinet_dev/`: test, bộ sinh giao diện (`redesign_ui.cjs`), `package_menu.py`, `sync_sketchup_2022.ps1`, `package.json`.

## Kiểm thử

- Lệnh kiểm tra và trạng thái xác minh: `TESTS.txt` (chạy từ `plugins/VGD_Cabinet`; cài dependency bằng `pnpm install --dir cabinet_dev --frozen-lockfile`).
- Phân biệt kết quả giả lập WASM/stub với kiểm tra trong SketchUp thật.

## Đóng gói

- `python cabinet_dev/package_menu.py` tạo RBZ và source ZIP trong `outputs/vgd_cabinet_modeling/` (git bỏ qua).
- Đổi giao diện qua `cabinet_dev/redesign_ui.cjs`, `menu.js`, `menu.css`, rồi sinh lại HTML trước khi đóng gói.

## Tài liệu đọc trước khi sửa

- `HANDOFF.md` (đọc trước khi sửa), `README.md`, `TESTS.txt`, `VALIDATION.json`, `PANO_RESEARCH.md`, `UPGRADE_RESEARCH.md`.

## Quy tắc riêng

Read HANDOFF.md before editing. Current source is cabinet_work; tests/generator/package/deploy are cabinet_dev.
- Communicate in Vietnamese. Keep the extension name VGD_Cabinet, namespace VGD_Cabinet, loader vgd_cabinet.rb.
- Preserve construction rules inherited from T+ Cabinet; the old handoff is an archive, not active runtime.
- Only deploy this Cabinet into SketchUp 2022. Explicit own-file whitelist; back up/retire only tplus_cabinet.rb. Do not modify other plugins, their data, or other SketchUp versions.
- Preserve read compatibility with TPlus_Cabinet model dictionaries. Write new cabinets/updates to VGD_Cabinet; do not migrate unrelated model objects.
- Presets belong in APPDATA/VGD/SketchUp/vgd_cabinet/presets_v1.json. Atomic temporary file, backup, file lock; no preset JSON in installation/Preferences. Read T+ Preferences once when no new store exists.
- Create, update and rename are distinct. Reject collisions, including case-insensitive names. Do not reset saved presets on reload/reinstall.
- New defaults: ceiling strip 20; door perimeter/between/top gaps 0; drawer front perimeter gaps 0; drawer tier gap 25; cabinet tier gap 25.
- front_bevel/bevel_lip now affect doors only. drawer_bevel/drawer_bevel_lip are independent. Migrate legacy shared handles only if handle_split_v1 is absent.
- Pano khung gỗ models separate stiles, rails, real straight grooves and flat floating panels. No CNC/BOM scope. Panel dimensions include groove capture minus expansion clearance. Validate tiny openings and groove/frame thickness.
- Change UI through redesign_ui.cjs/menu.js/menu.css, regenerate HTML before packaging. ui_beta1 is a reference only.
- Run meaningful geometry/preset/DOM/payload/UI/deployment tests. Distinguish WASM/stubs from native SketchUp; file locking is simulated in WASI.
- Deliver RBZ and source ZIP with updated version/validation. Never claim native manifold, Undo or restart unless actually tested in SketchUp.

- 4.5: matching name roles + geometry/materials share component definitions within a cabinet build; preserve left/right hinge separation and moving drawer/module containers.
- Library SKP assets/index/preview belong under APPDATA/VGD/SketchUp/vgd_cabinet/library; preserve user assets and atomic index/backup/locking. Export actual geometry, including manual edits; SU2022 loads must use a unique path to avoid reuse.
- Preview uses an in-memory builder sink; never create temporary model entities/materials/tags/definitions. Native Tool drawing and SKP/manifold must be verified separately from fixtures.
