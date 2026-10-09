# VGD Center

Trạng thái: bộ cài stable 1.0.0 đã được dựng cục bộ; đang chờ phát hành lên GitHub.

## Phạm vi hiện tại

- VGD Center là SketchUp extension có logo VGD trên toolbar và mục mở ở Extensions.
- Catalog chính đặt tại `shared/vgd-center/catalog.json` trên nhánh `main`. RBZ đi kèm trong gói Center làm bản dự phòng khi GitHub không truy cập được.
- Chỉ hiển thị phiên bản stable có số dạng `x.y.z`. Beta, alpha, RC, preview và dev không được chấp nhận trong catalog.
- Mỗi mục catalog dùng URL GitHub đã cho phép, dung lượng, SHA-256, tên extension và các thư mục cài đặt cố định theo ID plugin.
- VGD Center tải RBZ bằng SketchUp HTTP API, so dung lượng và SHA-256, kiểm tra danh sách đường dẫn ZIP, sao lưu file sẽ bị thay, rồi gọi `Sketchup.install_from_archive`.
- Nếu SketchUp báo lỗi khi cài, Center khôi phục những file đã sao lưu. Khi cài xong, Center báo người dùng lưu model và khởi động lại SketchUp.
- Center không tự cài lại chính nó. Người dùng cài RBZ Center qua Extension Manager.

## Catalog hiện tại

GitHub hiện chỉ có các Release plugin được đánh dấu prerelease. Catalog stable ban đầu vì vậy chỉ đưa hai gói stable đang có trong repo `main`:

- VGD Dim 3.1.0
- VGD Scenes 1.5.2

VGD Cabinet, VGD Library, VGD Image Importer và VGD BIM Lite chưa có gói stable được duyệt nên chưa xuất hiện trong kho. Khi có bản stable mới, cập nhật catalog với URL, dung lượng và SHA-256 đúng của RBZ; catalog sẽ được đọc lại khi mở Center hoặc bấm kiểm tra.

Các URL ban đầu trỏ tới file RBZ trong một commit `main` đã biết. Đường dẫn commit cố định để gói không đổi âm thầm khi nội dung nhánh được cập nhật.

## Luồng phát hành plugin

1. Duyệt và tạo gói stable `.rbz`.
2. Đưa asset vào GitHub Release stable hoặc commit gói stable trong repo.
3. Cập nhật `shared/vgd-center/catalog.json` bằng URL tải, phiên bản, dung lượng và SHA-256 đã xác minh.
4. Đưa catalog lên `main`; sau đó Center mới nhận thấy phiên bản.

## Tệp chính

- `VGD_Center.rb`: đăng ký extension.
- `VGD_Center/main.rb`: dialog, catalog, kiểm tra phiên bản, tải, xác minh, sao lưu/khôi phục và cài RBZ.
- `VGD_Center/dialog.html`: giao diện động, mặc định tối và có chế độ sáng.
- `shared/vgd-center/catalog.json`: catalog stable được phân phối trên GitHub.
- `VGD_Center/build_release.ps1`: tạo RBZ, source zip và file SHA-256.

## Kiểm tra trước khi phát hành

- Kiểm tra định dạng JSON và đối chiếu SHA-256/dung lượng các gói catalog.
- Kiểm tra archive RBZ và danh sách đường dẫn; từ chối ZIP có đường dẫn thoát thư mục hoặc liên kết tượng trưng.
- Kiểm tra Ruby syntax nếu có runtime Ruby tương thích.
- Cần kiểm tra thực tế bên trong SketchUp 2022 trước khi coi là đã xác nhận hoàn toàn hành vi HTTP, cài đặt và khôi phục.

## API tham khảo

- [SketchUp Ruby API — UI::HtmlDialog](https://ruby.sketchup.com/UI/HtmlDialog.html)
- [SketchUp Ruby API — Sketchup.install_from_archive](https://ruby.sketchup.com/Sketchup.html#install_from_archive-class_method)
- [SketchUp Ruby API — Sketchup::Http::Request](https://ruby.sketchup.com/Sketchup/Http/Request.html)
- [SketchUp extension requirements](https://ruby.sketchup.com/file.extension_requirements.html)
- [GitHub Docs — Linking to releases and assets](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases)
