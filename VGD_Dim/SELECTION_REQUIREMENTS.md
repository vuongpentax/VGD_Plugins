# Yêu cầu hiện tại · 2026-10-07

VGD_Dim_6.rbz là nguồn mới để tiếp tục phát triển: sidebar 6 tab, scope dùng chung Font/Style, Tag mặt cắt riêng, liên hệ Tag/Scene, thay bộ Smart owned trùng, toolbar một chạm, lưu cấu hình sau khi chạy thành công. Chỉ đo tủ upright theo trục riêng; báo lỗi tilt/shear/khác hệ trục. Units là nút riêng toàn model, không áp cùng style/preset. Xem DEVELOPMENT_NOTES.md và UI_DESIGN.md.

User chọn đưa đầy đủ các chức năng trong giao diện Claude và bổ sung mã thiếu. Phạm vi quét mở rộng selected/context/model, mặc định selected; có nested/components/hidden/locked. Definition chia sẻ đổi các bản sao và được giải thích trong UI.

Giữ Smart Dim, preset, Auto-Style, Animation, Units có opt-in, các setter Dim/Text/Label, tags, không popup; tên VGD Dim/style T+. APPLY mẫu Model Info chỉ selected trực tiếp. Rebuild Dim tuyến tính trên phạm vi quét, sao chép thuộc tính/links, radial skip.

Chỉ sửa VGD_Dim; không ghép mã vào các plugin khác.
