# VGD Dimension & Text Manager

Yêu cầu hiện tại ngày 2026-10-02 thay thế mẫu quét toàn model: chỉ Dim/Text được chọn, endpoint Dim/Label, tag 000 DIM/000 TEXT, không hộp thông báo hoàn tất.

- Giữ loader vgd_dim.rb, namespace VGD::Dim và thư mục VGD_Dim. Không đổi Cabinet.
- Style T+ Cabinet: nền sáng, header tối, nâu đồng #B48963, Segoe UI/Inter; một trang và APPLY ở footer.
- APPLY chỉ lấy Dimension/Text trực tiếp trong model.selection tại thời điểm bấm. Không quét Group/Component hay toàn model. Không có đối tượng phù hợp thì không ghi model.
- Dim vào 000 DIM; Text/Label vào 000 TEXT. Màu và endpoint áp bằng setter native trong một operation; lỗi abort.
- Không ghi UnitsOptions/model defaults trong APPLY. Người dùng chỉnh Model Info trước; native Update selected có thể thay vị trí/hướng chữ/leader theo mẫu. Giữ nội dung, điểm đo và hình học, khôi phục selection nếu người dùng chưa đổi vùng chọn.
- Trong context definition chia sẻ, chặn thao tác trước mutation; không âm thầm đổi các bản copy ngoài vùng chọn.
- Yêu cầu mới: Model Info → APPLY. Trên SU2022 không có setter font/size/Height. Windows English bridge tìm nút native Update selected trong chính process, kiểm tra trước rồi gọi cho Dim/Text riêng. Không dùng ID lệnh phỏng đoán/Select All. Height native không quy đổi mm sang pt.
- Native có Undo riêng; không hứa rollback hay một Undo cho cả APPLY. Lỗi sau khi một lệnh native đã gọi phải báo rõ cập nhật một phần.
- Không tạo ô nhập font/size/Height giả vờ APPLY được trên SU2022; không dùng edge/mesh, save/reimport model hoặc API bộ nhớ nội bộ.
- APPLY thành công im lặng; lỗi hiện inline trong dialog hoặc status bar, không UI.messagebox.
- Chỉ deploy whitelist của dev/deploy.ps1 vào SU2022; sao lưu và SHA256. Phân biệt fixture/UI với kiểm thử native.
