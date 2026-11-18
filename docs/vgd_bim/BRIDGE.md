# Cầu nối VGD_BIM và các plugin dựng hình (bridge_version 1)

Định hướng: **VGD_BIM quản lý dữ liệu, plugin nhỏ dựng hình**; khi cần dựng hoặc sửa hình, VGD_BIM gọi plugin đó (xem `ROADMAP.md` mục 1b). Tài liệu này là hợp đồng bản 1, làm theo nhu cầu của plugin đầu tiên (VGD_Room), sẽ mở rộng khi có plugin tiếp theo (tủ, cầu thang, cửa, sàn, tường).

## 1. Dữ liệu trên đối tượng do plugin dựng (để BIM ĐỌC)

Hai dictionary riêng, không đụng `VGD_BIM` (có dictionary đó là món "đã có dữ liệu VGD"):

| Dictionary | Khóa | Ý nghĩa |
|---|---|---|
| `VGD_BIM_ID` | `guid` | VGD ID (UUID chữ thường). Plugin dựng hình **nhận ID từ BIM** khi được gọi; dựng lại thì **giữ ID cũ** của đối tượng. |
| `VGD_BIM_SOURCE` | `plugin` | mã plugin dựng (ví dụ `vgd_structure`) |
| | `plugin_version` | phiên bản plugin lúc dựng |
| | `kind` | loại đối tượng (`room`...) |
| | `ref` | mã dữ liệu bên BIM mà hình này thể hiện (ví dụ mã phòng `rm_xxxxxxxx`) |

Tham số hình riêng của plugin (nếu có) nằm trong dictionary riêng của plugin đó; BIM không sửa.

## 2. Danh bạ và lệnh (để BIM GỌI)

Mỗi plugin dựng hình đăng ký lúc nạp vào danh bạ chung `VGD::Bridge` (file `bridge_registry.rb`/`core/bridge.rb`, **bản sao giống hệt ở mỗi plugin**: VGD_BIM, VGD_Structure để không phụ thuộc thứ tự nạp):

```ruby
VGD::Bridge.register('ten_plugin', {
  bridge_version: 1, version: '0.1.0',
  provides: ['ten_loai'],
  commands: {'lenh' => ->(model, ...) { ... }}
})
```

Chưa cài plugin thì `provider_for` trả nil và BIM báo cần cài qua VGD Center. Khác `bridge_version` thì không dùng (không đoán).

### Loại `room_volume` (đã gỡ ở VGD_BIM 1.1.1-beta.10)
Plugin VGD_Room đã bị xóa khỏi repo, nên không còn plugin nào cung cấp loại này. Tên loại được giữ để không dùng lại cho nghĩa khác. Khối phòng cũ (nếu còn trong file SketchUp) vẫn được nhận diện qua `VGD_BIM_SOURCE.kind = room` và không tính khối lượng.

### Loại `vgd_id` (VGD_BIM cung cấp, từ VGD_BIM 1.1.1-beta.6)
- `generate()`: trả VGD ID mới (UUID chữ thường). Plugin dựng hình (VGD Structure...) xin ID cho phần tử mới dựng; chưa cài BIM thì để trống, BIM gán sau bằng nút "Gán VGD ID". Plugin **không tự sinh** ID. Dựng lại thì plugin **giữ ID cũ** của đúng phần tử (theo `VGD_BIM_SOURCE.ref`), không xin ID mới.

### Loại `structure_element` (VGD Structure cung cấp, từ VGD Structure 0.8.0-beta.1)
- `edit(model, entity)`: mở cửa sổ VGD Structure ở đúng tab, tầng và phần tử của đối tượng (cột, dầm, tường, sàn, trần). Lỗi nếu đối tượng không do plugin dựng.
- BIM gọi lệnh `edit` của **plugin nguồn** (`VGD_BIM_SOURCE.plugin`) qua nút **Công cụ → Sửa bằng plugin dựng hình** (một dòng đang chọn); chưa cài plugin hoặc khác phiên bản cầu nối thì báo rõ, không đoán. BIM không sửa hình hay tham số của plugin khác.
- **Dữ liệu BIM đọc** từ phần tử của VGD Structure (đặc tả đầy đủ ở `docs/vgd_structure/SPEC.md` mục 2): `VGD_BIM_SOURCE` (`plugin`, `kind`, `ref`), `VGD_STRUCT` (`level`, `level_name`, `level_elevation`, `type`, `dims`). BIM (`core/structure_source.rb`) dùng `dims` để tính **khối lượng chính xác** (tường trừ lỗ cửa `openings_area`; cửa đi, cửa sổ `door` / `window` đếm theo cái, diện tích lỗ rộng x cao) thay vì đoán từ khối bao (tường chạy theo trục Y hay trần mỏng sẽ ra sai nếu dùng khối bao): cột, dầm: thể tích; tường: diện tích mặt (dài x cao) và thể tích; sàn, trần: diện tích mặt bằng và thể tích. Cách tính mặc định khi món không có tag cho biết: cột, dầm, sàn theo thể tích; tường, trần theo diện tích (người dùng vẫn đặt riêng theo tag được). Tầng của plugin hiện ở cột Tầng khi món chưa được gán tầng BIM.
- Nhóm chứa của plugin (`VGD_STRUCT.kind` = columns / beams / walls / slabs / ceilings) và nhóm lưới trục (`grid`, kể cả ký hiệu trục bên trong) **không phải món**, BIM không tính khối lượng; chọn nhóm chứa thì BIM lấy các phần tử bên trong làm dòng.

## 3. Quy tắc
- BIM luôn kiểm tra lại dữ liệu trước khi gọi; plugin dựng hình cũng kiểm tra lại (ranh giới tin cậy).
- Hình dựng ra là đối tượng thật trong model: đặt trên tag riêng, có tên rõ, không tự khóa. **BIM không tính khối lượng của đối tượng `kind = room`** (loại khỏi Bảng khối lượng).
- Hình bị sửa tay thì lệch dữ liệu; dữ liệu bên BIM là nguồn đúng, dựng lại để đồng bộ.
- Không ghi vào dictionary của plugin khác.

## 4. Chưa làm (bản 1)
Lệnh `edit` mở giao diện riêng của plugin, danh bạ khai báo trong `shared/vgd-center/catalog.json` (để Center gợi ý cài plugin còn thiếu), phiên bản cầu nối nhiều bản.
