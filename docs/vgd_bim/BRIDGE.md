# Cầu nối VGD_BIM và các plugin dựng hình (bridge_version 1)

Định hướng: **VGD_BIM quản lý dữ liệu, plugin nhỏ dựng hình**; khi cần dựng hoặc sửa hình, VGD_BIM gọi plugin đó (xem `ROADMAP.md` mục 1b). Tài liệu này là hợp đồng bản 1, làm theo nhu cầu của plugin đầu tiên (VGD_Room), sẽ mở rộng khi có plugin tiếp theo (tủ, cầu thang, cửa, sàn, tường).

## 1. Dữ liệu trên đối tượng do plugin dựng (để BIM ĐỌC)

Hai dictionary riêng, không đụng `VGD_BIM` (có dictionary đó là món "đã có dữ liệu VGD"):

| Dictionary | Khóa | Ý nghĩa |
|---|---|---|
| `VGD_BIM_ID` | `guid` | VGD ID (UUID chữ thường). Plugin dựng hình **nhận ID từ BIM** khi được gọi; dựng lại thì **giữ ID cũ** của đối tượng. |
| `VGD_BIM_SOURCE` | `plugin` | mã plugin dựng (ví dụ `vgd_room`) |
| | `plugin_version` | phiên bản plugin lúc dựng |
| | `kind` | loại đối tượng (`room`...) |
| | `ref` | mã dữ liệu bên BIM mà hình này thể hiện (ví dụ mã phòng `rm_xxxxxxxx`) |

Tham số hình riêng của plugin (nếu có) nằm trong dictionary riêng của plugin đó; BIM không sửa.

## 2. Danh bạ và lệnh (để BIM GỌI)

Mỗi plugin dựng hình đăng ký lúc nạp vào danh bạ chung `VGD::Bridge` (file `bridge_registry.rb`/`core/bridge.rb`, **bản sao giống hệt ở mỗi plugin** để không phụ thuộc thứ tự nạp):

```ruby
VGD::Bridge.register('vgd_room', {
  bridge_version: 1, version: '0.1.0',
  provides: ['room_volume'],
  commands: {'build' => ->(model, room, vgd_id) { ... }, 'find' => ->(model, room_id) { ... }}
})
```

BIM gọi `VGD::Bridge.call('room_volume', 'build', model, room, vgd_id)`. Chưa cài plugin thì `provider_for` trả nil và BIM báo cần cài qua VGD Center. Khác `bridge_version` thì không dùng (không đoán).

### Loại `room_volume` (VGD_Room)
- `build(model, room, vgd_id)`: tạo hoặc dựng lại khối phòng. `room` là bảng băm của BIM (`id`, `name`, `number`, `boundary` [[x, y] mm], `elevation` mm, `height` mm). Plugin tự mở **một thao tác** (một bước hoàn tác) và hủy nếu lỗi. Trả về Group.
- `find(model, room_id)`: Group đã dựng cho phòng đó (theo `VGD_BIM_SOURCE.ref`) hoặc nil.

## 3. Quy tắc
- BIM luôn kiểm tra lại dữ liệu trước khi gọi; plugin dựng hình cũng kiểm tra lại (ranh giới tin cậy).
- Hình dựng ra là đối tượng thật trong model: đặt trên tag riêng, có tên rõ, không tự khóa. **BIM không tính khối lượng của đối tượng `kind = room`** (loại khỏi Bảng khối lượng).
- Hình bị sửa tay thì lệch dữ liệu; dữ liệu bên BIM là nguồn đúng, dựng lại để đồng bộ.
- Không ghi vào dictionary của plugin khác.

## 4. Chưa làm (bản 1)
Lệnh `edit` mở giao diện riêng của plugin, danh bạ khai báo trong `shared/vgd-center/catalog.json` (để Center gợi ý cài plugin còn thiếu), phiên bản cầu nối nhiều bản.
