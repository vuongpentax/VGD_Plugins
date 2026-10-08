# Bàn giao VGD_Library

Cập nhật ngày 05/10/2026, bản 1.1.2-beta.2. Người dùng chọn VGD độc lập rồi yêu cầu mọi nhóm chức năng thấy trong N-TEXTURE RBZ, kể cả model. Kho Drive chỉ vật liệu; người dùng sẽ giải nén/sắp xếp sau. Không tổ chức lại kho.

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

Ruby syntax 14 files + engine/advanced/Drive/preferences/timers/online errors + binary SKM ZIP: PASS. UI Edge/Playwright: PASS. Native Node inventory metadata-only: no errors. Package excludes original code/DLL/license/server; see FEATURE_PARITY.md for behavior differences. Installed files updated with backup and SHA verification; no native SketchUp UI/geometry validation, commit or push. Do not modify unrelated projects together with this work.

## Sửa lỗi ngày 05/10/2026 — 1.1.1-beta.1

- Sửa SyntaxError khi đọc JSON có dấu nháy qua `Sketchup.read_default`: lưu JSON dưới dạng Base64 có prefix và key `json2_*`. Khôi phục các giá trị cũ từ đúng section VGD_Library trong PrivatePreferences.json trên Windows bằng JSON.parse, không eval dữ liệu đó. Bảo toàn folder, online sources, favorites và update URL nếu dữ liệu cũ còn hợp lệ.
- Callback mở picker được đánh dấu đã chạy và dừng timer trước khi xử lý, nên không mở thêm hộp thoại khi SketchUp gọi lại trong lúc modal còn mở. Callback download, seamless và observer cũng dùng cùng helper.
- Bộ quét chặn reentrant/stale callback, dừng timer và kết thúc trạng thái loading khi có lỗi, thay vì báo lỗi liên tục.
- Test regression tái hiện quoted-literal SyntaxError, cấu hình Unicode/quotes/backslashes, callback picker tái nhập và callback scan bị lỗi/stale. Ruby WASI không hỗ trợ Enumerator#next fibers: traversal thật được consume bằng to_a rồi adapter đưa entry cho timer orchestration.

Sau khi cập nhật, lưu bản vẽ, đóng tất cả cửa sổ SketchUp rồi mở lại. Không cần xóa cấu hình hoặc thư viện. Bản RBZ mới là `VGD_Library_v1.1.1-beta.1.rbz`.

## Sửa lỗi HTML Drive phủ cửa sổ — 1.1.2-beta.1

- Link folder Drive trước đây được lưu như URL danh mục JSON. HTTP 200 trả HTML, JSON::ParserError chứa toàn bộ response; dòng footer không giới hạn chiều cao đã ép workspace về 0 pixel. Tái hiện với đúng URL người dùng: HTML 943.144 byte, footer 688px/workspace 0 ở viewport 1120×760.
- `Drive.migrate_sources` chạy trước scan: nguồn folder đúng ID đã cấu hình được chuyển sang local root đã đồng bộ nếu tồn tại. Không tự mở picker, không thay đổi tệp trong kho. Nếu chưa sync, giữ cấu hình và báo hướng dẫn ngắn, bỏ qua HTTP cho folder web. Các nguồn JSON khác được bảo toàn. `Online.add` cũng nhận diện link folder/open?id của kho này.
- `Online.parse_catalog` báo lỗi HTML/JSON/schema bằng câu ngắn; áp dụng manifest, import và update. Không cache HTML. Footer cố định 38px, thông báo/tooltip tối đa 500 ký tự; UI và Ruby đều chặn raw HTML. Sidebar có scroll để các nút vẫn truy cập được khi cửa sổ nhỏ.
- Ruby regression dùng phản hồi Drive thật đã tải ở outputs (fallback HTML fixture trên máy khác), kiểm tra migration/dedupe/offline/no HTTP/no picker/valid source vẫn tải/scan complete. UI kiểm tra HTML thật và thông báo dài tại 1120×760 và 720×600, kể cả ghi trực tiếp DOM bỏ qua feedback để kiểm chứng CSS. `outputs/drive_error_fixed.png` là ảnh UI mô phỏng, không phải ảnh SketchUp native.
- `dev/apply_hotfix.ps1` cập nhật 9 file cài đặt SU2022, sao lưu vào workspace và kiểm tra SHA-256. Cần lưu và đóng tất cả cửa sổ SketchUp rồi mở lại; không tự tắt ứng dụng đang có bản vẽ.
