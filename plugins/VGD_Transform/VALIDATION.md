# Kiểm tra VGD Transform

Mọi kết quả dưới đây là **mô phỏng ngoài SketchUp**, trừ khi ghi khác.

## Bản 0.1.0-beta.13: đã kiểm tra tự động

Xoay tuyệt đối (mới): tab Xoay có khung Tuyệt đối (°) hiện góc X, Y, Z hiện tại của món (`Items.euler_degrees`, quy ước R = Rz·Ry·Rx, khớp công cụ Xoay), gõ góc (0 là quay về hướng gốc: trục riêng song song trục thế giới) hoặc bấm chuột phải ▲▼ để về 0. `RotateScale.absolute_rotate` tính cho mỗi món phép xoay đưa hướng hiện tại về hướng đích (ma trận 3×3 thuần Ruby, trục / góc xoay, có xử lý góc 180°), bước `rotate` quanh tâm đã chọn nên đi qua cùng kiểm tra ma trận / điểm gốc. Ô không sửa giữ góc hiện tại. Kéo ▲▼ trực tiếp dùng được (công cụ `rotate_abs` trong `Plan`).

- `dev/test_transform.rb`: góc hiện tại (không xoay, Z 90°, xoay (30, 20, 40) rồi đọc lại đúng, gimbal lock), về hướng gốc cho món xoay nhiều trục, điểm gốc đứng yên, chỉ đổi ô Z giữ X, Y, trường hợp 180°, nhiều món xoay khác nhau, NothingToDo, giới hạn góc, ghép công cụ `rotate_abs`.
- `dev/test_model_ops.rb`: đọc góc từ ma trận món; xoay tuyệt đối 0 qua `ModelOps.apply` với SketchUp giả lập (món về góc 0, điểm gốc đứng yên, qua kiểm tra ma trận).
- `dev/test_ui.cjs` (68): khung Tuyệt đối trong tab Xoay hiện góc, ô "khác nhau", Enter chỉ gửi ô đã sửa, chuột phải ▲▼ về 0 và áp dụng ngay.
- `ruby dev/run_tests.rb` và `tests/test_vgd_conventions.rb`: đạt.

**Chưa xác minh trong SketchUp thật:** góc hiện tại đọc từ món lồng nhiều cấp và món có scale không đều; hành vi gần gimbal lock; "hướng gốc" ở đây là song song trục thế giới (không phải hướng lúc món được tạo, SketchUp không lưu).

## Bản 0.1.0-beta.12: đã kiểm tra tự động

Gõ số, Enter, rồi gõ số khác: số mới thay hẳn số cũ. Trước đây ô giữ lại số vừa áp dụng (ô Tuyệt đối hiện giá trị mới) nên gõ tiếp bị nối đuôi (200 Enter, 300 ra 200300). Sau Enter ô được đánh dấu `dataset.fresh`; phím gõ tiếp theo (ký tự, Backspace, Delete) chọn hết nội dung cũ rồi gõ đè; bấm chuột vào ô, phím mũi tên, Home, End, Tab, Esc hoặc rời ô thì bỏ đánh dấu (sửa tiếp trong số cũ). Phím có Ctrl / Alt / Meta không tính.

- `dev/test_ui.cjs` (63): 200 Enter rồi gõ 300 ra 300 (trước khi sửa ra 200300, kiểm tra đỏ); Enter lần hai gửi 300; Backspace ngay sau Enter xóa cả số; điều hướng bằng End rồi gõ giữ số cũ (3005).
- `ruby dev/run_tests.rb` và `tests/test_vgd_conventions.rb`: đạt.

**Chưa xác minh trong SketchUp thật:** hành vi trong trình duyệt của SketchUp (CEF) với bộ gõ tiếng Việt; chỉ kiểm bằng Chromium của Playwright.

## Bản 0.1.0-beta.11: đã kiểm tra tự động

Hai việc: (1) kéo ▲▼ mượt hơn nữa; (2) Ctrl+Z ngay sau khi xong lệnh. (1) Bản beta.10 đã dùng một thao tác mở suốt; bản này thêm: giá trị kéo đầu tiên áp dụng NGAY (không chờ nhịp hẹn giờ 16 ms), các giá trị dồn trong 16 ms chỉ giữ giá trị mới nhất; mỗi nhịp đọc ngữ cảnh (`active_path`) một lần cho cả đợt thay vì hai lần cho mỗi món; nhịp giữa bỏ qua kiểm tra khóa từng món và kiểm lại ma trận (làm ở nhịp cuối khi thả nút, sai thì hủy cả thao tác); kéo xong báo số nhịp, thời gian Ruby trung bình và lâu nhất mỗi nhịp để biết chỗ chậm. (2) Phím tắt không tới SketchUp khi tiêu điểm còn ở cửa sổ plugin, nên Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z trong cửa sổ gọi `Sketchup.undo` / `Sketchup.send_action('editRedo:')` qua Ruby; ô đang gõ dở (`dirty`) thì để trình duyệt hoàn tác chữ; đang kéo thì bỏ qua.

- `dev/test_model_ops.rb`: mỗi nhịp đọc `active_path` không quá 2 lần dù có 5 món; nhịp thường không kiểm ma trận, nhịp cuối `check: true` bắt được lỗi; Panel: giá trị đầu áp dụng ngay, dồn trong nhịp chỉ hẹn giờ một lần, kéo xong có dòng báo nhịp và ms, undo / redo gọi đúng, đang kéo thì bỏ qua undo (đồng hồ và hẹn giờ giả lập). Các kiểm tra mới đỏ trước khi sửa.
- `dev/test_ui.cjs` (58): Ctrl+Z gửi `undo`, Ctrl+Y và Ctrl+Shift+Z gửi `redo`; ô đang gõ dở thì Ctrl+Z không gửi `undo`.
- `ruby dev/run_tests.rb` và `tests/test_vgd_conventions.rb`: đạt.

**Chưa xác minh trong SketchUp thật (rủi ro chính):** (a) độ mượt thực tế và số liệu dòng báo sau khi kéo; (b) `Sketchup.undo` gọi từ cửa sổ có hoàn tác đúng một bước vừa làm không; (c) `Sketchup.send_action('editRedo:')` có chạy trên Windows không (chưa biết; nếu không chạy thì Ctrl+Y trong cửa sổ không làm gì, dùng Ctrl+Y ở khung nhìn); (d) khung nhìn có vẽ lại đều khi thao tác đang mở.

## Bản 0.1.0-beta.10: đã kiểm tra tự động

Kéo mũi tên ▲▼ xem trực tiếp (bản beta.9 chưa đủ mượt so với lệnh Move của SketchUp, đã bỏ cách gửi có xác nhận `live_ack`): (1) cả lần kéo là MỘT thao tác mở suốt (`ModelOps.begin_live` / `apply_live` / `finish_live`), không `start_operation` / `commit_operation` mỗi nhịp, vì mỗi lần đóng ghi bước hoàn tác và báo `onTransactionCommit` cho mọi observer của mọi plugin đang nạp; (2) giá trị từ giao diện được gộp (`LiveQueue`, chỉ giữ giá trị mới nhất) và áp dụng theo nhịp hẹn giờ 16 ms; (3) mỗi nhịp mỗi món ghi biến đổi một lần; (4) mỗi nhịp gọi `View#invalidate`; (5) thả nút: có thay đổi thì đóng thành một bước Ctrl+Z, không còn thay đổi thì hủy (không để bước trống); đóng cửa sổ hoặc lỗi giữa lúc kéo thì hủy thao tác đang mở.

- `dev/test_live_queue.rb` (mới): chỉ giữ giá trị mới nhất, chỉ hẹn giờ một lần cho nhiều giá trị.
- `dev/test_model_ops.rb`: một thao tác mở suốt, các nhịp không mở / đóng thêm, ghi biến đổi một lần mỗi nhịp, về 0 không mở thao tác mới, đóng / hủy đúng; luồng Panel với HtmlDialog và hẹn giờ giả lập (gộp giá trị, thả nút áp dụng giá trị cuối và đóng một lần, kéo về 0 rồi thả thì hủy, đóng cửa sổ giữa lúc kéo thì hủy).
- `dev/test_ui.cjs` (56): hai giá trị kéo trong một nhịp chỉ gửi giá trị mới nhất; không còn `live_ack`.
- `ruby dev/run_tests.rb` và `tests/test_vgd_conventions.rb`: đạt.

**Chưa xác minh trong SketchUp thật (rủi ro chính của bản này):** (a) độ mượt thực tế so với lệnh Move; (b) khung nhìn có vẽ lại đều khi thao tác đang mở (đã dùng `start_operation(name, false)` và `View#invalidate`, chưa chạy thật); (c) `UI.start_timer` 16 ms có đều không; (d) hoàn tác một lần sau khi thả.

## Bản 0.1.0-beta.9: đã kiểm tra tự động

Kéo mũi tên ▲▼ xem trực tiếp trong SketchUp mượt hơn: (1) giao diện chỉ gửi một cập nhật tại một lúc, giá trị kéo mới dồn lại và được gửi khi Ruby báo xong (`live_ack`), nên không dồn hàng đợi gây trễ; khoảng cách tối thiểu giữa hai lần gửi 16 ms (trước 40 ms cố định); nếu Ruby không báo trong 1 giây thì gửi tiếp; (2) `ModelOps.apply` với `restore:` ghi biến đổi của mỗi món đúng một lần mỗi nhịp (trước ghi lại trạng thái đầu rồi mới ghi vị trí mới); món không còn trong danh sách bước vẫn được đưa về trạng thái đầu.

- `dev/test_model_ops.rb`: mỗi nhịp kéo ghi `transformation` một lần, vẫn tính từ trạng thái đầu, món không còn trong danh sách bước về vị trí đầu (trước khi sửa: ghi hai lần, kiểm tra đỏ).
- `dev/test_ui.cjs` (56): đang chờ Ruby thì giá trị mới dồn lại, chưa gửi thêm; `live_ack` thì gửi đúng một cập nhật với giá trị mới nhất; thả nút gửi giá trị cuối rồi `live_end` không chờ xác nhận (trước khi sửa: kiểm tra đỏ).
- `ruby dev/run_tests.rb`: đạt.

**Chưa xác minh trong SketchUp thật:** độ mượt khi kéo thực tế (chưa đo được ngoài SketchUp); `emit` `live_ack` qua `execute_script` mỗi nhịp có làm chậm không.

## Bản 0.1.0-beta.8: đã kiểm tra tự động

- Bản này: nút khóa như Lock của SketchUp; ghi chú và thông báo ở đáy bảng (bỏ `title`, bỏ chữ mặc định); dòng trạng thái xuống đáy; cửa sổ 320 × 250.
- `dev/test_model_ops.rb`: trạng thái khóa (lẫn lộn / khóa hết / không khóa / chưa chọn); khóa và mở khóa mọi món đang chọn trong một bước hoàn tác đúng tên; chưa chọn thì báo lỗi; món vừa khóa không biến đổi được.
- `dev/test_ui.cjs` (53): đáy bảng không có chữ mặc định; không còn `title` (trừ nút theme của theme chung); rê chuột hiện ghi chú, rời đi về thông báo; thông báo mới hiện cả khi chuột đang trên khung; nút khóa tắt khi chưa có lựa chọn, hiện đúng ba trạng thái, bấm gửi lệnh `lock` và không đổi công cụ đang mở (lỗi này bắt được nhờ test và đã sửa).
- Đã chụp ảnh ở 320 × 250, theme sáng và tối: rê chuột lên khung (ghi chú ở đáy), sau khi khóa (ổ đóng, báo "Đã khóa 2 món."). Không tràn, không thanh cuộn.

## Bản 0.1.0-beta.7: đã kiểm tra tự động

- Bản này: icon Dời / Xoay / Scale (thanh công cụ ba nút, icon trong cửa sổ), bỏ nút Áp dụng, cửa sổ gọn 320 × 230. `dev/test_reload.rb` kiểm tra thanh công cụ có đúng ba nút, icon là file có thật, tải lại không thêm thanh công cụ. `dev/test_ui.cjs` (42) kiểm tra icon công cụ, Ruby chọn sẵn công cụ, không còn nút Áp dụng, dòng trạng thái ngắn, ô Đều. Đã chụp ảnh cửa sổ ở 320 × 230 (ba công cụ, theme sáng và tối: không tràn, không thanh cuộn) và icon ở 16 / 24 / 32 px trên nền thanh công cụ sáng.

Các mục còn lại giữ như bản beta.6:

- `dev/test_units.rb` (21): số có đơn vị (mm, cm, m, in, ft, yd), số theo đơn vị file, dấu phẩy, sai định dạng, giới hạn ±1 km; chỉ số đơn vị SketchUp 0–5 và chỉ số lạ (nil); ô scale (hệ số / kích thước đích, đích 0 hoặc âm bị từ chối).
- `dev/test_transform.rb` (42): tâm hộp bao hình (không phải tâm các điểm gốc); tâm theo chế độ; giá trị chung; chặn món khóa / không đo được / lựa chọn rỗng; dời tuyệt đối theo tâm điểm gốc (thẳng hàng) và tâm cả lựa chọn; dời tương đối World và Local (món xoay 90°); xoay quanh các tâm, local, thứ tự X-Y-Z; scale đều / không đều / local / kích thước đích (world đo hộp bao, local đo trục riêng) / riêng từng món; scale tuyệt đối theo tỉ lệ hiện tại và trục riêng; `NothingToDo` cho trường hợp không có gì để làm; ghép công cụ với ô nhập (tâm, hệ trục, giá trị sai).
- `dev/test_model_ops.rb` (22, SketchUp giả lập, ma trận 4×4 độc lập với công thức trong code): đọc điểm gốc, trục riêng, tỉ lệ, hộp bao, kích thước; đếm cạnh / mặt bị bỏ qua; đơn vị yd và đơn vị lạ; dời ở gốc và trong group cha; xoay ba trục đặt biến đổi đúng **một** lần; xoay quanh tâm hộp bao; scale đến kích thước đích; scale local trên món đã xoay; scale tuyệt đối về 1; món khóa lúc áp dụng; SketchUp không đổi được vị trí → hủy; SketchUp bỏ mất phần xoay (điểm gốc vẫn đúng) → kiểm tra ma trận bắt được, hủy; kéo trực tiếp tính lại từ trạng thái đầu, gộp bước (transparent), kéo về 0 thì trở lại vị trí đầu.
- `dev/test_reload.rb`: menu đúng hai mục; tải lại 3 lần không nhân đôi; đang bận thì không nạp lại; lỗi cú pháp giữ nguyên bản đang chạy.
- `dev/test_ui.cjs` (Playwright): dòng trạng thái (số món, đơn vị, bỏ qua, đơn vị lạ); ô Tuyệt đối hiện giá trị theo tâm, "khác nhau", chỉ gửi ô đã sửa, cập nhật sau khi áp dụng; ô Tương đối về 0 sau Enter và sau khi kéo; hệ trục trong tiêu đề và lệnh gửi; ▲▼ (bước theo đơn vị file, Ctrl ×10, Alt ×0,1, giữ đơn vị đã gõ, kéo trên nút, kéo trên ô chữ không đổi, chuột phải về mặc định); xem trực tiếp bật / tắt (live_start, live, live_end); ô "khác nhau" không cho kéo; xoay, scale tuyệt đối / tương đối; thông báo thường và lỗi; không lỗi JavaScript. Đã chụp ảnh tab Dời và Scale ở 440 px.
- `tests/test_vgd_conventions.rb` (repo): tên extension, toolbar `VGD TRF`, mục "Tải lại code", chữ chuẩn khi tải lại.
- Quét cú pháp code chạy thật: không có cú pháp chỉ có từ Ruby 3 (SketchUp 2022 dùng Ruby 2.7). Chưa chạy bằng Ruby 2.7 thật.

## Chưa xác minh trong SketchUp thật

- **Kéo trực tiếp (beta.11: một thao tác mở suốt, áp dụng ngay giá trị đầu, Ctrl+Z trong cửa sổ; cần thử lại kỹ):** món chạy mượt khi kéo ▲▼; cả lần kéo là một bước Ctrl+Z (`start_operation` với `transparent`); tốc độ khi chọn nhiều món.
- **Ô Tuyệt đối tự cập nhật:** sau Ctrl+Z, sau khi dùng công cụ Move của SketchUp (`ModelObserver#onTransactionCommit/Undo/Redo`); không làm chậm SketchUp khi vẽ.
- **Đọc ma trận:** `Transformation#to_a` theo cột (trục X ở 0..2, gốc ở 12..14); trục riêng và tỉ lệ đọc đúng với món đã xoay / scale / lồng nhiều cấp.
- **Đơn vị:** chỉ số `LengthUnit` 0–5 (đặc biệt yd) trong SketchUp thật.
- **Xoay / scale thật:** `Geom::Transformation.rotation`, `.scaling(x, y, z)`, `.axes(origin, x, y, z)` cho kết quả giống ma trận giả lập.
- **Hệ trục riêng:** dời / xoay / scale theo trục của món đã xoay; món bị méo.
- **Spinner trong HtmlDialog thật:** kéo trên ▲▼ (pointer capture), Ctrl / Alt khi kéo, chuột phải không bật menu của trình duyệt.
- Biến đổi trong group đang mở và lồng nhiều cấp; Ctrl+Z đúng một bước; không ảnh hưởng món khác.
- Tải lại code khi cửa sổ đang mở và khi đang kéo (phải bị chặn).
- **Khóa:** `Entity#locked=` trong SketchUp thật (viền đỏ khi chọn món khóa, Ctrl+Z hoàn tác đúng một bước, công cụ Move của SketchUp không dời được món đã khóa); ổ khóa cập nhật khi khóa / mở khóa bằng menu chuột phải của SketchUp.
- Ghi chú ở đáy bảng khi rê chuột trong HtmlDialog thật.
- Icon trên thanh công cụ thật (SVG, cả cỡ nhỏ và lớn), bấm từng nút mở đúng công cụ.
- Cửa sổ 320 × 230 trong SketchUp thật trên màn FHD 24" (cỡ HtmlDialog có tính thanh tiêu đề hay không, chữ có rõ không).
