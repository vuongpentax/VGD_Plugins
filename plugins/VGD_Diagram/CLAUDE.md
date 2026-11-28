# VGD Diagram — hướng dẫn cho Claude

## Thông tin plugin

- Tên extension: `VGD Diagram`; loader `runtime/vgd_diagram.rb`; mã trong `runtime/vgd_diagram/`.
- Toolbar: `VGD DGM`, nút bật / tắt (`VGD::Diagram.toggle_dialog`: đang mở thì đóng, theo quy tắc chung ở `CLAUDE.md` gốc). Menu con: `Extensions → VGD → VGD Diagram`, có mục `Tải lại code`; mục menu của hộp thoại chỉ mở (`show_dialog`, lệnh riêng, không dùng chung với nút toolbar).
- Số phiên bản hiện dưới logo trong hộp thoại: Ruby gửi `onVersion` khi `ready`.
- Phiên bản: `runtime/vgd_diagram/version.rb`; README phải khớp khi đổi.
- Mục tiêu: sơ đồ cây lắp ráp, mô hình 3D tách rời và nhãn số cho khách hàng và thợ lắp đặt. Chưa làm: sơ đồ mũi tên hướng lắp, SVG vector, dùng đúng style đang bật của model.

## Cấu trúc

- `tree.rb`: logic thuần (gom cấu kiện, sắp thứ tự, kiểm tra trùng, xuất SVG). Không gọi API SketchUp.
- `scene.rb`: lấy hình học 3D (mặt, đã đổi về tọa độ thế giới, mm) từ model. Chỉ đọc. Giới hạn 100.000 tam giác. Chỉ lấy đối tượng đang thấy (`ModelIO.visible?`).
- `model_io.rb`: đọc cây (từ danh sách thực thể đã chọn), vị trí nhóm để đề xuất thứ tự, ghi thuộc tính `VGD_Diagram/order` trong một thao tác (Undo được), chọn cấu kiện.
- `dialog.rb`, `dialog.html`, `dialog.css`, `dialog.js`: hộp thoại `UI::HtmlDialog`. Giao tiếp Ruby ↔ JS qua `VGD.onTree`, `VGD.onToast`, `VGD.onError` và `sketchup.<tên>(JSON)`.
- `code_files.rb`: danh sách file mã (`CODE_FILES`, theo thứ tự nạp, main cuối), MỘT nơi duy nhất cho cả lúc mở SketchUp (`main.rb`) và `reload.rb`. Thêm file mới thì thêm vào đây và vào `dev/package.py` (`dev/test_reload.rb` kiểm tra).
- `reload.rb`: đọc lại `code_files.rb` từ đĩa, kiểm tra cú pháp cả bộ file trước khi nạp lại (lỗi thì trả danh sách cũ, bản đang chạy giữ nguyên).
- `vendor/three.min.js`: three.js r150.1 (MIT). Không sửa, không thay bằng CDN: plugin phải chạy khi không có mạng.
- `vgd-theme/`: bản copy của `shared/vgd-theme`, đồng bộ bằng `tools/sync_vgd_theme.py`. Không sửa tay.
- `.graphifyignore`: loại `vendor/` (three.js đã nén) khỏi đồ thị `graphify-out/`, để đồ thị chỉ còn mã của plugin.

## Kiểm thử

- `ruby dev/test_tree.rb`: logic và model giả lập.
- `ruby dev/test_reload.rb`: menu, toolbar, tải lại nhiều lần, lỗi cú pháp.
- `ruby dev/test_scene.rb`: lấy hình học 3D từ model giả lập.
- `ruby dev/test_formats.rb`: đuôi file và định dạng khi lưu.
- `ruby dev/test_ffmpeg.rb`: ghép MP4 chạy nền và xóa khung hình bằng ffmpeg thật (cần ffmpeg trong PATH), kể cả tên có dấu `%`, đuôi viết hoa, tiến trình, hủy, ffmpeg đứng, đóng hộp thoại (dùng "ffmpeg giả" chạy chậm bằng `sh`; bộ hẹn giờ `UI.start_timer` do test điều khiển).
- `node dev/test_ui.cjs`: giao diện, khung 3D, nhãn số, đề xuất thứ tự, xuất ảnh, cụm, bước, quay video, bố cục (980×680, 720×560, 1280×800), theme sáng / tối và giải phóng WebGL trong Chromium (Playwright có sẵn; WebGL chạy bằng swiftshader).
- `ruby tests/test_vgd_conventions.rb` (từ gốc repo) sau khi đổi tên, menu, toolbar.
- CI: `.github/workflows/vgd-diagram-tests.yml` chạy các lệnh trên (cài ffmpeg, Playwright 1.63.0; `test_ui.cjs` nhận `VGD_PLAYWRIGHT_MODULE`). CI không thay thế kiểm tra trong SketchUp thật.

## Đóng gói

`python dev/package.py` (từ thư mục plugin). Ghi SHA-256 khi gửi RBZ. `outputs/` và `*.rbz` không commit.

## Tài liệu đọc trước khi sửa

- `README.md` (hành vi và giả định gom nhóm, thứ tự).
- `shared/vgd-theme/` và `shared/HUONG_DAN_THEME.md` mục 9 (chuẩn giao diện dialog).

## Quy tắc riêng

- Chỉ đọc hình học model. Không sửa, xóa, di chuyển cấu kiện. Chỉ ghi thuộc tính `VGD_Diagram`, và chỉ khi người dùng bấm Lưu.
- Phạm vi làm việc là các đối tượng đã chọn lúc bấm Làm mới (`Dialog@scope_ids`), gắn với đúng model lúc đó (`@scope_model`: `entityID` chỉ có nghĩa trong một model, đổi file SketchUp thì phạm vi cũ bị bỏ). Không tự cập nhật khi đổi lựa chọn.
- Xuất ảnh vẽ bằng three.js (style mặc định SketchUp giả lập), không gọi API camera/`write_image` của SketchUp.
- Tên ảnh xuất chỉ gồm chữ thường, số và gạch ngang (kiểm tra ở `Dialog::IMAGE_KEY`).
- Tối đa 15 nhãn trên một ảnh (`MAX_TAGS` trong `dialog.js`).
- Video lắp ráp quay bằng `MediaRecorder` từ canvas trong giao diện. Định dạng quay trực tiếp là webm (`VIDEO_EXT`); MP4 không quay trực tiếp, chỉ có qua chuỗi khung PNG rồi ghép bằng ffmpeg. Hàm lưu: `Dialog#save_video`. Đuôi file trong hộp lưu quyết định định dạng (`Dialog::resolve_format`, test ở `dev/test_formats.rb`).
- Ảnh xuất: png hoặc jpg, chọn như video.
- Tách rời (`dialog.js`): vị trí mọi cụm luôn qua `explodedOffset` (khung 3D, ảnh xuất, video dùng chung). Hướng và khoảng cách riêng từng cụm lưu trong `explodeSettings` theo id, chỉ trong phiên mở hộp thoại; khoảng cách `null` là tự động.
- Đường dẫn ffmpeg lưu bằng `Sketchup.write_default` (`ffmpeg.rb#save_path`). Người dùng có thể nhập file hoặc thư mục (`ffmpeg.rb#resolve` tìm `ffmpeg.exe` trong thư mục, hoặc `bin\ffmpeg.exe`); chỉ lưu file vượt qua kiểm tra `-version` và có bộ mã hóa `libx264` hoặc `mpeg4` (`ENCODERS`, ưu tiên `libx264`).
- Ghép MP4 chạy NỀN (`Ffmpeg.start_encode` / `poll` / `cancel`, `Dialog#finish_frames` / `poll_encode` / `cancel_encode`): `Process.spawn` ghi tiến trình (`-progress`) và thông báo ra file tạm, `UI.start_timer` (`ENCODE_INTERVAL`) đọc lại. KHÔNG dùng luồng Ruby (luồng trong SketchUp chỉ chạy khi giao diện rảnh) và KHÔNG đọc ống (ống đầy thì ffmpeg kẹt). Đang ghép thì `Dialog.busy?` là true (không tải lại code), xuất ảnh / video khác bị chặn (`ensure_not_encoding!`). Hủy, đóng hộp thoại hoặc ffmpeg đứng quá `Ffmpeg::STALL_SECONDS` thì `KILL`, xóa MP4 dở và file tạm, giữ ảnh khung hình. Bộ hẹn giờ không được để lỗi bất ngờ lan ra (báo lặp mỗi 0,3 giây): `poll_encode` bắt lỗi và hủy.
- `ffmpeg.rb` gọi ffmpeg bằng danh sách tham số (không qua shell). Chỉ chạy file ffmpeg đã chọn hoặc lệnh `ffmpeg` trong PATH. Chỉ xóa khung hình do plugin vừa xuất, và chỉ sau khi người dùng xác nhận và ghép thành công.
- Tên file lấy đuôi bằng `File.extname` (không phân biệt hoa thường), không `basename(path, ".png")`. Mẫu khung hình cho ffmpeg dựng bằng `Ffmpeg.frame_pattern` (thoát `%` thành `%%`): tên thư mục hoặc file người dùng đặt có thể chứa `%`.
- Mỗi renderer WebGL tạm của lần xuất ảnh / video phải trả bằng `releaseRenderer` (`dispose` + `forceContextLoss`); trình duyệt chỉ cho khoảng 16 context cùng lúc.
- Video dạng PNG (chuỗi khung hình) không dùng MediaRecorder: `exportFrames` gửi từng khung qua `save_frame`, kết thúc bằng `video_done` (`Dialog#finish_frames`).
- Giao diện (`dialog.html`, `dialog.css`): theo `shared/HUONG_DAN_THEME.md`. Chỉ dùng token `--vgd-*` có trong `vgd-theme.css` (không có `--vgd-input`: nền ô nhập là biến cục bộ `--field`), nạp `vgd-theme/vgd-controls.css`, ô chọn / ô nhập / nút theo theme, không màu hex cứng; nút mặc định là nút phụ, nút chính (Lưu thứ tự) dùng `.primary`. Bố cục hai cột: cột trái là cây và nút Lưu thứ tự ngay dưới cây, cột phải là khung 3D, Tách rời, Phát lắp ráp và nhóm **Xuất** (ô chọn định dạng ghép liền nút bằng `.combo`), ffmpeg ở mục gập; chân cửa sổ là dòng trạng thái và (khi đang ghép MP4) thanh tiến trình kèm nút Hủy (`#encode-row`, không được làm chân cao thêm). Cỡ tối thiểu hộp thoại 720 × 560 (`Dialog.show`): dưới cỡ này bố cục hai cột bị vỡ, không hạ xuống. Sửa bố cục thì chạy `dev/test_ui.cjs` (kiểm tra tràn trang, bị cắt mép, token, theme sáng / tối).
- Mọi lần ghi model phải nằm trong `start_operation` / `commit_operation`, lỗi thì `abort_operation`.
- Không tải lại code khi đang ghi hoặc đang ghép MP4 (`Dialog.busy?`).
- Sơ đồ chỉ gồm đối tượng đang thấy: `ModelIO.visible?` loại đối tượng ẩn, tag tắt và tag trong thư mục tag tắt, dùng chung cho cây (`raw_level`) và khung 3D (`Scene.collect`, kể cả mặt) để số nhãn khớp. Không ghi thuộc tính lên đối tượng bị khóa: `apply_orders` bỏ qua và trả số bản bỏ qua, `Dialog.save_message` báo.
- CSV (`Tree.csv_cell`): ô bắt đầu bằng `=`, `+`, `-`, `@`, tab hoặc CR được thêm dấu nháy đơn (Excel không hiểu là công thức).
- Kết quả kiểm thử trong SketchUp thật phải ghi là "chưa xác minh" cho đến khi có người thử trên SketchUp.
