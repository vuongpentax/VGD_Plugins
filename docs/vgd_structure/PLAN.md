# Kế hoạch plugin VGD Structure (dựng phần thô theo lưới trục)

Trạng thái: **bản kế hoạch để chủ dự án duyệt, chưa có mã.** Soạn 17/11/2026.
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
| Cột | tại giao điểm trục, từ `Ei` lên **đáy sàn tầng trên** (`Ei+1 - t`) | đặt tâm lên trục, có độ lệch tâm tùy chọn |
| Dầm | dọc nhịp, **giữa hai mặt cột** (không chui vào cột), đỉnh dầm = đáy sàn, dầm treo dưới sàn | không chồng sàn |
| Tường | dọc nhịp, giữa hai mặt cột, từ `Ei` lên đáy dầm (hoặc đáy sàn nếu nhịp không có dầm) | dày, lệch tâm so với trục tùy chọn |
| Trần | trong ô, ở cao độ nhập, mỏng (tấm), tag riêng | chưa nối với treo / khung trần |

Mặc định không có chồng khối nên cộng khối lượng trong VGD BIM là đúng. Quy tắc này nằm ở một chỗ duy nhất trong mã (bảng hằng số có giải thích) để dễ đổi khi bạn muốn quy ước khác (ví dụ dầm nằm trong chiều dày sàn).

## 5. Dữ liệu và cầu nối với VGD BIM

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

## 9. Câu hỏi còn mở (cần bạn chốt trước cột mốc 0)

1. **Tên plugin:** "VGD Structure" (đề xuất), hay tên khác (VGD Frame, VGD Core...)?
2. **Quy ước dầm so với sàn:** dầm treo dưới sàn, không chồng (đề xuất), hay dầm nằm trong chiều dày sàn (theo cách vẽ phổ biến ở Việt Nam)? Ảnh hưởng cách tính khối lượng bê tông.
3. **Tầng:** dùng danh sách tầng riêng của plugin có gợi ý từ BIM (đề xuất), hay BIM là nguồn duy nhất?
4. **Trục cột có lệch tâm** (cột hoặc tường không đặt giữa trục) có cần ngay từ bản đầu không, hay để sau?
5. **Mặt bằng đề xuất:** gom theo tầng giống nhau ("tầng 2 đến 5 như nhau") có cần sớm không?

Không có việc nào trong kế hoạch này tự động chạy hay sửa model; mọi thứ đều xem trước rồi mới dựng.
