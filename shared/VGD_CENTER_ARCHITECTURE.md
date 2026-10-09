# VGD Center

Trạng thái: bộ cài VGD Center 1.0.1 đã được dựng cục bộ; đang chờ phát hành lên GitHub.

## Phạm vi hiện tại

- VGD Center là SketchUp extension có logo VGD trên toolbar và mục mở ở Extensions.
- Catalog chính đặt tại `shared/vgd-center/catalog.json` trên nhánh `main`. RBZ đi kèm trong gói Center làm bản dự phòng khi GitHub không truy cập được.
- Catalog `latest` hiển thị phiên bản mới nhất đã chọn cho mỗi plugin. Các bản beta và alpha được chấp nhận và phải ghi nhãn rõ trên giao diện.
- Mỗi mục catalog dùng URL GitHub đã cho phép, dung lượng, SHA-256, tên extension và các thư mục cài đặt cố định theo ID plugin.
- VGD Center tải RBZ bằng SketchUp HTTP API, so dung lượng và SHA-256, kiểm tra danh sách đường dẫn ZIP, sao lưu file sẽ bị thay, rồi gọi `Sketchup.install_from_archive`.
- Nếu SketchUp báo lỗi khi cài, Center khôi phục những file đã sao lưu. Khi cài xong, Center báo người dùng lưu model và khởi động lại SketchUp.
- Center không tự cài lại chính nó. Người dùng cài RBZ Center qua Extension Manager.

## Catalog hiện tại

Catalog đã được cập nhật theo yêu cầu để đưa bản mới nhất hiện có của cả sáu plugin vào kho, kể cả beta/alpha. Mỗi gói được ghim bằng URL Release, dung lượng và SHA-256 đã đối chiếu với release asset trên GitHub.

Các URL hiện trỏ tới asset của từng GitHub Release đã chọn. Gói được ghim theo tag và đối chiếu SHA-256 để phát hiện nội dung không khớp.

## Luồng phát hành plugin

1. Duyệt và tạo gói `.rbz` cho phiên bản được chọn, ghi rõ stable/beta/alpha.
2. Đưa asset vào GitHub Release hoặc commit gói trong repo.
3. Cập nhật `shared/vgd-center/catalog.json` bằng URL tải, phiên bản, kênh, dung lượng và SHA-256 đã xác minh.
4. Đưa catalog lên `main`; sau đó Center mới nhận thấy phiên bản.

## Tệp chính

- `VGD_Center.rb`: đăng ký extension.
- `VGD_Center/main.rb`: dialog, catalog, kiểm tra phiên bản, tải, xác minh, sao lưu/khôi phục và cài RBZ.
- `VGD_Center/dialog.html`: giao diện động, mặc định tối và có chế độ sáng.
- `shared/vgd-center/catalog.json`: catalog phiên bản mới nhất được phân phối trên GitHub.
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
