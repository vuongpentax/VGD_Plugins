# VGD Structure 0.1.0-beta.1

Plugin SketchUp dựng **phần thô** (cột, dầm, tường, sàn, trần) theo **lưới trục** và **tầng**, nối với VGD BIM để tính khối lượng. Kế hoạch: `docs/vgd_structure/PLAN.md`. Đặc tả dữ liệu: `docs/vgd_structure/SPEC.md`.

## Trạng thái

Đây mới là **khung plugin (cột mốc 0)**: chưa dựng được gì. Đã có:
- menu **Extensions → VGD → VGD Structure → Tải lại code** (nạp lại mã sau khi cài đè bản mới mà không phải mở lại SketchUp; menu và thanh công cụ chỉ có hiệu lực sau khi mở lại SketchUp);
- hằng số hợp đồng dữ liệu (`core/schema.rb`).

Cột mốc tiếp theo: lưới trục, rồi tầng và cột (xem kế hoạch).

## Cài đặt

Cài file `VGD_Structure_v0.1.0-beta.1.rbz` bằng Extension Manager của SketchUp (SketchUp 2022 trở lên), rồi mở lại SketchUp.

## Kiểm thử

- Tự động (mô phỏng, ngoài SketchUp): `ruby dev/run_tests.rb` từ `plugins/VGD_Structure`; kiểm tra cú pháp, menu, Tải lại code (nhiều lần không nhân đôi menu, lỗi cú pháp giữ bản đang chạy, đang bận thì từ chối).
- **Chưa xác minh trong SketchUp thật.**
