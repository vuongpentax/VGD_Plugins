# VGD Diagram 0.7.0-beta.1

Plugin SketchUp vẽ **sơ đồ cây lắp ráp** của đối tượng: các cấu kiện, số lượng và thứ tự lắp, để khách hàng và thợ lắp đặt dễ hiểu mô hình.

## Trạng thái

**0.7.0-beta.1 (chọn định dạng khi lưu).** Thay đổi so với 0.6.0-beta.1:

- **Hộp lưu:** xuất ảnh và video mở hộp chọn nơi lưu và tên file. Đuôi file bạn gõ quyết định định dạng: ảnh là `.png` hoặc `.jpg`, video là `.mp4` hoặc `.webm`. Không gõ đuôi thì dùng định dạng đã chọn cạnh nút.
- **MP4:** chỉ xuất được khi trình duyệt trong SketchUp hỗ trợ quay MP4. Nếu không, plugin báo rõ và bạn chọn WebM. Plugin không tự đổi sang WebM.
- **Chưa có:** GIF, và chuyển đổi video sang định dạng khác ngoài trình duyệt.
- **Chưa kiểm tra trong SketchUp thật.**

**0.6.0-beta.1 (xuất video lắp ráp).** Thay đổi so với 0.5.0-beta.1:

- **Xuất video:** quay video 1280×720, 30 fps, theo góc iso. Mỗi bước: cấu kiện của bước bay vào chỗ, các bước trước đã xám, bước hiện tại tô cam kèm mũi tên và chú thích. Cuối video giữ hình lắp hoàn chỉnh 2 giây. Mỗi bước khoảng 1,6 giây.
- **Định dạng:** MP4 nếu trình duyệt quay được; không thì WebM. File lưu là `<tên>-lap-rap.mp4` hoặc `.webm`.
- **Chưa kiểm tra trong SketchUp thật:** việc quay video (MediaRecorder) có chạy trong SketchUp 2022 không chưa biết; đã kiểm tra trong Chromium (đầu ra MP4/VP9, đúng trình tự bước).

**0.5.0-beta.1 (xuất theo cụm và theo bước lắp, cảnh báo).** Thay đổi so với 0.4.0-beta.1:

- **Xuất theo cụm:** mỗi nhóm cấp đầu một ảnh iso (`cum-01`, `cum-02`...), chỉ hiện cấu kiện của cụm đó.
- **Xuất theo bước:** mỗi số thứ tự lắp là một bước (`buoc-01`, `buoc-02`...). Cấu kiện đã lắp xám, cấu kiện của bước này tô cam kèm mũi tên chiều lắp, cấu kiện chưa lắp bị ẩn, có chú thích tên bước.
- **Cảnh báo:** nút **Kiểm tra** báo nhóm chưa có thứ tự, ảnh quá 15 nhãn, hoặc bước quá nhiều nhãn. Khi xuất cũng hiện cảnh báo tương tự.
- **Đã kiểm tra tự động:** Chromium 42/42 (gồm xuất đủ ảnh theo góc, cụm, bước, và cảnh báo).
- **Chưa kiểm tra trong SketchUp thật.**

**0.4.0-beta.1 (phạm vi theo đối tượng đã chọn, đề xuất thứ tự, xuất ảnh bằng style mặc định).** Thay đổi so với 0.3.0-beta.1:

- **Phạm vi:** sơ đồ, mô hình 3D và xuất ảnh chỉ làm việc với **đối tượng đang chọn** trong model, không phải cả model. Đổi lựa chọn thì bấm **Làm mới** để cập nhật.
- **Đề xuất thứ tự:** điền sẵn số lắp cho mọi nhóm, theo từng lớp group (cùng cấp đánh 1, 2, 3... từ dưới lên, theo độ cao thấp nhất của nhóm). Chưa lưu: kiểm tra rồi bấm **Lưu thứ tự**.
- **Xuất ảnh các góc:** vẽ bằng three.js theo **style mặc định SketchUp giả lập** (mặt xám trắng, cạnh đen, nền trắng), phối cảnh song song, kèm nhãn số. Không còn dùng `View#write_image` nên không phụ thuộc camera hay style của SketchUp.
- **Đã kiểm tra tự động:** logic gom nhóm, sắp thứ tự, đề xuất theo lớp, số trùng, đánh số và CSV, đọc/ghi model giả lập, lấy hình học, menu và Tải lại code, giao diện, khung 3D, nhãn số và xuất 4 ảnh trong Chromium (`dev/`).
- **Chưa kiểm tra trong SketchUp thật.** Cần thử trên SketchUp 2022 (Windows), đặc biệt khung 3D (WebGL) trong hộp thoại SketchUp.
- **Chưa làm:** sơ đồ mũi tên hướng lắp, SVG vector đúng style SketchUp, dùng đúng style đang bật của model.

## Cách dùng

1. Chọn đối tượng (nhóm hoặc component) trong model.
2. Bấm **Extensions → VGD → VGD Diagram → VGD Diagram** hoặc nút trên thanh **VGD DGM**, rồi bấm **Làm mới**.
3. Cây hiện các cấu kiện ở cấp đầu, bên trong là cấu kiện con.
   - Bấm tên để chọn các bản đó trong model.
   - Nhập thứ tự lắp (số nguyên 1 đến 9999) rồi bấm **Lưu thứ tự**. Có thể dùng Ctrl+Z để hoàn tác.
   - Hoặc bấm **Đề xuất thứ tự** để điền sẵn theo lớp group, rồi kiểm tra và lưu.
   - Số thứ tự chỉ cần không trùng giữa các cấu kiện **cùng cấp**.
4. **Xuất SVG** lưu sơ đồ thành file ảnh vector (vẽ bằng plugin).
5. **Xuất ảnh** chọn một thư mục. Plugin lưu:
   - 4 ảnh tổng quan (`truoc`, `phai`, `tren`, `iso`) theo trạng thái mô hình 3D hiện tại;
   - ảnh theo cụm (`cum-01`...), mỗi nhóm cấp đầu một ảnh;
   - ảnh theo bước (`buoc-01`...), mỗi số thứ tự lắp một ảnh;
   - file `danh-sach.csv`.
6. **Kiểm tra** báo các điều cần sửa trước khi xuất (nhóm chưa có thứ tự, quá nhiều nhãn trên một ảnh).
7. **Định dạng:** chọn PNG hoặc JPG (ảnh) và MP4 hoặc WebM (video) cạnh nút tương ứng; hoặc gõ đuôi file trong hộp lưu.

## Mô hình 3D

- Hình học lấy từ các mặt của đối tượng đã chọn, chỉ đọc. Model không bị đổi khi tách rời hay phát lắp ráp.
- **Tách rời:** mỗi mảnh di chuyển ra xa tâm mô hình theo tỉ lệ với khoảng cách của nó. Đây là cách tách theo hướng tâm, chưa phải tách theo trục như ảnh mẫu.
- **Phát lắp ráp:** các cấu kiện có thứ tự lắp được lắp lần lượt từ 1 đến hết. Cấu kiện chưa có thứ tự theo thanh trượt.
- Số nhãn hiện trên cây và trên mô hình, khớp nhau. Mỗi nhóm có hình học một nhãn, đặt trên cấu kiện đầu tiên của nhóm.
- Khi bấm tên hoặc trỏ vào một dòng trong cây, các cấu kiện thuộc dòng đó được tô màu cam.
- Giới hạn: tối đa 100.000 tam giác. Mô hình lớn hơn sẽ bị cắt bớt và có thông báo.
- Thư viện three.js r150.1 (MIT) nằm trong `runtime/vgd_diagram/vendor/`, không cần mạng.

## Quy tắc gom và thứ tự (giả định cần xác nhận)

- Các cấu kiện **cùng tên và cùng cấu trúc con** được gom thành một dòng kèm số lượng (ví dụ "Chân × 4").
- Dòng con chỉ hiện theo **một bản đại diện**. Khi bấm một dòng, chỉ các bản thuộc đại diện đó được chọn.
- Thứ tự lắp lưu thành thuộc tính trong model (dictionary `VGD_Diagram`, khóa `order`). Thứ tự áp cho mọi bản trong nhóm. Khi các bản có thứ tự khác nhau, ô hiện "nhiều số".
- Plugin **chỉ đọc** hình học. Chỉ thêm/xóa thuộc tính thứ tự khi bạn bấm Lưu thứ tự.

## Cài đặt và tải lại

- Cài file `VGD_Diagram_v<phiên bản>.rbz` qua Extension Manager.
- Nút **Tải lại code** (Extensions → VGD → VGD Diagram → Tải lại code) nạp lại mã sau khi cài bản mới. Không tải lại khi đang ghi thứ tự lắp.
- Menu và toolbar chỉ đổi sau khi **mở lại SketchUp**.

## Kiểm thử

Chạy từ thư mục `plugins/VGD_Diagram`:

```bash
ruby dev/test_tree.rb
ruby dev/test_reload.rb
ruby dev/test_scene.rb
node dev/test_ui.cjs
```

Đóng gói: `python dev/package.py` (tạo RBZ và SHA-256 trong `outputs/`, không commit).
