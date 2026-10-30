# Hướng dẫn kiểm thử thủ công VGD Plugin Manager

Dành cho máy Windows có SketchUp 2022 và 2024. Mọi mục dưới đây **chưa được kiểm chứng** trong SketchUp thật; tick từng mục khi đã làm và ghi kết quả.

Chuẩn bị: cài `VGD_PluginManager_1.0.0-beta.4.rbz` bằng Extension Manager ở cả hai bản, khởi động lại. Nên thử trên máy/tài khoản có dữ liệu có thể mất được, hoặc sao lưu thư mục `%APPDATA%\SketchUp` trước.

## 0. Nơi SketchUp lưu dữ liệu (đã khảo sát)

Khóa registry `...\Shortcuts` và `...\Toolbars` mà các bản trước dùng **không tồn tại**. Phím tắt nằm trong `SharedPreferences.json`, layout nằm trong registry `Workspace`/`RubyWorkspace` (2022) và `PrivatePreferences.json` (2022 và 2024). Chi tiết và phần còn chưa xác nhận: `docs/NOI_LUU_CAI_DAT_SKETCHUP.md`.

## 1. Mở plugin

Gỡ bản beta.3 (nếu có) trước khi cài beta.4.

1. Menu Plugins có một mục "VGD Plugin Manager"; thanh công cụ "VGD Plugin Manager" có một nút, icon rõ ở cỡ nhỏ, có tooltip.
2. Ruby Console không có lỗi đỏ khi khởi động.
3. Bấm nút thanh công cụ hoặc menu nhiều lần: chỉ có **một** hộp thoại, lần bấm sau đưa cửa sổ đang mở lên trước; đóng hộp thoại rồi bấm lại thì mở mới. Menu Plugins chỉ có một mục "VGD Plugin Manager" (nếu thấy thêm mục "VGD Plugin Migrator" hoặc "VGD: Nhập phím tắt..." là còn bản cũ chưa gỡ).
4. Hộp thoại có hai tab "Bật/tắt plugin" và "Chuyển plugin", font Manrope, nút ☾/☀ ở góc phải đổi sáng/tối, đóng mở lại vẫn giữ lựa chọn.

## 2. Chuyển plugin (2022 sang 2024), tab "Chuyển plugin"

1. Chọn phiên bản nguồn/đích bằng hai ô chọn (đổi ô thì danh sách plugin đổi theo), danh sách plugin hiện đúng, không có `VGD_PluginManager` hay `vgd_plugin_migrator`.
2. Chuyển 1 plugin thử: có thư mục `Plugins_backup_<thời gian>` cạnh thư mục Plugins đích; plugin xuất hiện ở đích.
3. Chuyển lần hai không tick "Ghi đè": mục đã có được bỏ qua.
4. Plugin dùng cú pháp Ruby cũ (ví dụ `File.exists?`) có hiện cảnh báo tương thích.

## 3. Layout và phím tắt theo bộ plugin (mới ở beta.5)

Nên sao lưu trước: đóng SketchUp, chạy `reg export "HKCU\Software\SketchUp" "%USERPROFILE%\Desktop\SketchUp_registry_backup.reg" /y` và chép hai file `PrivatePreferences.json` (trong `%LOCALAPPDATA%\SketchUp\SketchUp <năm>\SketchUp`) và `SharedPreferences.json` (trong `%APPDATA%\SketchUp\SketchUp <năm>\SketchUp`). Plugin cũng tự sao lưu vào `...\Plugins\VGD_PluginManager\data\backups\` trước khi ghi.

1. Tạo một bộ plugin (tab Bật/tắt), chỉnh vị trí vài thanh công cụ, gán thử một phím tắt.
2. Bấm "Lưu layout" của bộ, xác nhận. Đóng SketchUp bằng File > Exit. Chờ vài giây: SketchUp tự mở lại. Mở hộp thoại: có thông báo kết quả và bộ hiện nhãn "Đã lưu layout + phím tắt (SketchUp <năm>)". Nếu không mở lại, xem `%APPDATA%\SketchUp\VGD_PluginManager\migrator.log`.
3. Tắt một plugin bằng nút gạt, kéo vài thanh công cụ sang chỗ khác, thoát và mở lại: ghi nhận layout lộn xộn (nếu có) để so sánh.
4. Bấm "Áp layout" của bộ, xác nhận, đóng SketchUp bằng File > Exit. SketchUp mở lại: **thanh công cụ có về đúng vị trí đã lưu không? Phím tắt có về đúng không?** Đây là điểm kiểm tra chính.
5. Kiểm tra các điểm rủi ro: (a) toàn bộ plugin và thiết lập khác (kích thước cửa sổ plugin, tùy chọn) còn nguyên; (b) khi tắt một plugin rồi áp layout, thanh công cụ của các plugin còn lại có đúng chỗ không (ID thanh công cụ có bị lệch không); (c) không có file `.vgdtmp` nào còn sót cạnh hai file JSON.
6. Thử hủy: bấm "Lưu layout" rồi bấm "Áp layout" khác bộ trước khi đóng SketchUp: chỉ job sau cùng được thực hiện.
7. Chuyển phím tắt giữa hai bản: tab Chuyển plugin, tick "Chuyển cả phím tắt", chuyển 2022 sang 2024 (hoặc ngược lại); đóng cả hai bản; mở bản đích: phím tắt đã thay chưa?
8. Hoàn tác thử: chép lại hai file JSON và import file `.reg` từ thư mục sao lưu khi SketchUp đóng, xác nhận layout cũ trở lại.
9. Xuất/nhập sang máy khác: "Xuất các bộ ra file" (file `.json` có kèm layout), nhập ở máy kia bằng "Nhập bộ từ file", rồi "Áp layout". Ghi lại nếu màn hình khác độ phân giải làm thanh công cụ lệch.

## 3b. Nhập phím tắt từ file .dat (mới ở beta.8)

Sao lưu trước như mục 3. Chuẩn bị: xuất một file `.dat` từ Window > Preferences > Shortcuts > Export (ở máy khác hoặc bản khác).

1. Tab Chuyển plugin, mục Phím tắt, bấm "Nhập phím tắt từ file .dat", chọn file. Hộp xác nhận nêu đúng số phím tắt; chọn Không thì không có gì xảy ra.
2. Chọn Có, đóng SketchUp bằng File > Exit. SketchUp tự mở lại. Vào Window > Preferences > Shortcuts: **danh sách phím tắt đúng bằng file** (kể cả phím của plugin và tên có tiếng Việt)? Mở hộp thoại: có thông báo kết quả.
3. Thư mục `...\Plugins\VGD_PluginManager\data\backups\` có bản sao lưu `SharedPreferences.json` trước khi ghi.
4. Kiểm tra file `SharedPreferences.json` sau khi ghi: các giá trị dạng `24.0`, `150.0`, `1.0` (ví dụ `AviExportFPS`, `PixelsPerInch`) **vẫn giữ dạng `.0`**, không thành `24`, `150`; không có file `.vgdtmp` sót lại.
5. Thư mục thư viện (Models, Components, Materials...) trong Preferences > Files **không bị đổi** (mục `[File Locations]` của file `.dat` phải được bỏ qua).
6. Thử với file không phải `.dat` phím tắt: có báo lỗi, không đổi gì.
7. Layout 2024 hiện chưa áp được (xem HANDOFF, bản beta.8): bấm "Áp layout" cho bộ lưu từ 2024 phải báo "chưa được hỗ trợ"; chỉ phím tắt được áp.

## 4. Xuất gói .rbz tổng

1. Xuất gói với vài plugin; mở file .rbz bằng phần mềm giải nén, thấy plugin và `vgd_bundle_manifest.json` (gói chỉ chứa plugin, không kèm phím tắt hay layout).
2. Trên máy khác (hoặc bản khác), cài gói bằng Extension Manager: có chấp nhận không (gói không đăng ký SketchupExtension)?

## 5. Bật/tắt plugin và bộ plugin

1. Gạt nút tắt một plugin (không cần bấm thêm gì): nút chuyển sang trạng thái tắt, có thông báo cần khởi động lại; file nằm trong `...\SketchUp\Plugins\VGD_PluginManager\data\disabled\`.
2. Khởi động lại: plugin không nạp, và **không có plugin nào trong `data\disabled` bị SketchUp nạp** (kiểm tra Ruby Console). Gạt bật lại, khởi động lại: plugin nạp bình thường.
3a. Nút "Tắt tất cả (N)": hộp xác nhận nêu đúng số lượng và, nếu có, cảnh báo thư viện nền; chọn Không thì không đổi gì; chọn Có thì mọi plugin đang bật chuyển sang tắt (nút gạt đều tắt). Khởi động lại: các plugin đó không nạp. "Bật tất cả" đưa về như cũ.
3b. Gõ chữ vào ô tìm kiếm (ví dụ `curic`): nhãn nút đổi thành "Tắt tất cả đang hiện (N)" và chỉ tắt nhóm đó.
3. Danh sách không hiện `VGD_PluginManager`, `vgd_plugin_migrator` hay thư mục `data`.
4. Nếu còn dữ liệu bật/tắt cũ ở `...\SketchUp\VGD_PluginManager` (beta.3), mở hộp thoại: dữ liệu được chuyển vào vị trí mới và có thông báo.
5. Lưu một bộ (tick ô vuông bên trái các plugin rồi bấm lưu), tắt bộ, bật bộ, xóa bộ.
6. Thử tắt plugin có file `.dll/.so` đang nạp: nếu báo lỗi, các mục đã chuyển có được hoàn tác không?
7. Tên plugin có ký tự đặc biệt (`<`, `&`) hiển thị đúng.
8. Gỡ plugin bằng Extension Manager sẽ xóa luôn thư mục `data` (các plugin đã tắt): xác nhận hành vi này trên máy thử.

## 6. Xuất/nhập bộ plugin ra file (mới ở beta.3)

1. Lưu ít nhất 2 bộ, bấm "Xuất các bộ ra file", chọn nơi lưu: file `.json` được tạo.
2. Xóa một bộ, bấm "Nhập bộ từ file": bộ đã xóa quay lại.
3. Nhập lại lần nữa khi bộ trùng tên: hộp thoại hỏi Yes (ghi đè) / No (giữ bộ hiện có) và kết quả đúng.
4. Chọn một file `.json` bất kỳ không phải file bộ plugin: có báo "không đúng định dạng", không crash.

## 7. Nhật ký lỗi (mới ở beta.3)

Nhật ký ghi tại `%APPDATA%\SketchUp\VGD_PluginManager\migrator.log` (quá 512 KB thì đổi tên thành `.log.1`).

1. Gây một lỗi có chủ đích (ví dụ nhập file bộ plugin hỏng): hộp thoại hiện đường dẫn log, file log có dòng giờ, mô tả và loại lỗi.
2. Đường dẫn trong thông báo mở được bằng Explorer.

## Ghi kết quả

Với mỗi mục, ghi: Đạt / Không đạt / Chưa thử, phiên bản SketchUp, và nội dung log nếu có lỗi. Gửi lại để sửa tiếp.
