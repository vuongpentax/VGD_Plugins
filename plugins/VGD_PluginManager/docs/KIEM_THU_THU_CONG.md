# Hướng dẫn kiểm thử thủ công VGD Plugin Manager

Dành cho máy Windows có SketchUp 2022 và 2024. Mọi mục dưới đây **chưa được kiểm chứng** trong SketchUp thật; tick từng mục khi đã làm và ghi kết quả.

Chuẩn bị: cài `VGD_PluginManager_1.0.0-beta.4.rbz` bằng Extension Manager ở cả hai bản, khởi động lại. Nên thử trên máy/tài khoản có dữ liệu có thể mất được, hoặc sao lưu thư mục `%APPDATA%\SketchUp` trước.

## 0. Xác minh khóa registry (làm trước tiên)

Mở Command Prompt, chạy lần lượt (thay 2024 cho đúng bản đang có):

```
reg query "HKCU\Software\SketchUp\SketchUp 2024\Shortcuts"
reg query "HKCU\Software\SketchUp\SketchUp 2024\Toolbars"
reg query "HKCU\Software\SketchUp" /s /f Shortcut
```

1. Nếu hai lệnh đầu in ra dữ liệu: khóa đúng, không cần sửa.
2. Nếu báo "không tìm thấy": dùng lệnh thứ ba hoặc regedit để tìm khóa thật, rồi sửa `REG_SHORTCUTS`, `REG_TOOLBARS` trong `src/VGD_PluginManager/main.rb` và `KEYS` trong `src/VGD_PluginManager/bundle_import.rb`.
3. Chú ý: phím tắt chỉ được ghi vào registry sau khi SketchUp thoát; hãy đóng SketchUp rồi mới chạy lệnh.

## 1. Mở plugin

Gỡ bản beta.3 (nếu có) trước khi cài beta.4.

1. Menu Plugins có một mục "VGD Plugin Manager"; thanh công cụ "VGD Plugin Manager" có một nút, icon rõ ở cỡ nhỏ, có tooltip.
2. Ruby Console không có lỗi đỏ khi khởi động.
3. Hộp thoại có hai tab "Bật/tắt plugin" và "Chuyển plugin", font Manrope, nút ☾/☀ ở góc phải đổi sáng/tối, đóng mở lại vẫn giữ lựa chọn.

## 2. Chuyển plugin (2022 sang 2024), tab "Chuyển plugin"

1. Chọn phiên bản nguồn/đích bằng hai ô chọn (đổi ô thì danh sách plugin đổi theo), danh sách plugin hiện đúng, không có `VGD_PluginManager` hay `vgd_plugin_migrator`.
2. Chuyển 1 plugin thử: có thư mục `Plugins_backup_<thời gian>` cạnh thư mục Plugins đích; plugin xuất hiện ở đích.
3. Chuyển lần hai không tick "Ghi đè": mục đã có được bỏ qua.
4. Plugin dùng cú pháp Ruby cũ (ví dụ `File.exists?`) có hiện cảnh báo tương thích.

## 3. Phím tắt và thanh công cụ

1. Đặt một phím tắt riêng ở bản nguồn, đóng SketchUp, mở lại để chắc đã lưu.
2. Chuyển phím tắt sang bản đích; có file `Documents\SU_shortcuts_<ver>_backup_*.reg` nếu đích đã có dữ liệu.
3. Mở bản đích: phím tắt có xuất hiện không? Thoát bản đích rồi mở lại: có còn không? (kiểm tra rủi ro SketchUp ghi đè khi thoát.)
4. Lặp lại với thanh công cụ.

## 4. Xuất gói .rbz tổng

1. Xuất gói với vài plugin; mở file .rbz bằng phần mềm giải nén, thấy plugin, `vgd_bundle_import.rb`, `vgd_bundle_import/manifest.json`.
2. Trên máy khác (hoặc bản khác), cài gói bằng Extension Manager: có chấp nhận không (gói không đăng ký SketchupExtension)?
3. Khởi động lại, vào "VGD: Nhập phím tắt/giao diện từ gói", xác nhận; kiểm tra phím tắt sau khi thoát và mở lại.

## 5. Bật/tắt plugin và bộ plugin

1. Gạt nút tắt một plugin (không cần bấm thêm gì): nút chuyển sang trạng thái tắt, có thông báo cần khởi động lại; file nằm trong `...\SketchUp\Plugins\VGD_PluginManager\data\disabled\`.
2. Khởi động lại: plugin không nạp, và **không có plugin nào trong `data\disabled` bị SketchUp nạp** (kiểm tra Ruby Console). Gạt bật lại, khởi động lại: plugin nạp bình thường.
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
