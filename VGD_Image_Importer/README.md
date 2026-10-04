# VGD Image Importer

Thành viên bộ plugin VGD cho SketchUp 2022+ trên Windows, nâng cấp từ folder `vgd_image_importer` trên máy. Phiên bản `1.1.0-beta.2` giữ namespace và đường dẫn extension cũ để cập nhật tại chỗ.

## Chức năng

- Nhập component ảnh 2D dựng đứng, tùy chọn luôn hướng camera; ảnh nằm phẳng XY; hoặc chỉ thêm vật liệu vào Materials.
- Chọn cả thư mục, tùy chọn thư mục con; chọn một hoặc nhiều ảnh lẻ qua hộp thoại Windows Explorer. Giữ Ctrl/Shift hoặc quét chọn rồi bấm Open là thêm vào danh sách ngay. Cancel hủy chọn và giữ danh sách. Trên macOS dùng hộp thoại một file của SketchUp, không có vòng lặp Cancel.
- Hỗ trợ JPG/JPEG/JFIF/JPE, PNG/APNG, BMP/DIB, TIF/TIFF, TGA, WebP, GIF, AVIF, ICO, SVG. WebP và các định dạng mở rộng được giải mã trong Chromium của HtmlDialog rồi chuyển PNG, giữ kích thước và alpha. Ảnh động lấy khung đầu, SVG được raster hóa theo kích thước khai báo. AVIF phụ thuộc bộ giải mã Chromium của phiên bản SketchUp.
- HEIC/HEIF được chuyển qua Windows WIC nếu có codec HEIF trên máy; thiếu codec sẽ báo rõ từng ảnh. Plugin không tự cài codec hoặc tải bộ chuyển đổi bên ngoài. TIFF/TGA và HEIC có nhãn thay hình xem trước.
- Sắp tên tự nhiên (ảnh 2 trước ảnh 10), bỏ đường dẫn trùng, giữ tỉ lệ ảnh theo mm/pixel, chiều cao hoặc chiều rộng cố định.
- Bố trí theo hàng tại gốc tọa độ của `active_entities`; khoảng hở cho phép bằng 0. Với ảnh dựng đứng, khoảng cách hàng theo chiều cao ảnh là quy tắc bố trí kế thừa bản cũ.
- Vật liệu mới không ghi đè vật liệu sẵn có; SketchUp tự tạo tên riêng khi trùng. Lỗi một ảnh không chặn các ảnh còn lại; thông báo số thành công và từng ảnh lỗi. Undo một lần cho cả lượt nhập thành công.
- Theme sáng/tối, header VGD, màu nâu đồng và kiểu control theo VGD Scenes. Lưu theme, thông số và thư mục gần nhất trên máy. Danh sách ảnh giữ khi đóng/mở dialog trong cùng phiên SketchUp, không lưu qua lần khởi động.

## Cài đặt

Trong SketchUp: **Extension Manager → Install Extension**, chọn `VGD_Image_Importer_v1.1.0-beta.2.rbz`. Thoát và mở lại SketchUp để bản mới được nạp đầy đủ; không nạp chồng main.rb lên bản cũ trong Ruby Console vì bản cũ không có chặn đăng ký toolbar lặp.

Mở bằng **Extensions → VGD Tools → VGD Image Importer** hoặc toolbar **VGD Image Importer**. Nếu toolbar chưa hiện, bật ở **View → Toolbars**.

Đồng bộ từ mã nguồn trên Windows:

```powershell
powershell -ExecutionPolicy Bypass -File VGD_Image_Importer/dev/deploy.ps1 -VerifyOnly
powershell -ExecutionPolicy Bypass -File VGD_Image_Importer/dev/deploy.ps1
```

Mặc định cài vào SketchUp 2022; dùng `-PluginRoot` để chỉ định bản khác. Chỉ ghi 11 file của Image Importer, có kiểm tra quyền sở hữu loader, sao lưu trước khi ghi và kiểm tra SHA256. Bản sao lưu và báo cáo nằm ở `outputs/install_<timestamp>/`. Muốn khôi phục, đóng SketchUp, chép các file đã sao lưu về đúng đường dẫn, bỏ các file mới được đánh dấu `false` trong `existed_before`, rồi mở lại SketchUp.

## Phát triển và kiểm tra

`runtime/` là mã để đóng gói; `reference/` giữ nguyên loader, main.rb và icon bản 1.0.0 đã lấy từ Plugins. Không đóng gói reference vào RBZ. `dev/dependencies.cjs` ưu tiên dependency cài tại chỗ, có thể dùng dependency đang có của VGD Scenes/Cabinet.

```powershell
cd VGD_Image_Importer/dev
npm install
npm test
npm run package
```

Giao diện kiểm tra bằng Playwright + Edge headless, hoặc đặt `VGD_BROWSER_EXECUTABLE` tới Chromium phù hợp. Ruby được kiểm tra cú pháp và chạy fixture bằng Ruby 3.2 WASM. Fixture mô phỏng SketchUp; Windows WASI không hỗ trợ đọc directory entries nên test traversal dùng danh sách entry cố định, còn kiểm tra file và tính toán chạy qua engine.

Đã kiểm tra tự động: hồi quy `ImageRep.load_file` trả nil khi thành công, chuyển đổi kích thước, bảo toàn tỉ lệ, số liệu không hợp lệ, thứ tự/quét con, bố trí khi ảnh lỗi, cleanup đối tượng lỗi, vật liệu trùng tên, commit/abort, callback dialog, lưu cấu hình, payload UI, theme sáng/tối và cửa sổ 540×500. Kiểm tra bằng ảnh thật: giải mã WebP/GIF/AVIF/ICO/SVG/JFIF và chuyển PNG qua Edge, WebP giữ alpha và kích thước; ảnh hỏng báo lỗi. Bộ đọc ảnh native trong `SketchUpAPI.dll` của SketchUp 2022 đã đọc thành công JPG/PNG/BMP/TIFF/TGA và PNG của sáu định dạng đã chuyển, với tên file tiếng Việt; alpha WebP/AVIF giữ 0–255. WIC script đã được kiểm tra bằng PNG; HEIC chưa có dữ liệu/codec để xác nhận. Ruby fixture kiểm tra kết quả Unicode của hộp thoại một/nhiều file, token conversion, cache cleanup và PNG không hợp lệ. Gói RBZ được mở lại và so từng file với runtime. Chưa xác nhận tạo hình/Undo và thao tác Ctrl/Shift trong SketchUp thực tế: phiên tự động khởi động chưa chạy được RubyStartup trong môi trường hiện tại.

Kiểm tra thực tế sau khi mở lại SketchUp: chọn nhiều file bằng Ctrl/Shift → Open; nhập PNG/WebP có alpha ở ba chế độ; thử mm/pixel và chiều rộng/cao; chọn 2 ảnh/hàng và khoảng hở 0; thêm ảnh hỏng; xác nhận hướng camera, texture size và Undo. Chuyển định dạng lần lượt từng ảnh trước khi mở operation; model/vùng chỉnh sửa phải giữ nguyên trong bước chuẩn bị. Cache PNG nằm trong thư mục tạm riêng, được xóa sau lượt nhập/đóng dialog; pixel được nhúng vào model. Lượt nhập lớn vẫn có thể khiến SketchUp bận khi tạo đối tượng; dialog giữ mở sau kết quả.

`dev/make_images.py` tạo ảnh thật bằng Pillow chỉ cho phát triển, không phải dependency của plugin. Sau đó `dev/test_ui.cjs` tạo PNG từ sáu định dạng mở rộng; `dev/check_native_codec.py` kiểm tra trực tiếp bộ đọc ảnh SketchUp 2022 và lưu `outputs/native_codec_report.json`. `dev/make_native_fixture.py` tạo SKP trống qua SketchUp C API trên máy. `dev/native_smoke.rb` dành cho `-RubyStartup` trong tiến trình thử riêng, tuyệt đối không load vào model người dùng.

API dùng theo tài liệu SketchUp: [ImageRep](https://ruby.sketchup.com/Sketchup/ImageRep.html), [Texture](https://ruby.sketchup.com/Sketchup/Texture.html), [HtmlDialog](https://ruby.sketchup.com/UI/HtmlDialog.html). Hộp thoại nhiều file theo [OPENFILENAMEW](https://learn.microsoft.com/en-us/windows/win32/api/commdlg/ns-commdlg-openfilenamew).
