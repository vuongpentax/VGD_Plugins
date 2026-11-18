# VGD Plugins

Kho mã các công cụ và plugin SketchUp thuộc hệ sinh thái VGD, hướng tới SketchUp 2022 trở lên. Windows là môi trường phát triển và kiểm thử chính; mã chủ yếu viết bằng Ruby (SketchUp Ruby API), giao diện dùng `UI::HtmlDialog` (HTML/CSS/JavaScript).

## Các plugin

Mỗi plugin nằm trong `plugins/` và có README, ghi chú phát hành và bộ kiểm tra riêng. Xem README của từng plugin để biết cách dùng, cách chạy test và trạng thái xác minh.

| Plugin | Thư mục | Mô tả ngắn |
|---|---|---|
| VGD Center | `plugins/VGD_Center/` | Quản lý các plugin VGD: kho plugin để cài và cập nhật, tab Quản lý để bật/tắt plugin. |
| VGD BIM | `plugins/VGD_BIM/` | Bóc khối lượng từ group/component, gắn dữ liệu hạng mục, quét và xuất báo cáo. |
| VGD Room | `plugins/VGD_Room/` | Dựng khối 3D của phòng từ dữ liệu phòng của VGD BIM; không có giao diện riêng, VGD BIM điều khiển. |
| VGD Structure | `plugins/VGD_Structure/` | Dựng phần thô (cột, dầm, tường, sàn, trần) theo lưới trục và tầng, nối VGD BIM để tính khối lượng. Mới có khung plugin (cột mốc 0), xem `docs/vgd_structure/PLAN.md`. |
| VGD Cabinet | `plugins/VGD_Cabinet/` | Dựng và sửa tủ, có preview, preset, thư viện và chuyển hộp thành tủ. |
| VGD Cabinet Draw | `plugins/VGD_Cabinet_Draw/` | Dựng tủ bán tự động bằng thao tác trực tiếp trong viewport; đăng ký độc lập với VGD Cabinet. |
| VGD Dim | `plugins/VGD_Dim/` | Smart Dim cho tủ, Dim thủ công, vùng đo và áp mẫu Model Info. |
| VGD Scenes | `plugins/VGD_Scenes/` | Tạo view đối tượng, mặt cắt tùy chỉnh, quản lý scene, xuất ảnh và PDF. |
| VGD Image Importer | `plugins/VGD_Image_Importer/` | Nhập ảnh 2D thành component dựng đứng hoặc ảnh phẳng, hoặc thêm vật liệu. |
| VGD Library | `plugins/VGD_Library/` | Thư viện vật liệu (ảnh/SKM) và model (SKP), kho Drive đồng bộ và bộ công cụ map. |
| VGD Reference | `plugins/VGD_Reference/` | Ghim ảnh tham chiếu phía trên khung nhìn mô hình (cần SketchUp 2023 trở lên). |
| VGD Package | `plugins/VGD_Package/` | Quét texture vật liệu và kiểm tra thuộc tính Enscape (chỉ đọc); đang trong giai đoạn nghiên cứu. README ở `plugins/VGD_Package/vgd_package/README.md`. |
| VGD DC Exporter | `plugins/VGD_DC_Exporter/` | Extension hỗ trợ, chỉ đọc: xuất thuộc tính, công thức DC và cấu trúc component đang chọn ra JSON. |

## Cấu trúc thư mục

- `plugins/`: các plugin SketchUp dùng trong thực tế.
- `shared/`: tài nguyên dùng chung giữa các plugin (theme giao diện, catalog và tài liệu của VGD Center).
- `docs/`: tài liệu dự án và các quyết định kiến trúc quan trọng.
- `tools/`: công cụ hỗ trợ phát triển và bảo trì.
- `tests/`: kiểm thử dùng chung toàn repo.
- `archive/`: tài liệu và mã cũ được lưu trữ.

## Kiểm tra

Test chung kiểm tra quy ước đặt tên, menu và toolbar của mọi plugin; chỉ đọc mã nên không cần SketchUp. Chạy từ gốc repo:

```bash
ruby tests/test_vgd_conventions.rb
```

Mỗi plugin còn có test riêng, thường nằm trong `dev/` hoặc `test/` của plugin đó (xem README từng plugin). Các test dùng SketchUp giả lập nên không thay thế việc kiểm tra trực tiếp trong SketchUp.

## Lưu ý khi đóng góp

- Đọc [CLAUDE.md](CLAUDE.md) trước khi đóng góp: đó là quy định của repo (quy ước đặt tên, menu, phiên bản, phát hành).
- File `.rbz` (gói cài đặt) không được lưu trong git. Build lại bằng script của từng plugin hoặc lấy từ nơi phát hành.
- Chỉ bổ sung module và công cụ khi có nhu cầu cụ thể.
