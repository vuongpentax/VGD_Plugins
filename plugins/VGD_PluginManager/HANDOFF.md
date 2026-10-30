# HANDOFF: VGD Plugin Manager (SketchUp, Ruby)

Phiên bản hiện tại: **1.0.0-beta.10** (xem mục 8 cho phần thêm so với beta.2). Ngày bàn giao: 2026-10-30.
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
   1. `src/VGD_PluginManager.rb`: file loader, đăng ký SketchupExtension (version `1.0.0-beta.10`).
   2. `src/VGD_PluginManager/main.rb`: chuyển plugin, phím tắt, thanh công cụ; xuất gói tổng; giao diện HtmlDialog chính.
   3. `src/VGD_PluginManager/zip_writer.rb`: ghi file zip/.rbz thuần Ruby bằng Zlib (không cần thư viện ngoài).
   4. (đã bỏ ở beta.5) `bundle_import.rb`: mẫu nhập phím tắt/thanh công cụ từ gói tổng, dùng khóa registry sai.
   4b. `src/VGD_PluginManager/layout.rb`: lưu/áp layout và phím tắt theo từng bộ plugin (lập job, snapshot, xuất/nhập), và `src/VGD_PluginManager/helper/apply_layout.ps1`: script PowerShell chạy nền, chờ SketchUp đóng rồi chụp/áp layout và phím tắt (sao lưu trước, hoàn tác nếu lỗi, mở lại SketchUp). Chi tiết nơi SketchUp lưu dữ liệu: `docs/NOI_LUU_CAI_DAT_SKETCHUP.md`.
   5. `src/VGD_PluginManager/toggle.rb`: bật/tắt plugin và bộ plugin (module `Toggle`), xuất/nhập bộ ra file `.json`, chuyển dữ liệu từ vị trí cũ.
   7. `src/VGD_PluginManager/dialog.rb`: một hộp thoại hai tab (Bật/tắt plugin, Chuyển plugin); mọi callback và kiểm tra phiên bản nguồn/đích (`check_versions`).
   8. `src/VGD_PluginManager/ui/`: `dialog.html`, `dialog.css` và bản sao `vgd-theme/` (đồng bộ bằng `python tools/sync_vgd_theme.py`). Nạp bằng `set_file`; dữ liệu đẩy vào qua callback `ready`.
   9. `src/VGD_PluginManager/icons/plugin_manager.svg`: icon duy nhất cho thanh công cụ và menu (24x24, nét 1.8, nâu đồng `#A67C58` + than `#292B2D`).
   6. `src/VGD_PluginManager/logger.rb`: ghi nhật ký lỗi vào `%APPDATA%\SketchUp\VGD_PluginManager\migrator.log`.
3. `tests/`: bộ test chạy ngoài SketchUp bằng stub (xem mục 6).
4. `docs/KIEM_THU_THU_CONG.md`: hướng dẫn kiểm thử thủ công trong SketchUp thật.
5. File `.rbz` đóng gói không lưu trong repo (`.gitignore` loại `*.rbz`); tạo bằng mục 7.

## 3. Tính năng và hành vi đã chốt

### 3.1. Chuyển plugin (menu Plugins > VGD Plugin Manager)

1. Quét phiên bản có trong `%APPDATA%\SketchUp\SketchUp <năm>`, cho chọn nguồn và đích bằng `UI.inputbox`.
2. Plugin = file `.rb/.rbe/.rbs` ở gốc `...\SketchUp\Plugins` cộng thư mục cùng tên (nhóm theo tên bỏ đuôi).
3. Bỏ qua: chính plugin này (`SELF_NAMES`) và một số mục hệ thống (`SKIP_NAMES`).
4. Trước khi chép: sao lưu cả thư mục Plugins đích thành `Plugins_backup_<thời gian>`.
5. Có tùy chọn ghi đè; mặc định bỏ qua mục đã tồn tại.
6. `scan_compat`: quét `.rb` tìm cú pháp Ruby 2.7 dễ lỗi trên 3.2 (Fixnum/Bignum, File.exists?, Dir.exists?, URI.escape, taint/untaint). Chỉ cảnh báo, không sửa code.

### 3.2. Phím tắt và thanh công cụ (registry Windows)

> **Đã lỗi thời (beta.5):** các khóa registry mô tả dưới đây là giả định sai. Xem `docs/NOI_LUU_CAI_DAT_SKETCHUP.md` và mục 8, bản beta.5.

1. Dùng lệnh `reg query/export/import` trên khóa:
   1. `HKCU\Software\SketchUp\SketchUp <ver>\Shortcuts`
   2. `HKCU\Software\SketchUp\SketchUp <ver>\Toolbars`
2. Chuyển bằng cách export khóa nguồn, thay chuỗi `SketchUp <nguồn>` thành `SketchUp <đích>`, import lại. Có sao lưu khóa đích ra `Documents\SU_<loại>_<ver>_backup_<thời gian>.reg`.
3. Nếu không tìm thấy khóa thì báo "Không tìm thấy dữ liệu" và không ghi gì.

### 3.3. Xuất gói .rbz tổng

1. Nút "Xuất gói .rbz tổng" trong hộp thoại chính, chọn nơi lưu bằng `UI.savepanel`.
2. Gói chứa: file của các plugin đã tick (đường dẫn tương đối từ thư mục Plugins) và `vgd_bundle_manifest.json`. Từ beta.5 gói **không** kèm phím tắt/thanh công cụ (xem mục 8, bản beta.5).
3. Trên máy mới: cài .rbz bằng Extension Manager rồi khởi động lại SketchUp. (Menu nhập phím tắt từ gói đã bỏ ở beta.5.)
4. Zip viết thuần Ruby (deflate, tên file UTF-8, dùng `/`), đã kiểm chứng bằng Python `zipfile` và `unzip -t`.
5. Người dùng đã đồng ý cách này: file .rbz không tự áp dụng được registry nên cần bước nhập riêng.

### 3.4. Quản lý bật/tắt plugin (menu Plugins > VGD: Quản lý bật/tắt plugin)

Các lựa chọn người dùng đã chốt:

1. Cách tắt: **chuyển file sang thư mục "đã tắt"** (không dùng tắt/bật của Extension Manager).
2. Hiệu lực: **sau khi khởi động lại SketchUp** (không cố nạp/gỡ ngay).
3. Quản lý: **cả hai** kiểu, tức bật/tắt từng plugin và "bộ plugin" lưu sẵn (Tắt bộ / Bật bộ / Xóa bộ).

Chi tiết cài đặt:

1. Thư mục gốc: `%APPDATA%\SketchUp\SketchUp <năm hiện tại>\SketchUp\Plugins\VGD_PluginManager\data\` (từ beta.4, nằm trong thư mục Plugins; trước đó nằm ngoài Plugins và được tự chuyển vào một lần) (nằm ngoài `Plugins`).
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
3. Chưa thử cài gói tổng bằng Extension Manager trên máy khác (gói chỉ có file plugin, không đăng ký SketchupExtension; cần xác nhận Extension Manager chấp nhận).
4. Chưa thử tắt plugin đang có file bị khóa (dll/so đang nạp).

## 5. Rủi ro đã biết và việc nên làm tiếp

1. **Khóa registry đã khảo sát** (2026-10-30): xem `docs/NOI_LUU_CAI_DAT_SKETCHUP.md`. Khóa `Shortcuts`/`Toolbars` giả định ban đầu không tồn tại; code liên quan đã thay ở beta.5.
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
ruby tests/test_toggle.rb src
ruby tests/test_layout.rb src
ruby tests/test_dialog.rb src
ruby tests/test_splice.rb
ruby tests/test_private_splice.rb
ruby tests/test_linker.rb src
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
z=zipfile.ZipFile('../dist/VGD_PluginManager_1.0.0-beta.4.rbz','w',zipfile.ZIP_DEFLATED)
for n in ['VGD_PluginManager.rb','VGD_PluginManager/main.rb','VGD_PluginManager/zip_writer.rb','VGD_PluginManager/toggle.rb','VGD_PluginManager/logger.rb','VGD_PluginManager/dialog.rb','VGD_PluginManager/ui/dialog.html','VGD_PluginManager/ui/dialog.css','VGD_PluginManager/icons/plugin_manager.svg','VGD_PluginManager/layout.rb','VGD_PluginManager/linker.rb','VGD_PluginManager/helper/apply_layout.ps1']:
    z.write(n,n)
z.close()
"
```

Khi thêm file mới vào `src/VGD_PluginManager/` nhớ thêm vào danh sách trên. Khi đổi phiên bản, sửa cả `VERSION` trong `main.rb` và `ex.version` trong `VGD_PluginManager.rb`.

## 8. Ghi chú về các phiên bản

1. `1.0.0`: chuyển plugin, phím tắt, thanh công cụ.
2. `1.0.0-beta`: thêm xuất gói .rbz tổng.
3. `1.0.0-beta.2`: thêm quản lý bật/tắt plugin và bộ plugin.
4. `1.0.0-beta.3`: thêm xuất/nhập bộ plugin ra file `.json` (có hỏi ghi đè khi trùng tên, lọc dữ liệu sai kiểu), ghi nhật ký lỗi ra file, hướng dẫn test thủ công. Đã kiểm tra tự động ngoài SketchUp; **chưa kiểm tra trong SketchUp thật** (hộp thoại mở/lưu file `UI.openpanel`/`UI.savepanel`, `UI.messagebox` hỏi ghi đè).
   Giao diện: hai hộp thoại đổi sang theme VGD dùng chung (sáng/tối, nút đổi theme, font Manrope), giữ nguyên bố cục và hành vi. Thêm thanh công cụ 2 nút (mỗi nút cũng có trong menu Plugins). Danh sách plugin ở hộp thoại chuyển plugin giờ do JavaScript dựng (bằng `textContent`) thay vì Ruby. Plugin không có API đặt icon cho Extension Manager nên chưa làm icon đó. **Chưa kiểm tra trong SketchUp thật**: `set_file` với font/CSS tương đối, icon SVG trên thanh công cụ, nút đổi theme. Đã chụp ảnh thử bằng trình duyệt ở cả hai theme.
5. `1.0.0-beta.4`: đổi tên plugin thành **VGD_PluginManager** (loader `VGD_PluginManager.rb`, module `VGD::PluginManager`, module bật/tắt đổi tên thành `Toggle`); gộp hai tính năng vào **một hộp thoại hai tab** (bỏ `UI.inputbox`, chọn phiên bản bằng ô chọn trong tab Chuyển plugin); bật/tắt bằng **nút gạt** (gạt là chuyển file ngay, có hiệu lực sau khi khởi động lại; bỏ hai nút "Tắt/Bật mục đã chọn", ô tick chỉ còn để lưu bộ); một nút thanh công cụ và một mục menu; dữ liệu plugin đã tắt và `sets.json` chuyển vào `Plugins\VGD_PluginManager\data`.
   1. **Cập nhật từ beta.3:** gỡ bản cũ (file `vgd_plugin_migrator.rb` và thư mục `vgd_plugin_migrator` trong Plugins) trước khi cài, nếu không hai bản cùng nạp và có hai thanh công cụ. Bản mới bỏ qua cả hai tên khi quét plugin.
   2. **Rủi ro:** thư mục `data` nằm trong thư mục plugin nên **gỡ plugin bằng Extension Manager sẽ xóa luôn các plugin đã tắt**. Bật lại các plugin cần giữ trước khi gỡ. Chưa xác nhận SketchUp có nạp `.rb` nằm sâu trong `Plugins\VGD_PluginManager\data\disabled\` hay không (dự đoán là không, cần thử trên SketchUp thật).
6. `1.0.0-beta.5`: **layout và phím tắt theo bộ plugin**, áp dụng khi SketchUp đóng.
   1. Mỗi bộ có nút "Lưu layout" và "Áp layout"; ô "Kèm phím tắt". Bấm xong, plugin lập job và chạy script PowerShell ẩn; **người dùng phải đóng SketchUp bình thường (File > Exit)**, script chờ SketchUp thoát rồi chụp/áp dữ liệu và mở lại SketchUp. Kết quả hiện ở lần mở hộp thoại kế tiếp.
   2. Dữ liệu đụng tới: `HKCU\Software\SketchUp\SketchUp <năm>\Workspace` và `RubyWorkspace` (chỉ 2022), `PrivatePreferences.json` mục "This Computer Only" (các khóa layout), `SharedPreferences.json` mục "/Windows Only/Settings" (`Num_Shortcuts`, `Shortcut_N`). Chỉ các khóa này được đọc/ghi; sao lưu vào `Plugins\VGD_PluginManager\data\backups\<năm>-<thời gian>`.
   3. Layout chỉ áp cho **cùng phiên bản SketchUp** đã lưu (2022 dùng registry và JSON, 2024 chỉ JSON, định dạng khác nhau). Phím tắt dùng chung được giữa hai bản.
   4. Tab "Chuyển plugin": mục "Chuyển cả phím tắt" nay chạy theo cách này (mặc định tắt). **Đã bỏ** "Giao diện thanh công cụ" và phần phím tắt/thanh công cụ trong gói .rbz tổng cùng `bundle_import.rb`, vì code cũ dùng khóa registry không tồn tại. Muốn mang layout/phím tắt sang máy khác: "Xuất các bộ ra file" (file `.json` version 2 có kèm layout) và "Nhập bộ từ file".
   5. **Chưa kiểm tra trong SketchUp thật.** Script PowerShell không chạy thử được ngoài Windows; chỉ đã kiểm tra phần Ruby tự động (`tests/test_layout.rb`). Rủi ro còn lại: ID thanh công cụ Ruby có thể phụ thuộc thứ tự nạp plugin (chưa kiểm chứng); `SharedPreferences.json` có khóa `timestamp` chưa rõ tác dụng; JavaScriptSerializer có thể đổi số thực `1.0` thành `1` khi ghi lại file JSON.
7. `1.0.0-beta.6`: sửa lỗi bấm nút/menu nhiều lần mở nhiều hộp thoại. Nay chỉ có một hộp thoại (`dialog_open?`, `bring_to_front`); bấm lại thì đưa cửa sổ đang mở lên trước, đóng rồi bấm thì mở mới. Test: `tests/test_dialog.rb`. Nếu vẫn thấy nhiều hộp thoại, kiểm tra xem còn cài bản cũ (`vgd_plugin_migrator`) song song không. Thư mục/file `vgd_bundle_import` trong Plugins là phần còn sót của gói tổng cũ (beta.2 trở về trước), có thể xóa.
8. `1.0.0-beta.7`: nút **Tắt tất cả** và **Bật tất cả** ở tab Bật/tắt. Áp cho các mục đang hiện (ô tìm kiếm có chữ thì chỉ áp cho mục khớp); nhãn nút hiện số mục sẽ đổi. Luôn hỏi xác nhận; khi tắt, cảnh báo nếu có tên chứa "lib" (nghi là thư viện nền như TT_Lib2, Fredo6_!LibFredo6, 5d_library) nhưng không tự loại trừ. Plugin VGD_ cũng bị tắt như mọi plugin. Ruby kiểm tra lại danh sách tên JS gửi lên (`Toggle.bulk_targets`), dùng lại `Toggle.change` (hoàn tác từng mục nếu lỗi). Chưa có nút hoàn tác riêng: muốn khôi phục đúng trạng thái trước khi tắt tất cả, hãy lưu các mục đang bật thành một bộ trước (rồi dùng "Bật bộ").
9. `1.0.0-beta.8`: **sửa rủi ro ghi lại file cài đặt** và **nhập phím tắt từ file `.dat`**.
   1. Helper không còn đọc-ghi lại cả `SharedPreferences.json` bằng `JavaScriptSerializer` (làm `24.0` thành `24`). Phím tắt nay được thay bằng cách **chỉnh đúng các dòng `Num_Shortcuts`/`Shortcut_N`** trong khối `Windows Only > Settings`, mọi byte khác giữ nguyên (`Set-ShortcutLines` trong `helper/apply_layout.ps1`, bản tham chiếu Ruby và test: `tests/support/splice_reference.rb`, `tests/test_splice.rb`). Thuật toán đã kiểm chứng trên hai file `SharedPreferences.json` thật (2022, 2024) và file `.dat` thật: phần còn lại của file giống hệt từng dòng, chín số thực `X.0` giữ nguyên, tiếng Việt giữ đúng. Sau khi ghi còn kiểm tra đọc lại JSON và số phím tắt trước khi thay file. **Bản PowerShell chưa chạy thử được** (không có PowerShell ngoài Windows).
   2. **Layout nằm trong `PrivatePreferences.json` tạm không được ghi** (cờ `$allowPrivatePrefsWrite = $false` trong helper; phía Ruby `Layout.registry_layout?`). Vẫn *lưu* (đọc) được. Hệ quả: "Áp layout" chỉ áp được layout qua registry (SketchUp 2022); bộ lưu từ 2024 chỉ áp được phím tắt. Cần cách chỉnh theo dòng cho file này (cần biết cấu trúc thật, chưa có mẫu).
   3. Tab "Chuyển plugin" có mục "Phím tắt" với nút **Nhập phím tắt từ file .dat**: đọc mục `[Accelerator]` của file xuất từ Window > Preferences > Shortcuts > Export (UTF-16, bỏ qua `[File Locations]`), xác nhận, rồi **thay toàn bộ** phím tắt khi SketchUp đóng. Đọc file: `Layout.parse_dat`; lập việc: `Layout.schedule_import`.
10. `1.0.0-beta.9`: **ghi lại `PrivatePreferences.json` theo dòng** (bật lại việc áp layout 2024; thay mục 9.2).
   1. Snapshot đổi sang **format 2**: mỗi khối layout được lưu **nguyên văn** (các dòng của file) trong `blocks` (khóa là văn bản thô, hai dấu gạch chéo), và `main_window` lưu dòng `"DockWidgetState": "..."`, `"ToolBarState": "..."`. Snapshot cũ có `prefs` (beta.5 đến beta.8) không còn được nhận (chưa từng được kiểm chứng).
   2. Helper (`Get-PrivateLayout`, `Set-PrivateLayout`, `Save-PrivateChecked`) chỉ thay các khối layout trong `"This Computer Only"` và hai khóa của `MainWindow`; mọi byte khác giữ nguyên (số `X.0`, tiếng Việt, thụt lề). Trước khi thay file kiểm tra: JSON đọc lại được, số khóa cấp cao nhất không đổi, **mọi mục ngoài layout giống hệt trước (so sánh từng mục)**, đủ mục layout mới, `MainWindow` có giá trị mới. Bản tham chiếu Ruby và 36 test: `tests/support/splice_reference.rb` (`PrivateSplice`), `tests/test_private_splice.rb`, dựng theo cấu trúc thật. Bộ kiểm tra khối ở phía Ruby (`Layout.valid_block?`, `clean_blocks`, `clean_main_window`) chặn file nhập cố chèn mục hay khóa ngoài layout.
   3. **Bản PowerShell vẫn chưa chạy thử được** (không có PowerShell ngoài Windows). Mục layout không phẳng (có đối tượng lồng) bị bỏ qua khi chụp và được báo số lượng.
11. `1.0.0-beta.10`: **gộp loader với thư mục/file đi kèm khác tên** (`linker.rb`).
   1. Trước đây nhóm plugin chỉ theo tên bỏ đuôi, nên loader và thư mục khác tên (ví dụ `_jhs01_powerbar.rb` và `JHS`, `fixSolid_loader.rb` và `fixSolid.rbe`) thành hai mục riêng; tắt một mục để lại nửa còn lại (SketchUp tự nạp mọi `.rb/.rbe/.rbs` ở gốc Plugins nên nửa còn lại vẫn chạy, hoặc loader báo lỗi thiếu file), gây hiện tượng "tắt rồi vẫn chạy" và có thể dẫn tới "Trùng tên".
   2. Nay đọc nội dung các loader `.rb` (tối đa 100 KB mỗi file) và gộp mục được nhắc tên (trong chuỗi trích dẫn, tách theo `/` và `\`, không phân biệt hoa thường). Chỉ gộp khi mục đích **không có loader `.rb` đọc được của riêng nó**, **tên không chứa "lib"** (thư viện nền luôn đứng riêng) và **đúng một loader nhắc tới** (thư viện dùng chung luôn đứng riêng). Loader mã hóa (`.rbe`, `.rbs`) không đọc được nên chỉ nhóm theo tên. Dùng chung cho bật/tắt, Tắt tất cả, Chuyển plugin và xuất gói `.rbz`.
   3. Giao diện ghi "gồm cả: ..." dưới tên plugin gộp (rê chuột xem đủ danh sách); nhãn "Trùng tên" có lời giải thích khi rê chuột.
   4. Giới hạn: heuristic dựa trên chuỗi trong loader, có thể sót (loader dựng đường dẫn bằng biến) hoặc gộp nhầm hiếm gặp. Chưa thử trên danh sách plugin thật của người dùng. Trạng thái dở dang từ bản cũ (chỉ loader nằm trong thư mục cất, thư mục còn ở Plugins) vẫn hiện là hai mục riêng để người dùng tự xử lý.
12. `1.0.0-beta.11`: **nhật ký chẩn đoán cho helper** (chưa sửa lỗi gốc).
   1. Người dùng báo: lưu layout không chạy, nhập 85 phím tắt (báo thành công) nhưng mở lại SketchUp vẫn không có phím tắt. Cả hai đều đi qua helper PowerShell (`helper/apply_layout.ps1`) chưa từng chạy thật; nếu nó chết sớm thì không để lại dấu vết (stderr bỏ vào NULL).
   2. Nay helper ghi log ngay từ dòng đầu (kể cả khi không đọc được job: ghi vào `%APPDATA%\SketchUp\VGD_PluginManager\migrator.log`), ghi từng mốc: bắt đầu, đã đọc job, đang chờ SketchUp đóng, bắt đầu thực hiện, từng kết quả, đã mở lại SketchUp, kết thúc. Phía Ruby ghi dòng "Đã chạy helper nền (pid ...)" cùng dòng lệnh đầy đủ.
   3. Cách đọc log: không có dòng "helper: bat dau" = PowerShell không chạy (spawn/chính sách). Có "bat dau" nhưng dừng ở "dang cho SketchUp dong" = chưa đóng hết SketchUp (hoặc `Test-Running` nhận nhầm). Có "bat dau thuc hien" rồi "LOI buoc ..." = lỗi trong thuật toán ghi.
