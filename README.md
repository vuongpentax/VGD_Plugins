# VGD Plugins

Kho mã nguồn để tiếp tục phát triển plugin trên nhiều máy.

- `VGD_Dim/`: mã nguồn và gói VGD Dimension & Text Manager, style T+; APPLY lấy mẫu Model Info cho Dim/Text được chọn, rồi chỉnh màu/endpoint/tag (Windows English beta).
- `VGD_Scenes/`: plugin VGD Scenes cho SU22, mã nguồn, bộ kiểm tra, hướng dẫn và gói RBZ. Đọc `VGD_Scenes/README.md` và `VGD_Scenes/CODEX_HANDOFF.md` để tiếp tục phát triển.
- `VGD_Cabinet/`: mã nguồn Cabinet đang phát triển, giao diện VGD, preset lưu trên máy, cánh pano và gói RBZ. Đọc `VGD_Cabinet/AGENTS.md` và `VGD_Cabinet/CODEX_HANDOFF.md` trước khi sửa.
- `TPlus_Cabinet_Codex_Handoff_2026-10-01/`: bản bàn giao T+ Cabinet cũ và tài liệu DC Export để tham khảo. Phát triển Cabinet tiếp tại `VGD_Cabinet/`.

## Mở trên máy khác

Clone lần đầu:

```powershell
git clone https://github.com/vuongpentax/TPlus_Plugins.git
cd TPlus_Plugins
```

Mở thư mục `TPlus_Plugins` làm dự án trong Codex. Mã nguồn và gói RBZ được lưu trong repository; việc cài plugin vào SketchUp phải thực hiện riêng trên từng máy theo hướng dẫn của mỗi plugin.

Trước khi bắt đầu làm, nếu thư mục làm việc sạch:

```powershell
git pull --ff-only
```

Sau khi làm xong, kiểm tra file thay đổi rồi lưu và gửi lên GitHub:

```powershell
git status
git add .
git commit -m "Cap nhat plugin"
git push
```

Chỉ chuyển máy sau khi push thành công. Nếu Git báo xung đột hoặc có thay đổi chưa lưu, xử lý các thay đổi đó trước khi pull.

## Công cụ phát triển

Cache, `node_modules`, thư viện Python tại `VGD_Dim/dev/vendor`, log và bản sao lưu cài đặt tạm không được lưu trong Git. Các công cụ Node cần cài dependency theo `cabinet_dev/package.json` và lockfile của dự án Cabinet.

VGD Dim/Text dùng dim native. Đọc `VGD_Dim/README.md` để chỉnh mẫu font/cỡ chữ/Height trong Model Info và nạp bản mới. Cầu nối native mới chưa kiểm chứng trong SketchUp thực tế.
