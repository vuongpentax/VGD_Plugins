# VGD_Cabinet 4.5.2

VGD_Cabinet là plugin dựng và sửa tủ cho SketchUp, mục tiêu từ SketchUp 2022. Runtime 4.5.2 tập trung vào hình học tủ, giao diện `HtmlDialog`, preview, preset, thư viện và chuyển hộp thành tủ. VGD_EXPLODE và VGD_UNTAG không còn nằm trong runtime, menu hay gói Cabinet 4.5.2.

## Cấu trúc repository

```text
VGD_Plugins/
├── AGENTS.md, README.md, .gitignore
├── docs/, tools/, tests/, archive/
└── plugins/VGD_Cabinet/
    ├── AGENTS.md, CODEX_HANDOFF.md, README.md
    ├── cabinet_work/  # loader và runtime được đóng gói
    └── cabinet_dev/   # test, fixture, nguồn UI, generator và công cụ
```

`cabinet_work/vgd_cabinet.rb` là loader; runtime chính là `cabinet_work/VGD_Cabinet/main43.rb`. `cabinet_dev/` không thuộc runtime. HTML được đóng gói tại `cabinet_work/VGD_Cabinet/VGD_Cabinet_UI.html`, sinh từ generator/template và `menu.css`/`menu.js`. Repository hiện không lưu thư mục `outputs/`; `cabinet_dev/package_menu.py` tạo output cục bộ tại `outputs/vgd_cabinet_modeling/` khi được chạy.

## Tính năng

- Dựng tủ theo 3 điểm, xem trước cấu kiện trong viewport và sửa cabinet đã chọn.
- Cấu hình cánh, kính, Pano/Shaker, ngăn kéo, đợt, vách và các kiểu joinery hiện có.
- Xem trước rồi áp dụng cài đặt cánh/hộc cho nhiều cabinet; mỗi cabinet giữ kích thước và bố cục module riêng.
- Nhập mô tả cấu hình JSON đã kiểm tra; plugin không tự phân tích ảnh hoặc văn xuôi.
- Lưu preset thông số và thư viện cabinet riêng. Thư viện giữ hình học SKP đã lưu, kể cả chỉnh sửa thủ công.
- Chuyển group/component thành cabinet theo trục cục bộ của đối tượng.

Cabinet T+ cũ được nhận diện qua dictionary `TPlus_Cabinet`; cabinet mới/cập nhật ghi dữ liệu VGD. Preset nằm tại `%APPDATA%/VGD/SketchUp/VGD_Cabinet/presets_v1.json`; thư viện nằm trong thư mục `library` cùng đường dẫn. Sao lưu dữ liệu người dùng trước khi chuyển máy hoặc bảo trì thủ công.

## Tạo gói và kiểm tra

Không có thư mục build được lưu sẵn trong repository. Từ thư mục `plugins/VGD_Cabinet`, `python cabinet_dev/package_menu.py` tạo RBZ và source ZIP trong `outputs/vgd_cabinet_modeling/`. Các test và điều kiện chạy được ghi trong [TESTS.txt](TESTS.txt); kết quả đã ghi nhận nằm trong [VALIDATION.json](VALIDATION.json).

Hồ sơ native hiện kế thừa các kiểm tra trên runtime 4.5.1. Gói 4.5.2 đã được ghi nhận triển khai đủ file và xác minh checksum tại SketchUp 2022, nhưng chưa khởi động lại/chạy native với gói sạch. Undo trên model, đóng/mở lại model và UI batch mới còn chờ xác minh. Xem [CODEX_HANDOFF.md](CODEX_HANDOFF.md) để biết rõ phạm vi và chênh lệch deploy cần xử lý.

Trước khi đóng góp, đọc `AGENTS.md` trong plugin và hướng dẫn repository ở root.
