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

- `x_axes` / `y_axes`: tên trục (chuỗi không rỗng, không trùng trong cùng phương) và khoảng cách từ gốc, **tăng dần**, tối thiểu 2 trục mỗi phương; hạn chế: tối đa 60 trục mỗi phương, mọi số trong khoảng hợp lý (không âm vô lý, không NaN).
- `levels`: mỗi tầng RIÊNG (cao độ sàn khác nhau, không gom tầng). Cao độ sàn tăng dần theo thứ tự tầng; tầng trên cùng chỉ có sàn và trần (không cột, tường lên tầng khác).
- `picks`: các phần tử được chọn dựng ở tầng đó: cột theo giao điểm `"<trục x>-<trục y>"`, dầm và tường theo nhịp `"<x|y>:<tên trục chứa nhịp>:<tên hai trục chặn>"`, sàn và trần theo ô `"<x1>-<x2>/<y1>-<y2>"`. Mã này là `ref` ghi vào `VGD_BIM_SOURCE.ref`.
- Dữ liệu được kiểm tra lại mỗi lần đọc từ model và mỗi lần nhận từ giao diện (ranh giới tin cậy).

## 2. Dữ liệu trên khối dựng ra

| Dictionary | Khóa | Giá trị |
|---|---|---|
| `VGD_BIM_ID` | `guid` | VGD ID do VGD BIM cấp; dựng lại giữ ID cũ |
| `VGD_BIM_SOURCE` | `plugin` | `vgd_structure` |
| | `plugin_version` | phiên bản lúc dựng |
| | `kind` | `column` / `beam` / `wall` / `slab` / `ceiling` |
| | `ref` | mã phần tử ở mục 1 kèm tầng, ví dụ `sl_xxxxxxxx:1-A` |
| `VGD_STRUCT` | `level` | id tầng |
| | `dims` | kích thước đã dùng (mm): cột `w`,`d` hoặc `r`; dầm `w`,`h`,`length`; tường `thickness`,`height`,`length`; sàn / trần `thickness`, diện tích |
| | `placement` | cột: `middle` / `edge` / `corner`; dầm, tường: `inner` / `edge` |

VGD BIM đọc `kind`, `level`, `dims` để lập bảng khối lượng và gán tầng; **không sửa** dữ liệu này.

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

Tầng i: mặt sàn `Ei`, tầng kế `E(i+1)`, dày sàn `t(i+1)` của tầng kế.

| Loại | Cao độ |
|---|---|
| Sàn tầng i | mặt trên `Ei`, dày `t(i)` xuống dưới; phủ cả ô (kể cả phía trên cột và dầm) |
| Cột | từ `Ei` lên đáy sàn tầng trên `E(i+1) - t(i+1)` |
| Dầm | đỉnh tại đáy sàn tầng trên, treo xuống `h` |
| Tường | từ `Ei` lên đáy dầm của nhịp (nếu nhịp có dầm), không thì lên đáy sàn tầng trên |
| Trần | cao độ `Ei + height` của tầng, mỏng `thickness`, trong ô |

Tầng trên cùng chưa có tầng kế: cột, dầm, tường của tầng đó cần nhập chiều cao tầng; chi tiết chốt ở cột mốc 2.

## 6. Chưa có trong bản 0

Ô cửa trên tường, giao cắt phức tạp, lưới xiên, nhập CAD, mái, cầu thang, móng.
