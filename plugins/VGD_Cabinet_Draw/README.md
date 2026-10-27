# VGD_Cabinet Draw 1.0.0-beta.58

beta.58: khi SketchUp tự chỉnh lệch đỉnh lúc dời (hình cung của mộng bị kéo ra xa), tấm được dựng lại từ vị trí kế hoạch đã lưu (mặt, lỗ, cạnh, vật liệu, thuộc tính được giữ; đường cong cung thành đa giác, đối tượng dựng điểm/đường dựng hình không được dựng lại). Không dựng lại được thì hoàn tác và báo lỗi. Chưa xác minh trong SketchUp thật.

beta.57: kiểm tra từng đỉnh so với vị trí kế hoạch sau khi dời đỉnh và sau khi dời nhóm con; thông báo lỗi nói rõ lệch xảy ra ở bước nào (SketchUp chỉnh thêm hay chỉ sau khi dời nhóm con) và in ví dụ đỉnh lệch ra Ruby Console. Chưa xác minh trong SketchUp thật.

beta.56: sau khi co giãn tấm, kiểm tra hộp bao của thân tấm có đúng kế hoạch không; lệch (đỉnh bị kéo ra xa) thì báo lỗi và hoàn tác. Thêm công tắc VGD_Cabinet_Draw::Rebuild.move_nested = false để tắt việc dời nhóm con (ví dụ mặt tiết diện CNC) khi thử lỗi với tool khác. Chưa xác minh trong SketchUp thật.

beta.55: dời đỉnh của tấm trong một lần (transform_by_vectors) thay vì từng nhóm đỉnh, để tránh các đỉnh hình cung của mộng bị kéo ra xa khi scale. Chưa xác minh trong SketchUp thật. Mặt tiết diện CNC (group ABF_MA) có thể còn lệch so với vách sau khi scale.

beta.54: mọi tấm (nóc, đáy, hông, hậu, xà, đợt, vách) co giãn tại chỗ mà giữ nguyên kích thước chi tiết (mộng, lỗ, khấu, bản lề, dấu tiết diện, khối lẻ). Chỉ nhịp trống từ 150 mm giữa các chi tiết giãn; chi tiết nhỏ và khối rời giữ nguyên mm, khối rời dời theo vị trí tâm. Thêm dev/check_feature_sizes.rb để đối chiếu kích thước chi tiết trước/sau scale. Chưa xác minh trong SketchUp thật (gom khối rời theo cạnh, dời đỉnh).\n\nbeta.53: đợt/vách không dựng lại khi scale (giữ đối tượng, vật liệu, texture); mỗi đỉnh giữ khoảng cách tới mép gần nhất, nên khấu theo xà khớp khi scale dọc, kể cả tấm đã chỉnh tay. Khung tô sáng hover là hình thật của tấm (có khấu xà). Dời đỉnh dùng transform_entities trên đỉnh: chưa xác minh trong SketchUp thật.

beta.52: xóa vách không làm đợt nở cả tủ; đợt chỉ nở tới vách/hông còn lại gần nhất (vị trí tuyệt đối, giới hạn theo ô giữ nguyên). Chưa xác minh trong SketchUp thật.

beta.51: scale dọc tủ không còn hở phần khấu. Đợt và vách chưa chỉnh tay được dựng lại theo quy tắc khi scale; vách đã chỉnh tay vẫn co tại chỗ (có thể còn hở). Khung tô sáng vách theo chiều cao thật. Chưa xác minh trong SketchUp thật.

beta.50: tủ không có nóc (xà thay nóc/đáy) thì vách kéo tới mép xà và bị xà trước/sau khấu, thay vì dừng ở mép dưới xà. Tủ có nóc/đáy giữ nguyên. Đợt ngang chưa đổi. Chưa xác minh trong SketchUp thật.

beta.49: xem trước đợt và vách lấy đúng hình sẽ tạo (cùng một hàm dựng). Hàm dựng biên có khấu theo xà trước đang chắn, nhưng với các cấu hình tủ hiện tại xà trước nằm ngay mép ô nên chưa cắt tấm nào. Chưa xác minh trong SketchUp thật.

beta.48: vách khấu sát mép trên/dưới (ví dụ có xà trên sát nóc) không còn đi chồng lên chính nó, nên khối kín và công cụ khối (Outer Shell, khấu) dùng được. Chưa xác minh trong SketchUp thật.

beta.47: nhận tấm chỉnh tay bằng chữ ký tính trong hệ tọa độ của tấm (không dùng hộp bao thế giới), nên scale cả tủ không còn bị báo "chỉnh tay". Tủ dựng bằng bản trước giữ cách kiểm tra cũ cho đến khi tấm được dựng lại. Chưa xác minh trong SketchUp thật.

hoàn tác cách co giãn ván bằng phép biến đổi của group (gây văng và vân bị nhỏ), quay về cách beta.43. Vấn đề trục ván sau scale và báo "chỉnh tay" vẫn còn, đang chờ hướng xử lý khác. sửa lỗi tự cập nhật khi tủ có vân (SketchUp báo "Wrong number of points"), gom thông báo lỗi thành một hộp thoại, sửa tủ không mất vật liệu khi đổi hông chạm đất/đụng trần, xà kép là hai tấm rời, group "Tủ quá khổ" sửa và scale được, gốc trục từng ván nằm ở góc ván. beta.40 đổi tên "Tủ thường" thành "Tủ tùy biến", thùng tủ lạnh cũng tách khi cao trên 2400 mm, xà trước kép/đơn, xà sau một bản, và ván chân sau lùi vào khi hậu phủ. beta.39 thêm tủ quá khổ (tự tách tủ cao trên 2400 mm thành tủ dưới và tủ trên, ba kiểu liên kết) và cài đặt xà (nằm/đứng, kép/đơn). beta.38 thêm sáu kiểu hậu theo DC (âm 4 cạnh, âm 2 hông, lùa trên, lùa đáy, phủ, không hậu). beta.35 mở rộng tự cập nhật tủ khi kéo Scale sang ngăn kéo, khoang, xà chặn, hộc tủ áo và cánh (giai đoạn 2). beta.34 là giai đoạn 1 (vỏ tủ và đợt/vách). Nền tảng từ beta.33 đã đưa vào repository, thay cho baseline beta.1 (lịch sử beta.1 vẫn còn trong git).

- Đã xác minh tự động: bộ test giả lập (`test/`), gồm `test_stretch.rb` cho tự cập nhật khi Scale.
- Chưa xác minh: chưa mở trong SketchUp thật; chưa kiểm tra tương thích Ruby 2.7 đầy đủ (chỉ kiểm cú pháp bằng `ruby -c`).

## Tự cập nhật khi kéo Scale (beta.34 giai đoạn 1, beta.35 giai đoạn 2, beta.36 liên kết)

- Kéo Scale tủ xong (thả chuột) thì tủ tự dựng lại theo kích thước mới. Không cần mở Box → Board.
- Mọi cấu kiện đã có được co giãn tại chỗ, không xóa tạo lại: vỏ tủ, đợt/vách, mặt và thùng ngăn kéo, khoang, xà chặn, hộc tủ áo, cánh. Khấu, cắt, bo, vật liệu, tên và tay nắm được giữ.
- Vân vật liệu được đặt lại theo kích thước thật, không bị kéo theo tấm.
- Cánh đang mở được đóng về 0 trước khi co giãn, rồi mở lại đúng góc cũ quanh bản lề mới. Ngăn kéo đang kéo ra được đóng lại.
- Tay nắm cách mép đã chọn một khoảng mm cố định (xem phần Liên kết bên dưới).
- Liên kết (module `links.rb`): cánh mở trái/phải bắt bản lề vào hông trái/phải, mở lên vào nóc, mở xuống vào đáy. Cánh mở lên/xuống được xử lý trước. Nếu bản lề không còn bắt được vào tấm vỏ tủ thì tủ giữ nguyên và báo lỗi.
- Kích thước cố định theo mm: khung, gờ và khe cánh, thùng và đáy ngăn kéo, hông khoang giữ nguyên độ dày. Cánh, mặt hộc, khoang, xà chặn và hộc tủ áo được dựng lại nội dung ở kích thước mới.
- Tay nắm cách mép đã chọn một khoảng mm cố định.
- Xóa (beta.37): Alt-click trong công cụ Đợt/vách xóa một tấm; Shift-click đánh dấu nhiều tấm rồi xóa qua chuột phải. Chuột phải lên đợt/vách, cánh, ngăn kéo cũng có mục xóa. Cánh: chuột phải → xóa cánh (vùng thành trống, không gộp vào cánh bên cạnh); Alt+G (hoặc G) gộp vùng cánh đã chọn. Xóa đợt làm các đợt còn lại đổi sang vị trí tuyệt đối trước, nên không dời theo.
- Quan hệ giữa công cụ và cấu kiện: xem `docs/QUAN_HE_CONG_CU.md`.
- Chưa làm: lỗ khấu, cắt, bo trên vỏ tủ vẫn co theo tỷ lệ; cam, chốt, lề chưa làm.
- Tắt/bật ở tab 5 · Setting chung. Mặc định bật.
- Một lần kéo Scale tạo hai bước Undo: bước Scale và bước tự cập nhật.

## Tủ quá khổ và xà (beta.39)

- Tủ tùy biến, tủ bếp dưới và thùng tủ lạnh cao hơn "Ngưỡng tách tủ" (mặc định 2400 mm) được tách tự động khi dựng từ box thành tủ dưới (cao "Cao tủ dưới khi tách", mặc định 2100 mm) và tủ trên (phần còn lại). Hai tủ nằm trong group "Tủ quá khổ". Tủ trên của thùng tủ lạnh là tủ tùy biến. Tủ cao trên 2440 mm (khổ ván) luôn được tách; nếu tủ trên vẫn vượt 2440 mm thì báo lỗi và không tạo gì.
- Chưa làm: tự tách khi kéo Scale một tủ đã dựng (cần quyết định cách xử lý cánh, ngăn kéo, đợt nằm trên phần sẽ tách).
- Gốc trục của mỗi ván nằm ở góc của ván; trục song song với trục của tủ (trùng trục thế giới khi tủ không bị xoay sẵn). Tủ đã dựng bằng bản cũ giữ gốc cũ cho đến khi dựng lại.
- Liên kết khi tách: **Đấu đình** (nóc tủ dưới và đáy tủ trên gặp nhau, không xà); **Xà dưới** (tủ dưới thay nóc bằng xà); **Xà trên** (tủ trên thay đáy bằng xà). Tủ trên không có chân.
- Xà trước: nằm hoặc đứng; đơn (một bản) hoặc kép (hai tấm rời, ghép sát nhau). Xà sau: nằm hoặc đứng, luôn một bản, có bề rộng riêng. Mặc định giữ như cũ: xà trước nằm đơn, xà sau đứng.
- Chọn group "Tủ quá khổ" thì sửa được cả hai tủ con; kéo Scale cả nhóm sẽ đưa scale xuống hai tủ con rồi tự cập nhật từng tủ. Sửa liên kết vẫn làm trên từng tủ.

VGD_Cabinet Draw is a standalone SketchUp extension for a semi-automatic cabinet workflow. It keeps the user in control of face orientation, panel positions, door splits, openings, handles, drawers and finishing operations. Preview lives in the viewport; a tool commits model geometry only when the user presses Enter.

The extension is registered independently from VGD_Cabinet. It uses its own `VGD_Cabinet_Draw` model dictionary and `%APPDATA%/VGD/SketchUp/VGD_Cabinet_Draw` data folder. It does not import old cabinet model dictionaries or preset files. The old extension sources remain untouched beside this project.

## Workflow

Mô tả dưới đây viết cho beta.1 và chưa đối chiếu lại với beta.33. Khi kiểm thử thủ công beta.33, cần cập nhật lại.

1. Select a rough box and use **Box → Cabinet**. Click its front face to confirm local orientation.
2. Add shelves/partitions with the viewport tool. Enter a distance or `/n` in SketchUp's Measurements box to place or divide evenly.
3. Draw door splits on the cabinet face, set the opening direction, and place drawer fronts and boxes.
4. Add handles and blockers, then use cut, round and notch tools for manual finishing.
5. Save settings to a grouped preset for the next model.

## Development and validation

- Runtime entry point: `main.rb` → `runtime/VGD_Cabinet_Draw/main.rb`.
- Native target: SketchUp 2022, Ruby 2.7.
- Tests: chạy từ thư mục `test/`, ví dụ `ruby test_build.rb`. Có 15 file `test_*.rb`. Mặc định các bài test trỏ tới `../runtime/VGD_Cabinet_Draw`.
- Package builder: `dev/build_release.py`. Tạo `outputs/` (đã bị `.gitignore` bỏ qua). Gói `.rbz` gồm `VGD_Cabinet_Draw.rb`, `VGD_Cabinet_Draw/main.rb` và toàn bộ `runtime/`.
- Native acceptance script: `dev/native_smoke.rb` (từ beta.1, chưa đối chiếu với beta.33, không chạy trong đợt chuyển repository).

## Điều chưa kiểm chứng

- Toàn bộ test là giả lập. Click chọn, preview, Undo, chiều pushpull và hiệu năng chưa kiểm trong SketchUp thật.
- `runtime/VGD_Cabinet_Draw/vgd-theme/` đang khác `shared/vgd-theme/`, nên `tools/sync_vgd_theme.py --check` báo lệch. Chưa đồng bộ vì việc đó sẽ đổi giao diện.
- Tương thích Ruby 2.7 chưa kiểm (môi trường kiểm thử là Ruby 3.3).
