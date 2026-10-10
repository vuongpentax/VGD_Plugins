# VGD Scenes 1.5.3-beta.4 — SketchUp 2022–2026.2

Prerelease có thông báo cập nhật mỗi 24 giờ và lệnh kiểm tra thủ công. SketchUp hỏi trước khi mở trang tải RBZ; người dùng cài qua Extension Manager rồi khởi động lại.

Plugin tạo view đối tượng, mặt cắt tùy chỉnh, quản lý scene và xuất ảnh/PDF. Thương hiệu VGD, giao diện sáng/tối dùng bảng màu nâu, trắng và than theo theme T+.

### Dọn gọn và an toàn preview (1.5.2)

- Nhập các sửa giao diện từ bản 1.5.1 đã cài trên máy: nút theme tròn 32×32, marker thu gọn tương thích SU22, ô kích thước không có mũi tên thừa.
- Thống nhất **Lưu view** trên toolbar, menu, hàng scene, mục Canh view và hướng dẫn. Giữ nguyên callback/ID để không làm hỏng dữ liệu cũ.
- Gộp CSS trùng/ghi đè, bỏ rule và DOM không dùng của menu hàng, huy hiệu và thanh bước cũ. CSS từ 21.322 xuống 16.895 byte, giảm 20,8%; đối chiếu computed style ở 30 tổ hợp tab/theme/kích thước không có khác biệt.
- Bỏ timer đồng bộ giao diện 700 ms và observer trên từng nút; phản hồi góc nhìn/định dạng cập nhật ngay theo thao tác. Giữ refresh 2 giây để theo dõi scene/camera thay đổi ngoài bảng và một observer tiến trình.
- Preview mặt cắt tạo một plane tạm ở gốc model, không Make Unique, không ghi vào definition dùng chung và không snapshot sâu toàn bộ hình học. Chế độ chỉ hiện đối tượng ghi lại những root instance đổi trạng thái ẩn rồi phục hồi khi dọn. Mặt cắt scene thật vẫn tạo bên trong đối tượng như trước.
- Preview dùng operation thường, tránh abort operation transparent kéo theo thao tác trước của người dùng. Thao tác preview hiện có mục Undo riêng; fixture không chứng minh hành vi Undo/Redo của kernel SketchUp. Sau khi xem thử nên tắt preview trước khi lưu SKP; không sửa/purge definition hoặc mặt cắt cũ của model.
- Ruby WASM 3.2, Ruby 2.7.2 DLL với API mô phỏng và sáu bộ kiểm tra Edge headless đều PASS, gồm lỗi tạo/di chuyển/dọn preview, bản sao dùng chung, 50 scene và 20 lần refresh. Chưa chạy thử kernel/HtmlDialog SU22 thật; không bảo đảm mọi nguyên nhân crash đã được loại bỏ.
- Chỉ cài 17 file VGD Scenes, có backup và đối chiếu SHA256 tất cả file plugin khác. Giữ nguyên bản T+ đã vô hiệu hóa để tham khảo tính năng LayOut sau này.

### Giao diện gọn và thao tác scene (1.5.0)

- Năm tab ở cột trái: Tạo view, Mặt cắt, Scenes, Canh view, Xuất file. Giữ theme sáng/tối. Nút chọn góc chỉ có tên và sáng khi được chọn.
- Mặt cắt chỉ có X/Y/Z, vị trí %, đảo phía cắt. Kéo thanh trượt xem trực tiếp bằng mặt cắt tạm trong đối tượng; dọn khi rời tab, tắt xem trước, tạo scene hoặc đóng dialog. Make Unique bản được chọn nếu definition dùng chung; các bản sao khác không bị cắt.
- Bấm tên scene để mở; bấm đúp để đổi tên. Lưu camera và Xóa nằm ngay trên mỗi hàng. Bỏ Cập nhật từ đối tượng khỏi bảng; tạo/cập nhật view dùng tab Tạo view.
- Shift chọn dải scene, Ctrl chọn thêm/bớt. Kéo tay nắm để di chuyển cả nhóm theo thứ tự đang có; có tự cuộn khi kéo đến mép danh sách.
- Đổi tên hàng loạt theo tiền tố, tên chung (hoặc tên cũ), STT/chữ cái, hậu tố, dấu ngăn cách. Xem trước tên, chặn trùng trước khi ghi; giữ ID, camera và khung.
- Xếp xong bấm Đồng bộ thứ tự SketchUp để áp dụng vào thanh scene gốc. API `Pages#reorder` chỉ có từ SU2025; SU2022–2024 giữ thứ tự bảng cho xuất và cần Move Left/Move Right trên thanh scene gốc. Không xóa/tạo lại scene để đổi vị trí.
- Toolbar Copy/Paste chỉ copy camera đang xem và khung, paste vào view hiện tại. Không tạo/đổi tên/ghi scene; bấm Lưu camera để lưu. Copy/Paste bộ scene, đặt tên/nhập scene và JSON vẫn ở tab Scenes, dùng clipboard riêng.
- Kiểm tra Ruby WASM và Playwright/Edge headless đã PASS, gồm 50 scene, Shift/kéo nhóm, tên trùng, preview mặt cắt và toolbar camera memory. Hiển thị/cắt thật trong SU2022 cần kiểm tra trên máy.

Tài liệu API đổi thứ tự scene: https://ruby.sketchup.com/Sketchup/Pages.html#reorder-instance_method

### Làm mới giao diện (1.4.0)

Giữ nguyên bảng màu nâu/trắng/than, font, theme sáng/tối, ID và engine. Thay đổi chính:

- Chữ tối thiểu 11px; nút chính nâu đậm hơn để đủ tương phản; nút chia ba cấp, trạng thái bật có dấu ✓; nút bị khóa có chú thích lý do khi rê chuột.
- Thanh bước có đường nối và dấu ✓ cho bước đã qua. Theme mặc định theo hệ thống ở lần đầu; nút theme là biểu tượng ◐.
- Bước 1: biểu tượng góc nhìn, nút chính ghi số scene, xem trước tên scene. Bước 2: mỗi scene một dòng gọn với nút kích thước `rộng×cao · tỷ lệ` mở ô sửa khung; menu ⋯ tự đóng; tìm kiếm/chọn nhanh ghim ở đầu danh sách. Bước 3: canh trục theo cặp +/−, huy hiệu **Camera đã đổi · chưa lưu**. Bước 4: nút PNG/JPG/PDF, dòng đường dẫn đầu ra, tiến trình có %.
- Thuật ngữ thống nhất: **Lưu camera** thay cho Update view / Lưu view trong bảng (nút trên toolbar giữ tên cũ).
- `camera.rb`: `CameraControl.state` thêm trường chỉ đọc `sig` để nhận biết camera đã đổi.
- Nền khung lỗi dùng rgba, chỉ nâng cấp bằng `color-mix()` trong `@supports` vì SU2022 dùng Chromium 88.
- Chưa kiểm chứng trong HtmlDialog SU2022 thật.

### Luồng làm việc mới (1.3.1)

1. **Tạo view**: chọn góc nhìn hoặc nhánh Mặt cắt. Cài đặt nguồn/đặt tên thu gọn. Tạo xong tự chuyển sang bước 2 và đánh dấu các scene vừa tạo.
2. **Chọn scene**: đánh dấu, mở scene và sắp xếp. Mỗi dòng vẫn có rộng/cao/tỷ lệ/lề; nút **⋯** chứa Đổi tên/Lưu view. Chọn nhóm, chỉnh hàng loạt, cập nhật nguồn/xóa và chuyển scene giữa file nằm trong các mục mở khi cần.
3. **Canh view**: chọn scene đang chỉnh ngay trên đầu, đặt khung và preset; mở thêm FOV/canh trục hoặc cao độ nếu cần. **Update view** luôn ở chân bảng. Khung tự lưu và camera chỉ lưu khi Update như bản 1.3.0.
4. **Xuất file**: xem bộ scene và kích thước sau scale, chọn định dạng/scale/thư mục ngày rồi xuất. Có thể bỏ qua bước canh nếu scene đã sẵn sàng. Công cụ chuẩn bị SKP nằm trong mục thu gọn riêng.

Giữ nguyên màu, font và theme sáng/tối. Chỉ tổ chức lại điều hướng, nhóm điều khiển và phần tóm tắt đầu ra; engine tạo/cắt/lưu camera/xuất file giữ nguyên.

### Khung tự lưu và camera xem trước (1.3.0)

- Danh sách scene có rộng/cao/tỷ lệ/lề ngay trên từng dòng. Nhập rồi Enter hoặc rời ô để lưu khung của dòng đó; không tự mở scene.
- Trong Xuất & Khung, đổi rộng/cao/tỷ lệ/lề rồi Enter/rời ô, đảo ⇄ hoặc chọn preset tự lưu khung vào scene đang mở. Giữ eye, target, hướng, projection và FOV API của camera đã lưu. Không ghi lúc số đang gõ dở.
- Orbit/Pan/Zoom, FOV, canh trục và Căn lề chỉ đổi camera đang xem. Bấm **Update view** mới lưu góc đó. Ví dụ Orbit thử rồi đổi sang 3:4: xuất trước Update lấy góc cũ với khung 3:4.
- Chỉnh khung hàng loạt áp dụng cho scene đã đánh dấu. Tick **Giữ tỷ lệ riêng** dùng cạnh dài đã nhập, tính cạnh kia theo tỷ lệ từng scene và làm tròn px. Bỏ tick áp dụng cùng rộng/cao. Preset có tên lưu cùng file SKP; chọn preset hàng loạt chỉ điền thông số, bấm Lưu khung hàng loạt để áp dụng.
- FOV dùng độ theo [Camera API](https://ruby.sketchup.com/Sketchup/Camera.html), 1–120°, chỉ Perspective; ghi rõ đo ngang/dọc theo camera hiện tại. Parallel nhập chiều cao vùng nhìn (mm). Không có Overscan.
- Canh camera đủ **+X/−X, +Y/−Y, +Z/−Z** theo trục thế giới hoặc đối tượng. Dấu là hướng nhìn eye→target. Giữ điểm nhìn, khoảng cách và lens; **Tự động** chọn trục gần nhất, không căn lại đối tượng. Local dùng đối tượng chọn đầu tiên, hoặc nguồn của scene VGD đang mở.
- **Chọn cùng tên scene đang mở** đánh dấu các view cùng tên gốc; nhập chuỗi như Tủ bếp để chọn nhanh. Cả hai thao tác giữ nguyên view.

Kiểm thử hồi quy mới đã qua Ruby 2.7.2 DLL (API giả lập), WASM 3.2 và Edge headless. Chưa kiểm chứng các thao tác mới trong kernel/CEF SketchUp thực tế; Undo camera scene trên SU22–25 vẫn có giới hạn.

## Đã cài trên máy

Đã cài SU22 ngày 05/10/2026 lúc 16:05 +07; 17 file khớp nguồn, 8.162 file plugin khác không đổi SHA256. Backup 1.5.1: `outputs/install_20261005_160427_302/`. Không reload SketchUp hoặc sửa model đang mở; lưu công việc rồi khởi động lại để nạp 1.5.2.

- Loader: `%APPDATA%/SketchUp/SketchUp 2022/SketchUp/Plugins/vgd_scenes.rb`
- Thư mục riêng: `.../Plugins/vgd_scenes/`
- Loader scene T+ cũ được sao lưu và đổi thành `tplus_scenes_to_layout.rb.vgd-disabled`; chỉ có hiệu lực tắt ở lần khởi động SketchUp kế tiếp.
- Bộ cài chỉ ghi 17 file riêng của VGD Scenes. Không sửa thư mục `tplus`, plugin Cabinet/Dim hoặc bố trí toolbar khác; script đối chiếu hash tất cả file plugin khác trước/sau và lưu báo cáo trong `outputs/install_*/`.
- Lượt cài 1.1.0 ngày 03/10/2026: 16 file khớp runtime; **7.914 file plugin khác không đổi**. Backup: `outputs/install_20261003_111743_242/`.
- Lượt cài 1.2.0 ngày 03/10/2026: 17 file khớp runtime; **7.939 file plugin khác không đổi**. Backup: `outputs/install_20261003_171852_481/`.
- Lượt cài 1.2.1 ngày 03/10/2026: 17 file khớp runtime; **7.994 file plugin khác không đổi**. Backup: `outputs/install_20261003_183241_486/`.
- Lượt cài 1.2.2 ngày 03/10/2026: 17 file khớp runtime; **8.011 file plugin khác không đổi**. Backup: `outputs/install_20261003_194856_747/`.
- Lượt cài 1.3.0 ngày 04/10/2026: 17 file khớp runtime; **19.882 file plugin khác không đổi**. Backup: `outputs/install_20261004_010855_294/`. Không tắt hoặc đổi loader plugin khác.
- Lượt cài 1.3.1 ngày 04/10/2026: 17 file khớp runtime; **19.881 file plugin khác không đổi**. Backup: `outputs/install_20261004_015555_095/`.
- Báo cáo và bản sao loader cũ nằm trong `outputs/install_*/` trên máy đã cài, không đưa lên GitHub.

Hãy lưu công việc và khởi động lại SketchUp khi thuận tiện. Mở **Extensions → VGD Scenes → VGD Scenes · Bảng điều khiển**. Nếu muốn toolbar, chọn **Hiện thanh công cụ VGD Scenes** trong menu này.

### Cập nhật view bằng một nút

Toolbar có năm nút: bảng điều khiển, 4 view nhanh, **Lưu view**, **Copy scene hiện tại**, **Paste scenes**. Chọn scene, chỉnh camera/khung/mặt cắt rồi bấm nút thứ ba (máy ảnh/mũi tên vòng) để lưu vào scene đang chọn. Không cần mở bảng hoặc chọn đối tượng; giữ tên scene. Các lệnh cũng có trong **Extensions → VGD Scenes** để gán phím tắt.

Lệnh lưu camera, hiển thị, mặt cắt và khung giống **Lưu view** trong bảng. Khi chưa có scene đang chọn, đang edit Group/Component hoặc đang xuất, lệnh báo lý do và không cập nhật.

### Chuyển góc scene từ A sang B

1. Trong file A, lưu view vừa chỉnh vào scene. **Copy scenes** ở mục Scene lấy các scene đã đánh dấu; nếu chưa đánh dấu thì lấy scene đang mở. Copy trên toolbar luôn lấy riêng scene đang mở.
2. Mở file B, bấm **Paste scenes**. Chọn scene trong bảng xem trước và cách xử lý trùng: **Tạo mới** (mặc định, thêm số vào tên), **Cập nhật** hoặc **Bỏ qua**.
3. Cập nhật khớp ID trước, rồi tên chính xác; giữ tên/thứ tự ở B. ID nguồn ổn định qua rename/Save As. Khi nhiều scene cùng khớp mà tên không phân biệt được, plugin từ chối tự chọn. Nếu scene đích đổi sau preview, Paste/Nhập lại.
4. Mang sang máy khác: chọn **Toàn bộ scene trong model** hoặc **Scene đã đánh dấu**, bấm **Xuất bộ scene…**. Ở B dùng **Nhập bộ scene…** với tệp `.vgdscenes.json`. Tệp đã có không bị ghi đè.

Chuyển camera perspective/parallel, vị trí/hướng/roll, FOV hoặc chiều cao parallel và khung width/height/margin. Camera chưa khóa tỷ lệ được cố định theo khung xuất của scene để bố cục không phụ thuộc cửa sổ máy đích. Dùng tọa độ thế giới (inch theo API), không tự căn theo đối tượng: A/B cần cùng gốc và hướng trục. Scene nhập mới chỉ lưu camera, không nhận source paths/hình học từ A. Cập nhật scene VGD sẵn có giữ nguồn của B để dùng Cập nhật từ đối tượng khi chủ động yêu cầu.

Bản này chưa chuyển Tags, style, đối tượng ẩn, mặt cắt hoặc animation; cập nhật giữ thiết lập đó ở B. Từ chối hai điểm/Match Photo vì API không có setter đầy đủ để phục hồi chính xác. Giới hạn 1.000 scene/8 MB; kiểm tra JSON trước khi đổi model.

Clipboard riêng ở `%APPDATA%/VGD/Scenes/scene_clipboard_v1.json`, dùng giữa các process/phiên bản SketchUp trên cùng tài khoản Windows; không dùng clipboard hệ thống. Copy/xuất lần đầu gán attribute ID riêng vào scene nguồn, nên SKP có thể hiện đã sửa; lưu SKP để giữ ID khi mở lại.

### Sửa FOV khi chuyển scene (1.2.2)

Thông báo “FOV quy đổi: ngoài giới hạn” trước đây xuất hiện khi đổi FOV ngang/dọc theo tỷ lệ khung rồi áp giới hạn 1–120° của setter lên góc tương đương. Xuất/đọc JSON giờ chỉ kiểm tra dữ liệu và giữ nguyên FOV/trục đo, không dựng camera hoặc thay đổi camera nguồn. Khi nhập/copy/chỉnh cao độ, dùng cùng phép chuyển trục; góc ngoài 1–120° được đặt qua `image_width`/`focal_length` theo [Camera API](https://ruby.sketchup.com/Sketchup/Camera.html), phục hồi image_width rồi kiểm tra FOV thực tế. Không ép góc về giới hạn. Dữ liệu lỗi và lỗi preflight nhập có tên scene; nhập vẫn dựng tất cả camera trước khi sửa model.

`dev/test_transfer_fov.rb` đã qua Ruby 2.7.2 DLL và WASM 3.2: khung dọc FOV tương đương >120°, khung ngang góc <1°, xuất/đọc/nhập mới/cập nhật/xuất lại, copy/cao độ, camera nguồn nguyên vẹn, lỗi setter/clamp và dữ liệu không hợp lệ. Đây là fixture mô phỏng API, chưa kiểm chứng setter góc cực trị trong kernel SketchUp thật.

### Bỏ khung xám trước khi gửi SKP (1.2.1)

Trong **Xuất & Khung → Gửi file SketchUp**, bấm **Bỏ khung xám tất cả scene**, xác nhận rồi lưu SKP. Hoặc dùng **Extensions → VGD Scenes → VGD · Bỏ khung xám tất cả scene để gửi SKP** mà không mở bảng. Lệnh áp dụng toàn bộ scene trong model, kể cả scene ngoài VGD và scene không được đánh dấu xuất, cùng view hiện tại.

Lệnh đặt `camera.aspect_ratio = 0` trên camera gốc của từng scene theo [Camera API](https://ruby.sketchup.com/Sketchup/Camera.html). Người nhận không cần VGD để xem scene không còn dải xám. Khung nhìn theo tỷ lệ cửa sổ SketchUp của họ nên vùng thấy ở mép có thể rộng/hẹp hơn; kích thước xuất VGD đã lưu vẫn được giữ. Lệnh không cập nhật toàn bộ scene, không đổi vị trí/hướng camera, tên/ID/thứ tự, Tags/style/mặt cắt và không xóa geometry. Không tự lưu/ghi đè SKP.

**Khôi phục khung đã bỏ** dùng backup tỷ lệ riêng lưu cùng SKP. Cần lệnh này trên SU22–25 vì camera scene không có Undo đầy đủ như [SU2026](https://ruby.sketchup.com/Sketchup/Page.html). Khôi phục bỏ qua scene đã xóa hoặc đã chỉnh lại tỷ lệ khác 0; không bật lại lưới. Khi xuất VGD, ảnh vẫn dùng kích thước đã lưu mà không khóa lại camera của scene; bấm Áp dụng khung/Update view sau này có thể lưu khung trở lại, nên chạy Bỏ khung lần cuối trước khi gửi. Có rollback rõ ràng khi lỗi và chặn edit/export/model đã đổi.

Kiểm tra Ruby 2.7.2 DLL và WASM3.2 fixture + Chromium đã qua, gồm rollback lỗi giữa chừng, camera hai điểm không bị dựng lại, native scene/flags/frame size, restore/export, scope toàn model và hủy xác nhận. Chưa kiểm chứng lệnh trong kernel SketchUp thật.

### Sắp xếp và cao độ camera (1.2.0)

- Kéo nút ba sọc cuối dòng scene để đổi thứ tự **riêng trong bảng VGD**. Thứ tự được lưu cùng SKP, có Undo; PNG/JPG, các trang PDF và Copy/Xuất JSON dùng thứ tự này, không phụ thuộc thứ tự tick checkbox. Thanh scene, ID và liên kết scene SketchUp giữ nguyên trên mọi phiên bản. Scene mới thêm từ SketchUp được đặt cuối bảng; xóa/đổi tên vẫn nhận đúng ID. Khi đang lọc, thả trên/dưới một scene lấy vị trí của scene đó trong danh sách đầy đủ, không xóa scene đang ẩn bởi bộ lọc.
- Bấm tên scene rồi dùng ↑/↓ trong bảng để chuyển theo danh sách đang lọc. Không thêm shortcut vào SketchUp; PageUp/PageDown của SU giữ nguyên. Không bắt mũi tên khi đang gõ, ở checkbox, hộp xác nhận, đang xuất hoặc edit Group/Component.
- **Xuất & Khung → Cao độ mắt camera**: nhập Z tuyệt đối hoặc cao độ sàn + Eye Height, đơn vị mm theo trục Z thế giới. Ví dụ sàn +3200 và Eye Height 1500 cho mắt +4700 mm. Giữ hướng nhìn di chuyển cả mắt và điểm nhìn cùng độ cao; bỏ tick giữ điểm nhìn hiện tại. Hỗ trợ Perspective/Parallel; không dùng chiều cao khung Parallel làm Eye Height.
- **Xem trước cao độ** chỉ đổi view hiện tại. Bấm nút **Cập nhật view** trên toolbar hoặc **Lưu view** để lưu scene; xuất tiếp tục dùng camera đã lưu. Hai điểm/Match Photo và edit context được chặn.
- Clipping chưa tích hợp. [Báo cáo thí nghiệm](dev/CLIPPING_RESEARCH.md) và `dev/clipping_lab.rb` nằm riêng, không cài vào SU. Người dùng dừng Computer Use bằng Esc nên chưa kiểm chứng Force/Near trên model mẫu.

### Tương thích phiên bản

Mục tiêu Windows: SketchUp Desktop **2022, 2023, 2024, 2025 và 2026 đến 2026.2**; mốc hiện hành theo [release notes 2026.2](https://help.sketchup.com/en/sketchup-desktop-20262). Không dùng Overlay API hoặc clipboard API chỉ có ở bản mới, không cần thư viện native ngoài.

- Đã chạy cú pháp và bộ fixture với DLL Ruby **2.7.2 đi kèm SU22** trong process console riêng và Ruby WASM **3.2**. Hai bộ kiểm tra không điều khiển SketchUp đang mở.
- `vpwidth/vpheight` và `draw2d` dùng cùng hệ pixel trên từng phiên bản; SU2025+ đổi cả hai sang logical pixels theo [View API](https://ruby.sketchup.com/Sketchup/View.html).
- Chỉnh scene được bọc operation cho SU2026. Với SU22–25, không đảm bảo Undo camera scene; nhập có backup camera/attribute và rollback rõ ràng khi lỗi. Khác biệt theo [Page API](https://ruby.sketchup.com/Sketchup/Page.html).
- **Chưa chạy plugin trong kernel SketchUp thực tế trên tất cả các bản này.** Cần kiểm tra camera/mặt cắt/PNG/PDF và toolbar trên SU22 cùng các bản mới trước khi xác nhận đầy đủ.

## Cách dùng

1. Chọn Group/Component. Trong **Góc nhìn**, chọn view, hệ trục theo đối tượng hoặc thế giới, gộp cụm hoặc từng đối tượng. Bấm **Tạo / Cập nhật góc nhìn**. Có ISO và sáu hướng tiêu chuẩn; lặp lại cùng đối tượng/view sẽ cập nhật scene VGD tương ứng và đổi tên tất cả scene VGD của bộ đối tượng đó theo tên mới, kể cả view không đang chọn và scene mặt cắt. Tên theo mẫu đã lưu; tên sửa tay sẽ được tạo lại khi cập nhật.
2. Trong **Mặt cắt**, chọn X/Y/Z hoặc vector riêng; đặt vị trí theo phần trăm, dịch thêm bằng mm, đảo hướng và tên mặt cắt. Mỗi tên mặt cắt có scene riêng; chạy lại cùng tên sẽ cập nhật. Mặt cắt nằm bên trong từng Group/Component được chọn, không thêm mặt cắt ở cấp model. Component/Group dùng chung sẽ Make Unique bản chọn; với đối tượng nằm trong cha dùng chung, Make Unique cha trước. Camera luôn nhìn từ phía đã bỏ vào phần còn lại, kể cả khi đảo phía cắt.
3. Trong **Scene**, bấm tên để mở, đánh dấu scene cần xuất, đổi tên, xóa hoặc lưu view hiện tại. **Cập nhật từ đối tượng** tính lại camera/mặt cắt và tên scene từ đối tượng nguồn bằng thông số đã lưu, không cần chọn lại đối tượng; **Lưu view** giữ bố cục bạn vừa chỉnh. Undo scene tùy phiên bản SketchUp; xem mục Tương thích.
4. Trong **Xuất & Khung**, chọn preset hoặc nhập tỷ lệ rộng:cao như `3:4`. Enter/rời ô hoặc nút **⇄** tự lưu thông số khung, giữ góc đã lưu. **Căn lề view hiện tại** chỉ preview. **Áp dụng khung** lưu thông số khung; **Update view** mới lưu camera đang xem. **Bật/Tắt khung** đổi khung nhìn hiện tại, không đổi scene đã lưu; **Bật/Tắt lưới** độc lập, Esc tắt lưới.
5. Đánh dấu scene và xuất PNG/JPG vào thư mục, hoặc PDF nhiều trang theo thứ tự riêng trong bảng VGD. Mỗi scene dùng kích thước và bố cục đã lưu riêng (ví dụ TOP 1200×1600, ISO 1920×1080). PDF giữ đúng tỷ lệ từng ảnh trên khổ giấy A4/A3 ngang/dọc đã chọn. Scene cũ chưa lưu kích thước được suy từ khung camera và độ phân giải nguồn/batch. File đã có được thêm số, không ghi đè. Tiến độ và lỗi hiển thị trong dialog; không tạo JSON báo cáo cạnh ảnh.

## Những điểm cần biết

- PNG trong suốt bỏ nền SketchUp; không tự xóa mặt sàn, tường hay vật thể trong hình. JPG/PDF dùng nền bình thường.
- PDF chứa một ảnh của mỗi scene trên một trang, giữ tỷ lệ và chừa lề 10 mm. Đây là PDF hình ảnh, không phải bản vẽ vector có tỷ lệ in kỹ thuật.
- Khung/lưới hỗ trợ bố cục trong cửa sổ model; lưới được tạm ẩn khi xuất.
- Khi xuất, đóng chế độ edit Group/Component và giữ model ổn định. Plugin phục hồi camera, trạng thái hiển thị và mặt cắt sau tác vụ.
- Scene ngoài VGD được liệt kê và có thể xuất. Đổi tên/xóa/lưu view chỉ thực hiện với scene bạn chủ động chọn; cập nhật theo đối tượng chỉ áp dụng scene VGD.
- Khi xóa scene mặt cắt, mặt phẳng cắt VGD được giữ lại để tránh làm hỏng scene khác có thể dùng chung nó. Không xóa mặt cắt của plugin khác.
- Không có chức năng dimension tự động hoặc chuyển viewport sang LayOut; phạm vi bản này tập trung vào scene và xuất hình theo yêu cầu.

## Kiểm tra đã thực hiện

- Kiểm tra cú pháp 9 file runtime Ruby, engine fixture trên Ruby 2.7.2 của SU22 và WASM 3.2: tính năng trước, chuyển giữa model, camera/khung, rename/ID/tên trùng, tạo/cập nhật/bỏ qua, rollback khi lỗi, FOV ngang, JSON lỗi/quá lớn và clipboard qua file.
- Giao diện Chromium: Unicode/HTML, ID, scope xuất/nhập, xác nhận/hủy/lỗi, đổi model, token preview, sáng/tối, 640×780 và 460×540.
- Cài bằng allowlist 17 file và kiểm tra hash các plugin khác. Báo cáo thực tế ở backup lượt cài trong outputs.
- **Chưa hoàn tất kiểm tra engine trong SketchUp 2022 thật.** Script thử đã chạy trên SU22 22.0.316 / Ruby 2.7.2 nhưng dừng ở điều kiện bảo vệ model không rỗng, trước khi tạo hình/scene. Điều khiển máy sau đó được người dùng dừng bằng Esc. Kiểm tra WASM và Chromium không thay thế kiểm thử Ruby 2.7/CEF/LayOut thực tế trong SU22.

Mã nguồn runtime nằm trong `runtime/`; kiểm tra và script cài giới hạn phạm vi nằm trong `dev/`. RBZ chỉ đóng gói runtime, không chứa bộ test hoặc thư viện ngoài.

## Tiếp tục trên máy ở nhà

```powershell
git clone https://github.com/vuongpentax/VGD_Plugins.git
cd VGD_Plugins
```

Kho công khai; cần quyền ghi khi push. Mở repository trong Codex và yêu cầu tiếp tục `VGD_Scenes`, đọc `CODEX_HANDOFF.md` trước. Nếu đã clone, chạy `git pull --ff-only` khi không có thay đổi chưa lưu.

Để cài trên máy mới, dùng SketchUp **Window → Extension Manager → Install Extension**, chọn `VGD_Scenes/VGD_Scenes_v1.3.1.rbz`. Hoặc chạy script giới hạn phạm vi:

```powershell
.\VGD_Scenes\dev\deploy.ps1 -VerifyOnly
.\VGD_Scenes\dev\deploy.ps1
```

Script mặc định cài SU22 bằng APPDATA của tài khoản hiện tại, chỉ cài 17 file VGD. Với bản khác, cài RBZ trong Extension Manager của đúng bản SketchUp hoặc truyền `-PluginRoot` đến Plugins của bản đó. `-RetireLegacy` chỉ tắt loader Scenes T+ đã review đúng hash. Không sửa `tplus` dùng chung.

Kiểm tra mã/giao diện với Node.js 20 trở lên và Google Chrome:

```powershell
cd VGD_Scenes\dev
npm install
npm test
```

Thư viện Node chỉ phục vụ kiểm tra, không cần cho runtime SketchUp. Không đưa `node_modules`, file xuất thử hoặc bản sao cài đặt lên Git. Sau khi sửa và kiểm tra, commit rồi push trước khi chuyển máy.

Có SU22 tại đường dẫn mặc định và Python 3.8+: chạy `python VGD_Scenes/dev/check_ruby27.py` từ root repo để kiểm tra thêm bằng Ruby 2.7.2. Đường dẫn SU22 khác có thể đặt qua biến `VGD_SU22_ROOT`. DLL chỉ dùng trong console test, không đóng gói vào runtime.

## Vector XYZ và cập nhật từ đối tượng

Vector XYZ chỉ hướng vuông góc với mặt phẳng cắt trong hệ trục đã chọn ở Góc nhìn. (0,1,0) là Y; (1,1,0) là hướng chéo 45° giữa X/Y. (2,2,0) có cùng hướng (1,1,0), không làm cắt sâu hơn. Không dùng (0,0,0). Vị trí dùng % và dịch thêm mm; đảo phía cắt không đổi vị trí.

Cập nhật từ đối tượng: đánh dấu scene VGD trong danh sách rồi bấm nút. Plugin tìm lại đối tượng nguồn đã ghi bằng persistent paths, đọc hình học/transform/tên hiện tại, căn camera và mặt cắt theo các thông số lưu lúc tạo scene, rồi đổi tên theo mẫu. Nếu đã sửa thông số trên bảng và muốn áp dụng thông số mới, chọn đối tượng và dùng Tạo/Cập nhật tương ứng. Camera canh tay sẽ bị thay khi cập nhật từ đối tượng; dùng Lưu view để giữ bố cục tay.

Mặt cắt cấp model từ 1.0.0 vẫn giữ cho scene cũ. Đánh dấu scene mặt cắt cũ và Cập nhật từ đối tượng để chuyển scene đó sang mặt cắt bên trong đối tượng.

## Tạo nhanh 4 view

Nút toolbar với icon bốn ô tạo/cập nhật ISO, TOP, FRONT, RIGHT từ đối tượng chọn. Nút bảng điều khiển dùng icon riêng như cũ. Bộ 6 view chuẩn vẫn có trong bảng điều khiển nếu chủ động chọn.

## Khóa tỷ lệ, scale và thư mục xuất (1.0.4)

- Bấm Khóa tỷ lệ để giữ tỷ lệ rộng:cao; nhập rộng hoặc cao thì chiều kia tự nhảy theo. Tắt khóa để nhập độc lập. Pixel làm tròn đến số nguyên; tỷ lệ khóa gốc được giữ khi nhập liên tiếp.
- Scale xuất ảnh chỉ nhân độ phân giải đầu ra của từng scene, không sửa camera/frame trong model. Ví dụ 1920×1080 scale 2 thành 3840×2160; scale 0.5 thành 960×540. Áp dụng PNG/JPG và ảnh đặt trong PDF; khổ giấy PDF giữ nguyên. Cho số dương tùy ý trong giới hạn 1–12000 px mỗi chiều và tối đa 64 triệu pixel sau scale. Kiểm tra toàn bộ scene trước khi xuất.
- Nơi lưu luôn có thư mục loại PNG/JPG/PDF. Tick Tạo thư mục ngày sẽ dùng ngày địa phương máy lúc bắt đầu xuất, ví dụ thư mục chọn/2026.10.03/PNG. PDF chọn tên ở hộp lưu như trước rồi được đặt trong thư mục PDF tương ứng. Không ghi đè file đã có.
