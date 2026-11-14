# VGD Room 0.1.0-beta.1

Plugin nhỏ dựng **khối 3D của phòng** cho hệ BIM của VGD. Không có giao diện riêng: **VGD_BIM điều khiển**. Trong VGD_BIM bạn tạo phòng từ mặt sàn, rồi bấm **Dựng khối** ở hộp Quản lý phòng; VGD Room dựng (hoặc dựng lại) khối phòng.

## Làm gì
- Dựng một Group từ viền và chiều cao của phòng (dữ liệu do VGD_BIM gửi): mặt ở cao độ sàn, đùn lên đúng chiều cao, vật liệu trong suốt, đặt trên tag `VGD_ROOMS` (tắt / bật được).
- Một bước hoàn tác cho mỗi lần dựng. Dựng lại thì thay khối cũ và giữ nguyên VGD ID.
- Ghi dữ liệu cầu nối trên khối (VGD ID, plugin nguồn, loại phòng, mã phòng bên BIM) để VGD_BIM đọc, và loại khối phòng khỏi Bảng khối lượng.

## Không làm
Không tính diện tích hay khối lượng, không đặt tên / tầng / hoàn thiện (VGD_BIM làm). Không dựng tường, sàn, trần thật. Không tự dò viền từ tường.

## Lưu ý
- Khối phòng là hình thật trong model. Sửa tay khối (kéo, đẩy) thì lệch dữ liệu: dữ liệu bên VGD_BIM là đúng, bấm Dựng khối lại để đồng bộ.
- Khối cũ đang bị khóa thì không dựng lại được; hãy mở khóa trước.
- Cần SketchUp 2022 trở lên. Chưa kiểm thử trong SketchUp thật (xem phần Kiểm thử).

## Cầu nối
Đăng ký loại `room_volume` (lệnh `build`, `find`) với danh bạ cầu nối `VGD::Bridge`. Đặc tả: `docs/vgd_bim/BRIDGE.md`.

## Kiểm thử
`ruby dev/run_tests.rb` (từ `plugins/VGD_Room`): kiểm tra cú pháp và chạy test với SketchUp giả lập (dữ liệu sai, hình dựng, thao tác, dựng lại, cầu nối). **Chưa xác minh trong SketchUp thật:** `add_face` / `pushpull` với viền cong hoặc lõm, hướng pháp tuyến, tag và vật liệu, hoàn tác một bước.
