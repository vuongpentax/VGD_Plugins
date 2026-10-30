# HANDOFF: VGD Plugin Migrator (SketchUp, Ruby)

Phiên bản hiện tại: **1.0.0-beta.3** (xem mục 8 cho phần thêm so với beta.2). Ngày bàn giao: 2026-10-30.
Bàn giao từ chat Claude sang Claude Code để làm tiếp.

## 1. Mục tiêu và bối cảnh

1. Người dùng dùng song song SketchUp 2022 (Ruby 2.7) và SketchUp 2024 (Ruby 3.2) trên Windows.
2. Cần một plugin SketchUp (Ruby, đóng gói .rbz) để:
   1. Chuyển plugin từ bản này sang bản kia (có sao lưu, hỏi ghi đè).
   2. Chuyển phím tắt và giao diện thanh công cụ giữa các phiên bản.
   3. Xuất **một gói .rbz tổng** chứa nhiều plugin để mang sang máy khác, cài một lần bằng Extension Manager.
   4. Bật/tắt plugin ít dùng (không xóa), bật lại khi cần, có "bộ plugin" lưu sẵn.
3. Người dùng nhập liệu bằng giọng nói nên hay bị nhận sai chữ. Cách hiểu đã dùng:
   1. "blocking" = **plugin**.
   2. "RBJ", "RBJS", "BZ" = **.rbz**.
   3. "Attention Manager" = **Extension Manager**.
4. Sở thích giao tiếp của người dùng: tiếng Việt, giải thích dễ hiểu cho người không rành AI, hỏi làm rõ trước khi làm, đề xuất cách làm và nêu rủi ro, trình bày đầu dòng có đánh số.

## 2. Cấu trúc thư mục trong gói này

1. `HANDOFF.md`: file này.
2. `src/`: mã nguồn plugin (đúng cấu trúc bên trong .rbz).
   1. `src/vgd_plugin_migrator.rb`: file loader, đăng ký SketchupExtension (version `1.0.0-beta.2`).
   2. `src/vgd_plugin_migrator/main.rb`: chuyển plugin, phím tắt, thanh công cụ; xuất gói tổng; giao diện HtmlDialog chính.
   3. `src/vgd_plugin_migrator/zip_writer.rb`: ghi file zip/.rbz thuần Ruby bằng Zlib (không cần thư viện ngoài).
   4. `src/vgd_plugin_migrator/bundle_import.rb`: mẫu file được đóng vào gói tổng (đổi tên thành `vgd_bundle_import.rb`), tạo menu nhập phím tắt/thanh công cụ trên máy mới.
   5. `src/vgd_plugin_migrator/plugin_manager.rb`: quản lý bật/tắt plugin và bộ plugin, xuất/nhập bộ ra file `.json`.
   6. `src/vgd_plugin_migrator/logger.rb`: ghi nhật ký lỗi vào `%APPDATA%\SketchUp\VGD_PluginMigrator\migrator.log`.
3. `tests/`: bộ test chạy ngoài SketchUp bằng stub (xem mục 6).
4. `docs/KIEM_THU_THU_CONG.md`: hướng dẫn kiểm thử thủ công trong SketchUp thật.
5. File `.rbz` đóng gói không lưu trong repo (`.gitignore` loại `*.rbz`); tạo bằng mục 7.

## 3. Tính năng và hành vi đã chốt

### 3.1. Chuyển plugin (menu Plugins > VGD Plugin Migrator)

1. Quét phiên bản có trong `%APPDATA%\SketchUp\SketchUp <năm>`, cho chọn nguồn và đích bằng `UI.inputbox`.
2. Plugin = file `.rb/.rbe/.rbs` ở gốc `...\SketchUp\Plugins` cộng thư mục cùng tên (nhóm theo tên bỏ đuôi).
3. Bỏ qua: chính plugin này (`SELF_NAMES`) và một số mục hệ thống (`SKIP_NAMES`).
4. Trước khi chép: sao lưu cả thư mục Plugins đích thành `Plugins_backup_<thời gian>`.
5. Có tùy chọn ghi đè; mặc định bỏ qua mục đã tồn tại.
6. `scan_compat`: quét `.rb` tìm cú pháp Ruby 2.7 dễ lỗi trên 3.2 (Fixnum/Bignum, File.exists?, Dir.exists?, URI.escape, taint/untaint). Chỉ cảnh báo, không sửa code.

### 3.2. Phím tắt và thanh công cụ (registry Windows)

1. Dùng lệnh `reg query/export/import` trên khóa:
   1. `HKCU\Software\SketchUp\SketchUp <ver>\Shortcuts`
   2. `HKCU\Software\SketchUp\SketchUp <ver>\Toolbars`
2. Chuyển bằng cách export khóa nguồn, thay chuỗi `SketchUp <nguồn>` thành `SketchUp <đích>`, import lại. Có sao lưu khóa đích ra `Documents\SU_<loại>_<ver>_backup_<thời gian>.reg`.
3. Nếu không tìm thấy khóa thì báo "Không tìm thấy dữ liệu" và không ghi gì.

### 3.3. Xuất gói .rbz tổng

1. Nút "Xuất gói .rbz tổng" trong hộp thoại chính, chọn nơi lưu bằng `UI.savepanel`.
2. Gói chứa: file của các plugin đã tick (đường dẫn tương đối từ thư mục Plugins), `vgd_bundle_import.rb`, thư mục `vgd_bundle_import/` có `manifest.json` và (nếu có) `shortcuts.reg`, `toolbars.reg`.
3. Trên máy mới: cài .rbz bằng Extension Manager, khởi động lại, rồi vào menu "VGD: Nhập phím tắt/giao diện từ gói" để nhập registry (có hỏi xác nhận và sao lưu).
4. Zip viết thuần Ruby (deflate, tên file UTF-8, dùng `/`), đã kiểm chứng bằng Python `zipfile` và `unzip -t`.
5. Người dùng đã đồng ý cách này: file .rbz không tự áp dụng được registry nên cần bước nhập riêng.

### 3.4. Quản lý bật/tắt plugin (menu Plugins > VGD: Quản lý bật/tắt plugin)

Các lựa chọn người dùng đã chốt:

1. Cách tắt: **chuyển file sang thư mục "đã tắt"** (không dùng tắt/bật của Extension Manager).
2. Hiệu lực: **sau khi khởi động lại SketchUp** (không cố nạp/gỡ ngay).
3. Quản lý: **cả hai** kiểu, tức bật/tắt từng plugin và "bộ plugin" lưu sẵn (Tắt bộ / Bật bộ / Xóa bộ).

Chi tiết cài đặt:

1. Thư mục gốc: `%APPDATA%\SketchUp\SketchUp <năm hiện tại>\SketchUp\VGD_PluginManager\` (nằm ngoài `Plugins`).
   1. `disabled\`: nơi cất plugin đã tắt.
   2. `sets.json`: các bộ plugin `{ "tên bộ": ["plugin1", ...] }`.
2. Năm hiện tại lấy từ `2000 + Sketchup.version.to_i`.
3. Chỉ thao tác trên tên có trong danh sách quét thật (chống path traversal).
4. Trùng tên (plugin vừa ở Plugins vừa ở disabled) hiện trạng thái "Trùng tên", không tự ghi đè.
5. Di chuyển lỗi giữa chừng thì hoàn tác các mục đã chuyển.
6. Giao diện HtmlDialog dựng DOM bằng `textContent` (an toàn với tên plugin có ký tự HTML); lúc mở tải trạng thái qua callback `pm_ready`.

## 4. Trạng thái kiểm thử

Đã làm (trên Linux, ngoài SketchUp):

1. `ruby -c` đạt cho tất cả file `.rb`.
2. `node --check` đạt cho JavaScript của hộp thoại quản lý.
3. `tests/test_manager.rb`: 21 kiểm tra đạt (liệt kê, tắt/bật, bỏ qua tên lạ, trùng tên, lưu/áp dụng/xóa bộ). Có thử riêng hoàn tác khi `move_items` lỗi giữa chừng: đạt.
4. `tests/run_test.rb`: xuất gói .rbz trên cây thư mục giả, kiểm tra zip bằng Python và `unzip -t`: đạt, nội dung nhị phân và tiếng Việt giữ nguyên.

**Chưa làm được, cần kiểm tra trên máy Windows có SketchUp thật:**

1. Chưa chạy trong SketchUp 2022 và 2024 thật (HtmlDialog, `UI.savepanel`, `UI.inputbox`, menu).
2. **Phần registry chưa được kiểm chứng**: đường dẫn khóa Shortcuts và Toolbars ở mục 3.2 là giả định, chưa xác nhận bằng regedit. Máy test là Linux nên `reg` không chạy được; trên Linux code chỉ đi nhánh "không tìm thấy dữ liệu".
3. Chưa thử cài gói tổng bằng Extension Manager trên máy khác (gói chỉ có `vgd_bundle_import.rb`, không đăng ký SketchupExtension; cần xác nhận Extension Manager chấp nhận).
4. Chưa thử tắt plugin đang có file bị khóa (dll/so đang nạp).

## 5. Rủi ro đã biết và việc nên làm tiếp

1. **Xác minh khóa registry** của Shortcuts/Toolbars trên SketchUp 2022 và 2024 (regedit hoặc `reg query HKCU\Software\SketchUp /s`). Sửa hằng `REG_SHORTCUTS`, `REG_TOOLBARS` trong `main.rb` và `KEYS` trong `bundle_import.rb` nếu khác.
2. SketchUp có thể **ghi đè phím tắt/thanh công cụ khi thoát**, làm bản import không giữ. Cần kiểm tra thực tế; nếu đúng thì đổi quy trình (ví dụ nhập khi SketchUp đóng, qua công cụ ngoài hoặc file .reg).
3. Plugin có bản quyền hoặc mã hóa gắn phiên bản vẫn phải cài/kích hoạt lại ở bản mới hoặc máy mới (không vượt qua được).
4. Tắt plugin mà plugin khác phụ thuộc có thể gây lỗi khi mở lại. Có thể cân nhắc cảnh báo phụ thuộc.
5. Chỉ hỗ trợ Windows (đường dẫn `%APPDATA%`, lệnh `reg`). Chưa có nhánh macOS.
6. Chuỗi giao diện đang cứng tiếng Việt.
7. Gợi ý việc tiếp theo:
   1. Tạo test tích hợp trong SketchUp thật hoặc tối thiểu hướng dẫn test thủ công từng bước.
   2. Cân nhắc cho "bộ plugin" có thêm xuất/nhập ra file để mang sang máy khác.
   3. Cân nhắc dùng `SketchupExtension#check/uncheck` cho plugin đã đăng ký extension như phương án bổ sung.
   4. Nếu bán/phát hành: thêm nhật ký lỗi vào file thay vì chỉ hiện trong hộp thoại.

## 6. Cách chạy test

Cần Ruby (đã dùng ở môi trường Linux). Dùng **đường dẫn tuyệt đối** hoặc chạy đúng như dưới đây từ thư mục gốc gói:

```
ruby tests/test_manager.rb src
ruby tests/run_test.rb src
```

1. `tests/stub/sketchup.rb` giả lập tối thiểu `Sketchup.version`, `UI.menu`, `file_loaded?`.
2. Test dùng thư mục `APPDATA` giả tạo trong thư mục tạm, không đụng dữ liệu thật.

## 7. Cách đóng gói lại .rbz

File .rbz là zip có đường dẫn dùng dấu `/`, các file ở gốc của zip:

```
cd src
python3 -c "
import zipfile
z=zipfile.ZipFile('../dist/VGD_Plugin_Migrator_1.0.0-beta.3.rbz','w',zipfile.ZIP_DEFLATED)
for n in ['vgd_plugin_migrator.rb','vgd_plugin_migrator/main.rb','vgd_plugin_migrator/zip_writer.rb','vgd_plugin_migrator/bundle_import.rb','vgd_plugin_migrator/plugin_manager.rb','vgd_plugin_migrator/logger.rb']:
    z.write(n,n)
z.close()
"
```

Khi thêm file mới vào `src/vgd_plugin_migrator/` nhớ thêm vào danh sách trên. Khi đổi phiên bản, sửa cả `VERSION` trong `main.rb` và `ex.version` trong `vgd_plugin_migrator.rb`.

## 8. Ghi chú về các phiên bản

1. `1.0.0`: chuyển plugin, phím tắt, thanh công cụ.
2. `1.0.0-beta`: thêm xuất gói .rbz tổng.
3. `1.0.0-beta.2`: thêm quản lý bật/tắt plugin và bộ plugin.
4. `1.0.0-beta.3`: thêm xuất/nhập bộ plugin ra file `.json` (có hỏi ghi đè khi trùng tên, lọc dữ liệu sai kiểu), ghi nhật ký lỗi ra file, hướng dẫn test thủ công. Đã kiểm tra tự động ngoài SketchUp; **chưa kiểm tra trong SketchUp thật** (hộp thoại mở/lưu file `UI.openpanel`/`UI.savepanel`, `UI.messagebox` hỏi ghi đè).
