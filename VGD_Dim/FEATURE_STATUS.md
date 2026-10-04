# VGD Dim · 3.0.0-beta.1

| Chức năng | Trạng thái |
|---|---|
| Toàn bộ giao diện Claude | Đã gộp, style T+, tên VGD Dim |
| 6 dependency thiếu | Đã bổ sung store/core/presets/autostyle/animation/probe |
| Smart Dim | Mô phỏng đạt chain/tổng, 6 mặt chọn, dịch/chỉnh tỷ lệ/xoay 90°, orientation, tags, abort |
| Scope/quét/style | Selected/context/model; hidden/locked/nested/components; dedup definition |
| Rebuild size Model Info | Đã viết cho Dim tuyến tính; metadata/links/selection/failure mô phỏng đạt; radial skip |
| Text font từ Model Info | Cầu nối Windows English, selected trực tiếp; native chưa xác minh |
| Preset/Auto/Animation/Units | Đã viết và có kiểm thử; không popup hoàn tất |
| Native SketchUp | Font/Height, associations, observers, Undo/save-reopen cần kiểm chứng thực tế |

ZIP gốc giữ trong dev/claude_reference. Không coi fixture là bằng chứng font/Height đã đổi trong SketchUp.

Ngày 2026-10-05 đã mở SU2022; công cụ điều khiển lỗi “no screenshot targets found”, sau khi app vào Untitled thử lại lỗi “FrameArrived timed out”. Không chạy test native trên model.
