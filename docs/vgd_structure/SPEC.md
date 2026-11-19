# Đặc tả VGD Structure: dữ liệu và quy tắc hình học (bản 0)

Đi kèm `PLAN.md`. Đây là hợp đồng để mã sau này làm theo; đổi ở đây trước khi đổi mã. Đơn vị mm, trục X sang phải, Y vào trong, Z lên.

## 1. Dữ liệu nguồn (dictionary `VGD_STRUCT` của model, khóa `state`, JSON)

```json
{
  "schema_version": 1,
  "grid": {
    "origin": [0, 0],
    "x_axes": [{"name": "1", "offset": 0}, {"name": "2", "offset": 4200}],
    "y_axes": [{"name": "A", "offset": 0}, {"name": "B", "offset": 3600}]
  },
  "levels": [
    {"id": "sl_xxxxxxxx", "name": "Tầng 1", "elevation": 0, "slab_thickness": 120,
     "defaults": {"column": {"shape": "rect", "w": 300, "d": 300}, "beam": {"w": 200, "h": 400},
                  "wall": {"thickness": 200}, "ceiling": {"height": 2800, "thickness": 9}},
     "picks": {"columns": ["1-A", "2-A"], "beams": ["x:A:1-2"], "walls": ["x:A:1-2"], "slabs": ["1-2/A-B"], "ceilings": ["1-2/A-B"]}}
  ]
}
```

- `symbol`: `{"scale": 100, "both_ends": false}`; `scale` là tỉ lệ bản vẽ 1:n (n nguyên từ 10 đến 1000), `both_ends` đặt ký hiệu trục ở cả hai đầu.
- `x_axes` / `y_axes`: tên trục (chuỗi không rỗng, không trùng trong cùng phương) và khoảng cách từ gốc, **tăng dần**, tối thiểu 2 trục mỗi phương; hạn chế: tối đa 60 trục mỗi phương, mọi số trong khoảng hợp lý (không âm vô lý, không NaN).
- `levels`: mỗi tầng RIÊNG (cao độ sàn khác nhau, không gom tầng). Cao độ sàn tăng dần theo thứ tự tầng; tầng trên cùng chỉ có sàn và trần (không cột, tường lên tầng khác).
- `types` (cột mốc 2): `[{"id": "ct_xxxxxxxx", "name": "C30x30", "w": 300, "d": 300}]`, 1 đến 50 loại, tên tối đa 20 ký tự không trùng, `w`/`d` 100 đến 3000 mm; bản đầu chỉ cột chữ nhật.
- Mỗi tầng: `id` `sl_xxxxxxxx`, `name` (tối đa 30, không trùng), `elevation` (mm, tăng dần, cách tầng dưới tối thiểu 500), `slab_thickness` (50 đến 1000), `column_type` (mã loại hoặc null = loại đầu danh sách), `picks`. Tối đa 40 tầng. **Tầng trên cùng chỉ có sàn** (không cột).
- `picks.columns` là bảng `{"1-A": {"type": "ct_...", "x": "center", "y": "min"}}`; chỉ ghi khóa khác mặc định: `type` (mặc định = loại của tầng), `x`/`y` ∈ `center` / `min` / `max` (mặc định auto theo quy ước mục 4: `min` cạnh nhỏ tại trục, cột lùi về phía tăng; `max` cạnh lớn tại trục). Giao điểm không còn trên lưới thì bị bỏ khi đọc.
- `beam_types` (cột mốc 3): `[{"id": "bt_xxxxxxxx", "name": "D20x40", "w": 200, "h": 400}]`, `w` 100 đến 1500, `h` 100 đến 2000 mm. Tầng có thêm `beam_type` (mã hoặc null = loại đầu danh sách).
- `picks.beams` là bảng `{"x:A:1-2": {"type": "bt_...", "p": "center"}}`; `p` ∈ `center` / `min` / `max` (mặc định auto: dầm trên trục biên đầu `min`, biên cuối `max`, giữa `center`; `min` cạnh nhỏ tại trục).
- `wall_types` (cột mốc 4): `[{"id": "wt_xxxxxxxx", "name": "T200", "t": 200}]`, `t` 50 đến 1000 mm; tầng có thêm `wall_type`. `picks.walls` giống `picks.beams`: `{"x:A:1-2": {"type": "wt_...", "p": "center"}}`. Tường cao từ `Ei` lên đáy dầm của nhịp (nếu nhịp có dầm được chọn cùng tầng) hoặc đáy sàn tầng trên; đặc, chưa khoét cửa.
- `opening_types` (cột mốc 8): `[{"id": "ot_xxxxxxxx", "name": "D900x2100", "kind": "door|window", "w": 900, "h": 2100, "sill": 0}]`; `w` 300 đến 5000, `h` 300 đến 4000, `sill` 0 đến 3000 mm. `picks.openings` là `{"op_xxxxxxxx": {"wall": "x:B:2-3", "type": "ot_...", "pos": 1950, "flip": false}}`: `pos` là tâm cửa tính từ đầu tường (mm). Cửa nằm trọn trong chiều dài và chiều cao tường, cách cửa khác >= 50 mm; tường khoét lỗ chữ nhật; kind `door` / `window` ở `VGD_BIM_SOURCE`, `dims` của cửa: `w`,`h`,`sill`,`thickness`,`wall`; `dims` của tường thêm `openings` (số lỗ) và `openings_area` (m²).
- Tầng có thêm `ceiling_height` (1500 đến 20000, mặc định 2800) và `ceiling_thickness` (5 đến 100, mặc định 9). `picks.slabs` / `picks.ceilings` là `{"1-2/A-B": {}}` (mã ô). Sàn: mặt trên tại `Ei`, dày `slab_thickness` xuống dưới, lùi theo dầm, tường và cột của tầng dưới (tầng thấp nhất phủ trọn ô), kể cả tầng trên cùng. Trần: mặt dưới tại `Ei + ceiling_height`, dày `ceiling_thickness` lên trên, lùi tới mặt tường (nếu có), khoét góc theo cột; tầng trên cùng không có trần. Mã nhịp / ô như sau: cột theo giao điểm `"<trục x>-<trục y>"`, dầm và tường theo nhịp `"<x|y>:<tên trục chứa nhịp>:<tên hai trục chặn>"`, sàn và trần theo ô `"<x1>-<x2>/<y1>-<y2>"`. Mã này là `ref` ghi vào `VGD_BIM_SOURCE.ref`.
- Dữ liệu được kiểm tra lại mỗi lần đọc từ model và mỗi lần nhận từ giao diện (ranh giới tin cậy).

## 2. Dữ liệu trên khối dựng ra

| Dictionary | Khóa | Giá trị |
|---|---|---|
| `VGD_BIM_ID` | `guid` | VGD ID xin từ VGD BIM qua cầu nối `vgd_id` (không có BIM thì trống); dựng lại giữ ID cũ của đúng phần tử |
| `VGD_BIM_SOURCE` | `plugin` | `vgd_structure` |
| | `plugin_version` | phiên bản lúc dựng |
| | `kind` | `column` / `beam` / `wall` / `slab` / `ceiling` |
| | `ref` | mã phần tử ở mục 1 kèm tầng, ví dụ `sl_xxxxxxxx:1-A` |
| `VGD_STRUCT` | `level` | id tầng |
| | `level_name`, `level_elevation` | tên và cao độ mặt sàn của tầng (mm) để BIM hiển thị |
| | `type` | tên loại (C30x30, D20x40, T200); sàn / trần không có |
| | `dims` | JSON, mm: cột `w`,`d`,`height`; dầm `w`,`h`,`length`; tường `thickness`,`height`,`length`,`under_beam`; sàn / trần `thickness`,`area` (m²),`z_top` |
| | `placement` | cột: `middle` / `edge` / `corner`; dầm, tường: `inner` / `edge` |

VGD BIM đọc `kind`, `level`, `level_name`, `dims` để lập bảng khối lượng chính xác và hiện tầng (từ VGD BIM 1.1.1-beta.6); **không sửa** dữ liệu này. Cầu nối: `docs/vgd_bim/BRIDGE.md`.

## 3. Quy ước đặt tên và tag

Tên: `<Loại>-<ref rút gọn>-<tầng>` (ví dụ `Cột-B2-T1`). Tag theo loại: Cột, Dầm, Tường, Sàn, Trần (`Schema::TAGS`).

## 4. Vị trí theo lưới (chủ dự án chốt 17/11/2026)

Lưới quyết định vị trí và **không phần tử nào nhô ra ngoài khung lưới** (hình chữ nhật bao các trục):

- **Cột** (kích thước `w` theo X, `d` theo Y):
  - giữa (không nằm trên trục biên của cả hai phương): tâm đúng giao điểm;
  - biên (nằm trên một trục biên): mặt ngoài tiếp giáp trục biên đó, tâm dời vào trong `w/2` hoặc `d/2` theo phương vuông góc với trục biên;
  - góc: tiếp giáp cả hai trục biên.
- **Dầm, tường** dọc nhịp: nhịp giữa có tâm trên trục; nhịp nằm trên trục biên có mặt ngoài tiếp giáp trục biên (dày / rộng dời vào trong nửa bề rộng). Chiều dài là khoảng **hở giữa hai mặt cột** hai đầu nhịp (không chui vào cột); khoảng hở không dương thì bỏ nhịp và báo.
- Người dùng có thể đổi tay một cột sang "tâm trên trục" ở bước xem trước (ghi vào `picks`, cột mốc 2).

## 5. Quy tắc cao độ (không chồng khối)

Tầng i: cao độ `Ei` là cốt sàn HOÀN THIỆN; cán nền `c(i)` (mặc định 50 mm, 0 đến 300, sửa từng tầng) nên **mặt trên sàn kết cấu** là `Si = Ei - c(i)`. Dày sàn `t(i)`. Cột, dầm, tường kết cấu tính từ `Si`; ngưỡng cửa và cao trần tính từ `Ei` (cốt hoàn thiện).

| Loại | Cao độ |
|---|---|
| Sàn tầng i | mặt trên `Si`, dày `t(i)` xuống dưới; nằm **lọt lòng** giữa các dầm, tường và cột của tầng dưới (lùi tới mặt trong dầm và tường, khoét góc theo cột), nên không chồng khối |
| Cột | từ `Si` lên `S(i+1)` (mặt trên sàn kết cấu tầng trên) |
| Dầm | **đỉnh bằng `S(i+1)`**, chiều cao `h` là TỔNG chiều cao tính từ đỉnh sàn xuống (phần nhô dưới sàn là `h - t(i+1)`) |
| Tường | từ `Si` lên đáy dầm của nhịp (nếu có dầm), không thì lên đáy sàn tầng trên `S(i+1) - t(i+1)` |
| Cửa | ngưỡng `sill` tính từ `Ei` (cốt hoàn thiện) |
| Trần | cao độ `Ei + height` của tầng, mỏng `thickness`, trong ô; mặt trên không vượt đáy sàn tầng trên |

Tầng trên cùng chưa có tầng kế: cột, dầm, tường của tầng đó cần nhập chiều cao tầng; chi tiết chốt ở cột mốc 2.

## 5b. Lưới trục trong model (cột mốc 1)

- Một Group tên `Lưới trục` trên tag **`!grid`** (tên, màu tím (186, 0, 204) và thư mục `! INFORMATION` theo bộ tag mẫu của VGD BIM; IFC IfcGrid), ghi `VGD_STRUCT.kind = grid` và phiên bản plugin; chứa các đường trục và mỗi ký hiệu trục là nhóm con.
- Đường trục: nét **gạch dài - chấm** (kiểu nét của tag; chỉ đặt khi tag còn nét liền, không đè kiểu người dùng đã chọn), kéo dài quá trục biên `1,5 x` đường kính vòng tròn.
- Ký hiệu trục (thông lệ bản vẽ quốc tế): vòng tròn đường kính **10 mm trên giấy x tỉ lệ**, tên trục ở giữa (chữ cao `0,4 x` đường kính; từ 3 ký tự thu nhỏ). Trục đứng (số) có ký hiệu ở đầu dưới, trục ngang (chữ) ở đầu trái; tùy chọn cả hai đầu.
- Chữ trục: số 1, 2, 3... cho trục đứng; chữ A, B, C... cho trục ngang, bỏ **I và O** (dễ nhầm với 1 và 0); hết 24 chữ thì AA, AB.... Người dùng đổi tên tay được.

## 6. Chưa có trong bản 0

Ô cửa trên tường, giao cắt phức tạp, lưới xiên, nhập CAD, mái, cầu thang, móng.
