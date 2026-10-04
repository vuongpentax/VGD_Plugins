# Đối chiếu N-TEXTURE 2.0.19 → VGD_Library 1.1.2-beta.1

Nhóm chức năng được xác định từ registry command, core dispatch, browser model/local/online và UI/callback của RBZ. Mọi mục đã viết dưới đây là mã VGD mới, đã kiểm tra mô phỏng/giao diện khi phù hợp, **chưa kiểm chứng SketchUp native**. Lõi Texture/Seamless, phép tính thay đối tượng và một số thuật toán nằm ở máy chủ/DLL không đủ trong RBZ. Không cam kết hành vi/chất lượng giống 100% bản gốc.

| Nhóm bản gốc | VGD hiện tại | Giới hạn / khác biệt |
|---|---|---|
| Thư viện map các hãng | Ảnh/SKM, folders/category/search/favorites/current model | Kho riêng; không dùng kho/server N-TEXTURE |
| Thư viện model local | SKP, thumbnail, chuột placement/xoay, lưu mẫu | Origin/preview/Undo native cần QA; SKP mới hơn có thể không mở SU22 |
| Model/map online | JSON HTTPS + checksum/cache, JSON local import | Cần host tệp/danh mục thật; chưa có service VGD hoặc OAuth Drive native |
| Drive người dùng gửi | Nút nối kho `03 MTL` qua sync ổ G | Chỉ vật liệu; archive bỏ qua/báo số lượng, không tự giải nén |
| Phục hồi map | Cỡ thật, cạnh dài nhất; thêm reset UV | Chọn hướng/cạnh có thể khác lõi gốc |
| Xoay 90° | UV có xét tỷ lệ ảnh chữ nhật | Mapping phẳng 3 cặp điểm; projected/perspective cần QA |
| Xoay từng mặt/Ctrl nhập góc | PickHelper xuyên group + isolate route | Thứ tự clone native cần QA |
| Random/nhập góc context menu | 0/90/180/270°, góc inspector/Ctrl tool | Góc nhập xoay tương đối; không xác nhận giống `turn_to_angle` gốc |
| Random đoạn vân giữ hướng | Dịch UV ngẫu nhiên | Phân phối offset của VGD |
| Thay vật liệu A/B | Chuột A giữ/B thay, selection/model, front/back/shell | Bỏ hidden/locked, bảo vệ shared definitions |
| Thay đối tượng A/B + family/DC | Bounds/anchor/size option, instance props, compatible DC/redraw optional | Chưa bảo đảm mọi DC/family giống lõi gốc |
| Xóa map | Xóa mặt trước và vỏ | Giữ mặt sau tô riêng; guard shell ngoài edit context |
| AUTO SCALE | Một ô ảnh fit bao mặt dọc cạnh dài nhất | Có thể đổi tỷ lệ ảnh; chưa xác nhận cách scale gốc |
| Tô lại | Nhớ riêng theo model | Tô mặt trước/vỏ; no-selection bucket |
| Fix lồng map | Audit, shell wins hoặc faces preserve | Quy tắc rõ trong UI; thuật toán VGD riêng |
| Theo dõi map vỏ | Observers group VGD quản lý, pause/Undo reset | Native timer/transparent operation cần QA; gắn lại khi mở thư viện |
| Flowmap | BFS mở phẳng mặt kề qua cạnh chung | Topology liền/cùng vật liệu; vòng kín cắt UV, không mọi surface unwrap hoàn hảo |
| Convert line | Quantized contours/RDP/group mặt màu+lỗ | Polygon, không Bézier/PowerTRACE/DLL; tối đa 512px, kernel hole cần QA |
| Seamless/preset/preview/batch | Khử loang/hòa viền, 3×3 preview/autoskip/giữ cỡ | Thuật toán riêng, có thể đổi vân; không xác nhận chất lượng giống DLL |
| Displacement/Specular/Normal/AO | 5 PNG với hai chuẩn Normal | Ước lượng từ diffuse, không renderer/PBR đo đạc |
| Cập nhật danh mục | Quét local/Drive, refresh nguồn online | Drive desktop chịu trách nhiệm sync |
| Cập nhật extension | Manifest HTTPS VGD riêng, mở link tải | Chưa có endpoint VGD; không auto-install |
| Account/mã máy/license | Không yêu cầu theo lựa chọn bản độc lập | Không tái tạo/can thiệp tài khoản/bản quyền N-TEXTURE |

Toolbar có 18 lệnh: account gốc bỏ theo lựa chọn độc lập, model tách thành lệnh riêng. Các nhóm có code nhưng native QA vẫn cần trước khi coi là bản ổn định. Chi tiết ở README.md; checklist ở CODEX_HANDOFF.md.
