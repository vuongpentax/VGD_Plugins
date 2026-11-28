# VGD Diagram 0.10.6-beta.1

Plugin SketchUp vẽ **sơ đồ cây lắp ráp** của đối tượng: các cấu kiện, số lượng và thứ tự lắp, để khách hàng và thợ lắp đặt dễ hiểu mô hình.

## Trạng thái

**0.10.6-beta.1 (bỏ qua đối tượng ẩn, ghép MP4 chạy nền, CSV an toàn, đối tượng khóa, CI).** Thay đổi so với 0.10.5-beta.1:

- **Đối tượng ẩn:** cây và khung 3D chỉ gồm những gì đang thấy trong SketchUp: bỏ qua đối tượng ẩn (Edit > Hide), đối tượng trên tag đã tắt và trên tag nằm trong thư mục tag đã tắt (kể cả con và mặt bên trong). Muốn đưa vào sơ đồ thì hiện lại rồi bấm **Làm mới**.
- **Ghép MP4 chạy nền:** SketchUp không còn đứng khi ghép. Chân cửa sổ hiện thanh tiến trình, phần trăm và nút **Hủy**; nhóm Xuất bị khóa trong lúc ghép. Hủy, đóng hộp thoại hoặc ffmpeg đứng (120 giây không thêm khung nào) thì ffmpeg bị dừng, file MP4 dở bị xóa, ảnh khung hình được giữ lại. Đang ghép thì không tải lại code. Cách làm: `Process.spawn` ghi tiến trình ra file tạm, bộ hẹn giờ của SketchUp đọc mỗi 0,3 giây (không dùng luồng Ruby).
- **Đối tượng bị khóa:** **Lưu thứ tự** không ghi lên đối tượng bị khóa và báo "Bỏ qua N đối tượng bị khóa (mở khóa rồi lưu lại)".
- **CSV an toàn:** tên bắt đầu bằng `=`, `+`, `-`, `@` được thêm dấu nháy đơn phía trước trong file CSV để Excel không hiểu là công thức. Tên trong model không đổi.
- **CI:** `.github/workflows/vgd-diagram-tests.yml` chạy test Ruby (cài ffmpeg thật), quy ước repo và giao diện Playwright khi đẩy code có thay đổi trong plugin.
- **Kiểm tra tự động:** `dev/test_tree.rb` 56, `dev/test_reload.rb` 27, `dev/test_scene.rb` 16, `dev/test_formats.rb` 6, `dev/test_ffmpeg.rb` 66 (ffmpeg thật, gồm hủy, ffmpeg đứng, đóng hộp thoại), `dev/test_ui.cjs` 113 (Chromium). Test giao diện đã được thử phá để chắc bắt đúng lỗi; đã xem ảnh chụp trạng thái đang ghép ở cả hai theme.
- **Chưa kiểm tra trong SketchUp thật:** ghép nền trên Windows (`Process.spawn`, `Process.wait2` không chặn, bộ hẹn giờ, có thể thấy cửa sổ dòng lệnh đen trong lúc ghép), cách nhận biết ẩn / tag / thư mục tag (`Layer#visible?`, `Layer#folder`), ghi thuộc tính lên đối tượng khóa, và các mục của 0.10.5-beta.1 (bố cục trong HtmlDialog, nút bật / tắt, icon, giải phóng WebGL).

**0.10.5-beta.1 (rà soát lỗi, theo chuẩn repo, bố cục giao diện).** Thay đổi so với 0.10.4-beta.1:

- **Sửa lỗi tên file:** gõ đuôi viết hoa trong hộp lưu (`Anh.PNG`) không còn làm tên ảnh thành `Anh.PNG-truoc.png`.
- **Sửa lỗi ghép MP4:** tên file hoặc thư mục có dấu `%` (ví dụ `tu 50%`) trước đây làm ffmpeg không mở được chuỗi khung hình; nay ghép được.
- **Đổi file SketchUp khi hộp thoại đang mở:** vùng làm việc cũ không còn trỏ nhầm đối tượng của file mới (phải chọn lại rồi bấm Làm mới).
- **Xuất ảnh và video nhiều lần:** trả hẳn context WebGL sau mỗi lần xuất, để không mất khung 3D chính vì vượt giới hạn của trình duyệt. Chưa kiểm tra trong SketchUp thật.
- **Nút trên thanh VGD DGM là nút bật / tắt:** bấm khi hộp thoại đang đóng thì mở, bấm lại thì đóng. Mục menu vẫn chỉ mở.
- **Một danh sách file nạp** (`runtime/vgd_diagram/code_files.rb`) dùng cho cả lúc mở SketchUp và Tải lại code; có test chặn quên file.
- **Icon** theo quy tắc icon của repo (nét 1,8 px, nét chính than `#292B2D`, điểm nhấn `#B48963`). Chưa xem trên thanh công cụ SketchUp thật.
- **Giao diện:** sắp xếp lại theo nhóm chức năng. Cột trái: Làm mới, Đề xuất thứ tự, Kiểm tra, cây cấu kiện, rồi Lưu thứ tự ngay dưới cây. Cột phải: khung 3D, Tách rời, hàng Phát lắp ráp / Đặt lại và nhóm **Xuất** (SVG, Ảnh, Video; ô chọn định dạng ghép liền với nút), mục gập **Ghép MP4 bằng ffmpeg**. Gợi ý xoay / phóng nằm ở chân cửa sổ cho đến khi có thông báo.
- **Theme:** ô chọn, ô nhập, thanh trượt, ô tick và nút theo token và chuẩn điều khiển chung (`vgd-controls.css`); trước đây dùng token `--vgd-input` không tồn tại nên ô nhập không có nền. Có viền focus 2 px.
- **Cỡ cửa sổ:** tối thiểu 720 × 560 (trước là 360 × 480, ở cỡ nhỏ bố cục bị vỡ). Cỡ mặc định 980 × 680 giữ nguyên.
- **Đồ thị mã nguồn** (`graphify-out/`) loại thư viện three.js (`.graphifyignore`), chỉ còn mã của plugin.
- **Kiểm tra tự động:** `dev/test_tree.rb` 46, `dev/test_reload.rb` 27, `dev/test_scene.rb` 11, `dev/test_formats.rb` 6, `dev/test_ffmpeg.rb` 47 (ffmpeg thật), `dev/test_ui.cjs` 103 (Chromium: gồm bố cục ở 980×680, 720×560, 1280×800, sáng và tối, và giải phóng WebGL). Đã xem ảnh chụp giao diện ở cả hai theme.
- **Chưa kiểm tra trong SketchUp thật** (bố cục trong HtmlDialog, nút bật / tắt, icon, cỡ tối thiểu).

**0.10.4-beta.1 (tách rời theo cụm: hướng, khoảng cách và góc nhìn).** Thay đổi so với 0.10.3-beta.1:

- **Cụm:** chọn "Tất cả" hoặc từng cấu kiện trong danh sách (đánh số theo thứ tự trong model).
- **Hướng tách:** Tự động (đẩy ra từ tâm mô hình), Giữ nguyên (cụm không di chuyển), Trước, Sau, Trái, Phải, Lên, Xuống. Chọn "Tất cả" thì đổi hướng cho mọi cụm; nếu các cụm đang khác hướng, ô hiện "Nhiều hướng".
- **Khoảng cách (mm):** nhập tay khoảng cách tách của cụm đang chọn, hoặc bật **Tự động** để plugin tính. Số mm là khoảng cách khi thanh "Tách rời" ở 100 %.
- **Góc nhìn:** Góc đang xem, Trước trái, Trước phải, Sau trái, Sau phải. Có thể vẫn xoay chuột sau khi chọn.
- **Canh khoảng cách:** tách tự động giờ tính theo kích thước của từng cụm (cộng nửa kích thước theo hướng tách và một khe hở nhỏ 5 % kích thước mô hình), nên các cụm tách ra không còn chồng lên nhau như trước.
- **Ảnh xuất và video** dùng cùng công thức tách nên khớp với khung 3D.
- **Kiểm tra tự động:** Chromium (`dev/test_ui.cjs`, 72/72), gồm danh sách, hướng riêng, "Giữ nguyên", khoảng cách nhập tay, bật/tắt Tự động và góc camera. Đã xem ảnh tủ mẫu 6 tấm tách 100 % trong Chromium: các tấm không chồng nhau.
- **Chưa kiểm tra trong SketchUp thật.**

**0.10.3-beta.1 (bỏ MP4 khi quay trực tiếp; sửa lỗi xuất WebM; báo lỗi ffmpeg chi tiết hơn).** Thay đổi so với 0.10.2-beta.1:

- **Bỏ MP4 trong danh sách video:** trình duyệt SketchUp không quay được MP4, nên tùy chọn này đã bỏ. Danh sách còn **WebM** (quay trực tiếp) và **PNG (chuỗi khung hình)**. Muốn có MP4 thì chọn PNG rồi ghép bằng ffmpeg.
- **Sửa lỗi xuất WebM:** bản 0.10.2-beta.1 gọi hàm lưu video nhưng hàm đó bị thiếu, nên báo `undefined method 'save_video'`. Đã bổ sung và có test.
- **Báo lỗi ffmpeg chi tiết hơn:** khi file không chạy được như ffmpeg, thông báo nêu mã thoát và dòng đầu kết quả, để biết vì sao.
- **Kiểm tra tự động:** ffmpeg thật (`dev/test_ffmpeg.rb`, 43/43), gồm luồng lưu WebM và báo lỗi chi tiết. Chromium (`dev/test_ui.cjs`, 60/60).
- **Chưa kiểm tra trong SketchUp thật.**

**0.10.2-beta.1 (ffmpeg: nhập thư mục, dự phòng MPEG-4; hiện số phiên bản).** Thay đổi so với 0.10.1-beta.1:

- **Nhập thư mục:** ô đường dẫn và nút **Chọn...** nhận cả thư mục chứa ffmpeg, ví dụ `C:\Program Files\ShareX`. Plugin tự tìm `ffmpeg.exe` trong thư mục đó (hoặc trong `bin\`) và nhớ đường dẫn file đã tìm được. Nếu không thấy, thông báo nêu rõ đường dẫn đã kiểm tra.
- **Dự phòng MPEG-4:** một số ffmpeg (ví dụ bản đi kèm phần mềm khác) không có bộ mã hóa `libx264`. Khi đó plugin dùng `mpeg4` và vẫn ghép ra file `.mp4`. Chất lượng và độ nén có thể kém hơn H.264. Nếu ffmpeg không có cả hai, plugin báo rõ và không ghép.
- **Số phiên bản:** dưới logo trong hộp thoại có dòng `Phiên bản …` để biết đang chạy bản nào.
- **Kiểm tra tự động:** ffmpeg thật (`dev/test_ffmpeg.rb`, 37/37): nhập thư mục, dự phòng mpeg4 với ffmpeg giả lập thiếu libx264, trường hợp không có bộ mã hóa nào, số phiên bản gửi về giao diện. Chromium (`dev/test_ui.cjs`, 59/59): nhãn phiên bản dưới logo.
- **Chưa kiểm tra trong SketchUp thật**, đặc biệt đường dẫn thư mục có khoảng trắng và tiếng Việt trên Windows.

**0.10.1-beta.1 (sửa lỗi ô đường dẫn ffmpeg không hiện khi mở).** Thay đổi so với 0.10.0-beta.1:

- **Sửa:** khi mở hộp thoại, đường dẫn ffmpeg đã lưu không được gửi về ô nhập, vì một chuỗi lệnh dừng sớm. Đường dẫn vẫn được dùng khi ghép MP4; chỉ có ô hiển thị bị trống.
- **Kiểm tra thêm:** test đi qua các callback với payload JSON như SketchUp gửi, gồm lưu/chọn ffmpeg, xuất ảnh JPG, xuất khung PNG và ghép MP4 (`dev/test_ffmpeg.rb`, 25/25).
- **Chưa kiểm tra trong SketchUp thật.**

**0.10.0-beta.1 (ô đường dẫn ffmpeg, video khớp thứ tự lắp).** Thay đổi so với 0.9.0-beta.1:

- **Ô đường dẫn ffmpeg:** nhập hoặc dán đường dẫn tới `ffmpeg.exe` rồi bấm **Lưu**. Bấm **Chọn...** để chọn bằng hộp thoại. Plugin kiểm tra file đúng là ffmpeg và có bộ mã hóa `libx264`, rồi nhớ lại cho lần sau. Để trống rồi bấm Lưu để xóa cài đặt.
- **Video khớp với "Phát lắp ráp":** trước đây video gom các cấu kiện cùng số thứ tự bay cùng lúc và ẩn cấu kiện chưa đến bước. Bây giờ video dùng đúng thứ tự và thời gian của bản xem trước: từng cấu kiện bay vào lần lượt theo thứ tự, mọi cấu kiện đều hiện từ đầu. Mũi tên và chú thích "Đang lắp" là phần thêm.
- **Ảnh theo bước** (`buoc-NN`) vẫn gom các cấu kiện cùng số thứ tự vào một bước, như thiết kế.
- **Đã kiểm tra tự động:** Chromium (57/57, gồm thứ tự bay và ô ffmpeg), ffmpeg thật (14/14, gồm lưu, từ chối file sai và xóa đường dẫn), Ruby.
- **Chưa kiểm tra trong SketchUp thật.**

**0.9.0-beta.1 (tự ghép MP4 bằng ffmpeg).** Thay đổi so với 0.8.0-beta.1:

- **Tự ghép:** sau khi xuất chuỗi khung hình PNG, plugin dùng ffmpeg trên máy để ghép thành MP4 (`<tên>.mp4`) trong cùng thư mục. Lệnh ffmpeg được gọi bằng danh sách tham số, không qua shell.
- **Tìm ffmpeg:** plugin dùng ffmpeg trong PATH, hoặc file bạn đã chọn trước đó. Nếu chưa có, plugin hỏi bạn chọn file `ffmpeg.exe` và nhớ lại cho lần sau. Cài ffmpeg một lần, ví dụ từ trang chính thức của ffmpeg.
- **Xác nhận trước khi xóa:** sau khi ghép thành công, plugin hỏi có xóa các ảnh khung hình không. Chỉ xóa đúng các ảnh vừa xuất trong lần đó. Nếu ghép lỗi thì giữ lại ảnh.
- **Ghi đè:** nếu MP4 cùng tên đã có, plugin hỏi trước khi ghi đè.
- **Đã kiểm tra tự động:** ffmpeg thật trên máy kiểm tra (`dev/test_ffmpeg.rb`, 10/10): ghép, xóa đúng file, từ chối và giữ lại ảnh, báo khi chưa có ffmpeg.
- **Chưa kiểm tra trong SketchUp thật**, đặc biệt việc gọi ffmpeg.exe trên Windows và đường dẫn có tiếng Việt.

**0.8.0-beta.1 (video MP4 qua chuỗi khung hình PNG).** Thay đổi so với 0.7.0-beta.1:

- **Chọn PNG (chuỗi khung hình) trong ô định dạng video:** plugin ghi từng khung hình thành file PNG đánh số (`<tên>-khung-00001.png`...), 30 khung mỗi giây, cùng nội dung video lắp ráp. Không cần MediaRecorder, nên chạy được trên mọi phiên bản SketchUp, kể cả khi trình duyệt không quay được MP4.
- **Đổi sang MP4 trên máy:** sau khi xuất, thông báo hiện lệnh ffmpeg. Chạy trong thư mục chứa các khung hình (cần cài ffmpeg một lần):

```bash
ffmpeg -framerate 30 -i lap-rap-khung-%05d.png -c:v libx264 -pix_fmt yuv420p lap-rap.mp4
```

- **Đã kiểm tra:** chuỗi khung hình xuất từ plugin đổi thành MP4 H.264 1280×720 bằng đúng lệnh trên (trong môi trường kiểm tra).
- **Chưa kiểm tra trong SketchUp thật.**

**0.7.0-beta.1 (chọn định dạng khi lưu).** Thay đổi so với 0.6.0-beta.1:

- **Hộp lưu:** xuất ảnh và video mở hộp chọn nơi lưu và tên file. Đuôi file bạn gõ quyết định định dạng: ảnh là `.png` hoặc `.jpg`, video là `.webm` hoặc `.png` (chuỗi khung hình). Không gõ đuôi thì dùng định dạng đã chọn cạnh nút.
- **MP4:** chỉ xuất được khi trình duyệt trong SketchUp hỗ trợ quay MP4. Nếu không, plugin báo rõ và bạn chọn WebM. Plugin không tự đổi sang WebM.
- **Chưa có:** GIF, và chuyển đổi video sang định dạng khác ngoài trình duyệt.
- **Chưa kiểm tra trong SketchUp thật.**

**0.6.0-beta.1 (xuất video lắp ráp).** Thay đổi so với 0.5.0-beta.1:

- **Xuất video:** quay video 1280×720, 30 fps, theo góc iso. Mỗi bước: cấu kiện của bước bay vào chỗ, các bước trước đã xám, bước hiện tại tô cam kèm mũi tên và chú thích. Cuối video giữ hình lắp hoàn chỉnh 2 giây. Mỗi bước khoảng 1,6 giây.
- **Định dạng:** WebM, quay trực tiếp trong SketchUp. File lưu là `<tên>-lap-rap.webm`. MP4 chỉ có khi chọn PNG (chuỗi khung hình) rồi ghép bằng ffmpeg.
- **Chưa kiểm tra trong SketchUp thật:** việc quay video (MediaRecorder) có chạy trong SketchUp 2022 không chưa biết; đã kiểm tra trong Chromium (đầu ra MP4/VP9, đúng trình tự bước).

**0.5.0-beta.1 (xuất theo cụm và theo bước lắp, cảnh báo).** Thay đổi so với 0.4.0-beta.1:

- **Xuất theo cụm:** mỗi nhóm cấp đầu một ảnh iso (`cum-01`, `cum-02`...), chỉ hiện cấu kiện của cụm đó.
- **Xuất theo bước:** mỗi số thứ tự lắp là một bước (`buoc-01`, `buoc-02`...). Cấu kiện đã lắp xám, cấu kiện của bước này tô cam kèm mũi tên chiều lắp, cấu kiện chưa lắp bị ẩn, có chú thích tên bước.
- **Cảnh báo:** nút **Kiểm tra** báo nhóm chưa có thứ tự, ảnh quá 15 nhãn, hoặc bước quá nhiều nhãn. Khi xuất cũng hiện cảnh báo tương tự.
- **Đã kiểm tra tự động:** Chromium 42/42 (gồm xuất đủ ảnh theo góc, cụm, bước, và cảnh báo).
- **Chưa kiểm tra trong SketchUp thật.**

**0.4.0-beta.1 (phạm vi theo đối tượng đã chọn, đề xuất thứ tự, xuất ảnh bằng style mặc định).** Thay đổi so với 0.3.0-beta.1:

- **Phạm vi:** sơ đồ, mô hình 3D và xuất ảnh chỉ làm việc với **đối tượng đang chọn** trong model, không phải cả model. Đổi lựa chọn thì bấm **Làm mới** để cập nhật.
- **Đề xuất thứ tự:** điền sẵn số lắp cho mọi nhóm, theo từng lớp group (cùng cấp đánh 1, 2, 3... từ dưới lên, theo độ cao thấp nhất của nhóm). Chưa lưu: kiểm tra rồi bấm **Lưu thứ tự**.
- **Xuất ảnh các góc:** vẽ bằng three.js theo **style mặc định SketchUp giả lập** (mặt xám trắng, cạnh đen, nền trắng), phối cảnh song song, kèm nhãn số. Không còn dùng `View#write_image` nên không phụ thuộc camera hay style của SketchUp.
- **Đã kiểm tra tự động:** logic gom nhóm, sắp thứ tự, đề xuất theo lớp, số trùng, đánh số và CSV, đọc/ghi model giả lập, lấy hình học, menu và Tải lại code, giao diện, khung 3D, nhãn số và xuất 4 ảnh trong Chromium (`dev/`).
- **Chưa kiểm tra trong SketchUp thật.** Cần thử trên SketchUp 2022 (Windows), đặc biệt khung 3D (WebGL) trong hộp thoại SketchUp.
- **Chưa làm:** sơ đồ mũi tên hướng lắp, SVG vector đúng style SketchUp, dùng đúng style đang bật của model.

## Cách dùng

1. Chọn đối tượng (nhóm hoặc component) trong model.
2. Bấm **Extensions → VGD → VGD Diagram → VGD Diagram** (chỉ mở) hoặc nút trên thanh **VGD DGM** (bấm lần nữa thì đóng), rồi bấm **Làm mới**.
3. Cây hiện các cấu kiện ở cấp đầu, bên trong là cấu kiện con.
   - Bấm tên để chọn các bản đó trong model.
   - Nhập thứ tự lắp (số nguyên 1 đến 9999) rồi bấm **Lưu thứ tự**. Có thể dùng Ctrl+Z để hoàn tác.
   - Hoặc bấm **Đề xuất thứ tự** để điền sẵn theo lớp group, rồi kiểm tra và lưu.
   - Số thứ tự chỉ cần không trùng giữa các cấu kiện **cùng cấp**.
4. Nhóm **Xuất** dưới khung 3D: **SVG** lưu sơ đồ thành file ảnh vector (vẽ bằng plugin).
5. **Ảnh** chọn nơi lưu. Plugin lưu:
   - 4 ảnh tổng quan (`truoc`, `phai`, `tren`, `iso`) theo trạng thái mô hình 3D hiện tại;
   - ảnh theo cụm (`cum-01`...), mỗi nhóm cấp đầu một ảnh;
   - ảnh theo bước (`buoc-01`...), mỗi số thứ tự lắp một ảnh;
   - file `danh-sach.csv`.
6. **Kiểm tra** báo các điều cần sửa trước khi xuất (nhóm chưa có thứ tự, quá nhiều nhãn trên một ảnh).
7. **Định dạng:** chọn PNG hoặc JPG (ảnh), WebM hoặc PNG chuỗi khung hình (video) ở ô liền bên nút **Ảnh** / **Video**; hoặc gõ đuôi file trong hộp lưu. Muốn có MP4: chọn PNG chuỗi khung hình, plugin ghép bằng ffmpeg ở nền (đặt đường dẫn trong mục gập **Ghép MP4 bằng ffmpeg**; xem tiến trình và bấm **Hủy** ở chân cửa sổ).

## Mô hình 3D

- Hình học lấy từ các mặt của đối tượng đã chọn, chỉ đọc. Model không bị đổi khi tách rời hay phát lắp ráp. Đối tượng đang ẩn hoặc trên tag đã tắt không có trong sơ đồ.
- **Tách rời:** mặc định (Hướng tách "Tự động") mỗi cụm đi ra xa tâm mô hình, cộng nửa kích thước của cụm và một khe hở nhỏ. Có thể đặt hướng tách cố định (Trước, Sau, Trái, Phải, Lên, Xuống) hoặc Giữ nguyên cho từng cụm, và nhập khoảng cách tay (mm). Khi chọn một hướng cố định, cụm nằm phía ngược với hướng đó vẫn chỉ được đẩy đi theo kích thước của chính nó.
- **Phát lắp ráp:** các cấu kiện có thứ tự lắp được lắp lần lượt từ 1 đến hết. Cấu kiện chưa có thứ tự theo thanh trượt.
- Số nhãn hiện trên cây và trên mô hình, khớp nhau. Mỗi nhóm có hình học một nhãn, đặt trên cấu kiện đầu tiên của nhóm.
- Khi bấm tên hoặc trỏ vào một dòng trong cây, các cấu kiện thuộc dòng đó được tô màu cam.
- Giới hạn: tối đa 100.000 tam giác. Mô hình lớn hơn sẽ bị cắt bớt và có thông báo.
- Thư viện three.js r150.1 (MIT) nằm trong `runtime/vgd_diagram/vendor/`, không cần mạng.

## Quy tắc gom và thứ tự (giả định cần xác nhận)

- Các cấu kiện **cùng tên và cùng cấu trúc con** được gom thành một dòng kèm số lượng (ví dụ "Chân × 4").
- Dòng con chỉ hiện theo **một bản đại diện**. Khi bấm một dòng, chỉ các bản thuộc đại diện đó được chọn.
- Thứ tự lắp lưu thành thuộc tính trong model (dictionary `VGD_Diagram`, khóa `order`). Thứ tự áp cho mọi bản trong nhóm. Khi các bản có thứ tự khác nhau, ô hiện "nhiều số".
- Plugin **chỉ đọc** hình học. Chỉ thêm/xóa thuộc tính thứ tự khi bạn bấm Lưu thứ tự, và bỏ qua đối tượng bị khóa.

## Cài đặt và tải lại

- Cài file `VGD_Diagram_v<phiên bản>.rbz` qua Extension Manager.
- Nút **Tải lại code** (Extensions → VGD → VGD Diagram → Tải lại code) nạp lại mã sau khi cài bản mới. Không tải lại khi đang ghi thứ tự lắp.
- Menu và toolbar chỉ đổi sau khi **mở lại SketchUp**.

## Kiểm thử

Chạy từ thư mục `plugins/VGD_Diagram`:

```bash
ruby dev/test_tree.rb
ruby dev/test_reload.rb
ruby dev/test_scene.rb
ruby dev/test_formats.rb
ruby dev/test_ffmpeg.rb   # cần ffmpeg trong PATH
node dev/test_ui.cjs
```

Đóng gói: `python dev/package.py` (tạo RBZ và SHA-256 trong `outputs/`, không commit).
