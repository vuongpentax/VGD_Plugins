# Hướng dẫn kiểm thử thủ công VGD Plugin Manager

Dành cho máy Windows có SketchUp 2022 và 2024. Mọi mục dưới đây **chưa được kiểm chứng** trong SketchUp thật; tick từng mục khi đã làm và ghi kết quả.

Chuẩn bị: cài `VGD_PluginManager_1.0.0-beta.16.rbz` (hoặc bản mới nhất) bằng Extension Manager ở cả hai bản, khởi động lại. Nên thử trên máy/tài khoản có dữ liệu có thể mất được, hoặc sao lưu thư mục `%APPDATA%\SketchUp` trước.

## 1. Mở plugin

Gỡ bản cũ (file `vgd_plugin_migrator.rb` và thư mục `vgd_plugin_migrator` trong Plugins, nếu có) trước khi cài.

1. Menu Plugins có một mục "VGD Plugin Manager"; thanh công cụ "VGD Plugin Manager" có một nút, icon rõ ở cỡ nhỏ, có tooltip.
2. Ruby Console không có lỗi đỏ khi khởi động.
3. Bấm nút thanh công cụ hoặc menu nhiều lần: chỉ có **một** hộp thoại, lần bấm sau đưa cửa sổ đang mở lên trước; đóng hộp thoại rồi bấm lại thì mở mới. Menu Plugins chỉ có một mục "VGD Plugin Manager" (nếu thấy thêm mục "VGD Plugin Migrator" hoặc "VGD: Nhập phím tắt..." là còn bản cũ chưa gỡ).
4. Hộp thoại có hai tab "Bật/tắt plugin" và "Chuyển plugin", font Manrope, nút ☾/☀ ở góc phải đổi sáng/tối, đóng mở lại vẫn giữ lựa chọn.

## 2. Chuyển plugin (2022 sang 2024), tab "Chuyển plugin"

1. Chọn phiên bản nguồn/đích bằng hai ô chọn (đổi ô thì danh sách plugin đổi theo), danh sách plugin hiện đúng, không có `VGD_PluginManager` hay `vgd_plugin_migrator`.
2. Chuyển 1 plugin thử: có thư mục `Plugins_backup_<thời gian>` cạnh thư mục Plugins đích; plugin xuất hiện ở đích.
3. Chuyển lần hai không tick "Ghi đè": mục đã có được bỏ qua.
4. Plugin dùng cú pháp Ruby cũ (ví dụ `File.exists?`) có hiện cảnh báo tương thích.

## 3. Xuất gói .rbz tổng

1. Xuất gói với vài plugin; mở file .rbz bằng phần mềm giải nén, thấy plugin và `vgd_bundle_manifest.json` (gói chỉ chứa plugin, không kèm phím tắt hay layout).
2. Trên máy khác (hoặc bản khác), cài gói bằng Extension Manager: có chấp nhận không (gói không đăng ký SketchupExtension)?

## 4. Bật/tắt plugin và bộ plugin

1. Nút "Mở thư mục Plugins" mở Explorer đúng thư mục Plugins của bản SketchUp đang chạy; nút "Mở thư mục đã tắt" mở `Plugins\VGD_PluginManager\data\disabled` (tạo nếu chưa có).

1. Gạt nút tắt một plugin (không cần bấm thêm gì): nút chuyển sang trạng thái tắt, có thông báo cần khởi động lại; file nằm trong `...\SketchUp\Plugins\VGD_PluginManager\data\disabled\`.
2. Khởi động lại: plugin không nạp, và **không có plugin nào trong `data\disabled` bị SketchUp nạp** (kiểm tra Ruby Console). Gạt bật lại, khởi động lại: plugin nạp bình thường.
3a. Nút "Tắt tất cả (N)": hộp xác nhận nêu đúng số lượng và, nếu có, cảnh báo thư viện nền; chọn Không thì không đổi gì; chọn Có thì mọi plugin đang bật chuyển sang tắt (nút gạt đều tắt). Khởi động lại: các plugin đó không nạp. "Bật tất cả" đưa về như cũ.
3c. **Gộp loader và thư mục khác tên (mới ở beta.10):** các plugin có loader khác tên thư mục (ví dụ `_jhs01_powerbar` với `JHS`, `fixSolid_loader` với `fixSolid`, `evrp_icons` với `Edge Visibility Restore PRO`) giờ hiện thành **một mục** với dòng "gồm cả: ...". Gạt tắt một mục: trong `Plugins` không còn file hay thư mục nào của plugin đó (kể cả thư mục đi kèm); khởi động lại, plugin thật sự không chạy. Gạt bật lại thì trả đủ cả hai. Với "Tắt tất cả": thư mục `Plugins` không còn sót nửa nào (chỉ còn `VGD_PluginManager` và các mục hệ thống). Ghi lại plugin nào còn bị tách nửa hoặc gộp nhầm (một thư viện dùng chung bị tắt theo plugin khác) kèm tên loader và thư mục, để tôi chỉnh luật gộp.
3b. Gõ chữ vào ô tìm kiếm (ví dụ `curic`): nhãn nút đổi thành "Tắt tất cả đang hiện (N)" và chỉ tắt nhóm đó.
3. Danh sách không hiện `VGD_PluginManager`, `vgd_plugin_migrator` hay thư mục `data`.
4. Nếu còn dữ liệu bật/tắt cũ ở `...\SketchUp\VGD_PluginManager` (beta.3), mở hộp thoại: dữ liệu được chuyển vào vị trí mới và có thông báo.
5. Lưu một bộ (tick ô vuông bên trái các plugin rồi bấm lưu), tắt bộ, bật bộ, xóa bộ.
6. Thử tắt plugin có file `.dll/.so` đang nạp: nếu báo lỗi, các mục đã chuyển có được hoàn tác không?
7. Tên plugin có ký tự đặc biệt (`<`, `&`) hiển thị đúng.
8. Gỡ plugin bằng Extension Manager sẽ xóa luôn thư mục `data` (các plugin đã tắt): xác nhận hành vi này trên máy thử.

## 5. Xuất/nhập bộ plugin ra file

1. Lưu ít nhất 2 bộ, bấm "Xuất các bộ ra file", chọn nơi lưu: file `.json` được tạo.
2. Xóa một bộ, bấm "Nhập bộ từ file": bộ đã xóa quay lại.
3. Nhập lại lần nữa khi bộ trùng tên: hộp thoại hỏi Yes (ghi đè) / No (giữ bộ hiện có) và kết quả đúng.
4. Chọn một file `.json` bất kỳ không phải file bộ plugin: có báo "không đúng định dạng", không crash.

## 6. Nhật ký lỗi

Nhật ký ghi tại `%APPDATA%\SketchUp\VGD_PluginManager\migrator.log` (quá 512 KB thì đổi tên thành `.log.1`).

1. Gây một lỗi có chủ đích (ví dụ nhập file bộ plugin hỏng): hộp thoại hiện đường dẫn log, file log có dòng giờ, mô tả và loại lỗi.
2. Đường dẫn trong thông báo mở được bằng Explorer.

## Ghi kết quả

Với mỗi mục, ghi: Đạt / Không đạt / Chưa thử, phiên bản SketchUp, và nội dung log nếu có lỗi. Gửi lại để sửa tiếp.
