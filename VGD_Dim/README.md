# VGD Dimension & Text Manager · 2.3.0-beta.1

Chỉnh mẫu trong **Model Info**, chọn các Dim/Text cần đổi, rồi bấm **APPLY**. Giao diện một trang theo style T+ Cabinet.

1. Bấm **Mở Model Info · Dimensions** để chỉnh font, cỡ chữ Points hoặc Height (ví dụ 3 mm), endpoint và các thiết lập Dim native.
2. Bấm **Mở Model Info · Text** để chỉnh mẫu chữ màn hình và chữ có đường dẫn. Lưu SKP sau khi chỉnh để các mẫu Model Info đi cùng file.
3. Chọn trực tiếp Dim/Text/Label. Nếu nằm trong group, mở group rồi chọn đối tượng. Chọn cả group/component không áp vào nội dung bên trong.
4. Chọn màu và endpoint trong plugin, rồi **APPLY**. Plugin gọi **Update selected dimensions** và **Update selected text** riêng từng loại; sau đó đổi màu/endpoint và đưa Dim vào **000 DIM**, Text/Label vào **000 TEXT**.

Không có hộp thông báo hoàn tất. Lỗi hiện trong cửa sổ hoặc status bar. Endpoint “Giữ nguyên” nghĩa là plugin không ghi đè endpoint sau khi áp mẫu native. Màu/endpoint trong plugin chỉ áp lên vùng chọn, không ghi ngược vào mẫu Model Info.

Bản beta hỗ trợ **SketchUp Windows với giao diện English**. SU2022 Ruby không có setter font/size của Dimension; plugin dùng Fiddle/user32 để tìm đúng bảng Model Info và nút native trong chính tiến trình SketchUp, rồi gửi BM_CLICK. Không dùng ID lệnh phỏng đoán, Select All, edge/mesh hoặc truy cập bộ nhớ entity. Chưa xác nhận việc gọi nút này và thay font/Height trong SketchUp thực tế.

Các nút được kiểm tra trước khi gọi cập nhật. Nếu không có hoặc có nhiều kết quả, thao tác dừng. Nếu người dùng đổi selection/model/ngữ cảnh khi đang áp, plugin dừng và không ghi đè vùng chọn mới. Đối tượng trong definition chia sẻ bị chặn trước mutation; cần Make Unique bản cần sửa.

Mẫu native có thể đổi cả kiểu Dim, vị trí/hướng chữ hoặc leader theo Model Info. Plugin không thay UnitsOptions. Phần màu/endpoint/tag có một Undo; các lệnh native có Undo riêng. Nếu một cập nhật native đã chạy rồi phần sau lỗi, thông báo nêu phần đã gọi; không cam kết rollback toàn bộ các lệnh native.

## Cài / nạp

RBZ: outputs/VGD_Dimension_Text_Manager_v2.3.0-beta.1.rbz.

dev/deploy.ps1 cài 10 file VGD vào SketchUp 2022, backup và kiểm tra SHA256. Không đổi Cabinet/plugin khác. Loader T+ Dim cũ được sao lưu và tắt khi chuyển thương hiệu.

Trong SketchUp đang chạy: **Extensions → Nạp lại VGD Dim/Text**. Nếu cài lần đầu, restart SketchUp. Ruby Console cũng có thể nạp:

```ruby
load File.join(Sketchup.find_support_file('Plugins'), 'VGD_Dim', 'reload.rb')
```

## Kiểm tra

- dev/check_ruby.cjs: cú pháp, engine selection-only, endpoint/tag/material isolation, guard/abort; mô phỏng native subsets, timeout, đổi selection/model, cancel và lỗi cập nhật một phần.
- dev/test_ui.cjs: giao diện Edge, payload, Model Info, trạng thái đang áp, lỗi inline và footer.
- dev/test_deploy.py: bộ cài PowerShell trong APPDATA mô phỏng, backup, whitelist và giữ nguyên Cabinet.
- dev/native_smoke.rb: test thủ công trong model trống; chưa chạy trong phiên này.
- outputs/VALIDATION.json phân biệt kết quả mô phỏng với native chưa xác minh.

Tài liệu: [Model Info / Update selected / Font / Height](https://help.sketchup.com/en/sketchup/adding-text-labels-and-dimensions-model), [Dimension Ruby API](https://ruby.sketchup.com/Sketchup/Dimension.html), [BM_CLICK](https://learn.microsoft.com/en-us/windows/win32/controls/bm-click).
