# VGD Dim

Yêu cầu ngày 2026-10-05: gộp đầy đủ giao diện Claude và bổ sung module thiếu, thay các giới hạn scope của bản 2.3. Chỉ phát triển Dim; không sửa Cabinet/Scenes/Importer/Library.

- Tên VGD Dim; loader vgd_dim.rb, namespace VGD::Dim, thư mục VGD_Dim. Style T+ sáng/nâu đồng.
- Phạm vi selected/context/model, mặc định selected; bộ lọc nested/components/hidden/locked. Definition dùng chung dedup, ảnh hưởng các bản sao và giải thích trên UI.
- Smart Dim quét hình học tủ được chọn; bỏ ẩn/khóa/tag tắt. Tạo Dim native trong active_entities, tag 000 DIM, một operation, giữ selection. Không tạo edge/mesh.
- Core style: màu tùy bật; Dim endpoint/orientation/position; Label endpoint/leader; Text/Label tag 000 TEXT.
- Rebuild Dim tuyến tính theo mẫu Model Info. Giữ điểm/liên kết/text override/style/attributes; tạo xong mới xóa Dim cũ; lỗi giữ bản cũ, radial skip, cập nhật selection sang replacement. Không hứa giữ persistent ID.
- APPLY mẫu Model Info chỉ Dim/Text chọn trực tiếp trên Windows English. Native Undo riêng, lỗi một phần báo rõ; không nói đã xác minh native nếu chưa chạy.
- Preset và Auto-Style lưu cục bộ. Auto mặc định tắt, observers phải trì hoãn setters, suspend khi thao tác manual, tắt/reload dọn observers/timers, không cản Undo.
- Animation/Units ghi bằng options native; Units chỉ khi explicitly enabled; Animation không có Undo.
- Không popup hoàn tất; lỗi/kết quả inline. Không nạp dev/claude_reference vào runtime.
- Kiểm thử có ý nghĩa geometry/scopes/rebuild/error/services/UI. Deploy whitelist 18 file, backup/hash, không tác động plugin khác.
