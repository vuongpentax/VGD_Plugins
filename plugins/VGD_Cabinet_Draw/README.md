# VGD Cabinet Draw 1.0.1 (beta.1)

VGD Cabinet Draw là extension SketchUp (2022 trở lên) cho quy trình dựng tủ bán tự động: người dùng chủ động chọn mặt trước, vị trí đợt/vách, cách chia cánh, hướng mở, ngăn kéo và tay nắm. Preview hiện trong viewport; mỗi công cụ chỉ ghi hình học vào model khi người dùng click hoặc nhấn Enter.

Extension đăng ký độc lập với VGD_Cabinet (cũ, ở `plugins/VGD_Cabinet`): dùng dictionary model `VGD_Cabinet_Draw` và thư mục dữ liệu `%APPDATA%/VGD/SketchUp/VGD_Cabinet_Draw`, không đọc dictionary hay preset của bản cũ.

**Trạng thái:** bản 1.0.1-beta.2 (thử; bản ổn định gần nhất 1.0.0), cùng mã với beta.70; khác beta.70 ở tên extension (nay là "VGD Cabinet Draw", xem `RELEASE_NOTES_v1.0.0.md`). Kiểm thử tự động bằng giả lập SketchUp (`test/`); chưa kiểm thử thủ công đầy đủ trong SketchUp thật, chỉ có vài mục người dùng đã xác nhận (xem "Điều chưa kiểm chứng").

## Cài và đóng gói

- Đóng gói: `python3 dev/build_release.py` (chạy từ thư mục plugin) tạo `outputs/VGD_Cabinet_Draw_<phiên bản>.rbz` và bản source ZIP cùng phiên bản. `outputs/` bị `.gitignore` bỏ qua, không lưu trong git.
- Cài: Extensions → Extension Manager → Install Extension, chọn file `.rbz` (ví dụ `VGD_Cabinet_Draw_1.0.1-beta.2.rbz`). Gói gồm `vgd_cabinet_draw.rb`, `vgd_cabinet_draw/main.rb` và toàn bộ `runtime/`.
- Phiên bản ghi ở ba chỗ phải khớp nhau: `VERSION` trong `runtime/vgd_cabinet_draw/main.rb`, `extension.version` trong `vgd_cabinet_draw.rb`, số trong `runtime/vgd_cabinet_draw/dialog.html`; thêm `VERSION` trong `dev/build_release.py`.

## Công cụ và menu

Theo `TOOLBAR_BUTTONS` và menu trong `runtime/vgd_cabinet_draw/main.rb` (menu **Extensions → VGD → VGD Cabinet Draw** và thanh công cụ **VGD CDR**). Mỗi nút trên thanh công cụ cũng có trong menu.

1. **Box → Board**: chọn box rồi click mặt trước để chuyển thành thùng tủ, hoặc chọn face để tạo ván.
2. **Chia đợt / vách**: chia đợt (nóc/đáy) hoặc vách (hông); rê chuột xem trước, click để đặt, gõ khoảng cách hoặc `/n` để chia đều.
3. **Cánh tủ**: chia vùng cánh trên mặt tủ (xem phần Cánh).
4. **Ngăn kéo**: tạo mặt và thùng kéo.
5. **Scale VGD**: chọn một tủ, bấm điểm ở tâm mặt muốn dời (mặt đối diện đứng yên), kéo chuột hoặc gõ số mm + Enter. Số hiện là kích thước mới theo trục đó. Chỉ đổi một trục mỗi lần, một bước Undo.
6. **Quét & dời tấm**: quét chọn nhiều tấm của tủ rồi dời cùng một khoảng (xem phần Quét & dời tấm).
7. **VGD Chọn**: bật công cụ rồi chuột phải lên tủ, cánh hoặc mặt hộc để hiện thanh nút tròn tại con trỏ.
8. **Setting**: mở bảng điều khiển để chỉnh, lưu, xuất và nhập setting cho từng công cụ.
9. Chỉ có trong menu: **Đóng tất cả cánh của tủ đang chọn**, **Tìm tấm bị trùng**, **Chuẩn hóa tên ván (vai trò + số)**, **Tải lại VGD Cabinet Draw (nạp code mới)**.

Menu chuột phải **VGD Cabinet** có thêm các lệnh theo đối tượng (chia nhanh, cánh tự động theo hồi, mở/đóng cánh, xóa tấm/cánh/ngăn kéo...). Preview chỉ hiện số (không đơn vị, không chữ), ngoại trừ góc mở cánh có dấu độ.

## Thùng tủ, tủ quá khổ và xà

- Sáu kiểu hậu theo tên DC: âm 4 cạnh, âm 2 hông, lùa trên, lùa đáy, phủ, không hậu.
- Tủ tùy biến, tủ bếp dưới và thùng tủ lạnh cao hơn "Ngưỡng tách tủ" (mặc định 2400 mm) được tách tự động khi dựng từ box thành tủ dưới (cao "Cao tủ dưới khi tách", mặc định 2100 mm) và tủ trên (phần còn lại), nằm trong group "Tủ quá khổ". Tủ cao trên 2440 mm (khổ ván) luôn được tách; nếu tủ trên vẫn vượt 2440 mm thì báo lỗi và không tạo gì. Chọn group "Tủ quá khổ" thì sửa được cả hai tủ con; Scale cả nhóm được đưa xuống hai tủ con rồi tự cập nhật từng tủ.
- Liên kết khi tách: **Đấu đình** (nóc tủ dưới và đáy tủ trên gặp nhau, không xà); **Xà dưới** (tủ dưới thay nóc bằng xà); **Xà trên** (tủ trên thay đáy bằng xà). Tủ trên không có chân.
- Xà trước: nằm hoặc đứng; đơn (một bản) hoặc kép (hai tấm rời, ghép sát nhau). Xà sau: nằm hoặc đứng, luôn một bản, có bề rộng riêng. Mặc định: xà trước nằm đơn, xà sau đứng.
- Gốc trục của mỗi ván nằm ở góc của ván; trục song song với trục của tủ.
- Tủ không có nóc (xà thay nóc/đáy): vách kéo tới mép xà và bị xà trước/sau khấu.
- Chưa làm: tự tách khi kéo Scale một tủ đã dựng.

## Đợt và vách

- Xem trước đợt và vách dùng đúng hình sẽ tạo (cùng một hàm dựng, có khấu theo xà đang chắn); khung tô sáng khi rê chuột là hình thật của tấm.
- Xóa: Alt-click trong công cụ Đợt/vách xóa một tấm; Shift-click đánh dấu nhiều tấm rồi xóa qua chuột phải. Chuột phải lên đợt/vách, cánh, ngăn kéo cũng có mục xóa. Xóa được ghi vào bước tạo của tủ nên dựng lại hay Scale không làm tấm hiện lại. Xóa một vách/đợt làm các tấm còn lại đổi sang vị trí tuyệt đối trước, nên không dời theo và đợt chỉ nở tới vách/hông còn lại gần nhất.
- Quan hệ giữa công cụ và cấu kiện (dữ liệu lưu ở đâu, ai dựng lại): xem `docs/QUAN_HE_CONG_CU.md`.

## Quét & dời tấm

- Chọn một tủ (hoặc click vào tủ), rồi quét chọn các group/component của tủ: kéo khung trái→phải chọn tấm nằm trọn trong khung, phải→trái chọn mọi tấm chạm khung; **Tab** đổi sang quét cọ (rê qua các tấm); **Shift** cộng thêm/bớt; click chọn một tấm; **F** đổi bộ lọc (tất cả / hồi và đợt / chỉ hồi / chỉ đợt).
- Chọn xong, click tiếp theo là bắt đầu kéo (di chuột rồi click để đặt), hoặc gõ số mm + Enter (số âm = ngược lại). Esc lùi từng bước. Kéo khung mới hoặc Esc để chọn lại.
- Hồi (vách) dời ngang, đợt dời đứng, mỗi tấm theo hướng riêng cùng một khoảng. Vị trí mới được ghi vào bước tạo tấm nên Scale hoặc dựng lại tủ vẫn giữ, và cánh tự động đi theo hồi đã dời. Hai tấm cùng bước chồng nhau thì báo lỗi, không đổi gì; vách/đợt bị chặn ở mép lòng tủ.
- Tấm khác (hông, đáy, nóc, hậu, cánh, ngăn kéo, vật tự vẽ) chỉ dời khi đã khóa trục bằng phím mũi tên (→ trái–phải, ← trước–sau, ↑/↓ lên–xuống, bấm lại để bỏ khóa) và bị đánh dấu chỉnh tay.
- Một bước Undo cho mỗi lần dời.

## Cánh

- Bố cục theo vùng (`door_layout.rb`): mặt tủ là các hình chữ nhật ghép kín. Click chia vùng (dọc hoặc ngang, Ctrl đổi hướng), Shift-click chọn vùng rồi G (hoặc Alt+G) để gộp, `/n` chia đều, gõ số mm chia theo khoảng cách. Chỉ khi nhấn Enter mới dựng cánh thật. Số "rộng x cao" hiện trong từng vùng (tùy chọn `door_show_dims`).
- Khi chia thủ công, chuột được đo trên mặt trước thùng tủ (nơi mép hồi nhìn thấy) nên vạch chia bám đúng chỗ trỏ ở mọi góc nhìn; vạch chia hút vào tim vách giữa trong ngưỡng 10 pixel, có đường mảnh báo điểm hút.
- Cánh tự động (phím A, gõ `a`, hoặc menu "Cánh tự động theo hồi"): chia ở tim mặt trước các vách cao suốt lòng tủ (hai vách liền kề thì chia ở giữa), và khoang trống (giữa hai vách hoặc hông–vách) rộng hơn "Ngưỡng chia 2 cánh" (mặc định 450 mm, 0 = tắt) thì chia đôi. Bố cục tự động được đánh dấu: tủ đổi kích thước thì tính lại theo vách/hông, giữ hướng mở, cánh đã xóa và tay nắm. Chia hoặc gộp tay thì bỏ dấu tự động và chỉ giãn theo tỷ lệ vùng.
- Hai khe giữa cánh: "Khe trái–phải" (chia dọc) và "Khe trên–dưới" (chia ngang). Alt rồi gõ số (hoặc gõ `k5`) đặt khe theo hướng chia hiện tại. Tủ lưu bằng bản cũ có một khe chung: khe trên–dưới lấy bằng khe đó.
- "Mở cánh…" dùng công cụ rê chuột; cánh bản lề trái mở khi rê sang trái. Cánh phủ thì ván chân lùi bằng hông. Xóa hết cánh rồi tạo lại được (chọn một vùng trống rồi G).
- Liên kết bản lề (`links.rb`): cánh mở trái/phải bắt bản lề vào hông hoặc hồi giữa gần nhất; mở lên/xuống vào nóc, đáy hoặc đợt giữa. Bản lề không còn bắt được (cách tấm hơn 40 mm) thì Scale bị hủy, tủ giữ nguyên và báo lỗi. Khi số cánh tự động đổi sau Scale, cánh có bản lề ở giữa khoang tự đổi sang mép sát hông/hồi.

## Co giãn khi Scale

- Kéo Scale tủ xong (thả chuột) thì tủ tự dựng lại theo kích thước mới, không cần mở Box → Board. Tắt/bật ở tab 5 · Setting chung (mặc định bật). Một lần kéo Scale tạo hai bước Undo: Scale và tự cập nhật. Lỗi thì hủy và tủ giữ nguyên trạng thái đã kéo.
- Mọi cấu kiện co giãn tại chỗ, không xóa tạo lại: vỏ tủ, đợt/vách, mặt và thùng ngăn kéo, khoang, xà chặn, hộc tủ áo, cánh. Khấu, cắt, bo, vật liệu, tên và tay nắm được giữ; vân vật liệu đặt lại theo kích thước thật.
- Trong từng tấm, chi tiết nhỏ (mộng, lỗ, khấu, bản lề, dấu tiết diện, khối lẻ) giữ nguyên mm: dải 100 mm sát mỗi mép tấm dời nguyên khối theo mép, chỉ nhịp trống từ 150 mm ở phần giữa mới giãn; tấm quá ngắn vẫn giãn như cũ. Khối rời dời theo vị trí tâm.
- Khung, gờ và khe cánh, thùng và đáy ngăn kéo giữ đúng mm; cánh, mặt hộc, khoang, xà chặn và hộc tủ áo được dựng lại nội dung ở kích thước mới. Tay nắm cách mép đã chọn một khoảng mm cố định. Cánh đang mở được đóng về 0 trước khi co giãn rồi mở lại; ngăn kéo đang kéo ra được đóng lại.
- Đỉnh của tấm được dời trong một lần (`transform_by_vectors`) rồi kiểm tra từng đỉnh so với kế hoạch; lệch thì dựng lại tấm từ vị trí kế hoạch (đường cong cung thành đa giác, điểm/đường dựng hình không được dựng lại), không được thì hoàn tác và báo lỗi. Công tắc `VGD_Cabinet_Draw::Rebuild.move_nested = false` tắt việc dời nhóm con (ví dụ mặt tiết diện CNC) khi thử lỗi.
- Tủ copy dùng chung dữ liệu: mọi tầng được tách riêng trước khi sửa; còn dùng chung thì dừng và báo.
- Nhận tấm chỉnh tay bằng chữ ký tính trong hệ tọa độ của tấm; tấm chỉnh tay được giữ khi dựng lại.
- Scale VGD dùng cùng cơ chế này: đo kích thước theo tia chuột (đúng ở góc nhìn nghiêng), làm tròn 1 mm, quanh mặt đứng yên của điểm neo.

## Giao diện theo theme VGD

- Dialog dùng bộ theme chung (`runtime/vgd_cabinet_draw/vgd-theme/`, đồng bộ bằng `tools/sync_vgd_theme.py`; khóa lưu `vgd.cabinet_draw.theme`, nút `#themeBtn`). Dialog báo chế độ sáng/tối cho Ruby nên HUD, thanh mini, khung chữ và preview trong viewport đổi theo.
- Chữ trong viewport dùng Manrope nếu máy đã cài, không thì Segoe UI.
- Icon thanh công cụ: PNG 16 px (small) và 24 px (large), nét 1.8, màu than và đồng `#B48963`. Bản 24/32 px từng làm mất icon trên SketchUp 2024. `icon.svg` ở gốc plugin vẫn dùng màu cũ `#A67C58`.

## Kiểm thử

- Chạy từ thư mục `test/`, mỗi file một lệnh, ví dụ `ruby test_build.rb`. Có 25 file `test_*.rb` (giả lập SketchUp trong `mock_su.rb`). Mặc định test trỏ tới `../runtime/vgd_cabinet_draw`; riêng `test_back_modes.rb`, `test_panel_model.rb`, `test_rails.rb` bắt buộc truyền đường dẫn: `ruby test_rails.rb ../runtime/vgd_cabinet_draw`.
- Công cụ chẩn đoán chỉ đọc, chạy trong Ruby Console của SketchUp thật: `dev/check_parts_solid.rb` (tấm có là khối kín không), `dev/check_feature_sizes.rb` (chi tiết nhỏ có giữ mm sau Scale), `dev/dump_part_structure.rb` (cấu trúc một tấm).
- `dev/native_smoke.rb` chỉ chạy trong SketchUp thật; chưa đối chiếu với bản hiện tại.

## Điều chưa kiểm chứng

- Toàn bộ test là giả lập. Click chọn, preview, Undo, phím mũi tên và Alt trên Windows, hiệu năng chưa kiểm trong SketchUp thật. Các mục người dùng đã xác nhận bằng mắt: texture UV, hồi chạm xà, khung tô sáng, các tấm kín.
- Từ beta.54, hành vi co giãn giữ chi tiết nhỏ, dời đỉnh, dựng lại từ vị trí kế hoạch và `Group#make_unique` chưa xác minh trong SketchUp thật. Mặt tiết diện CNC (group ABF_MA) có thể còn lệch so với vách sau khi Scale. Tấm có nhóm con (đáy/nóc đánh mộng) có thể không phải khối kín theo SketchUp.
- Quét & dời tấm: chỉ thử ở góc nhìn thẳng trong giả lập; quét ở góc nhìn nghiêng (các tấm chồng nhau trên màn hình) chưa thử thật.
- Tương thích Ruby 2.7 chưa kiểm (môi trường kiểm thử là Ruby 3.x; chỉ kiểm cú pháp bằng `ruby -c`).
- Chưa làm: khấu, cắt, bo trên vỏ tủ vẫn co theo tỷ lệ; lỗ cam, chốt, lề chưa thiết kế; cánh chia tay không tự khớp lại với hồi sau khi dời hồi.

## Lịch sử phiên bản

| Bản | Nội dung chính |
|---|---|
| 1.0.0 | Phát hành ổn định từ mã beta.70; tên extension đổi từ "VGD_Cabinet Draw" thành "VGD Cabinet Draw" để khớp quy tắc catalog của VGD Center. |
| beta.70 | Chia cánh thủ công bắt điểm đúng ở góc nhìn nghiêng (đo trên mặt trước thùng tủ). |
| beta.69 | Preview chỉ hiện số; Quét & dời tấm: chọn xong click tiếp theo là kéo luôn. |
| beta.68 | Công cụ Quét & dời tấm (quét khung/cọ, dời hồi, đợt và tấm khác). |
| beta.67 | Scale VGD đo theo tia chuột (đúng ở góc nhìn nghiêng); bỏ chữ góc trên trái. |
| beta.66 | Scale VGD: điểm bấm là mặt dời; icon toolbar về PNG 16/24. |
| beta.65 | Scale VGD có điểm neo; dải 100 mm sát mép tấm giữ nguyên khi co giãn. |
| beta.64 | Bản lề bắt vào hồi giữa khi Scale; thêm nút Scale VGD (hộp nhập số). |
| beta.63 | Hai khe cánh ngang/dọc; cánh tự động theo khoang và ngưỡng; cánh bám hồi khi Scale; preview theo theme. |
| beta.62 | Đồng bộ theme VGD cho dialog, viewport (HUD, mini bar, nhãn, font) và icon. |
| beta.61 | Tự chia cánh theo hồi, hút tim hồi, nhãn "rộng x cao", Alt + số cho khe. |
| beta.60 | "Mở cánh…" rê chuột, bản lề trái, chân lùi bằng hông, tạo lại cánh sau khi xóa. |
| beta.59 | Tủ copy không bị hỏng khi Scale tủ gốc. |
| beta.55–58 | Dời đỉnh một lần, kiểm tra từng đỉnh, công tắc `move_nested`, dựng lại tấm từ vị trí kế hoạch. |
| beta.54 | Mọi tấm co giãn tại chỗ, giữ chi tiết nhỏ đúng mm; thêm `dev/check_feature_sizes.rb`. |
| beta.53 | Đợt/vách không dựng lại khi Scale; khấu theo xà khớp khi Scale dọc; khung tô sáng là hình thật. |
| beta.52 | Xóa vách không làm đợt nở cả tủ. |
| beta.51 | Scale dọc không còn hở phần khấu; khung tô sáng vách theo chiều cao thật. |
| beta.50 | Tủ không nóc: vách kéo tới mép xà và bị xà khấu. |
| beta.49 | Xem trước đợt/vách đúng hình sẽ tạo. |
| beta.48 | Vách khấu sát mép trên/dưới thành khối kín. |
| beta.47 | Nhận tấm chỉnh tay bằng chữ ký theo hệ tọa độ của tấm. |
| beta.41–46 | Sửa vân, gom thông báo lỗi, tách/sửa/scale tủ quá khổ, gốc trục ván; thử rồi hoàn tác cách co ván bằng transform của group. |
| beta.39–40 | Tủ quá khổ (tự tách tủ cao), cài đặt xà trước/sau, tủ tùy biến, xà kép. |
| beta.38 | Sáu kiểu hậu theo DC. |
| beta.37 | Xóa đợt/vách, cánh, ngăn kéo có ghi vào bước tạo. |
| beta.34–36 | Tự cập nhật khi kéo Scale; mở rộng sang ngăn kéo, khoang, xà chặn, cánh; liên kết bản lề. |
| beta.33 | Mã nguồn được chuyển vào repository. |
