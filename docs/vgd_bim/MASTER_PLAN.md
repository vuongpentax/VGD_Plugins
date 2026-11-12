# VGD BIM — Kế hoạch phát triển Plugin BIM cho SketchUp

## 1. Mục tiêu

Xây dựng hệ sinh thái BIM cho SketchUp theo hướng:

> Biến model SketchUp thành model có dữ liệu có cấu trúc, có quan hệ, có thể kiểm tra, bóc khối lượng, lập schedule và xuất dữ liệu.

VGD BIM không nhằm thay thế Revit ngay từ đầu. Mục tiêu ban đầu là tạo một **BIM Data Layer trên SketchUp**, đặc biệt mạnh cho kiến trúc và nội thất.

---

## 2. Kiến trúc tổng thể

```text
                    VGD BIM
                       │
                ┌──────┴──────┐
                │ VGD BIM Core │
                └──────┬──────┘
                       │
       ┌───────────────┼────────────────┐
       ↓               ↓                ↓
   BIM Object       BIM Data        BIM Model
       │               │                │
       ├─ Wall         ├─ Property      ├─ Level
       ├─ Door         ├─ Material      ├─ Room
       ├─ Window       ├─ ID            ├─ Zone
       ├─ Furniture    ├─ Classification└─ Relationship
       └─ Cabinet      └─ Parameter
                       │
              ┌────────┼────────┐
              ↓        ↓        ↓
          Quantity   Schedule   Audit
              │        │        │
              └────────┼────────┘
                       ↓
                 Excel / CSV
```

Sau này mở rộng:

```text
VGD BIM
├── Core
├── Object
├── Data
├── Material
├── Level
├── Room
├── Quantity
├── Schedule
├── Documentation
├── Clash
├── 4D
└── 5D
```

---

# 3. PHASE 0 — BIM Foundation

Mục tiêu: tạo nền tảng dữ liệu trước khi làm các module nghiệp vụ.

## 3.1 BIM Object

Mỗi BIM Object gồm:

```text
VGD BIM Object
├── GUID
├── Category
├── Type
├── Name
├── Description
├── Geometry
└── Properties
```

Category ban đầu:

- Wall
- Floor
- Ceiling
- Door
- Window
- Column
- Beam
- Stair
- Furniture
- Cabinet
- Sanitary
- Lighting
- Equipment
- Generic

## 3.2 Property System

Hỗ trợ:

- Text
- Number
- Length
- Area
- Volume
- Boolean
- Enum
- Material
- Object reference

Ví dụ:

```text
Door D01

Identity
├── ID: D01
├── Name: Cửa phòng ngủ
└── Type: Single Door

Dimensions
├── Width: 900
├── Height: 2200
└── Thickness: 40

Material
├── Frame: Wood
└── Panel: Veneer Oak

BIM
├── Category: Door
├── Level: L2
└── Room: Master Bedroom
```

---

# 4. PHASE 1 — BIM Identity

Mục tiêu: mỗi đối tượng có danh tính ổn định.

## 4.1 GUID

Mỗi BIM Object có ID duy nhất:

```text
VGD-DOOR-8A42F1
```

Không dùng tên Group làm ID.

## 4.2 Object ID

Cho phép người dùng đặt:

```text
D01
D02
D03
W01
W02
TB01
```

## 4.3 Type / Instance

```text
TYPE
Door 900×2200 Veneer

      ↓

INSTANCE
D01
D02
D03
```

Sửa Type → các Instance liên quan cập nhật.

---

# 5. PHASE 2 — Classification

Mục tiêu: xác định object thuộc loại gì.

Ví dụ:

```text
Furniture
 └── Cabinet
     ├── Wardrobe
     ├── Kitchen Cabinet
     └── TV Cabinet
```

Hoặc:

```text
Architecture
├── Wall
├── Floor
├── Ceiling
├── Door
└── Window

Furniture
├── Table
├── Chair
├── Sofa
└── Cabinet
```

Nên thiết kế hệ Classification mở:

```text
VGD Classification
        │
        ├── VGD
        ├── IFC
        ├── OmniClass
        └── Custom
```

---

# 6. PHASE 3 — Material Data

Material không chỉ là texture.

```text
Material
├── Name
├── Code
├── Category
├── Manufacturer
├── Product
├── Finish
├── Thickness
├── Unit
├── Unit Cost
└── Specification
```

Ví dụ:

```text
MFC01
├── Name: MFC Oak
├── Thickness: 18mm
├── Unit: m²
├── Manufacturer: An Cường
└── Code: ...
```

Mục tiêu:

```text
Model → Material → Quantity → Cost
```

---

# 7. PHASE 4 — Level / Storey

Quản lý công trình theo tầng:

```text
Building
│
├── Ground
├── Level 1
├── Level 2
└── Level 3
```

Mỗi Object có thể biết:

```text
Door D01 → Level 2
```

Tính năng:

- Create Level
- Rename Level
- Elevation
- Height
- Assign Object to Level
- Move Object between Levels
- Level Visibility

---

# 8. PHASE 5 — Room / Space

Đặc biệt quan trọng với BIM nội thất.

Ví dụ:

```text
Master Bedroom
Living Room
Kitchen
Dining Room
Bathroom
Walk-in Closet
```

Room:

```text
Room
├── Name
├── Number
├── Area
├── Volume
├── Level
├── Finish
└── Objects
```

Có thể truy vấn:

- Diện tích phòng
- Số đèn
- Số ổ cắm
- Số đồ nội thất
- Vật liệu hoàn thiện
- Tổng quantity theo room

---

# 9. PHASE 6 — Relationship Engine

Đây là nền tảng quan trọng.

Không chỉ:

```text
Object → Property
```

mà cần:

```text
Object → Object
Object → Room
Object → Level
Object → Type
Object → Material
```

Ví dụ:

```text
Door D01
│
├── Type → Door 900×2200
├── Material → Veneer Oak
├── Level → L2
├── Room → Master Bedroom
└── Wall → W12
```

Relationship Engine phải được thiết kế trước Quantity và Schedule.

---

# 10. PHASE 7 — Quantity Engine

Đây là một module chủ lực của VGD.

Quantity cơ bản:

```text
Count
Length
Area
Volume
Weight
```

Ví dụ:

```text
Wall
→ Length
→ Area
→ Volume

Floor
→ Area

Cabinet
→ Width
→ Height
→ Area
→ Volume
→ Count
```

Quantity theo Category:

```text
Door
24 cái

Window
18 cái

Floor Tile
286 m²

Paint
720 m²

Cabinet
42 bộ
```

---

# 11. PHASE 8 — Quantity Rule Engine

Không chỉ tính hình học mà phải có Rule.

Ví dụ sơn:

```text
Wall Paint Area
=
Wall Gross Area
-
Door Opening
-
Window Opening
```

Cabinet:

```text
Board Area
=
Side Panels
+ Top
+ Bottom
+ Shelves
+ Doors
+ Back
```

Tile:

```text
Tile Area
=
Room Floor Area
× Waste Factor
```

Đây là nơi VGD có thể tạo lợi thế cho BIM nội thất.

---

# 12. PHASE 9 — Schedule

Tạo bảng thống kê từ BIM database.

## Door Schedule

```text
ID | Type | W | H | Material | Level
```

## Furniture Schedule

```text
ID | Name | Category | Material | Qty | Room
```

## Cabinet Schedule

```text
ID | W | D | H | Door | Drawer | Material
```

## Finish Schedule

```text
Room | Floor | Wall | Ceiling
```

Schedule phải liên kết ngược về model.

Click một dòng → SketchUp chọn và zoom tới Object tương ứng.

---

# 13. PHASE 10 — BIM Audit

Tự kiểm tra chất lượng BIM model.

Ví dụ:

```text
BIM AUDIT

❌ 12 objects chưa có Category
❌ 7 objects chưa có GUID
❌ 4 objects chưa có Material
⚠️ 8 objects chưa assign Level
⚠️ 3 objects nằm ngoài Room
```

Có thể có:

```text
Fix All
```

hoặc sửa từng lỗi.

---

# 14. PHASE 11 — Model Validation

Rule validation:

```text
IF Door.Width < 700
→ Warning

IF Cabinet.Depth > Room.Depth
→ Error

IF Object.Level = NULL
→ Warning

IF BIM Object has no GUID
→ Error
```

Severity:

```text
INFO
WARNING
ERROR
```

---

# 15. PHASE 12 — Change Tracking

So sánh hai phiên bản model:

```text
Model A
vs
Model B
```

Kết quả:

```text
ADDED
REMOVED
MODIFIED
UNCHANGED
```

Ví dụ:

```text
D01
Width
900 → 1000

Material
Oak → Walnut
```

Có thể xuất:

```text
BIM Revision Report
```

---

# 16. PHASE 13 — IFC

Không nên làm IFC ngay từ đầu.

Sau khi VGD Data Model ổn định:

```text
SketchUp
   ↓
VGD BIM Object
   ↓
VGD Data Model
   ↓
IFC
```

Mục tiêu interoperability:

- Revit
- Archicad
- Navisworks
- Solibri
- BIMcollab
- Các phần mềm BIM khác

VGD tập trung vào BIM authoring cho SketchUp, đặc biệt kiến trúc và nội thất.

---

# 17. PHASE 14 — Clash Detection

Sau IFC và Relationship ổn định mới làm.

Các loại:

```text
Geometry Clash
Clearance Clash
Rule Clash
```

Ví dụ:

- Ống ↔ dầm
- Cửa ↔ tủ
- Cửa ↔ giường
- Cửa ↔ thiết bị
- Đèn ↔ trần
- Điều hòa ↔ tủ
- Thiết bị ↔ khoảng bảo trì

---

# 18. PHASE 15 — Documentation

Khi BIM data đã ổn:

```text
Model
 ↓
View
 ↓
Schedule
 ↓
Sheet
```

Có thể phát triển:

- Plan
- Section
- Elevation
- Detail
- Schedule
- Annotation
- Sheet
- Title Block

Không ưu tiên trước Quantity.

---

# 19. PHASE 16 — Cost / 5D

Khi Quantity đã ổn:

```text
Quantity
+
Unit Price
=
Cost
```

Ví dụ:

```text
MFC 18mm
125 m²
×
285.000đ
=
35.625.000đ
```

Hỗ trợ:

- Material price
- Labor
- Installation
- Waste
- Tax
- Total

Có thể liên kết Excel.

---

# 20. PHASE 17 — 4D

Thêm thời gian vào BIM:

```text
Object
+
Construction Activity
+
Date
```

Ví dụ:

```text
01/12 → Tường
05/12 → Trần
10/12 → Sàn
15/12 → Nội thất
```

Có thể tạo simulation thi công.

---

# 21. Kiến trúc sản phẩm VGD BIM

Không nên làm toàn bộ BIM thành một plugin khổng lồ.

Chia thành 4 tầng:

## Tầng 1 — VGD BIM Core

```text
01 BIM Object
02 GUID
03 Property
04 Type / Instance
05 Classification
06 Material
07 Level
08 Room
09 Relationship
```

## Tầng 2 — VGD BIM Data

```text
10 Quantity Engine
11 Quantity Rules
12 Schedule
13 Audit
14 Validation
15 Revision
```

## Tầng 3 — VGD BIM Interoperability

```text
16 IFC Import
17 IFC Export
18 Model Coordination
19 Clash Detection
```

## Tầng 4 — VGD BIM Management

```text
20 Documentation
21 Cost / 5D
22 Schedule / 4D
23 Project Data
24 Collaboration
```

---

# 22. MVP — VGD BIM 1.0

Không làm toàn bộ BIM ngay.

MVP gồm:

```text
VGD BIM 1.0
│
├── BIM Object
├── GUID
├── Category
├── Property
├── Type / Instance
├── Material
├── Level
├── Room
├── Object Relationship
├── Quantity
├── Schedule
├── Audit
└── Excel Export
```

UI đề xuất:

```text
VGD BIM
│
├── Model
│   ├── Objects
│   ├── Levels
│   └── Rooms
│
├── Data
│   ├── Properties
│   ├── Materials
│   └── Classification
│
├── Quantity
│   ├── Takeoff
│   ├── Rules
│   └── Schedule
│
└── Audit
    ├── Check Model
    └── Fix Issues
```

Chưa cần:

- IFC
- Clash
- 4D
- 5D
- Collaboration

ở phiên bản đầu.

---

# 23. Tích hợp VGD_Cabinet

VGD_Cabinet nên trở thành một BIM-aware module thay vì tồn tại tách biệt hoàn toàn.

```text
VGD BIM Core
       │
       ├───────────────┐
       ↓               ↓
 VGD_Cabinet       VGD_Furniture
       │
       ↓
 BIM Object
       │
       ├── GUID
       ├── Category
       ├── Properties
       ├── Material
       ├── Quantity
       └── Room / Level
```

Ví dụ Cabinet tạo từ VGD_Cabinet:

```text
VGD_Cabinet
     ↓
Geometry
     ↓
BIM Data
     ↓
Quantity
     ↓
Schedule
     ↓
Excel
```

---

# 24. Backlog theo mức ưu tiên

| # | Hạng mục | Ưu tiên |
|---|---|---|
| 1 | BIM Data Model | Bắt buộc |
| 2 | BIM Object + GUID | Bắt buộc |
| 3 | Property System | Bắt buộc |
| 4 | Classification | Bắt buộc |
| 5 | Material | Bắt buộc |
| 6 | Level | Bắt buộc |
| 7 | Room | Bắt buộc |
| 8 | Relationship | Bắt buộc |
| 9 | Quantity Engine | Rất cao |
| 10 | Schedule | Rất cao |
| 11 | Audit / Validation | Rất cao |
| 12 | Excel | Rất cao |
| 13 | VGD_Cabinet Integration | Rất cao |
| 14 | IFC | Sau MVP |
| 15 | Clash | Sau IFC |
| 16 | 4D | Sau |
| 17 | 5D | Sau |

---

# 25. Nguyên tắc phát triển

1. **BIM Data Model trước UI.**
2. **GUID phải ổn định.**
3. **Object phải có Relationship.**
4. **Type và Instance phải tách biệt.**
5. **Quantity phải dựa trên Rule Engine, không hard-code.**
6. **Material phải là dữ liệu, không chỉ là texture.**
7. **Mọi module VGD nên dùng chung BIM Core.**
8. **VGD_Cabinet là module nghiệp vụ đầu tiên tích hợp sâu với BIM.**
9. **IFC chỉ triển khai sau khi Data Model ổn định.**
10. **Không biến VGD BIM thành một plugin monolithic khó bảo trì.**
11. **Ưu tiên workflow kiến trúc/nội thất thực tế của SketchUp.**
12. **Mỗi phiên bản phải có migration strategy cho BIM data cũ.**

---

# 26. Mục tiêu cuối

Kiến trúc cuối cùng nên hướng tới:

```text
                     VGD BIM CORE
                          │
          ┌───────────────┼────────────────┐
          │               │                │
      VGD_Cabinet     VGD_Furniture    VGD_Architecture
          │               │                │
          └───────────────┼────────────────┘
                          ↓
                    BIM DATA MODEL
                          │
          ┌───────────────┼────────────────┐
          ↓               ↓                ↓
      Quantity         Schedule          Audit
          │               │                │
          └───────────────┼────────────────┘
                          ↓
                     Excel / IFC
                          │
                          ↓
                Coordination / Cost
```

Mục tiêu là để **một lần tạo model trong SketchUp có thể sử dụng dữ liệu đó cho nhiều việc**:

```text
Model
 ↓
BIM
 ↓
Quantity
 ↓
Schedule
 ↓
Cost
 ↓
IFC
 ↓
Coordination
 ↓
Documentation
```

Đây là roadmap nên dùng làm **Master Plan cho VGD BIM**, sau đó tách từng phase thành specification, architecture, task list và milestone riêng trước khi bắt đầu code.
