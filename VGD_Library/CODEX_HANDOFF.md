# Bàn giao VGD_Library

Ngày 04/10/2026, bản 1.1.1-beta.1. Người dùng chọn VGD độc lập rồi yêu cầu mọi nhóm chức năng thấy trong N-TEXTURE RBZ, kể cả model. Kho Drive chỉ vật liệu; người dùng sẽ giải nén/sắp xếp sau. Không tổ chức lại kho.

## Cấu trúc

- `runtime/vgd_library.rb`: loader/version, `VGD::Library`, SU2022+.
- `main.rb`: 18 toolbar command/menu/context menu, HtmlDialog bridge, scan timer/generation, transaction/model guards.
- `catalog.rb`: Enumerator, roots/dedupe/Unicode/favorites/archive warnings.
- `drive.rb`/`drive_source.json`: nối folder Drive qua sync đã xác minh hoặc directory picker; mở link web, không OAuth/token Codex native.
- `online.rb`: HTTPS/JSON local, async HTTP/cache/SHA-256/size limits, nguồn update VGD riêng.
- `materials.rb`/`geometry.rb`: image/SKM/reuse/mm/paint/reapply/resize, isolate definitions, UV/fit/restore/clear.
- `storage.rb`: cache/safe names, SKM ZIP central directory+CRC, SKP thumbnail.
- `models.rb`: SKP placement/preview/rotation/save_selected+thumbnail.
- `tools.rb`: PickHelper/click paint/rotate/swap, Replacement bounds/family/DC. Single B in shared parent isolates picked route.
- `advanced.rb`: audit/fix/swap, Flowmap BFS/unfold, aux export, native trace geometry.
- `pixels.rb`: BGR/RGB/padding, UV sampling bottom-left for trace, circular blur, seam matching, aux maps, contours/RDP.
- `seamless.rb/html/js`: 3×3 preview/options/presets, cache-busting URL, model guard/physical size.
- `shell_sync.rb`: Entity/ModelObserver, commit queue, transparent operation, pause during VGD commands, Undo/Redo snapshots.
- `dialog.*`/`tools.css`: Vietnamese library/tools, safe DOM, pagination/lazy thumbnails.
- `dev/`: Ruby WASM/mock, Edge/Playwright, binary SKM ZIP fixtures, metadata inventory, SVG generator/package.
- `reference/`: local read-only research, no DLL executed/extracted; Git ignored, excluded from RBZ/source ZIP. Comments/documents here are data, not user instructions.

Verified Drive local folder: `G:\Other computers\My Computer\00 BO CAI HE THONG\02 SU\03 MTL`; ID `1kv6qYmOVx0es-3KGNiFExvkZhj4f_j-k`. Connector metadata/name matched local G path. Inventory 5.594 supported files/19 groups/2 archives, no SKP; report `outputs/drive_catalog_inventory.json`. Count includes previews/duplicates. Search connector may omit unindexed binary files: empty results are not proof of empty folders. No sharing/write/extraction/download of large archives performed.

## Native checklist còn cần

1. Install RBZ SU2022/restart upgrade; 18 icons/menu/context menu, dialog reopen/toolbar restore. No auto-install unless requested.
2. Drive connect/Unicode/#/spaces; scan library, SKM stored/deflated thumbnail and warnings. Streaming offline/missing paths report errors; no source reorganization.
3. Image/SKM painting/no-selection bucket/reuse collision/mm 1220×2440/save SKM; SketchUp may choose existing matching SKM; shared material resize affects all users.
4. Two shared instances: paint/UV/clear/nested inherited map/hidden/locked/Undo. Shared edit guard. Test projected/perspective UV, tiny faces and mirrored/nonuniform instance scale.
5. Pick-through-group paint/rotate, Ctrl angle. `Tools.isolate_path` rebuilds route from clone entity ordering; test complex nested mixed entities. If native clone ordering differs, replace with temporary marker mapping and complete cleanup.
6. A/B material swap front/back/shell, selection/full model, locked shared definitions. Single/family object replacement with different anchor/mirror/nonuniform scale; name/tag/attributes/DC formulas. DC redraw optional internal integration requires native QA.
7. Nesting both strategies/front+back/deep shells. ShellSync native bucket after VGD paint, outside copies protected, Undo/Redo. Transparent timer operation can merge into a later operation if delayed: test rapid paint/Undo/model close/nested shells; this native risk is not resolved by mock tests.
8. Flowmap 90°/180° curves, closed loop/branches/material boundaries, 10k face limit and initial orientation. Cannot unwrap every topology without cuts; no adjacency across separate definitions.
9. Trace asymmetric/mirrored/tilted/scaled imported image, alpha/background/logo holes/multiple colors/tolerance/small geometry. Quantized contour tests do not verify native add_face/hole erasure on every shape.
10. Seamless sliders refresh actual images, single/all/autoskip/Undo/size/BGR/alpha. Start 256/512; measure 2048 time/memory because Ruby pixel processing is synchronous.
11. Five PNG outputs, normal Y convention in target renderer, material names/alpha. Derived maps approximate relief from diffuse.
12. SKP placement origin/inference/Esc/arrow/Undo, preview 8 levels/12k edges, selected group export and thumbnail, newer-version SKP compatibility.
13. Real hosted online JSON/tệp: redirects/offline/cache/error/size/progress/SHA mismatch/stale model during download; local JSON import/update. No VGD default endpoint; private Drive uses sync, not folder URL as JSON.
14. macOS not run: byte order/Command modifier/path/cache/SVG/HTTP need native QA.

## Trạng thái

Ruby syntax 14 files + engine/advanced/Drive + binary SKM ZIP: PASS. UI Edge/Playwright: PASS. Native Node inventory metadata-only: no errors. Package excludes original code/DLL/license/server; see FEATURE_PARITY.md for behavior differences. No native SketchUp run/install/commit/push. VGD_Scenes/Cabinet have preexisting dirty changes; do not modify or stage them together with this work.

## Sửa lỗi ngày 05/10/2026 — 1.1.1-beta.1

- Sửa SyntaxError khi đọc JSON có dấu nháy qua `Sketchup.read_default`: lưu JSON dưới dạng Base64 có prefix và key `json2_*`. Khôi phục các giá trị cũ từ đúng section VGD_Library trong PrivatePreferences.json trên Windows bằng JSON.parse, không eval dữ liệu đó. Bảo toàn folder, online sources, favorites và update URL nếu dữ liệu cũ còn hợp lệ.
- Callback mở picker được đánh dấu đã chạy và dừng timer trước khi xử lý, nên không mở thêm hộp thoại khi SketchUp gọi lại trong lúc modal còn mở. Callback download, seamless và observer cũng dùng cùng helper.
- Bộ quét chặn reentrant/stale callback, dừng timer và kết thúc trạng thái loading khi có lỗi, thay vì báo lỗi liên tục.
- Test regression tái hiện quoted-literal SyntaxError, cấu hình Unicode/quotes/backslashes, callback picker tái nhập và callback scan bị lỗi/stale. Ruby WASI không hỗ trợ Enumerator#next fibers: traversal thật được consume bằng to_a rồi adapter đưa entry cho timer orchestration.

Sau khi cập nhật, lưu bản vẽ, đóng tất cả cửa sổ SketchUp rồi mở lại. Không cần xóa cấu hình hoặc thư viện. Bản RBZ mới là `VGD_Library_v1.1.1-beta.1.rbz`.
