# VGD_BIM — Lộ trình phát triển (đã duyệt ngày 12/11/2026)

Tài liệu này là kế hoạch làm việc của plugin `plugins/VGD_BIM`, lập từ bản kế hoạch tổng hợp do chủ dự án soạn (`MASTER_PLAN.md` cùng thư mục, giữ nguyên bản gốc). Mỗi lần làm xong một cột mốc phải cập nhật phần "Trạng thái" bên dưới trong cùng commit. Tài liệu viết cho người không chuyên mã nguồn; thuật ngữ khó có giải thích ngay chỗ dùng.

**Tầm nhìn (chủ dự án, 12/11/2026):** biến SketchUp thành phần mềm **dựng hình và BIM đối tượng**, như Archicad hay Revit: dựng hình bằng các plugin nhỏ, còn VGD_BIM định nghĩa, quản lý và điều khiển thông tin của mọi đối tượng.

## 1. Những điều đã chốt

| Việc | Quyết định |
|---|---|
| Thứ tự làm | Danh tính (ID) → Tầng và Phòng → Vật liệu và luật khối lượng → Schedule mẫu và Audit → Type, Classification mở, so sánh hai phiên bản, tích hợp VGD_Cabinet. |
| Phòng | Có nhãn **và có vùng, có hình, có diện tích**, dựng được thành khối 3D. |
| Người dùng | Nội thất **và** kiến trúc ngay từ đầu. |
| Tầm nhìn | Về sau làm đủ các tính năng BIM (IFC, Clash, Documentation, 4D, 5D...). Mỗi tính năng lớn có đặc tả riêng trước khi code. |
| Cách ghi ID | Theo chuẩn của BIM (xem mục 3), không tự bịa kiểu mới. |
| Giữ một plugin | VGD_BIM vẫn là một plugin, chia module trong `core/`. VGD_Cabinet nối qua dữ liệu chung (dictionary), không gộp mã. |
| Dựng hình | **BIM không tự dựng hình** (giữ lõi nhẹ). Việc dựng do các plugin nhỏ riêng đảm nhận (tủ, cầu thang, cửa, sàn, tường, phòng... tên plugin chỉ là ví dụ, chưa sản xuất), nối với BIM qua "cầu nối" (mục 1b). **BIM đọc dữ liệu và khi cần sửa thì BIM gọi đúng plugin đã dựng ra đối tượng đó để sửa mô hình**, như Revit / Archicad. Kế hoạch triển khai từng plugin viết khi tới phase của nó. |
| ID | **VGD ID** (xem mục 3). |
| Nơi giữ danh bạ plugin | Trong repo (toàn bộ plugin đã nằm trong repo); VGD Center đã giữ danh mục plugin (`shared/vgd-center/catalog.json`) nên mở rộng danh mục đó để khai báo cầu nối. |

## 1b. Kiến trúc: BIM quản lý, plugin nhỏ dựng hình (định hướng, chủ dự án chốt 12/11/2026)

```text
 Plugin dựng hình (nhỏ, riêng)        Cầu nối          VGD_BIM (quản lý)
 Cabinet, thang, cửa, sàn, tường  ──►  hợp đồng dữ liệu ──►  ID, Category, Level, Room,
 (vẽ và sửa hình, tham số riêng)       + lệnh Tạo / Sửa      Material, Quantity, Schedule, Audit
```

Nguyên tắc đề xuất cho cầu nối (chi tiết viết thành đặc tả riêng ở cột mốc 1, trước khi có plugin dựng hình nào dùng nó):

1. **Hợp đồng bằng dữ liệu để ĐỌC.** Plugin dựng hình ghi vào dictionary `VGD_BIM` của đối tượng theo đặc tả công bố (category, loại, nguồn tạo `source_plugin` và `source_version`, trường bắt buộc), tham số riêng của plugin nằm trong dictionary riêng của plugin đó. BIM đọc được đối tượng của plugin chưa cài (chỉ không sửa được hình).
2. **Lệnh để SỬA do BIM gọi.** Khi người dùng muốn sửa hình một đối tượng, BIM tìm plugin nguồn (`source_plugin`), kiểm tra plugin đã cài và đủ phiên bản cầu nối, rồi gọi lệnh "Sửa đối tượng" của plugin đó với đối tượng đang chọn; plugin tự mở giao diện / công cụ sửa và dựng lại hình. Tương tự lệnh "Tạo mới" để BIM điều khiển việc dựng. Chưa cài plugin thì BIM báo rõ cần cài plugin nào (qua VGD Center).
3. **ID do ai gán:** quy tắc duy nhất. Đề xuất: plugin dựng hình gọi hàm chung của BIM để xin VGD ID khi tạo đối tượng; nếu BIM chưa cài thì để trống, BIM sẽ gán sau bằng nút "Gán VGD ID". Plugin dựng hình không tự sinh ID kiểu riêng.
4. **Danh bạ plugin (registry):** mỗi plugin khai báo mã, loại đối tượng nó dựng, lệnh Tạo mới và lệnh Sửa đối tượng đã có. BIM hiện nút "Sửa bằng <plugin>" trên dòng của đối tượng đó. VGD Center (đã biết plugin nào được cài) là nơi hợp lý để giữ danh bạ này.
5. **Có số phiên bản cầu nối** (`bridge_version`); plugin và BIM khác phiên bản thì báo rõ, không đoán.
6. **Một nguồn sự thật cho hình và tham số:** hình và tham số thuộc plugin dựng; thông tin quản lý (ID, tầng, phòng, vật liệu, khối lượng, trạng thái) thuộc BIM. BIM không sửa tham số hình của plugin khác.
7. **Phát triển dần:** cột mốc 1 viết đặc tả hợp đồng dữ liệu (ID, Category, nguồn tạo) để mọi plugin dựng hình về sau theo đúng; danh bạ và lệnh Tạo / Sửa (BIM gọi plugin) làm khi có plugin dựng hình đầu tiên (VGD_Cabinet hoặc plugin Phòng ở cột mốc 2, tùy cái nào tới trước). Trên menu Công cụ của VGD_BIM đã có chỗ giữ sẵn tên "Cầu nối dữ liệu".

Hệ quả cho kế hoạch: tường, sàn, cửa, thang, mái... **không phải việc của VGD_BIM**; mục "công cụ dựng đối tượng kiến trúc có tham số" ở cuối mục 5 được hiểu là các plugin riêng nối qua cầu nối.

## 2. VGD_BIM hiện có gì (đối chiếu với kế hoạch gốc)

Mức: **Có** / **Một phần** / **Rất ít** / **Chưa**.

| Hạng mục | Mức | Hiện trạng (tính đến 1.1.0-beta.61) |
|---|---|---|
| BIM Object, GUID | Một phần | Dùng mã bền `persistent_id` của SketchUp (không phải GUID riêng; món copy ra có mã mới). Có trường Mã (`code`). |
| Category | Một phần | 8 nhóm (`architecture`, `finish`, `furniture`, `electrical`, `equipment`, `plumbing`, `hvac`, `other`). Chưa có Wall / Door / Window... |
| Property | Một phần | 14 trường cố định (`core/schema.rb`) và cột thêm tay (3 kiểu). Chưa có kiểu dữ liệu (độ dài, danh sách chọn, tham chiếu đối tượng...). |
| Type / Instance | Một phần | "Họ" (định nghĩa SketchUp) đóng vai Type; mặt trước lưu ở định nghĩa. Chưa có dữ liệu Type riêng. |
| Classification | Một phần | 18 nhóm tag của 5D Auto Tag, đọc Loại IFC. Chưa có hệ mở VGD / IFC / OmniClass. |
| Material Data | Chưa | Chỉ có tên vật liệu. |
| Level | Rất ít | Trường chữ `floor`. |
| Room | Rất ít | Trường chữ `zone`, preset "Phòng & Khu vực". |
| Relationship | Rất ít | Chỉ quan hệ cha–con. |
| Quantity Engine | Có | Đếm, diện tích, mét dài, thể tích theo tag; cột Khối lượng tính. |
| Quantity Rule Engine | Một phần | Luật tag → cách tính. Chưa có công thức (trừ ô cửa, hao hụt). |
| Schedule | Một phần | Bảng khối lượng lọc / nhóm / sắp xếp, bấm dòng chọn và zoom tới món. Chưa có mẫu Door / Furniture / Finish. |
| Audit, Validation | Một phần | Tab Kiểm tra (schema, trường bắt buộc). Chưa có "Fix All", chưa có luật tự đặt. |
| Excel / PDF | Có | .xlsx kèm ảnh, trang PDF. |
| Change Tracking | Chưa | |
| IFC, Clash, Documentation, 4D | Chưa | |
| 5D | Một phần | Đơn giá, thành tiền trong bảng. |
| Tích hợp VGD_Cabinet | Chưa | |

## 3. ID trong BIM hoạt động thế nào (nghiên cứu)

**Hai loại ID khác nhau, phải tách riêng:**

1. **ID máy** (GUID, "mã định danh toàn cầu"): một số 128 bit sinh ngẫu nhiên, gần như không bao giờ trùng, gắn với đối tượng suốt đời, người dùng không đọc và không sửa. Dùng để *nhận ra đúng đối tượng* khi so sánh hai phiên bản, trao đổi với phần mềm khác, nối dữ liệu. Ví dụ: `GlobalId` của IFC, `UniqueId` của Revit, GUID của Archicad.
2. **Mã người dùng** (Element ID, Mark, Tag): tên ngắn do người dùng đặt (`D01`, `TB01`), đọc được trên bản vẽ và bảng thống kê, **có thể đổi**. Archicad tách hẳn hai thứ này: Element ID là nhãn do người dùng đặt, còn GUID là ID máy riêng.

**Chuẩn IFC:** `GlobalId` là chuỗi cố định **22 ký tự**, là GUID 128 bit nén bằng bảng 64 ký tự riêng của IFC (0-9, A-Z, a-z, `_`, `$`). Cách thông dụng: thêm 2 byte 0 vào đầu GUID rồi mã hóa, bỏ 2 ký tự đầu. Nếu GUID được lưu đủ 128 bit từ đầu thì sau này đổi sang IFC chính xác, không mất.

**Archicad:** có tuỳ chọn khi xuất IFC là giữ nguyên GUID (để so sánh hai phiên bản) hay sinh mới mỗi lần xuất (mỗi bản xuất thành một dự án riêng). Kết luận: GUID phải được **giữ ổn định** qua các lần lưu / xuất.

**Revit:** `ElementId` là số nguyên nội bộ của từng file (không ổn định giữa các file), còn `UniqueId` là mã ổn định dùng để nhận diện đối tượng; IFC GUID của Revit tính ra từ `UniqueId`. (Chi tiết cách ghép chưa xác minh trong tài liệu chính thức của Autodesk; không cần cho giai đoạn này.)

**SketchUp (nền tảng của chúng ta):**
- `entityID`: không ổn định giữa các lần mở file, **không dùng làm ID**.
- `persistent_id`: số nguyên, ổn định qua lưu / mở (từ SketchUp 2017). Từng gặp bị trùng khi dán đối tượng từ file khác vào.
- `guid` của Group / ComponentInstance: có từ lâu, ổn định, nhưng **copy có thể làm trùng** (đối tượng lồng bên trong group được copy từng báo trùng).
- Hệ quả: SketchUp copy luôn thuộc tính (dictionary) của đối tượng, nên ID do VGD ghi cũng **bị nhân đôi khi người dùng copy**. Phải có bước phát hiện trùng và sửa.

**Quyết định ID cho VGD_BIM (chờ xác nhận lần cuối ở cột mốc 1):**
- **VGD ID** = UUID 128 bit ngẫu nhiên (v4), lưu trong dictionary `VGD_BIM`, khóa `guid`, ở **bản đặt vào model (instance)**, không ở định nghĩa (định nghĩa là Type). Chỉ ghi khi người dùng bấm nút "Gán VGD ID".
- **Mã đối tượng** (`code`, đã có) là mã người dùng tự đặt, tách khỏi VGD ID. Kèm công cụ đặt mã hàng loạt theo mẫu (ví dụ `D01, D02...`, tái dùng bộ đổi tên hàng loạt).
- Hiển thị ngắn dạng `VGD-<LOẠI>-<6 ký tự đầu của ID>` cho người đọc (ví dụ `VGD-DOOR-8A42F1`, theo kế hoạch gốc), nhưng dữ liệu gốc là UUID đủ 128 bit để đổi sang IFC `GlobalId` 22 ký tự khi làm IFC.
- **Phát hiện trùng:** nếu hai đối tượng cùng `guid` thì báo trong tab Kiểm tra và có nút sửa. Quy tắc đề xuất: giữ ID cho đối tượng có `persistent_id` nhỏ nhất (cũ nhất), các bản còn lại nhận ID mới; luôn cho người dùng xem trước.
- **Không đổi ID khi** đổi tên, đổi tag, đổi vật liệu, di chuyển hay sửa hình học.

## 4. Phân loại ưu tiên

- **Ưu tiên 1 (nền tảng):** danh tính, tầng và phòng, vật liệu có dữ liệu, luật khối lượng mở rộng.
- **Ưu tiên 2:** schedule mẫu, Audit "Fix All" và luật kiểm tra tự đặt, Type / Instance dữ liệu, Classification mở, so sánh hai phiên bản file, tích hợp VGD_Cabinet.
- **Ưu tiên 3:** xuất / nhập IFC, Documentation (mặt bằng, mặt cắt, bản vẽ).
- **Ưu tiên 4:** Clash, 4D, 5D đầy đủ, cộng tác.

## 5. Cột mốc

Quy tắc chung mỗi bản (theo `CLAUDE.md` của repo): viết kiểm tra với dữ liệu sai trước; mỗi lần đổi dữ liệu ghi trong file SketchUp phải có chuyển đổi cho file cũ (`schema_version`) và **không làm hỏng file của người dùng**; chỉ ghi vào model khi người dùng bấm nút, một bước hoàn tác, bỏ qua đối tượng bị khóa; cập nhật README, hướng dẫn, ghi chú phát hành, `VALIDATION.md`; gửi RBZ kèm SHA-256 cho người dùng thử; ghi rõ phần chưa thử trong SketchUp thật. Người dùng thử xong mới sang cột mốc sau.

### Cột mốc 1 — Danh tính và Category

Làm: VGD ID, Mã đối tượng, phát hiện và sửa trùng, mở rộng Category cho kiến trúc (Wall, Floor, Ceiling, Door, Window, Column, Beam, Stair) và nội thất (Furniture, Cabinet, Sanitary, Lighting, Equipment, Generic), chuyển `schema_version` 1 → 2.
- 1a (**xong ở beta.62**, ghi ở dictionary riêng `VGD_BIM_ID` thay vì `VGD_BIM` để không làm đổi nghĩa "món đã có dữ liệu VGD"; trùng mới phát hiện trong bảng, tab Kiểm tra làm ở 1b): `guid` + nút "Gán VGD ID" (món đang chọn / cả bảng, xem trước số món sẽ gán), cột VGD ID trong bảng, kiểm tra trùng trong tab Kiểm tra.
- 1b: nút sửa ID trùng (xem trước); đặt Mã đối tượng hàng loạt theo mẫu.
- 1c: Category mở rộng + bảng ánh xạ 8 nhóm cũ sang nhóm mới (không mất dữ liệu cũ); migration `schema_version`.
- Kiểm tra: dữ liệu sai, copy trùng, file cũ không có `guid`, hoàn tác một bước, món khóa.

### Cột mốc 2 — Tầng và Phòng (có hình, 3D)

- 2a **Tầng (Level):** danh sách tầng lưu trong model (tên, cao độ, chiều cao). Gán món vào tầng (nhãn, **không dời hình học**). Cột Tầng, nhóm theo tầng, ẩn / hiện theo tầng.
- 2b **Phòng (Room):** phòng trong BIM là **khoảng không gian (thể tích) được bao bởi sàn, tường, trần**, không phải bản thân tường / sàn / trần (như Room của Revit, Zone của Archicad). Dữ liệu phòng do VGD_BIM quản lý: viền (đa giác), tên, mã, tầng, cao độ trần, vật liệu hoàn thiện của sàn / tường / trần, trạng thái. VGD_BIM tính **diện tích sàn, chu vi, thể tích, diện tích trần, diện tích tường hoàn thiện** (chu vi x cao, trừ ô cửa khi đã có dữ liệu cửa). **Khối 3D của phòng do một plugin nhỏ dựng riêng** (đùn từ viền lên cao độ trần, nằm trên tag riêng, tắt / bật được), BIM điều khiển qua cầu nối; sàn, tường, trần thật là các đối tượng khác do plugin sàn / tường / trần dựng. Cần phiên thiết kế plugin Phòng riêng khi tới cột mốc này.
- 2c **Món thuộc phòng:** tự gợi ý theo vị trí (tâm đáy của món nằm trong viền phòng), người dùng xác nhận, có thể gán tay. Cột Phòng, tổng khối lượng theo phòng, Finish Schedule.
- Cảnh báo: dựng khối phòng **thêm đối tượng mới vào model của người dùng**. Chỉ tạo khi bấm nút, một bước hoàn tác, đặt trên tag riêng và có thể khóa.

### Cột mốc 3 — Vật liệu có dữ liệu và luật khối lượng

Trạng thái: 3a, 3b và hao hụt % của 3c đã làm (beta.67). Còn lại của 3c: trừ ô cửa / cửa sổ (cần quan hệ món–tường) và công thức đơn giản.

- 3a Thư viện vật liệu (mã, tên, hãng, sản phẩm, độ dày, đơn vị, đơn giá, quy cách), lưu trên máy, nhập / xuất; nối với vật liệu SketchUp theo tên.
- 3b Nối vật liệu → khối lượng → thành tiền.
- 3c Luật khối lượng mở rộng: hao hụt %, trừ ô cửa / cửa sổ khỏi tường, công thức đơn giản. Không viết cứng trong mã.

### Cột mốc 4 — Schedule mẫu, Audit và Validation

Trạng thái: 4a đã có sẵn trong preset (Cửa & Cửa sổ, Nội thất, Hoàn thiện...); chưa thêm mẫu Cabinet riêng vì chờ chốt cột cho tủ. Một phần 4b đã làm (beta.69): báo món thiếu VGD ID và nút gán hàng loạt. 4c đã làm (beta.70): luật cột + so sánh + giá trị, lưu trong file SketchUp, chạy trên Bảng khối lượng. Còn lại: Fix All khác và điều kiện lọc theo nhóm món.

- 4a Mẫu Door / Window / Furniture / Cabinet / Finish Schedule lưu như preset; bấm dòng chọn và zoom tới món (đã có).
- 4b Audit: liệt kê lỗi theo mức INFO / WARNING / ERROR, "Fix All" có xem trước.
- 4c Luật kiểm tra tự đặt (ví dụ cửa rộng < 700 thì cảnh báo; món chưa có tầng / phòng / ID).

Trạng thái cột mốc 5: so sánh phiên bản (mốc dữ liệu bảng) đã làm ở beta.71; preset Tủ đã thêm. Chưa làm: Type/Instance riêng, Classification mở, tích hợp VGD_Cabinet (cần phiên thiết kế riêng với chủ dự án).

### Cột mốc 5 — Type, Classification, so sánh phiên bản, VGD_Cabinet

- 5a Type / Instance có dữ liệu Type riêng (sửa Type thì các Instance cập nhật).
- 5b Classification mở: VGD, IFC, OmniClass, tuỳ chỉnh; ánh xạ giữa các hệ.
- 5c **So sánh hai phiên bản file** theo VGD ID (thêm / bớt / sửa / không đổi), xuất báo cáo. Giải quyết luôn nhu cầu gửi file đi rồi nhận lại.
- 5d Tích hợp VGD_Cabinet: tủ tạo ra đã có dữ liệu BIM. Cần phiên thiết kế riêng với chủ dự án trước khi làm.

### Sau các cột mốc trên (mỗi mục lớn cần đặc tả riêng)

Relationship đầy đủ (Object → Object / Room / Level / Type / Material), xuất / nhập IFC (dùng VGD ID đổi sang `GlobalId`), Documentation (mặt bằng, mặt cắt, mặt đứng, chi tiết, khung tên), Clash Detection, 4D, 5D đầy đủ, cộng tác, công cụ dựng đối tượng kiến trúc có tham số (tường, sàn, cửa, cầu thang).

## 6. Rủi ro

- **Ghi thêm dữ liệu vào file SketchUp:** chỉ khi người dùng bấm nút, một bước hoàn tác, không ghi vào món bị khóa.
- **ID bị nhân đôi khi copy:** xử lý ở cột mốc 1 trước khi làm các phần dựa vào ID (so sánh phiên bản, IFC).
- **Phòng 3D thêm hình vào model:** xem cảnh báo ở cột mốc 2.
- **Chưa thử trong SketchUp thật:** nhiều tính năng đã làm vẫn chờ xác nhận (xem `plugins/VGD_BIM/VALIDATION.md`). Mỗi cột mốc cần người dùng thử trước khi sang cột mốc sau.
- **Dữ liệu cũ:** mọi thay đổi schema phải có chuyển đổi (nguyên tắc 12 của kế hoạch gốc) và không đổi ý nghĩa dữ liệu cũ.
- **Quy mô:** đây là chương trình nhiều tháng; không làm gộp nhiều cột mốc trong một bản.

## 7. Câu hỏi còn mở (quyết ở đầu cột mốc liên quan)

1. Cột mốc 1: quy tắc chọn đối tượng giữ ID khi trùng (đề xuất: `persistent_id` nhỏ nhất) có hợp lý không.
2. Cột mốc 2: viền phòng lấy bằng cách nào là chính: chọn mặt sàn có sẵn, vẽ đa giác, hay tự dò từ các tường vây quanh.
3. Cột mốc 2: tầng có tự gợi ý theo cao độ Z của món không, hay chỉ gán tay.
4. Cột mốc 5d: cách VGD_Cabinet và VGD_BIM trao đổi dữ liệu.
5. ~~Phòng 3D~~ **Đã chốt:** khối phòng do plugin nhỏ dựng riêng, BIM điều khiển (xem cột mốc 2b). Còn mở: tên và phạm vi plugin Phòng (chỉ dựng khối hay cả vẽ viền).
6. Cầu nối: ai gán VGD ID khi plugin dựng hình tạo đối tượng (đề xuất mục 1b điểm 3); danh bạ mở rộng từ `shared/vgd-center/catalog.json` (đã chốt hướng, còn thiết kế chi tiết).

## 8. Trạng thái

| Cột mốc | Trạng thái |
|---|---|
| 1 Danh tính và Category | **Xong ở beta.63** (1a VGD ID, 1b Mã đối tượng hàng loạt và ID trùng ở tab Kiểm tra, 1c danh mục mở rộng). Chủ dự án chốt không làm chuyển đổi dữ liệu cũ nên không đổi `schema_version`; chờ người dùng thử trong SketchUp thật |
| 2 Tầng và Phòng | Đang làm: 2a Tầng xong (beta.64: danh sách tầng trong model, nhãn ở dictionary `VGD_BIM_LOC`, gợi ý theo cao độ). Câu hỏi mở đã chốt 12/11/2026: viền phòng lấy từ mặt sàn hoặc đa giác đóng được chọn (dò tường làm sau); tầng gợi ý theo Z rồi người dùng xác nhận; khối phòng do plugin `VGD_Room` dựng (chỉ khối), dữ liệu và diện tích do VGD_BIM tính. 2b dữ liệu xong ở beta.65 (danh sách phòng trong model, viền đọc từ mặt sàn, diện tích / chu vi / thể tích / tường / trần, gán món theo vị trí). `VGD_Room` 0.1.0-beta.1 dựng khối phòng và cầu nối `room_volume` xong ở beta.66 (BIM gọi plugin, `docs/vgd_bim/BRIDGE.md`). Còn: nhận viền dò từ tường, mặt có lỗ, lệnh `edit` có giao diện riêng, thêm `VGD_Room` vào catalog của Center khi phát hành |
| 3 Vật liệu và luật khối lượng | Chưa bắt đầu |
| 4 Schedule, Audit, Validation | Chưa bắt đầu |
| 5 Type, Classification, so sánh phiên bản, VGD_Cabinet | Chưa bắt đầu |

## 9. Nguồn tham khảo

- IFC `IfcGloballyUniqueId` (buildingSMART): <https://standards.buildingsmart.org/IFC/RELEASE/IFC4_1/FINAL/HTML/schema/ifcutilityresource/lexical/ifcgloballyuniqueid.htm>
- Diễn đàn buildingSMART về cách mô tả GlobalId: <https://forums.buildingsmart.org/t/ifcgloballyuniqueids-spec-description-is-incorrect-proposal-to-simplify/1083>
- Revit `UniqueId` và IFC GUID: <https://blog.autodesk.io/uniqueid-dwf-and-ifc-guid/>, <https://jeremytammik.github.io/tbc/a/0104_uniqueid_dwf_ifc_guid.htm>
- Archicad, thuộc tính IFC GlobalId: <https://help.graphisoft.com/AC/22/INT/_AC22_Help/115_IFC/115_IFC-41.htm>
- SketchUp, GUID và `persistent_id`: <https://forums.sketchup.com/t/guid-vs-persistent-id-for-groups-and-component-instances/83638>
- SketchUp, `persistent_id` trùng khi dán từ file khác: <https://forums.sketchup.com/t/duplicate-persistent-id-not-fixed-by-fix-problems-in-sketchup-2017/141220>
- SketchUp, GUID trùng khi copy group lồng nhau: <https://forums.sketchup.com/t/non-unique-group-guid-in-grouped-entities-after-copying-a-group/19286>
