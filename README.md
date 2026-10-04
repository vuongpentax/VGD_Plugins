# VGD Plugins

Kho mã nguồn để tiếp tục phát triển plugin trên nhiều máy.

- `VGD_Dim/`: VGD Dim, gộp bộ Claude với Smart Dim, style Dim/Text/Label, Model Info, preset, Auto-Style, Animation và phạm vi quét; giữ style T+.
- `VGD_Scenes/`: plugin VGD Scenes cho SU22, mã nguồn, bộ kiểm tra, hướng dẫn và gói RBZ. Đọc `VGD_Scenes/README.md` và `VGD_Scenes/CODEX_HANDOFF.md` để tiếp tục phát triển.
- `VGD_Library/`: thư viện vật liệu/model (ảnh, SKM, SKP), kho Drive đồng bộ, nguồn online và 18 nhóm lệnh map/Flowmap/seamless/Convert line/thay đối tượng/xuất map phụ; beta cho SketchUp 2022+. Đọc `VGD_Library/README.md`, `VGD_Library/FEATURE_PARITY.md` và `VGD_Library/CODEX_HANDOFF.md` để cài thử và tiếp tục phát triển.
- `VGD_Image_Importer/`: nhập hàng loạt ảnh 2D, ảnh nằm phẳng và vật liệu; danh sách ảnh, kích thước đúng tỉ lệ, bố trí hàng và theme VGD sáng/tối. Đọc `VGD_Image_Importer/README.md` và `VGD_Image_Importer/CODEX_HANDOFF.md`.
- `VGD_Cabinet/`: mã nguồn Cabinet đang phát triển, giao diện VGD, preset lưu trên máy, cánh pano và gói RBZ. Đọc `VGD_Cabinet/AGENTS.md` và `VGD_Cabinet/CODEX_HANDOFF.md` trước khi sửa.
- `VGD_BIM/`: VGD BIM Lite, quản lý thông tin đối tượng, kiểm tra dữ liệu và xuất báo cáo CSV tiếng Việt. Đọc `VGD_BIM/README.md` và `VGD_BIM/VALIDATION.md` để cài và kiểm tra bản alpha.
- `TPlus_Cabinet_Codex_Handoff_2026-10-01/`: bản bàn giao T+ Cabinet cũ và tài liệu DC Export để tham khảo. Phát triển Cabinet tiếp tại `VGD_Cabinet/`.

## Mở trên máy khác

Clone lần đầu:

```powershell
git clone https://github.com/vuongpentax/VGD_Plugins.git
cd VGD_Plugins
```

Mở thư mục vừa clone làm dự án trong Codex. Mã nguồn và gói RBZ được lưu trong repository; việc cài plugin vào SketchUp phải thực hiện riêng trên từng máy theo hướng dẫn của mỗi plugin.

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
