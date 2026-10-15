# VGD Dim · rà soát và tiếp tục phát triển

Ngày 07/10/2026, nguồn nhập: VGD_Dim_6.rbz (loader ghi 3.2.0). Bản 3.3.0-beta.3 bổ sung pilot updater online; beta.4 sửa tùy chọn process group để khởi chạy helper trên Windows; beta.6 thêm Dim thủ công và giới hạn vùng đo. Snapshot/SHA256: dev/claude_v6_reference/IMPORT.json; dữ liệu gốc chỉ tham khảo, không chạy runtime.

## Các điểm đã sửa

- V6 tạo Group mới mỗi lần và nhận diện Smart group bằng tên. Bản mới dùng owner/key metadata, khóa nguồn gồm persistent IDs của các tủ, mặt, mặt cắt và Scene. Đổi tên Group không làm mất nhận diện. Chỉ xóa các bộ do bản này sở hữu sau khi dựng/style/ghi Scene thành công; Group có đối tượng thêm tay hoặc bị khóa sẽ báo lỗi.
- V6 đo theo trục chung làm sai số đo thực của tủ xoay. Dùng cơ sở trục chuẩn hóa của tủ đầu tiên; kiểm tra trục vuông góc, đứng thẳng và chi tiết cùng hệ trục trước operation. Xoay Z tùy góc, mirror X/Y và scale theo trục hỗ trợ. Root tủ nghiêng X/Y, shear, scale 0 và các khối khác hệ trục không được chiếu rồi gắn nhãn giả là số đo thật.
- Mặt cắt cần active và DisplaySectionCuts bật. Kiểm tra trong context/ancestor và các tủ đã chọn. Nhiều mặt cắt cùng hoạt động báo lỗi; mặt cắt không song song trục tủ báo lỗi. Pháp tuyến dùng biến đổi covector (tangent cross), không transform vector trực tiếp khi nonuniform scale.
- Tag riêng cho mặt cắt: 000_DIM_SECTION_<axis>_<plane/path IDs>[_S<scene PID>]. Mặt thường: 000_DIM_<axis>_<PLUS/MINUS>[_S<scene PID>]. Dim bên trong Untagged, Group giữ Tag. Áp style/rebuild/native gán Tag không phá bộ Smart mới. Tag trùng tên của người dùng được tránh; Tag do plugin tạo có slot metadata để nhận ra khi đổi tên.
- Scene lưu Tags: đặt visibility của riêng Tag mới/cập nhật bằng Page#set_visibility; không Page#update và không ghi camera/style/section plane của Scene. Scene hiện tại chưa lưu Tags sẽ báo lỗi trước thay đổi. Scene khác chưa lưu Tags không thể cô lập hiển thị bằng Tag: không sửa flag của Scene đó. Tag gắn Scene ẩn trên Scene mới mặc định. Giữ cả bộ của Scene khác khi chạy lại.
- Toolbar có nút một chạm lấy cấu hình options/style của lượt thành công cuối. Lưu một JSON record Base64 an toàn sau khi commit. Validation/thất bại không thay record; lưu thất bại báo rõ Dim đã tạo nhưng cấu hình chưa lưu.
- Bỏ ghi Units khỏi Core.run. UNITS/validate_units/read_units/apply_units_model tách khỏi STYLE. Lệnh Units ảnh hưởng toàn model, readback sau ghi, rollback khi lỗi; không sửa màu/tag. Mở numeric text là tùy chọn mặc định tắt, bỏ qua nhóm khóa, giữ chữ như “Cao 2400”.
- Giữ rebuild an toàn của bản hiện tại: không nuốt lỗi sao chép properties/attachments rồi xóa bản cũ như V6. So chữ với Dim mới để tránh khóa chữ đo tự động thành literal khi làm mới font.
- UI 6 bảng, scope chung, theme sáng/tối, payload/busy/keyboard; giới hạn 500 chi tiết/2000 đoạn/64 cấp lồng và ngân sách lọc che khuất.

## Giới hạn cần biết

Smart Dim dùng hộp bao của hình học từng chi tiết, không tính giao tuyến Face chính xác. Phù hợp panel/tủ vuông, không chứng nhận số đo cho đồ cong, tấm có khoét hoặc chi tiết hình học xiên bên trong. Không liên kết associative tới hình học tủ; sửa tủ rồi chọn lại/bấm Smart Dim. Root container của tủ cần có trục phản ánh hướng tủ; nếu đã bake phép xoay vào vertices, thuật toán không tự suy ra hướng thiết kế.

Bản V6 cũ không có owner/source metadata. Không tự xóa Group chỉ vì tên 000_DIM_*; người dùng xóa bộ cũ một lần nếu không muốn giữ. Khi đổi tập nguồn được chọn, coi là bộ khác. Không tự dọn bộ khi xóa tủ/Scene hoặc Make Unique; đây là bước tiếp theo cần một màn quản lý có preview rõ ràng.

Scene visibility lỗi được snapshot/restore tường minh, nhưng native Undo/Redo của Page visibility trên SU2022 vẫn cần kiểm chứng. Không coi Undo geometry là xác nhận Undo mọi thiết lập Scene hoặc Options. Font/Height/native bridge/associations/Auto observer/CEF vẫn cần acceptance trong SketchUp.

## Acceptance native trên model thử riêng

1. Cài RBZ, khởi động lại SU2022; có 2 toolbar buttons, các bảng/theme mở đúng.
2. Tủ 800×600×720 với hồi 18 mm: đo -Y, ±Z, xoay Z 30°/45°/90°, mirror, scale; kiểm tra số native thực.
3. Tủ nghiêng/shear/chi tiết quay 15° phải báo lỗi trước tạo Group. Kiểm tra raw geometry đã bake rotation.
4. Bật mặt cắt root/nested/ancestor; kiểm tra Tag riêng, vị trí Dim, bộ lọc, nhiều mặt cắt và mặt cắt xiên.
5. Scene A/B bật lưu Tags: tạo bộ riêng, chuyển cảnh; camera/style khác giữ nguyên. Scene không lưu Tags cần thông báo rõ. Scene mới không hiện Tag gắn Scene khác.
6. Chạy lại, đổi tên Group/Tag, lock Group, thêm geometry thủ công, đổi tủ, Undo/Redo và save/reopen: không mất dữ liệu và không sinh bản sao ngoài ý muốn.
7. Toolbar một chạm phải giữ mặt/offset/style lần thành công cuối. Cấu hình lỗi không chặn mở dialog.
8. Áp style có preset đơn vị cũ không đổi Units; nút Units riêng có readback và không gán Tag/màu. Test chữ numeric/custom và save/reopen/Undo.
9. Rebuild/Model Info/native Update selected: font/pt/Height, links, custom text, scopes, Undo; không dùng fixture để khẳng định native font đã đổi.

API tham khảo: [Page visibility](https://ruby.sketchup.com/Sketchup/Page.html#set_visibility-instance_method), [Layer page behavior](https://ruby.sketchup.com/Sketchup/Layer.html#page_behavior=-instance_method), [SectionPlane](https://ruby.sketchup.com/Sketchup/SectionPlane.html), [Dimension text override](https://ruby.sketchup.com/Sketchup/Dimension.html#text=-instance_method).
