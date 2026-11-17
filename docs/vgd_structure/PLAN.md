# Kế hoạch plugin VGD Structure (dựng phần thô theo lưới trục)

Trạng thái: **kế hoạch đã chốt các câu hỏi mở (17/11/2026), chưa có mã.** Cột mốc 0 (khung), 1 (lưới trục) và 2 (tầng và cột, kèm loại cột và sao chép lựa chọn giữa tầng) đã làm xong ở `plugins/VGD_Structure`; các cột mốc 3 (dầm), 4 (tường), 5 (sàn và trần) 6 (đề xuất bán tự động, kiểm tra, dựng tất cả; không làm overlay xem trước trong model theo quyết định chủ dự án) và 7 (nối VGD BIM: VGD ID, khối lượng chính xác, sửa từ BIM) đã làm xong, chủ dự án quyết định (17/11/2026) **chưa phát hành**: còn nhiều phần phải làm (mục 11). Cột mốc phát hành dời xuống cuối giai đoạn 2.
Các lựa chọn dưới đây đã được chủ dự án chốt ở phiên trao đổi: trục nhập ngay trong plugin; nội suy **bán tự động có xem trước**; plugin mới lo phần thô, **VGD Room giữ nguyên**; bản đầu dựng **khối thô theo lưới, chưa khoét cửa**.

## 1. Mục tiêu

Người dùng nhập **lưới trục** (trục ngang A, B, C... và trục dọc 1, 2, 3... kèm khoảng cách) và **danh sách tầng** (cao độ). Từ đó plugin **đề xuất** cột, dầm, tường, sàn, trần; người dùng xem trước, bỏ / thêm, rồi dựng thành khối 3D trong model, trong **một bước hoàn tác**. Khối dựng ra mang dữ liệu để VGD BIM đọc và tính khối lượng (đối tượng thật, khác khối phòng của Room).

Không làm trong bản đầu: ô cửa / ô trống trên tường, giao cắt phức tạp, mái dốc, cầu thang, móng, thép, nhập CAD, lưới xiên hoặc cong.

## 2. Vì sao tách plugin riêng

- Room dựng **khoảng không gian**; plugin này dựng **vật thể kết cấu**. Hai thứ khác bản chất, BIM xử lý khác (khối phòng bị loại khỏi bảng khối lượng, cột / dầm / tường thì tính).
- Đúng hướng đã chốt ở `docs/vgd_bim/ROADMAP.md` mục 1b: BIM quản lý, plugin nhỏ dựng hình, nối qua cầu nối.
- Sau này Room có thể **tự dò viền phòng từ tường của plugin này** (đúng việc "Room bước 2" đang chờ).

## 3. Cách hoạt động (mô tả cho người dùng)

1. **Khai báo lưới trục:** bảng nhập "trục ngang: A 0, B 4200, C 3600..." và tương tự trục dọc. Có hình xem trước.
2. **Khai báo tầng:** tên, cao độ sàn, có thể lấy gợi ý từ danh sách tầng của VGD BIM.
3. **Quy cách mặc định:** cột (rộng x sâu hoặc tròn), dầm (rộng x cao), tường (dày), sàn (dày), trần (cao độ, dày).
4. **Đề xuất (nội suy):** bản vẽ phẳng của lưới hiện các **nhịp** (đoạn trục giữa hai giao điểm) và **ô** (vùng giữa các trục). Plugin gợi ý sẵn: cột ở mọi giao điểm, dầm ở mọi nhịp, tường ở các nhịp biên, sàn và trần ở mọi ô. Người dùng bấm từng nhịp / ô để bật tắt hoặc đổi loại, chọn tầng áp dụng.
5. **Xem trước** trong model (khung mờ, không đổi model) → bấm **Dựng**.
6. **Sửa thông số rồi dựng lại:** đổi khoảng cách trục, quy cách hay cao độ rồi bấm Dựng lại; dữ liệu của plugin là nguồn đúng, hình được dựng lại (giữ VGD ID cũ).

## 4. Quy tắc hình học (tránh khối chồng nhau để khối lượng không bị tính đôi)

Cho mỗi tầng i có cao độ mặt sàn `Ei`, tầng trên `Ei+1`, dày sàn `t`:

| Đối tượng | Vị trí | Ghi chú |
|---|---|---|
| Sàn | phủ cả ô, mặt trên tại `Ei`, dày `t` xuống dưới | sàn phủ trên cột và dầm |
| Cột | tại giao điểm trục, từ `Ei` lên **đáy sàn tầng trên** (`Ei+1 - t`) | **luôn nằm lọt trong khung lưới**: cột giữa đặt tâm trên giao điểm; cột biên có mặt ngoài **tiếp giáp trục biên** (tâm dời vào trong nửa kích thước); cột góc tiếp giáp cả hai trục biên (xem 4.1) |
| Dầm | dọc nhịp, **giữa hai mặt cột** (không chui vào cột), đỉnh dầm = đáy sàn, dầm treo dưới sàn | không chồng sàn; dầm biên cũng tiếp giáp trục biên như cột biên |
| Tường | dọc nhịp, giữa hai mặt cột, từ `Ei` lên đáy dầm (hoặc đáy sàn nếu nhịp không có dầm) | tường biên: mặt ngoài tiếp giáp trục biên, dày vào trong; tường giữa: tâm trên trục |
| Trần | trong ô, ở cao độ nhập, mỏng (tấm), tag riêng | chưa nối với treo / khung trần |

### 4.1. Quy ước vị trí cột (chủ dự án chốt 17/11/2026)

Lưới trục quyết định cột nằm đâu và **cột không bao giờ nhô ra ngoài khung lưới**:
- cột **giữa** (không nằm trên trục biên): tâm đúng giao điểm trục;
- cột **biên** (nằm trên một trục biên): mặt ngoài tiếp giáp trục biên, tâm dời vào trong nửa kích thước cột theo phương vuông góc với trục biên đó;
- cột **góc**: tiếp giáp cả hai trục biên.
Mỗi cột vẫn có thể được đổi tay sang "tâm trên trục" ở bước xem trước nếu cần. Tường và dầm ở biên theo cùng quy ước (mặt ngoài tiếp giáp trục biên).

Mặc định không có chồng khối nên cộng khối lượng trong VGD BIM là đúng. Quy tắc này nằm ở một chỗ duy nhất trong mã (bảng hằng số có giải thích) để dễ đổi khi bạn muốn quy ước khác (ví dụ dầm nằm trong chiều dày sàn).

## 5. Dữ liệu và cầu nối với VGD BIM

- **Tầng:** mỗi tầng là **riêng** (cao độ sàn khác nhau, quy cách và phần đề xuất riêng từng tầng, không có "gom tầng giống nhau"). Danh sách tầng là của plugin (không phụ thuộc danh sách tầng của BIM); BIM **đọc** tầng và thông số của từng khối (qua `VGD_BIM_SOURCE.ref` và dictionary `VGD_STRUCT` của khối) để lập bảng khối lượng đúng và gán tầng, không sửa danh sách của plugin.
- **Dữ liệu của plugin** ở dictionary riêng `VGD_STRUCT` của model (JSON: lưới, tầng, quy cách mặc định, danh sách đối tượng được chọn): đây là "nguồn đúng", không lẫn với dữ liệu BIM.
- **Mỗi khối dựng ra** là Group hoặc ComponentInstance: nhóm theo loại, tên có nghĩa (ví dụ `C-B2-T1` = cột tại B-2 tầng 1), tag riêng theo loại (Cột, Dầm, Tường, Sàn, Trần), ghi `VGD_BIM_SOURCE` (`plugin = vgd_structure`, `kind = column | beam | wall | slab | ceiling`, `ref` = mã nhịp / ô / giao điểm) và nhận **VGD ID từ BIM** theo đúng hợp đồng trong `docs/vgd_bim/BRIDGE.md`.
- **Cột cùng quy cách và cùng chiều cao dùng chung một component definition** (nhẹ model, bảng BIM đếm được số lượng).
- **BIM tính khối lượng bình thường** (khác khối phòng bị loại khỏi bảng): thể tích, diện tích, thể loại. Cần bổ sung nhỏ ở BIM: đọc `kind` của plugin này để gợi ý hạng mục (Cột / Dầm / Tường / Sàn / Trần) và gán tầng từ `ref`.
- **Lệnh cầu nối** (`bridge_version 1`, thêm lệnh mới): `structure_grid` loại `build` / `find` / `edit` để BIM gọi dựng lại hoặc mở sửa khi người dùng chọn một cột trong bảng.
- Plugin **không** phụ thuộc BIM để chạy: BIM chưa cài thì plugin vẫn dựng khối, ID để trống và gán sau.

## 6. Cấu trúc mã (theo quy ước repo)

- Tên extension **VGD Structure**, loader `vgd_structure.rb`, thư mục `vgd_structure/`, toolbar `VGD STR`, menu Extensions → VGD → VGD Structure (có mục **Tải lại code**). Namespace `VGD::Structure`. Id Center: `structure` (thêm vào `shared/vgd-center/catalog.json` khi phát hành).
- `core/` logic thuần, test được ngoài SketchUp: `grid.rb` (lưới, giao điểm, nhịp, ô), `levels.rb`, `specs.rb` (quy cách + kiểm tra dữ liệu), `planner.rb` (nội suy đề xuất), `geometry_rules.rb` (bảng quy tắc mục 4 → hộp / đa giác mm), `ids.rb`.
- `builder/` phần gọi SketchUp: dựng khối, component dùng chung, tag, dictionary, `Data.transaction` một bước hoàn tác, **xem trước** bằng overlay (SketchUp 2023+) hoặc tool vẽ tạm (2022).
- `ui/` HtmlDialog (theo theme VGD): tab Lưới trục, Tầng, Quy cách, Mặt bằng đề xuất (bản vẽ phẳng bấm bật tắt nhịp / ô).
- `dev/` test và `package.py`; `CLAUDE.md`, `README.md` theo mẫu; `docs/vgd_structure/` đặc tả.
- Đơn vị: dữ liệu lưu **mm**, đổi sang inch SketchUp ở đúng một chỗ (`.mm`).

## 7. Các cột mốc

Mỗi cột mốc đều có test tự động và một bản RBZ để bạn thử trong SketchUp; việc nào chỉ kiểm được trong SketchUp thật thì ghi "chưa xác minh".

| # | Cột mốc | Kết quả | Kiểm tra |
|---|---|---|---|
| 0 | Khung plugin và đặc tả | Loader, menu, toolbar, Tải lại code, README, CLAUDE.md; viết đặc tả dữ liệu `VGD_STRUCT` và quy tắc mục 4 | `tests/test_vgd_conventions.rb`, test tải lại |
| 1 | Lưới trục | Nhập lưới trục, hiện trong model bằng guide / nhãn A, B, 1, 2 (vật thể nhẹ, tag riêng), tính giao điểm, nhịp, ô | test logic lưới (giao điểm, ô, lưới sai bị từ chối), xem trong SketchUp |
| 2 | Tầng và cột | Danh sách tầng; dựng cột ở giao điểm đã chọn; cột dùng chung definition | test hộp cột, độ cao, một bước hoàn tác |
| 3 | Dầm | Dầm theo nhịp, giữa hai mặt cột, treo dưới sàn | test không chồng khối, nhịp ngắn hơn cột bị báo |
| 4 | Tường | Tường theo nhịp, dày và lệch tâm, lên đáy dầm | test cao độ theo có / không dầm |
| 5 | Sàn và trần | Sàn phủ ô, trần theo ô | test diện tích và thể tích khớp tính tay |
| 6 | Đề xuất bán tự động | Mặt bằng đề xuất bấm bật tắt, xem trước trong model, dựng một lần | test planner (đề xuất đúng, bỏ nhịp), test giao diện Playwright |
| 7 | Nối với VGD BIM | Cầu nối `structure_*`, VGD ID từ BIM, BIM đọc `kind` để gán hạng mục và tầng, Sửa từ BIM | test cầu nối, test BIM đọc khối của plugin |
| 8 | Hoàn thiện phát hành | Thêm vào catalog Center, tài liệu hướng dẫn, bản ổn định | theo quy trình phát hành trong `CLAUDE.md` gốc |

Gợi ý làm theo thứ tự 0 → 1 → 2 và dừng cho bạn thử trong SketchUp sau cột mốc 2, vì lưới và cột là nền của mọi thứ còn lại.

## 8. Rủi ro và cách giảm

| Rủi ro | Cách giảm |
|---|---|
| Dựng cả tòa nhà một lần làm treo SketchUp | dựng theo tầng; dùng chung component; hiện tiến độ; giới hạn số khối mỗi lần (có cảnh báo trước) |
| Khối chồng nhau, khối lượng tính đôi | quy tắc hình học mục 4, test kiểm tra không chồng |
| Người dùng sửa tay khối rồi bấm dựng lại bị mất | cảnh báo trước khi dựng lại nếu phát hiện khối đã bị sửa (so với hình dự kiến); không xóa khối do người khác vẽ |
| Mô hình có điểm gốc và hướng bắc lệch | lưới có điểm gốc (x, y) và góc xoay 0 độ ở bản đầu; lưới xiên làm sau |
| Dữ liệu plugin và hình lệch nhau | dữ liệu plugin là nguồn đúng; nút "Dựng lại" và bản so sánh |
| Xung đột tên với Room, BIM | dictionary riêng `VGD_STRUCT`, tag riêng, không ghi vào dictionary của plugin khác |
| Làm quá to ở bản đầu | mỗi cột mốc là một bản phát hành nhỏ, dừng sau cột mốc 2 để duyệt |
| Chưa thử được trong SketchUp thật trong môi trường này | chỉ kiểm bằng giả lập; mọi cột mốc gửi RBZ để bạn thử, ghi rõ phần chưa xác minh |

## 9. Các quyết định đã chốt (17/11/2026)

1. **Tên:** VGD Structure.
2. **Dầm** treo dưới sàn, không chồng khối.
3. **Tầng:** plugin có danh sách tầng riêng; BIM đọc thông số từ khối để lập bảng khối lượng đúng.
4. **Vị trí cột:** theo 4.1 (lọt trong khung lưới; cột biên tiếp giáp trục biên, cột giữa ở giữa). Hướng 4.1 là cách hiểu của tôi về lời chốt; sẽ chỉnh nếu chưa đúng ý.
5. **Mỗi tầng riêng**, không gom tầng.

Còn mở (không chặn cột mốc 0): kích thước cột mặc định theo tầng (ví dụ cột tầng trệt lớn hơn tầng trên) và cách đặt lại tay vị trí từng cột; sẽ hỏi khi tới cột mốc 2.

Không có việc nào trong kế hoạch này tự động chạy hay sửa model; mọi thứ đều xem trước rồi mới dựng.

## 10. Đối chiếu với VTBim (17/11/2026)

Nguồn: README công khai của `github.com/mencom95/vtbim`. Repo đó **chỉ có README và link tải bản .rbz đã đóng gói, không có mã nguồn, không có giấy phép mở**, nên VGD **không dùng mã hay file của VTBim**; chỉ tham khảo ý tưởng từ phần mô tả tính năng, tự thiết kế theo hệ VGD. Chủ dự án chốt hướng này.

| Tính năng VTBim (theo mô tả) | Quyết định cho VGD Structure | Ở đâu |
|---|---|---|
| Lưới trục có ký hiệu, tự động | Đã làm (nhập tay, ký hiệu theo chuẩn); "lưới tự động" từ cột có sẵn để sau | cột mốc 1 (xong) |
| Cột, dầm, sàn tham số, đổi tham số thì dựng lại | Trùng hướng đã chốt: dữ liệu là nguồn đúng, dựng lại theo dữ liệu | mục 3, 7 |
| **Loại phần tử** (định nghĩa dùng lại, ví dụ cột C30x30, dầm D20x40) | **Nên thêm**: thư viện loại có tên, mỗi tầng chọn loại thay vì nhập số lại; dùng chung component | đề xuất đưa vào cột mốc 2 |
| Tầng, sao chép phần tử giữa các tầng | Giữ "mỗi tầng riêng"; thêm nút **sao chép lựa chọn từ tầng khác** (không gom, vẫn sửa riêng được) | đề xuất cột mốc 2 hoặc 6 |
| Tường nhiều lớp, nối tường chữ L, T tự động | Tường nhiều lớp để sau; **nối L / T** làm sau cột mốc 4 (bản đầu tường dừng ở mặt cột) | sau cột mốc 4 |
| Tự khoét ô cửa trên tường | Ngoài phạm vi bản đầu (đã chốt); làm khi có plugin cửa | sau cột mốc 8 |
| Bảng thống kê cột, dầm tự cập nhật | VGD BIM đã làm bảng khối lượng; chỉ cần BIM đọc đúng dữ liệu (cột mốc 7); thêm tóm tắt số lượng theo loại trong cửa sổ plugin | cột mốc 7 |
| Kiểm tra tài liệu (chồng, thiếu) | Thêm **kiểm tra kết cấu** (nhịp ngắn hơn cột, cột lệch lưới, tầng thiếu cao độ) trong xem trước | cột mốc 6 |
| Nhập DWG / DXF | Đã hoãn (nhập lưới từ CAD) | sau cột mốc 8 |
| Phòng / vùng | Là việc của VGD Room (có thể dò viền từ tường của plugin này) | ngoài plugin |
| Mặt bằng, mặt đứng, mặt cắt, trình bày, xuất PDF/DWG, thang, mái, cửa, thiết bị vệ sinh, MCP | Không thuộc phần thô; nếu cần sẽ là plugin / hệ khác | ngoài phạm vi |

Việc cần chủ dự án duyệt trước cột mốc 2: có nhận hai bổ sung "loại phần tử" và "sao chép lựa chọn từ tầng khác" hay không.


## 11. Giai đoạn 2 (chủ dự án chốt 17/11/2026): hoàn thiện công trình theo cấu trúc tính năng của VTBim

Cấu trúc tính năng lấy từ README công khai của VTBim (chỉ ý tưởng, không dùng mã). Các câu hỏi đã chốt: **làm cửa đi, cửa sổ trước rồi tới hoàn thiện**; cửa ở mức **lỗ mở + khung và cánh đơn giản theo tham số**; tất cả **nằm trong VGD Structure** (thêm tab), vì cửa phải sửa hình học tường và lớp hoàn thiện bám theo tường, sàn.

| # | Cột mốc | Nội dung chính | Kiểm tra |
|---|---|---|---|
| 8 | **Cửa đi và cửa sổ** (ĐÃ LÀM, 0.9.0-beta.1) | Loại cửa (đi / sổ: rộng, cao, cao ngưỡng); đặt cửa lên tường theo vị trí trên tường; tường **tự khoét lỗ**; khung và cánh đơn giản theo tham số; tag A. DOOR / A. WINDOW; BIM đếm theo loại và trừ lỗ mở khỏi diện tích tường | test kế hoạch (lỗ nằm trong tường, không chồng nhau, dưới dầm), test dựng, test BIM |
| 9 | Tường nhiều lớp và nối góc | Loại tường có lớp cấu tạo (gạch, vữa, ốp); nối góc L / T (tường dừng ở mặt tường vuông góc thay vì mặt cột khi không có cột) | test hình học nối góc |
| 10 | **Hoàn thiện** | Sàn hoàn thiện (lát), tường hoàn thiện (ốp, sơn) bám mặt tường kể cả quanh lỗ cửa, trần hoàn thiện; tag A. FINISHING FLOOR / WALL / CEILING; khối lượng theo vật liệu | test diện tích trừ lỗ, không chồng khối |
| 11 | Cầu thang và lan can | Thang theo tham số (vế, chiếu nghỉ), lỗ mở sàn cho thang, lan can liên tục | test bậc, lỗ sàn |
| 12 | Mái | Mái dốc / mái bằng từ viền tường, ban đầu mái phẳng và dốc đơn giản | test độ dốc, viền |
| 13 | Khác | Vách kính, thiết bị vệ sinh, nhập lưới từ CAD, nối phòng (VGD Room tự dò viền từ tường) | theo từng việc |
| 14 | Phát hành | Catalog Center, hướng dẫn, chốt bản ổn định cho Structure, BIM, Room | quy trình trong `CLAUDE.md` gốc |

Mỗi cột mốc có test và RBZ như trước; phần chỉ kiểm được trong SketchUp thật ghi rõ "chưa xác minh". Cột mốc 8 xong thì dừng cho chủ dự án thử trước khi làm cột mốc 9.
