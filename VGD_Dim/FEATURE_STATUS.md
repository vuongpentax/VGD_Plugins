# VGD Dim · 3.3.0-beta.4

| Chức năng | Trạng thái |
|---|---|
| Nguồn V6 Claude 3.2.0 | Đã rà soát/tích hợp Smart/mặt cắt; snapshot 15 file có SHA256 |
| Sidebar / scope / theme | 6 bảng, scope chung Font/Style, sáng/tối; Edge/keyboard/callbacks/760–360px PASS |
| Smart Dim | 8 mặt lựa chọn; mô phỏng chain/tổng/yaw 0/30/45/90/123°, mirror/scale PASS; tilt/shear/khác trục bị chặn |
| Mặt cắt | Tag riêng, plane/normals và lọc bbox; chỉ một mặt cắt bật, song song trục tủ; mô phỏng PASS |
| Chống Group trùng | Owned metadata/source/face/Scene; dựng xong mới xóa bộ cũ; foreign/manual/lock/failure guards PASS |
| Scene / Tag | Riêng Tag Smart, chỉ Scene lưu Tags, không update camera/style; visibility failure restore mô phỏng PASS |
| Toolbar Smart một chạm | Dùng lại options/style thành công cuối, cập nhật bộ cũ; command wiring mô phỏng PASS |
| Units riêng | Core.apply_units_model, readback/rollback; không ghi cùng style/preset; reset numeric opt-in PASS |
| Model Info / rebuild | Giữ logic bảo toàn links/properties; tránh khóa measured text; native font/Height vẫn chưa xác minh |
| Auto / preset / Animation | Giữ chức năng, JSON Base64; regression PASS |
| Deploy fixture / gói | Whitelist 20 file, backup/guards/Cabinet preservation PASS; CRC/byte/SHA256 kiểm tra khi package |
| SketchUp native 3.3 | Chưa chạy acceptance 3.3 trên kernel: Scene/Options Undo, font/Height, associations, observer, CEF cần test thực tế |

Không khẳng định fixture là kiểm chứng native. Giới hạn bbox, trục tủ baked và nâng cấp bộ V6 không metadata được ghi trong DEVELOPMENT_NOTES.md.
