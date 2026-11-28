# VGD Diagram — hướng dẫn cho Claude

## Thông tin plugin

- Tên extension: `VGD Diagram`; loader `runtime/vgd_diagram.rb`; mã trong `runtime/vgd_diagram/`.
- Toolbar: `VGD DGM`. Menu con: `Extensions → VGD → VGD Diagram`, có mục `Tải lại code`.
- Số phiên bản hiện dưới logo trong hộp thoại: Ruby gửi `onVersion` khi `ready`.
- Phiên bản: `runtime/vgd_diagram/version.rb`; README phải khớp khi đổi.
- Mục tiêu: sơ đồ cây lắp ráp, mô hình 3D tách rời và nhãn số cho khách hàng và thợ lắp đặt. Chưa làm: sơ đồ mũi tên hướng lắp, SVG vector, dùng đúng style đang bật của model.

## Cấu trúc

- `tree.rb`: logic thuần (gom cấu kiện, sắp thứ tự, kiểm tra trùng, xuất SVG). Không gọi API SketchUp.
- `scene.rb`: lấy hình học 3D (mặt, đã đổi về tọa độ thế giới, mm) từ model. Chỉ đọc. Giới hạn 100.000 tam giác.
- `model_io.rb`: đọc cây (từ danh sách thực thể đã chọn), vị trí nhóm để đề xuất thứ tự, ghi thuộc tính `VGD_Diagram/order` trong một thao tác (Undo được), chọn cấu kiện.
- `dialog.rb`, `dialog.html`, `dialog.css`, `dialog.js`: hộp thoại `UI::HtmlDialog`. Giao tiếp Ruby ↔ JS qua `VGD.onTree`, `VGD.onToast`, `VGD.onError` và `sketchup.<tên>(JSON)`.
- `reload.rb`: kiểm tra cú pháp cả bộ file trước khi nạp lại.
- `vendor/three.min.js`: three.js r150.1 (MIT). Không sửa, không thay bằng CDN: plugin phải chạy khi không có mạng.
- `vgd-theme/`: bản copy của `shared/vgd-theme`, đồng bộ bằng `tools/sync_vgd_theme.py`. Không sửa tay.

## Kiểm thử

- `ruby dev/test_tree.rb`: logic và model giả lập.
- `ruby dev/test_reload.rb`: menu, toolbar, tải lại nhiều lần, lỗi cú pháp.
- `ruby dev/test_scene.rb`: lấy hình học 3D từ model giả lập.
- `ruby dev/test_formats.rb`: đuôi file và định dạng khi lưu.
- `ruby dev/test_ffmpeg.rb`: ghép MP4 và xóa khung hình bằng ffmpeg thật (cần ffmpeg trong PATH).
- `node dev/test_ui.cjs`: giao diện, khung 3D, nhãn số, đề xuất thứ tự, xuất ảnh, cụm, bước và quay video trong Chromium (Playwright có sẵn; WebGL chạy bằng swiftshader).
- `ruby tests/test_vgd_conventions.rb` (từ gốc repo) sau khi đổi tên, menu, toolbar.

## Đóng gói

`python dev/package.py` (từ thư mục plugin). Ghi SHA-256 khi gửi RBZ. `outputs/` và `*.rbz` không commit.

## Tài liệu đọc trước khi sửa

- `README.md` (hành vi và giả định gom nhóm, thứ tự).
- `shared/vgd-theme/` và `shared/HUONG_DAN_THEME.md` mục 9 (chuẩn giao diện dialog).

## Quy tắc riêng

- Chỉ đọc hình học model. Không sửa, xóa, di chuyển cấu kiện. Chỉ ghi thuộc tính `VGD_Diagram`, và chỉ khi người dùng bấm Lưu.
- Phạm vi làm việc là các đối tượng đã chọn lúc bấm Làm mới (`Dialog@scope_ids`). Không tự cập nhật khi đổi lựa chọn.
- Xuất ảnh vẽ bằng three.js (style mặc định SketchUp giả lập), không gọi API camera/`write_image` của SketchUp.
- Tên ảnh xuất chỉ gồm chữ thường, số và gạch ngang (kiểm tra ở `Dialog::IMAGE_KEY`).
- Tối đa 15 nhãn trên một ảnh (`MAX_TAGS` trong `dialog.js`).
- Video lắp ráp quay bằng `MediaRecorder` từ canvas trong giao diện. Định dạng quay trực tiếp là webm (`VIDEO_EXT`); MP4 không quay trực tiếp, chỉ có qua chuỗi khung PNG rồi ghép bằng ffmpeg. Hàm lưu: `Dialog#save_video`. Đuôi file trong hộp lưu quyết định định dạng (`Dialog::resolve_format`, test ở `dev/test_formats.rb`).
- Ảnh xuất: png hoặc jpg, chọn như video.
- Đường dẫn ffmpeg lưu bằng `Sketchup.write_default` (`ffmpeg.rb#save_path`). Người dùng có thể nhập file hoặc thư mục (`ffmpeg.rb#resolve` tìm `ffmpeg.exe` trong thư mục, hoặc `bin\ffmpeg.exe`); chỉ lưu file vượt qua kiểm tra `-version` và có bộ mã hóa `libx264` hoặc `mpeg4` (`ENCODERS`, ưu tiên `libx264`).
- `ffmpeg.rb` gọi ffmpeg bằng danh sách tham số (không qua shell). Chỉ chạy file ffmpeg đã chọn hoặc lệnh `ffmpeg` trong PATH. Chỉ xóa khung hình do plugin vừa xuất, và chỉ sau khi người dùng xác nhận và ghép thành công.
- Video dạng PNG (chuỗi khung hình) không dùng MediaRecorder: `exportFrames` gửi từng khung qua `save_frame`, kết thúc bằng `video_done` (`Dialog#finish_frames`).
- Mọi lần ghi model phải nằm trong `start_operation` / `commit_operation`, lỗi thì `abort_operation`.
- Không tải lại code khi đang ghi (`Dialog.busy?`).
- Kết quả kiểm thử trong SketchUp thật phải ghi là "chưa xác minh" cho đến khi có người thử trên SketchUp.
