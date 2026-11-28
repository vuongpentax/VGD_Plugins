# VGD Diagram — hướng dẫn cho Claude

## Thông tin plugin

- Tên extension: `VGD Diagram`; loader `runtime/vgd_diagram.rb`; mã trong `runtime/vgd_diagram/`.
- Toolbar: `VGD DGM`. Menu con: `Extensions → VGD → VGD Diagram`, có mục `Tải lại code`.
- Phiên bản: `runtime/vgd_diagram/version.rb`; README phải khớp khi đổi.
- Mục tiêu: sơ đồ cây lắp ráp, mô hình 3D tách rời và nhãn số cho khách hàng và thợ lắp đặt. Chưa làm: sơ đồ mũi tên hướng lắp, SVG vector đúng style SketchUp.

## Cấu trúc

- `tree.rb`: logic thuần (gom cấu kiện, sắp thứ tự, kiểm tra trùng, xuất SVG). Không gọi API SketchUp.
- `scene.rb`: lấy hình học 3D (mặt, đã đổi về tọa độ thế giới, mm) từ model. Chỉ đọc. Giới hạn 100.000 tam giác.
- `views.rb`: xuất PNG các góc chuẩn bằng `View#write_image` (phối cảnh song song), đổi camera tạm rồi trả lại. Chưa kiểm trong SketchUp thật.
- `model_io.rb`: đọc cây, ghi thuộc tính `VGD_Diagram/order` trong một thao tác (Undo được), chọn cấu kiện.
- `dialog.rb`, `dialog.html`, `dialog.css`, `dialog.js`: hộp thoại `UI::HtmlDialog`. Giao tiếp Ruby ↔ JS qua `VGD.onTree`, `VGD.onToast`, `VGD.onError` và `sketchup.<tên>(JSON)`.
- `reload.rb`: kiểm tra cú pháp cả bộ file trước khi nạp lại.
- `vendor/three.min.js`: three.js r150.1 (MIT). Không sửa, không thay bằng CDN: plugin phải chạy khi không có mạng.
- `vgd-theme/`: bản copy của `shared/vgd-theme`, đồng bộ bằng `tools/sync_vgd_theme.py`. Không sửa tay.

## Kiểm thử

- `ruby dev/test_tree.rb`: logic và model giả lập.
- `ruby dev/test_reload.rb`: menu, toolbar, tải lại nhiều lần, lỗi cú pháp.
- `ruby dev/test_scene.rb`: lấy hình học 3D từ model giả lập.
- `ruby dev/test_views.rb`: xuất các góc (tên file, phối cảnh song song, trả camera kể cả khi lỗi).
- `node dev/test_ui.cjs`: giao diện và khung 3D trong Chromium (Playwright có sẵn; WebGL chạy bằng swiftshader).
- `ruby tests/test_vgd_conventions.rb` (từ gốc repo) sau khi đổi tên, menu, toolbar.

## Đóng gói

`python dev/package.py` (từ thư mục plugin). Ghi SHA-256 khi gửi RBZ. `outputs/` và `*.rbz` không commit.

## Tài liệu đọc trước khi sửa

- `README.md` (hành vi và giả định gom nhóm, thứ tự).
- `shared/vgd-theme/` và `shared/HUONG_DAN_THEME.md` mục 9 (chuẩn giao diện dialog).

## Quy tắc riêng

- Chỉ đọc hình học model. Không sửa, xóa, di chuyển cấu kiện. Chỉ ghi thuộc tính `VGD_Diagram`, và chỉ khi người dùng bấm Lưu.
- Khi xuất ảnh, camera của khung nhìn được đổi tạm và phải trả lại trong `ensure`.
- Mọi lần ghi model phải nằm trong `start_operation` / `commit_operation`, lỗi thì `abort_operation`.
- Không tải lại code khi đang ghi (`Dialog.busy?`).
- Kết quả kiểm thử trong SketchUp thật phải ghi là "chưa xác minh" cho đến khi có người thử trên SketchUp.
