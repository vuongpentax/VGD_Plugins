# Quan hệ giữa các công cụ và cấu kiện (VGD Cabinet Draw)

Tài liệu này dành cho người thêm tính năng sau này. Mục tiêu: biết một cấu kiện được lưu ở đâu, ai tạo nó,
ai dựng lại nó khi tủ đổi, và cách liên kết với cấu kiện khác mà không phá các tính năng cũ.

## 1. Dữ liệu gắn vào model

Mọi dữ liệu nằm trong từ điển thuộc tính `VGD_Cabinet_Draw` (hằng `Schema::DICTIONARY`).

| Đối tượng | Thuộc tính quan trọng | Ý nghĩa |
|---|---|---|
| Tủ (group gốc) | `kind = cabinet`, `params_json`, `build_ops_json`, `door_layout_json` | Thông số, kích thước (`width_mm`…), danh sách bước tạo, bố cục cánh |
| Thùng tủ `Thùng tủ` | `kind = shell`, `body_z0_mm`, `body_z1_mm` | Vỏ chứa mọi cấu kiện bên trong |
| Tấm vỏ tủ / đợt / vách | `kind = part`, `role` (hông, nóc, đáy, đợt `shelf`, vách `partition`…), `op`, `index`, `geo_sig` | `geo_sig` là chữ ký hình học lúc dựng, để biết tấm có bị chỉnh tay không |
| Mặt / thùng ngăn kéo | `kind = drawer_front` / `drawer_box`, attribute `op`, `op_index` | Cùng một `op` là cùng một hộc |
| Khoang ngăn kéo, xà chặn, hộc tủ áo | `kind = bay` / `blocker` / `wardrobe_compartment`, `params.op` | Một bước tạo = một container |
| Cánh | tên `Cánh Draw`, `region_id`, `opening_type`, `angle_deg`, `opening_side` | Cánh nằm trong group `Cánh` của tủ |
| Tay nắm | tên `Tay Nắm`, `ax/dx_mm`, `az/dz_mm` (neo theo mép, mm), `u/v` (tỷ lệ, cũ) | Gắn trong cánh hoặc mặt hộc |
| Tấm khoét / cắt / bo | cờ `notched` | Bị coi là chỉnh tay; hình học theo tỷ lệ khi co giãn (chưa làm theo mm) |

Quy tắc: thêm thuộc tính mới thì đặt trong `Schema::DICTIONARY`, không đặt tên lạ ở ngoài.

## 2. Bước tạo và dựng lại

- Mỗi lệnh tạo chi tiết (đợt/vách, ngăn kéo, khoang, xà chặn, hộc tủ áo) ghi một bước vào `build_ops_json`
  qua `Rebuild.record`, với loại (`panel`, `drawer`, `bay`, `blocker`, `wardrobe`) và điểm neo tỷ lệ.
- `Rebuild.run(root, settings, dims, keep)` dựng lại tủ: xóa phần không giữ, dựng vỏ tủ, rồi chạy lại các bước theo thứ tự `op`.
  `keep` là các cấu kiện giữ nguyên (tấm chỉnh tay, hoặc mọi cấu kiện khi co giãn).
- Cánh dựng lại bằng `rebuild_doors` từ `door_layout_json`. Tay nắm được chép lại qua `Operations.handle_specs` và `add_handle`.

Nếu thêm một cấu kiện mới có vị trí: ghi bước vào `build_ops_json`, đặt `op` trên mọi phần của nó, và thêm loại đó vào `Rebuild.replay`.

## 3. Co giãn khi kéo Scale (`rebuild.rb`, `auto_stretch.rb`)

Quy trình: `AutoStretch.after_commit` → `Rebuild.stretch(root)`:
1. Dựng thử hai bản sao của tủ (kích thước cũ và mới) để lấy hộp và nội dung đúng công thức (`with_probe`).
2. Kiểm tra liên kết bản lề trên bản thử (`Links.check!`). Lỗi thì hủy thao tác, tủ giữ nguyên.
3. Phân loại theo khóa (`stretch_key`):
   - Vỏ tủ, đợt/vách: co theo hộp cũ → hộp mới (`stretch_part!`), độ dày giữ nguyên.
   - Cánh, mặt/thùng hộc, khoang, xà chặn, hộc tủ áo: thay nội dung bằng nội dung bản thử (`replace_contents`),
     để khung, gờ, khe giữ đúng mm. Vật liệu đặt lại theo đường dẫn tên.
4. Dựng lại phần còn lại (ngăn kéo, tay nắm, phào, chân) bằng `Rebuild.run` với `keep` là các cấu kiện đã co giãn.

Muốn một cấu kiện mới co giãn đúng: thêm khóa trong `stretch_key`, và nếu nó là vật thể có nội dung riêng thì thêm vào `REGENERATED_KINDS`.

## 4. Liên kết (`links.rb`)

- Cánh có bản lề vào tấm vỏ tủ theo hướng mở: trái → hông trái, phải → hông phải, mở lên → nóc, mở xuống → đáy.
- Cánh mở lên/xuống được xử lý trước (`Links.ordered`).
- Bản lề không còn bắt được vào tấm vỏ tủ thì `Links.check!` ném lỗi và tủ giữ nguyên.
- Mọi quy tắc liên kết mới đặt ở đây, không rải vào công cụ.

## 5. Các công cụ và nơi chúng nằm

| Công cụ | Tệp | Ghi gì |
|---|---|---|
| Box → Board, Sửa tủ | `tools.rb` (`BoxTool`, `EditCabinetTool`) | Tạo thùng tủ; sửa tủ qua `Rebuild.run` |
| Đợt / vách | `tools.rb` (`PanelTool`), `panel_model.rb` | Bước `panel` |
| Cánh | `tools.rb` (`DoorTool`), `door_layout.rb`, `door_geometry.rb` | Bố cục `door_layout_json`, cánh |
| Hướng mở, tay nắm | `tools.rb` (`OpeningTool`, `handles`, `add_handle`) | Thuộc tính cánh, `Tay Nắm` |
| Ngăn kéo, khoang | `tools.rb` (`DrawerTool`), `drawer_bay.rb`, `drawer_slide.rb` | Bước `drawer`/`bay`, mở kéo |
| Xà chặn, hộc tủ áo | `tools.rb` (`blockers`, `wardrobe`) | Bước `blocker`/`wardrobe` |
| Cắt, bo, khấu | `tools.rb` (`CutTool`, `SelectAndApplyTool`, `NotchTool`) | Subtract, cờ `notched` |
| Co giãn khi Scale | `auto_stretch.rb`, `rebuild.rb` | Xem mục 3 |
| Liên kết | `links.rb` | Xem mục 4 |
| Menu chuột phải, HUD | `context_menu.rb`, `preset_hud.rb`, `mini_bar.rb` | Gọi các công cụ trên |

## 6. Việc còn lại đã biết

- Khấu, cắt, bo trên vỏ tủ vẫn co theo tỷ lệ (chưa lưu lại thao tác để dựng lại theo mm).
- Lỗ cam, chốt, cốc, lề: chưa thiết kế.
- `Chia nhanh` (menu chuột phải) xóa ngăn kéo nhưng còn giữ khoang: cần kiểm tra lại.
- Click trong công cụ Sửa tủ luôn dựng lại tủ (thiết kế hiện tại), dễ kích hoạt nhầm.
