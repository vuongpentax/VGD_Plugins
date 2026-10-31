# HANDOFF: VGD Plugin Manager (SketchUp, Ruby)

Phiên bản hiện tại: **1.0.0-beta.17** (cập nhật 2026-10-31). Nhánh làm việc: `claude/plugin-migrator-beta3`.
Plugin chưa từng được kiểm chứng đầy đủ trong SketchUp thật (xem mục 4).

## 1. Mục tiêu và bối cảnh

1. Người dùng dùng song song SketchUp 2022 (Ruby 2.7) và SketchUp 2024 (Ruby 3.2) trên Windows, có khoảng 70 plugin.
2. Plugin làm bốn việc:
   1. **Bật/tắt plugin** bằng nút gạt: chuyển plugin vào thư mục "đã tắt" (không xóa), hiệu lực sau khi khởi động lại SketchUp. Có Tắt tất cả/Bật tất cả và "bộ plugin" lưu sẵn (xuất/nhập ra file).
   2. **Chuyển plugin** giữa hai bản SketchUp (có sao lưu, hỏi ghi đè, cảnh báo cú pháp Ruby cũ).
   3. **Xuất gói .rbz tổng** chứa nhiều plugin để mang sang máy khác.
   4. Hai nút mở nhanh thư mục **Plugins** và thư mục **đã tắt**.
3. Đã thử rồi **gỡ bỏ** (beta.16): lưu/áp layout thanh công cụ và nhập phím tắt (xem mục 6).
4. Người dùng nhập liệu bằng giọng nói nên hay bị nhận sai chữ: "blocking" = plugin; "RBJ/RBJS/BZ" = .rbz; "Attention Manager" = Extension Manager.
5. Sở thích giao tiếp: tiếng Việt, giải thích dễ hiểu cho người không rành AI, hỏi làm rõ trước khi làm, đề xuất cách làm và nêu rủi ro. Người dùng đã cho phép tự commit và push lên nhánh `claude/plugin-migrator-beta3` (không tạo PR, không đụng `main`).

## 2. Cấu trúc thư mục

1. `src/`: mã nguồn plugin (đúng cấu trúc bên trong .rbz).
   1. `VGD_PluginManager.rb`: loader, đăng ký SketchupExtension (`ex.version` phải khớp `VERSION`; test kiểm tra).
   2. `VGD_PluginManager/main.rb`: hằng số, đường dẫn, danh sách plugin (`list_plugins`), chép plugin, quét tương thích, xuất gói tổng, menu và nút thanh công cụ (một nút duy nhất).
   3. `toggle.rb`: module `Toggle`: bật/tắt, Tắt/Bật hàng loạt, bộ plugin, xuất/nhập bộ ra file `.json`, chuyển dữ liệu từ vị trí cũ (beta.3).
   4. `linker.rb`: gộp loader `.rb` với thư mục/file đi kèm khác tên bằng cách đọc nội dung loader (xem mục 3.2).
   5. `dialog.rb`: hộp thoại một cửa sổ hai tab (Bật/tắt plugin, Chuyển plugin), mọi callback, `check_versions`, `open_folder`.
   6. `logger.rb`: nhật ký lỗi `%APPDATA%\SketchUp\VGD_PluginManager\migrator.log` (quá 512 KB đổi tên `.log.1`).
   7. `zip_writer.rb`: ghi zip/.rbz thuần Ruby (Zlib).
   8. `ui/`: `dialog.html`, `dialog.css`, bản sao `vgd-theme/` (đồng bộ bằng `python tools/sync_vgd_theme.py`, kiểm tra bằng `--check`).
   9. `icons/plugin_manager.svg`: icon duy nhất (24x24, nét 1.8, nâu đồng `#A67C58` + than `#292B2D`).
2. `tests/`: test chạy ngoài SketchUp bằng stub (mục 5).
3. `docs/KIEM_THU_THU_CONG.md`: hướng dẫn kiểm thử thủ công trong SketchUp thật.
4. `docs/NOI_LUU_CAI_DAT_SKETCHUP.md`: kết quả khảo sát nơi SketchUp lưu phím tắt và layout (tư liệu, plugin hiện **không** dùng).
5. File `.rbz` không lưu trong repo (`.gitignore` loại `*.rbz`).

## 3. Hành vi đã chốt

### 3.1. Bật/tắt

1. Thư mục dữ liệu: `%APPDATA%\SketchUp\SketchUp <năm>\SketchUp\Plugins\VGD_PluginManager\data\` (năm = `2000 + Sketchup.version.to_i`).
   1. `disabled\`: nơi cất plugin đã tắt (SketchUp không nạp vì không nằm ở gốc Plugins).
   2. `sets.json`: bộ plugin `{ "tên bộ": ["plugin1", ...] }`.
2. Chỉ thao tác trên tên có trong danh sách quét thật (chống path traversal); lỗi giữa chừng thì hoàn tác các mục đã chuyển.
3. Plugin vừa ở Plugins vừa ở disabled hiện "Trùng tên", không tự ghi đè, nút gạt bị khóa.
4. "Tắt tất cả"/"Bật tất cả": hộp xác nhận nêu số lượng; thư viện nền (tên khớp `LIBRARY_PATTERN`) được cảnh báo riêng. Khi ô tìm kiếm có chữ chỉ áp cho mục đang hiện.
5. Giao diện dựng DOM bằng `textContent` (an toàn với tên có ký tự HTML).
6. Gỡ plugin bằng Extension Manager sẽ xóa luôn thư mục `data` (các plugin đã tắt nằm trong đó).

### 3.2. Gộp loader và thư mục khác tên (`linker.rb`, beta.10)

1. Lý do: SketchUp tự nạp **mọi** `.rb/.rbe/.rbs` ở gốc Plugins; thư mục con chỉ chạy khi được `require`. Nếu loader và thư mục khác tên (ví dụ `_jhs01_powerbar.rb` và `JHS`, `fixSolid_loader.rb` và `fixSolid.rbe`) mà dời riêng, plugin còn một nửa vẫn chạy hoặc báo lỗi, và có thể sinh "Trùng tên".
2. Đọc các loader `.rb` (tối đa 100 KB mỗi file), lấy chuỗi trong dấu nháy tách theo `/` và `\`, bỏ đuôi, không phân biệt hoa thường.
3. Gộp mục X vào loader L chỉ khi: X không có loader `.rb` đọc được của riêng nó; tên X không chứa "lib"; đúng **một** loader nhắc tới X.
4. Loader mã hóa (`.rbe/.rbs`) không đọc được, chỉ nhóm theo tên. Heuristic có thể sót hoặc gộp nhầm hiếm gặp; chưa thử trên danh sách thật.
5. Dùng chung cho bật/tắt, chuyển plugin và xuất gói.

### 3.3. Chuyển plugin

1. Nguồn/đích chọn bằng hai ô trong tab "Chuyển plugin". Trước khi chép: sao lưu thư mục Plugins đích thành `Plugins_backup_<thời gian>`. Mặc định bỏ qua mục đã tồn tại, có ô "Ghi đè".
2. `scan_compat` quét `.rb` tìm cú pháp Ruby 2.7 dễ lỗi trên 3.2 (Fixnum/Bignum, `File.exists?`, `Dir.exists?`, `URI.escape`, taint/untaint). Chỉ cảnh báo.
3. Bỏ qua chính plugin này (`SELF_NAMES`, gồm tên cũ `vgd_plugin_migrator`) và mục hệ thống (`SKIP_NAMES`).

### 3.4. Xuất gói .rbz tổng

1. Gói chứa file của các plugin đã tick (đường dẫn tương đối từ thư mục Plugins) và `vgd_bundle_manifest.json`. Không kèm phím tắt hay layout.
2. Trên máy mới cài bằng Extension Manager rồi khởi động lại. Chưa xác nhận Extension Manager chấp nhận gói không đăng ký SketchupExtension.

### 3.5. Bộ plugin xuất/nhập

1. File `.json` `{ format: 'vgd_plugin_sets', version: 1, sets: {...} }`. File `version` 2 từ bản beta cũ vẫn đọc được, mục `layouts` bị bỏ qua.
2. Nhập trùng tên thì hỏi ghi đè hay giữ bộ hiện có. Dữ liệu sai kiểu bị lọc.

## 4. Trạng thái kiểm thử

Đã xác minh tự động (Linux, ngoài SketchUp):

1. `ruby -c` đạt cho mọi `.rb`; `node --check` đạt cho JavaScript của `dialog.html`.
2. `tests/test_toggle.rb`, `tests/test_dialog.rb`, `tests/test_linker.rb`, `tests/run_test.rb` đạt (bật/tắt, bộ plugin, hoàn tác khi lỗi, hàng loạt, gộp loader, mở thư mục, xuất gói và kiểm tra zip bằng Python).

**Chưa xác minh (cần Windows có SketchUp thật):**

1. Toàn bộ hộp thoại, `UI.savepanel`, nút mở thư mục (`explorer.exe`) chưa chạy trong SketchUp 2022/2024 thật. Người dùng đã cài và dùng các bản beta, đã thấy hộp thoại hiển thị đúng ở beta.16 (ảnh chụp tab Chuyển plugin).
2. Luật gộp loader trên danh sách plugin thật.
3. Extension Manager có chấp nhận gói tổng không.
4. Tắt plugin có file `.dll/.so` đang bị khóa.

## 5. Cách chạy test

Chạy từ thư mục `plugins/VGD_PluginManager`, tham số là thư mục `src`:

```
ruby tests/test_toggle.rb src
ruby tests/test_dialog.rb src
ruby tests/test_linker.rb src
ruby tests/run_test.rb src
```

1. `tests/stub/sketchup.rb` giả lập tối thiểu `Sketchup.version`, `UI`, `file_loaded?`. Test dùng `APPDATA` giả trong thư mục tạm, không đụng dữ liệu thật.
2. Đóng gói .rbz: zip toàn bộ nội dung `src/` với đường dẫn dùng `/` ở gốc zip (ví dụ bằng `python3` + `zipfile`). Khi đổi phiên bản, sửa cả `VERSION` trong `main.rb` và `ex.version` trong `VGD_PluginManager.rb`.

## 6. Bài học: vì sao gỡ layout và phím tắt (beta.5 đến beta.16)

1. Ý định: giữ layout thanh công cụ và phím tắt theo từng bộ plugin, chuyển giữa các máy. Đã khảo sát: phím tắt nằm trong `SharedPreferences.json`, layout trong registry (2022) và `PrivatePreferences.json` (xem `docs/NOI_LUU_CAI_DAT_SKETCHUP.md`). SketchUp ghi đè các file này khi thoát nên phải ghi lúc SketchUp đã đóng, qua một script PowerShell chạy nền.
2. Kết quả thực tế:
   1. Beta.4 trở về trước dùng khóa registry không tồn tại (suy đoán sai).
   2. Beta.4 đến beta.11: script không bao giờ chạy đúng vì biến `$job` trùng tham số `[string]$Job` (PowerShell không phân biệt hoa thường) làm dữ liệu việc bị ép thành chuỗi. Sửa ở beta.12 nhờ log của người dùng.
   3. Beta.12/13: nhập `.dat` 85 phím tắt rồi mở SketchUp 2024 thì SketchUp **văng khi khởi động 3 lần** đến khi xóa `SharedPreferences.json`. Nguyên nhân chưa rõ: dựng lại phép ghi bằng bản tham chiếu Ruby cho kết quả JSON hợp lệ, không trùng phím; hai nghi vấn chưa kiểm chứng là script PowerShell ghi khác bản tham chiếu, hoặc SketchUp 2024 văng với phím tắt trỏ vào menu plugin chưa nạp (19/85 phím).
3. Beta.14 khóa việc ghi; beta.16 xóa hẳn `layout.rb`, `helper/apply_layout.ps1` và các test liên quan. Mã cũ xem được trong lịch sử git (commit `49d1fd7` và trước đó).
4. Phím tắt: dùng Import/Export của SketchUp (Window > Preferences > Shortcuts). Layout thanh công cụ: tự sắp xếp.
5. Nếu làm lại: ghi ra file thử cạnh bên trước (không đụng file thật), sao lưu, và thử với một file có đúng một phím tắt trước.
6. Bài học PowerShell: không đặt biến cục bộ trùng tên tham số (khác hoa thường vẫn là một biến); script chưa chạy thật phải ghi log từng bước từ dòng đầu.

## 7. Rủi ro đã biết và việc có thể làm tiếp

1. Plugin có bản quyền hoặc mã hóa gắn phiên bản vẫn phải kích hoạt lại ở bản/máy mới.
2. Tắt plugin mà plugin khác phụ thuộc có thể gây lỗi khi mở lại. Có thể thêm cảnh báo phụ thuộc.
3. Chỉ hỗ trợ Windows (`%APPDATA%`, `explorer.exe`). Chuỗi giao diện cứng tiếng Việt.
4. Ý tưởng chưa làm: "Tắt/Bật mục đã chọn", "Giữ mục đã chọn, tắt phần còn lại", Hoàn tác sau Tắt tất cả, nút "Xử lý trùng tên", dùng `SketchupExtension#check/uncheck` bổ sung.

## 8. Lịch sử phiên bản (tóm tắt)

1. `1.0.0` / `beta`: chuyển plugin, xuất gói tổng (tên cũ VGD_Plugin_Migrator).
2. `beta.2`: bật/tắt plugin và bộ plugin.
3. `beta.3`: xuất/nhập bộ plugin ra file, nhật ký lỗi, theme VGD dùng chung, thanh công cụ.
4. `beta.4`: đổi tên thành VGD_PluginManager; dữ liệu đặt trong thư mục Plugins; gộp thành một hộp thoại hai tab.
5. `beta.5`, `beta.8`, `beta.9`: thử lưu/áp layout, nhập phím tắt `.dat`, ghi `PrivatePreferences.json` (tất cả đã gỡ ở beta.16).
6. `beta.6`: chỉ mở một hộp thoại (sửa lỗi mở nhiều bảng); sau đó đổi icon thành một nút gạt duy nhất.
7. `beta.7`: nút Tắt tất cả/Bật tất cả có xác nhận.
8. `beta.10`: gộp loader với thư mục khác tên (`linker.rb`).
9. `beta.11` đến `beta.14`: chẩn đoán và sửa helper PowerShell, bỏ tự mở lại SketchUp, khóa việc ghi sau sự cố SketchUp văng.
10. `beta.15`/`beta.16`: nút Mở thư mục Plugins và Mở thư mục đã tắt; gỡ hẳn layout và phím tắt.
11. `beta.17`: **sửa lỗi beta.16 làm danh sách ở tab Chuyển plugin luôn trống**: lúc gỡ layout đã xóa nhầm callback `mg_list` (nằm xen giữa các callback layout). Đã khôi phục và thêm test hồi quy (`mg_list` trả danh sách; mọi lệnh `sketchup.*`/`send(...)` trong `dialog.html` đều có callback tương ứng). Bài học: sau khi xóa hàng loạt, đối chiếu tập callback trước/sau.
