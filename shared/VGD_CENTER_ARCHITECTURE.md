# VGD Center

VGD Center 1.0.1 được đóng gói dưới dạng RBZ, dùng danh mục phiên bản mới nhất trên GitHub.

## Phạm vi hiện tại

- VGD Center là SketchUp extension có logo VGD trên toolbar và mục mở ở Extensions.
- Catalog chính đặt tại `shared/vgd-center/catalog.json` trên nhánh `main`. RBZ đi kèm trong gói Center làm bản dự phòng khi GitHub không truy cập được.
- Catalog `latest` hiển thị phiên bản mới nhất đã chọn cho mỗi plugin. Các bản beta và alpha được chấp nhận và phải ghi nhãn rõ trên giao diện.
- Mỗi mục catalog dùng URL GitHub đã cho phép, dung lượng, SHA-256, tên extension và đúng hai đường dẫn cài đặt (loader và thư mục). Plugin có sẵn dùng danh sách cố định `PLUGIN_LAYOUTS` trong `main.rb`; plugin mới khai báo trong catalog và được nhận nếu đạt quy tắc ở mục "Plugin mới".
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

## Plugin mới

Từ VGD Center 1.2.0, plugin có `id` mới không cần cập nhật Center nếu mục catalog đạt các quy tắc sau (xem `validate_plugin_layout`):

- `id` dạng `[a-z][a-z0-9_]` (2–40 ký tự), khác `center`.
- `extension_name` bắt đầu bằng `VGD ` và không trùng tên plugin khác.
- `allowed_paths` gồm đúng hai đường dẫn: loader `VGD_*.rb` hoặc `vgd_*.rb` và thư mục cùng tên (không phân biệt hoa thường), không trùng đường dẫn của plugin khác hoặc của Center.
- Không trùng đường dẫn mà tab Quản lý bảo vệ (`Manager::SELF_NAMES`), đặc biệt `VGD_PluginManager` (nơi Plugin Manager cũ để dữ liệu).
- Các kiểm tra khác (phiên bản và kênh, URL, dung lượng, SHA-256) giống plugin có sẵn.

Ý nghĩa bảo mật: một mục catalog chỉ ghi được vào đúng loader và thư mục của chính nó, không ghi đè plugin khác. Catalog vẫn là nguồn tin cậy: ai sửa được catalog có thể đưa một plugin `VGD_*` mới lên máy người dùng, nên `main` phải được bảo vệ như nguồn phát hành.

Đổi lại, plugin mới dùng icon hộp mặc định và không có cảnh báo gỡ riêng (trừ `uninstall_note` tùy chọn trong catalog). Muốn có các thứ đó thì cần cập nhật Center. Trang Hướng dẫn thì không cần (xem mục dưới).

## Hướng dẫn (từ 1.2.2)

- Bản gốc của mọi trang hướng dẫn: `shared/vgd-center/guides/<id>.html`. Gói Center mang bản đi kèm ở `vgd_center/guides/` (`package.py` chép từ shared khi đóng gói; `dev/test_guides.rb` kiểm tra hai nơi giống nhau).
- Bấm **Hướng dẫn** (`open_guide`): Center tải `https://raw.githubusercontent.com/vuongpentax/VGD_Plugins/main/shared/vgd-center/guides/<id>.html`, kiểm tra (`valid_guide_html?`), ghi vào `guides/<id>.html` (file tạm rồi đổi tên) rồi mở. Chờ tối đa `GUIDE_TIMEOUT` (5 giây); lỗi mạng, mã khác 200 hoặc trang không hợp lệ thì mở bản đang có (đi kèm gói hoặc tải lần trước). Chưa có bản nào thì báo chưa có.
- Nút hiện nếu trang đã có trong thư mục guides hoặc mục catalog khai báo `"guide": true` (plugin mới chưa có trang trong gói).
- Trang chỉ được là tài liệu tĩnh (không script, khung nhúng, form, base, meta refresh, tài nguyên hay liên kết ra ngoài). Ai sửa được `main` có thể đổi nội dung trang, cũng như đã có thể đổi catalog, nên `main` phải được bảo vệ như nguồn phát hành.
- Chưa kiểm thử trong SketchUp thật: `Sketchup::Http::Request` với raw.githubusercontent.com, ghi file vào thư mục guides trên Windows.

## Tab Quản lý (từ 1.2.1)

Tab Quản lý có nguồn gốc từ VGD Plugin Manager 1.0.0-beta.17. Plugin đó đã được gỡ khỏi repo và khỏi catalog; mã nằm trong Center (`vgd_center/manager/`, module `VGD::Center::Manager`). Giao diện: trang `page-manager` trong `dialog.html`, cùng `manager/manager.js` và `manager/manager.css` (tên lớp có tiền tố `mgr-`). Khác với phần cài đặt, tab này **dời file của mọi plugin** trong thư mục Plugins, nên rủi ro cao hơn:

- **Mục được bảo vệ** (`Manager::SELF_NAMES`): `VGD_Center`, `VGD_PluginManager` và tên cũ `vgd_plugin_migrator`. Không bao giờ hiện trong danh sách, không tắt hay chuyển được; so khớp không phân biệt hoa thường. `VGD_Center` chứa thư mục dữ liệu; `VGD_PluginManager` được giữ vì máy cũ có thể còn cài Plugin Manager hoặc còn dữ liệu cũ chưa chuyển.
- **Thư mục dữ liệu** `Plugins/vgd_center/data` (`disabled/` chứa plugin đã tắt, `sets.json` chứa bộ plugin). Không phải trong `VGD_PluginManager` như Plugin Manager cũ.
- **Chuyển dữ liệu cũ** (`Toggle.migrate_old_data`): dữ liệu ở `Plugins/VGD_PluginManager/data` (Plugin Manager beta.4 trở đi) và ở thư mục beta.3 (ngoài Plugins) được chuyển vào `VGD_Center/data`, vì gỡ Plugin Manager bằng Extension Manager có thể xóa thư mục của nó. Chạy ngay lúc khởi động SketchUp (hẹn giờ 8 giây sau khi nạp, `Manager.migrate_on_start`) và mỗi lần mở tab Quản lý. Chỉ dùng thao tác đổi chỗ từng mục, không bao giờ xóa đệ quy, không ghi đè: mục trùng tên ở chỗ mới ở lại chỗ cũ và được báo; file bộ plugin được gộp (bộ cùng tên ở chỗ mới thắng), file hỏng giữ nguyên. Thư mục cũ chỉ bị xóa khi đã rỗng. Plugin Manager cũ còn cài sẽ không thấy dữ liệu đã chuyển; tab báo để người dùng gỡ nó. Gỡ Extension Manager của chính Center sẽ xóa luôn `VGD_Center/data`; Center không tự gỡ mình.
- **Nạp ngay** (`Toggle.load_now`, lệnh `mgr_load`): nạp plugin đang bật mà chưa chạy trong phiên bằng `Sketchup.require` trên file nạp (`.rb/.rbe/.rbs` cùng tên plugin), không cần khởi động lại. Plugin "đã chạy" nếu có trong Plugins lúc SketchUp khởi động (`Toggle.remember_startup`, gọi trong `main.rb`), đã được Nạp ngay, hoặc có trong `$LOADED_FEATURES`; những plugin này không bị nạp lại vì sẽ nhân đôi menu, toolbar, observer. Thư viện nền (tên chứa `lib`) nạp trước; lỗi của một plugin không dừng các plugin còn lại (bắt cả `SyntaxError`/`LoadError`) và plugin lỗi vẫn ở trạng thái chờ nạp. Hộp xác nhận chỉ hiện lần đầu mỗi phiên. Tắt plugin không gỡ được khỏi bộ nhớ.
- **Khóa khi Center bận**: bật/tắt, bộ plugin và chuyển plugin bị từ chối khi Center đang tải/cài/gỡ (`VGD::Center.busy?`), để không dời file trong Plugins cùng lúc.
- Lỗi bất ngờ được ghi vào `%APPDATA%\SketchUp\VGD_Center\manager.log` (luôn tiếng Việt, dành cho người hỗ trợ) và hiện trong tab.
- Lệnh Ruby của tab đều bắt đầu bằng `mgr_`; Ruby gọi giao diện qua `window.VGDManager.<hàm>`.
- **Tiếng Anh**: chữ tĩnh trong `dialog.html` dịch qua bảng `englishText` của Center; phần tử do JS ghi chữ mang thuộc tính `data-no-translate` để bộ dịch bỏ qua. Chữ do `manager.js` sinh ra dùng bảng `I18N` trong file đó. Thông báo, hộp xác nhận và tiêu đề hộp chọn file do Ruby tạo dùng `manager/text.rb`; mỗi lệnh `mgr_*` nhận `lang` từ giao diện, thiếu hoặc lạ thì dùng tiếng Việt. Thêm chữ mới thì phải thêm cả hai ngôn ngữ; `dev/test_manager_i18n.rb` kiểm tra đủ cặp, cùng chỗ điền, và không sót chữ Việt trong bản tiếng Anh.
- Chưa kiểm thử trong SketchUp thật.

### Bài học từ Plugin Manager (đã gỡ)

Mã, HANDOFF và hướng dẫn kiểm thử thủ công của Plugin Manager xem được trong lịch sử git: `git show e6404f3:plugins/VGD_PluginManager/HANDOFF.md` (cùng thư mục `docs/`). Những điều quan trọng khi bảo trì tab Quản lý:

- SketchUp nạp mọi `.rb/.rbe/.rbs` ở gốc Plugins; thư mục con chỉ chạy khi được `require`. Vì vậy loader và thư mục đi kèm phải bật/tắt/chuyển cùng nhau (`manager/linker.rb` gộp theo tên và theo nội dung loader).
- **Không ghi vào file cài đặt của SketchUp** (phím tắt `SharedPreferences.json`, layout thanh công cụ). Plugin Manager từng nhập 85 phím tắt rồi SketchUp 2024 văng khi khởi động 3 lần; tính năng đã gỡ. Dùng Import/Export của SketchUp.
- Chưa xác minh trong SketchUp thật: Nạp ngay (`Sketchup.require` trên plugin thật, việc SketchUp ghi file nạp lúc khởi động vào `$LOADED_FEATURES`), hộp thoại, `UI.savepanel`, mở thư mục bằng `explorer.exe`, luật gộp loader trên danh sách plugin thật, Extension Manager có nhận gói tổng không, tắt plugin có file `.dll` đang bị khóa.

## Tệp chính

- `vgd_center.rb`: đăng ký extension.
- `vgd_center/main.rb`: dialog, catalog, kiểm tra phiên bản, tải, xác minh, sao lưu/khôi phục và cài RBZ.
- `vgd_center/dialog.html`: giao diện động, mặc định tối và có chế độ sáng.
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
