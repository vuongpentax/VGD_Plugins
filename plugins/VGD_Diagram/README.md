# VGD Diagram 0.1.0-beta.1

Plugin SketchUp vẽ **sơ đồ cây lắp ráp** của đối tượng: các cấu kiện, số lượng và thứ tự lắp, để khách hàng và thợ lắp đặt dễ hiểu mô hình.

## Trạng thái

**0.1.0-beta.1 (bản thử đầu tiên).** Đã có: cây cấu kiện theo cấp, gom cấu kiện giống nhau kèm số lượng, nhập thứ tự lắp, chọn cấu kiện trong model khi bấm tên, xuất SVG.

- **Đã kiểm tra tự động:** logic gom nhóm, sắp thứ tự, kiểm tra số trùng, đọc/ghi model giả lập, menu và nút Tải lại code, giao diện hộp thoại trong Chromium (`dev/`).
- **Chưa kiểm tra trong SketchUp thật.** Cần thử trên SketchUp 2022 (Windows) trước khi tin cậy.
- **Chưa làm:** sơ đồ mũi tên thứ tự lắp (bước B), xuất PNG.

## Cách dùng

1. Mở model có các nhóm (Group) hoặc component lồng nhau.
2. Bấm **Extensions → VGD → VGD Diagram → VGD Diagram** hoặc nút trên thanh **VGD DGM**.
3. Cây hiện các cấu kiện ở cấp đầu, bên trong là cấu kiện con.
   - Bấm tên để chọn các bản đó trong model.
   - Nhập thứ tự lắp (số nguyên 1 đến 9999) rồi bấm **Lưu thứ tự**. Có thể dùng Ctrl+Z để hoàn tác.
   - Số thứ tự chỉ cần không trùng giữa các cấu kiện **cùng cấp**.
4. **Xuất SVG** lưu sơ đồ thành file ảnh vector.

## Quy tắc gom và thứ tự (giả định cần xác nhận)

- Các cấu kiện **cùng tên và cùng cấu trúc con** được gom thành một dòng kèm số lượng (ví dụ "Chân × 4").
- Dòng con chỉ hiện theo **một bản đại diện**. Khi bấm một dòng, chỉ các bản thuộc đại diện đó được chọn.
- Thứ tự lắp lưu thành thuộc tính trong model (dictionary `VGD_Diagram`, khóa `order`). Thứ tự áp cho mọi bản trong nhóm. Khi các bản có thứ tự khác nhau, ô hiện "nhiều số".
- Plugin **chỉ đọc** hình học. Chỉ thêm/xóa thuộc tính thứ tự khi bạn bấm Lưu thứ tự.

## Cài đặt và tải lại

- Cài file `VGD_Diagram_v<phiên bản>.rbz` qua Extension Manager.
- Nút **Tải lại code** (Extensions → VGD → VGD Diagram → Tải lại code) nạp lại mã sau khi cài bản mới. Không tải lại khi đang ghi thứ tự lắp.
- Menu và toolbar chỉ đổi sau khi **mở lại SketchUp**.

## Kiểm thử

Chạy từ thư mục `plugins/VGD_Diagram`:

```bash
ruby dev/test_tree.rb
ruby dev/test_reload.rb
node dev/test_ui.cjs
```

Đóng gói: `python dev/package.py` (tạo RBZ và SHA-256 trong `outputs/`, không commit).
