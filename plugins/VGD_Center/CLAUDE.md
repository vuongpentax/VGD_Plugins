# VGD Center

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây vì dễ lỗi thời: xem nơi giữ phiên bản ở mục "Thông tin plugin".

## Thông tin plugin

- Tên extension: VGD Center. Namespace: `VGD::Center`.
- Loader: `VGD_Center.rb` (nạp `VGD_Center/main`). Mã chạy ở `VGD_Center/` trong thư mục plugin.
- Phiên bản: `VERSION` trong `VGD_Center/main.rb`, khớp `extension.version` trong `VGD_Center.rb`. Đóng gói cần có `RELEASE_NOTES_v<phiên bản>.md`.
- SketchUp tối thiểu: 2022 (Ruby 2.7).
- Dữ liệu tab Quản lý: `Plugins/VGD_Center/data` (`disabled/`, `sets.json`).

## Cấu trúc

- `VGD_Center/`: `main.rb`, `dialog.html`, `manager/` (tab Quản lý: Ruby, JS, CSS), `guides/`, `assets/`, `vgd-theme/`, bản catalog và `center-update.json` đi kèm gói.
- `dev/`: `package.py`, các file `test_*.rb`, `stub/` (giả lập SketchUp).
- Ngoài plugin: `shared/vgd-center/catalog.json`, `center-update.json` và `guides/` là bản Center đọc qua URL raw trên nhánh `main`; `shared/VGD_CENTER_ARCHITECTURE.md` mô tả luồng phát hành và quy tắc.

## Kiểm thử

- Chạy từ `plugins/VGD_Center`: `ruby dev/test_center.rb`, `ruby dev/test_manager_toggle.rb`, `ruby dev/test_manager_linker.rb`, `ruby dev/test_manager_dialog.rb`, `ruby dev/test_manager_bundle.rb`, `ruby dev/test_manager_i18n.rb`, `ruby dev/test_manager_load.rb`, `ruby dev/test_guides.rb`.
- Test dùng giả lập SketchUp trong `dev/stub`. Dời file plugin thật, hộp thoại và hộp chọn file chưa được xác minh trong SketchUp thật.

## Đóng gói

- Từ gốc repo: `python plugins/VGD_Center/dev/package.py <phiên bản>` (nhận cả bản thử `x.y.z-beta.N`, dùng chung `RELEASE_NOTES_vx.y.z.md`). Script chép `catalog.json` và `center-update.json` từ `shared/vgd-center/` vào gói rồi kiểm tra.
- Phát hành là việc riêng, chỉ làm khi được yêu cầu: GitHub Release, rồi cập nhật `shared/vgd-center/center-update.json`. Sửa các file trong `shared/vgd-center/` trên `main` có hiệu lực ngay với người dùng.

## Tài liệu đọc trước khi sửa

- `README.md` và `shared/VGD_CENTER_ARCHITECTURE.md`.

## Quy tắc riêng

- Plugin mới vào kho không cần sửa Center nếu mục catalog đạt quy tắc trong `shared/VGD_CENTER_ARCHITECTURE.md` (id, tên extension bắt đầu bằng `VGD `, đúng hai đường dẫn). Không nới quy tắc này mà không được yêu cầu.
- Tab Quản lý dời file thật của mọi plugin. `VGD_Center` và `VGD_PluginManager` luôn được bảo vệ (không hiện, không tắt được); tên `VGD_PluginManager` cũng bị giữ chỗ trong catalog. Không làm yếu các bảo vệ này.
- Nạp ngay chỉ nạp plugin chưa chạy trong phiên (xem `Toggle.already_running?`). Không nạp lại plugin đã chạy: sẽ nhân đôi menu, toolbar, observer. Không thay `Sketchup.require` bằng `load`.
- Trang hướng dẫn tải từ kho phải qua `valid_guide_html?` trước khi ghi; không nới kiểm tra này (script, khung nhúng, tài nguyên và liên kết ra ngoài). Bản gốc hướng dẫn ở `shared/vgd-center/guides/`, bản trong `VGD_Center/guides/` phải giống hệt (test kiểm tra).
- Plugin đăng ký tên extension khác `extension_name` trong catalog (Cabinet, Library, BIM) được nhận qua nhánh `case` trong `find_installed_extension`. Đổi `extension_name` của plugin có sẵn trong catalog làm các Center cũ loại mục đó khỏi Kho (so khớp đúng tên trong `PLUGIN_LAYOUTS`), nên chỉ đổi khi phát hành bản plugin mới và sau khi Center nhận tên mới đã được phát hành.
- Chuyển plugin phải chép trọn một plugin (loader và thư mục cùng lúc), kiểm tra lại từng file sau khi chép (`verify_copy`) và ghi `manager.log` mỗi lần chuyển. Không quay lại cách bỏ qua riêng từng mục.
- Hộp thoại dùng `STYLE_DIALOG` như các plugin VGD khác (kiểu cửa sổ độc lập từng bị chìm sau SketchUp).
- Chữ giao diện mới phải có cả tiếng Việt và tiếng Anh: bảng `englishText` trong `dialog.html`, bảng `I18N` trong `manager/manager.js`, và `manager/text.rb` cho thông báo từ Ruby. `dev/test_manager_i18n.rb` kiểm tra đủ cặp.
