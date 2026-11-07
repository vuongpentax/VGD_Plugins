# VGD_BIM — Hướng dẫn nhanh

Mở bằng **Extensions → VGD → VGD_BIM**: cửa sổ mở thẳng tab **Bảng khối lượng**. Cửa sổ có 5 tab: Bảng khối lượng · Thông tin · Quét & xuất · Phân loại · Soạn tag. Mọi tab nằm trong cùng một cửa sổ.

## Bóc khối lượng nhanh (Bảng khối lượng)

1. Chọn group hoặc component trong SketchUp. Bảng tự đọc đối tượng đang chọn, không quét cả model.
2. Chọn **preset cột** (Tất cả, Phần thô, Hoàn thiện, Đồ rời) hoặc tự chọn cột, kéo đổi thứ tự, kéo giãn độ rộng cột. Lưu bộ cột của bạn thành preset riêng; bảng nhớ lại cột và thứ tự khi mở lại SketchUp.
3. **Chọn nhiều dòng như Excel:** bấm = một dòng; giữ **Ctrl** và bấm = thêm hoặc bớt một dòng; giữ **Shift** và bấm = chọn cả dãy từ dòng đã bấm trước đó; **Ctrl + Shift** và bấm = thêm cả dãy; **Ctrl+A** = chọn hết các dòng đang hiện; **Esc** = bỏ chọn. SketchUp cũng chọn các đối tượng đó để bạn dùng tiếp ở tab Thông tin, Phân loại, Soạn tag. Nếu các dòng nằm ở cấp lồng khác nhau, SketchUp chỉ chọn dòng cuối (đổi tên vẫn áp dụng cho mọi dòng đã chọn).
4. Bấm một ô: đối tượng được đánh dấu trong SketchUp bằng khung nét đứt và khung tên. Bấm ô **Tên** thì khung hiện tên, bấm ô **Mô tả** thì hiện mô tả; bấm cả dòng thì hiện tên, mô tả, tình trạng và phân loại. Bỏ chọn thì khung tắt. Trên SketchUp 2023 trở lên, bạn chọn đối tượng bằng công cụ Select như bình thường (Shift/Ctrl chọn nhiều, kéo chọn, nhấp đúp vào group). Trên SketchUp 2022, khi khung đang bật các thao tác chọn nhiều đó không dùng được: nhấn **Esc** hoặc chọn công cụ khác rồi thao tác.
5. **Nhấp đúp** vào ô để sửa. **Tên**, **Mô tả**: gõ ngay trong ô, Enter để lưu, Esc để hủy. **Tình trạng** (Mới, Hiện hữu, Dùng lại, Tạm thời, Loại bỏ), **Tag**, **Vật liệu**: hiện bảng chọn có ô tìm kiếm, mục hiện tại có dấu ✓; Enter chọn mục đầu tiên; ở ô Tag gõ tên chưa có sẽ có mục **Tạo tag**. Muốn sửa nhiều đối tượng một lúc, chọn nhiều dòng (Ctrl / Shift) rồi nhấp đúp vào ô của một dòng trong vùng chọn. Đối tượng bị khóa được bỏ qua. Cả đợt là một bước hoàn tác (Ctrl+Z).
6. **Nhóm theo**: bấm nút **Nhóm theo** rồi chọn Cha, Loại, Tên họ, Tên, Vật liệu, Tag, Nhóm hạng mục hoặc Tình trạng. Mỗi nhóm có dòng tiêu đề (tên nhóm, số đối tượng, tổng); bấm mũi tên để thu gọn, bấm tiêu đề để chọn cả nhóm rồi sửa hoặc đổi tên hàng loạt. Tích **Gộp dòng giống nhau** để gộp các dòng giống hệt nhau thành một dòng (Số lượng, diện tích, thể tích cộng dồn).
7. Tuỳ chọn ở thanh công cụ: **Thu phóng**, **Cô lập đối tượng chọn** (tạm ẩn các đối tượng khác; tắt tuỳ chọn hoặc đóng cửa sổ để hiện lại, và đừng lưu file khi đang cô lập), **Chọn sâu bên trong** (đọc cả group / component nằm bên trong), dòng **Tổng cộng**, **Tổng chỉ cấp cao nhất** (không cộng trùng group lồng nhau).

## Đổi tên hàng loạt

1. Trong tab **Bảng khối lượng**, chọn các dòng cần đặt tên (Ctrl / Shift như trên) rồi bấm **Đổi tên**. Panel ghi rõ áp dụng cho bao nhiêu dòng; chưa chọn dòng nào thì áp cho mọi dòng trong bảng.
2. Nhập **Mẫu tên**, ví dụ `Cửa-{số}` hoặc `{phân loại}-{số}`. Bấm các nút `{tên}`, `{họ}`, `{phân loại}`, `{nhóm}`, `{số}` để chèn: tên hiện tại, tên định nghĩa, phân loại, nhóm hạng mục, số thứ tự.
3. Cần thì **Tìm** / **Thay bằng**, **Tiền tố** / **Hậu tố**, **Kiểu chữ**. Với số thứ tự, chọn **Số bắt đầu**, **Số chữ số** (ví dụ 2 thì ra 01, 02), **Bước nhảy** và **Đánh số theo**: thứ tự trong bảng, vị trí (X rồi Y rồi Z) hoặc tên hiện tại.
4. Bấm **Xem trước** để xem tên cũ và tên mới. Dòng bị khóa được bỏ qua, tên trùng nhau được đánh dấu. Sửa bất kỳ ô nào thì phải xem trước lại.
5. Bấm **Áp dụng**. Cả đợt là một bước hoàn tác (Ctrl+Z). Chỉ đổi tên đối tượng, không đổi tên định nghĩa dùng chung nên các bản sao khác không bị ảnh hưởng.

Lưu ý: diện tích (X*Z), (X*Y) tính theo khung bao của đối tượng; thể tích chỉ có cho group kín. Số liệu chưa trừ hao hụt hoặc phần bị che.

## Gắn dữ liệu hạng mục (Thông tin)

1. Chọn nhóm hoặc đối tượng nội thất trong SketchUp rồi mở tab **Thông tin**.
2. Chọn **Mẫu hạng mục**, ví dụ **Tủ áo**, **Tủ bếp dưới**, **Ổ cắm**. Mẫu điền nhóm, loại, đơn vị và cách đo; không tự sửa mô tả của bạn.
3. Đánh dấu **Mô tả tiếng Việt**, nhập tên dùng trong bảng báo giá, ví dụ `Tủ áo phòng ngủ chính`. Điền mã hạng mục, khu vực và tầng nếu cần.
4. Bấm **Áp dụng thông tin**. Chỉ các trường được đánh dấu mới đổi. Chọn nhiều đối tượng để nhập cùng lúc.

Chuột phải vào group hoặc component và chọn **VGD_BIM · Thông tin đối tượng** để mở nhanh tab này.

## Với model của đối tác hoặc model cũ

1. **Quét & xuất** để xem số lượng thành phần và diện tích vật liệu đang có. Có thể quét cả model hoặc chỉ đối tượng đang chọn, và bật / tắt quét mặt để quét nhanh hơn.
2. **Phân loại** để xem gợi ý theo tên. Gợi ý chưa tự ghi vào model.
3. Bấm **Chỉnh thông tin** ở dòng cần làm. Nhập mô tả, mã hạng mục và phân loại phù hợp.
4. Bấm **Xem trước chuyển đổi** để xem số đối tượng bị ảnh hưởng, rồi **Xác nhận chuyển đổi**.
5. Dữ liệu VGD đã có và đối tượng khóa được bảo vệ. Hình học, tên, thẻ và vật liệu giữ nguyên.
6. Trong tab **Phân loại**, mở **Kiểm tra** để xem thông tin còn thiếu. Bấm dòng kết quả để tìm đúng đối tượng cần sửa.

## Xuất báo cáo (Quét & xuất)

Chọn báo cáo rồi chọn vị trí lưu file CSV. File mở bằng Excel, có tiêu đề và tên nhóm hạng mục bằng tiếng Việt.

| Báo cáo | Nội dung |
|---|---|
| Danh mục đối tượng | Mã, mô tả, nhóm, loại, đơn vị, cách đo, khu vực, tầng, nguồn dữ liệu và kích thước từng lần xuất hiện |
| Thống kê thành phần | Số lần xuất hiện theo định nghĩa, tên, thẻ, vật liệu và kích thước mẫu |
| Diện tích vật liệu gốc | Diện tích mặt trước và mặt sau có sơn, tính từ hình học hiện tại |
| Kết quả kiểm tra | Thông tin còn thiếu, lỗi đơn vị và cảnh báo |

Các báo cáo chưa tính đơn giá/thành tiền. Danh mục có cả đối tượng cha và con để kiểm tra dữ liệu; không cộng các dòng thành tổng khối lượng công việc. Diện tích gốc chưa trừ hao hụt hoặc phần bị che. Plugin không đọc cạnh (edge) nên báo cáo không có số cạnh hay chiều dài cạnh.

File CSV dùng UTF-8, dấu chấm phẩy tách cột và dấu phẩy thập phân. Nếu Excel mở chưa đúng, chọn **Dữ liệu → Từ văn bản/CSV**, chọn UTF-8 và dấu chấm phẩy.

## Preset, đơn vị và ảnh (nút Preset ở thanh đầu)

Nút **Preset** nằm cạnh nút Sáng/Tối. Bấm vào để mở bảng gồm hai phần: bên trái là **Đơn vị** và **Hình ảnh**, bên phải là danh sách preset.

1. **Chọn preset**: bấm tên preset. Bảng đổi cột, tiêu đề cột, đơn vị và cách chụp ảnh theo preset. Nút ↻ cạnh preset có sẵn khôi phục về bản gốc.
2. **Tạo preset**: sắp xếp bảng như ý (chọn cột, kéo thứ tự, đổi đơn vị, đổi tên cột), gõ tên vào ô **Tạo mới...** rồi bấm **+**. Từ đó, mọi thay đổi trong lúc dùng preset này tự cập nhật vào nó. Nút × xóa preset tự tạo.
3. **Đổi tên cột**: nhấp đúp vào tiêu đề cột, gõ tên mới rồi Enter (Esc hủy, để trống để về tên gốc). Tên cột lưu theo preset.
4. **Đơn vị**: chọn đơn vị và số lẻ cho chiều dài, diện tích, thể tích; chọn tiền tệ và dấu thập phân. Chỉ đổi cách hiển thị, báo cáo CSV ở tab Quét & xuất vẫn dùng mm.
5. **Nhập / Xuất** (menu ở chân trang): nhập hoặc xuất preset bằng file JSON (đọc được file preset của plugin tham khảo), hoặc xuất bảng đang hiện ra CSV để mở bằng Excel.

Ảnh món đồ nằm trong cột **Ảnh** của Bảng khối lượng (bật trong **Chọn cột**, preset "Tất cả" đã có sẵn). Ảnh **chỉ được chụp khi bạn bấm**, plugin không tự chụp:

1. Bấm **Cập nhật ảnh**: hộp xác nhận cho biết sẽ chụp bao nhiêu đối tượng (đang chọn, hoặc tất cả đang hiện). Tích **Chỉ chụp đối tượng chưa có ảnh** để bỏ qua đối tượng đã có. Chụp nhiều thì có nút **Dừng**; mỗi lần tối đa 200 đối tượng.
2. Rê chuột vào một ô ảnh để chụp lại riêng dòng đó (↻), chọn file ảnh (⋯) hoặc xóa ảnh (×).
3. Trong bảng Preset, phần **Hình ảnh** chọn cỡ ảnh (rộng, cao), **góc nhìn** (Khung nhìn hiện tại, Phối cảnh iso, Chính diện), kiểu hiển thị (Màu có texture hoặc Kiểu hiện tại), nền (trong suốt hoặc trắng) và thư mục lưu ảnh. Khung nhìn hiện tại chụp đúng những gì đang thấy. Iso và Chính diện cô lập món đồ: tạm ẩn phần còn lại, đặt camera, chụp rồi trả model về như cũ, không để lại bước hoàn tác. Chính diện là nhìn từ phía -Y của model. Món đồ nằm trong thành phần dùng chung nhiều nơi thì không cô lập được; hãy dùng Khung nhìn hiện tại.
4. Muốn dùng ảnh của bạn: kéo thả file ảnh (PNG, JPG, WebP, BMP) vào ô ảnh, hoặc bấm ô rồi dán ảnh đã copy (**Ctrl+V**), hoặc nút ⋯. Ảnh được thu nhỏ vừa khung rộng x cao của preset.
5. Ảnh lưu thành file PNG ngoài file SketchUp, theo từng model và mã đối tượng. Chép file SKP sang máy khác thì ảnh không đi theo: hãy sao lưu thư mục ảnh cùng file SKP.

Nút ⚙ ở thanh đầu chỉ để chọn **ngôn ngữ** (Tiếng Việt / English). Đổi sẽ tải lại cửa sổ. Báo cáo CSV và hộp thoại gốc của SketchUp vẫn bằng tiếng Việt.

## Các cột mới của Bảng khối lượng

**Diện tích chiếu** (hình chiếu xuống mặt phẳng ngang, hợp cho phòng và khu vực; chỉ tính khi bật công tắc **Diện tích chiếu** ở chân trang, hoặc tự bật khi bạn hiện cột này), **Lớp IFC** (đọc phân loại IFC có sẵn), **Hãng**, **Link** (nút ↗ mở bằng trình duyệt; chỉ nhận http hoặc https), **Cỡ**, **Đơn giá** (bạn tự nhập, chỉ số, ví dụ 1250000 hoặc 12,5) và **Thành tiền** (= đơn giá x số lượng, dòng tổng cộng cộng dồn). Nhấp đúp vào ô để nhập. Link, Cỡ, Đơn giá được lưu riêng cho bảng, không đổi dữ liệu dùng chung với các plugin VGD khác.

## Thay thế hàng loạt chữ

Gõ chữ vào ô **Tìm kiếm** thì hiện thêm ô **Thay bằng** và nút **Thay thế (n)** (n là số ô sẽ đổi). Chữ được thay trong các cột Tên, Mô tả, Hãng, Cỡ đang hiện, ở các dòng đang lọc, không phân biệt hoa thường; cả đợt là một bước hoàn tác (Ctrl+Z) và đối tượng bị khóa được bỏ qua.

## Soạn tag

Tab **Soạn tag** để soạn bộ tag theo nhóm hạng mục (Phần thô, Hoàn thiện, Đồ rời, Thiết bị, Khác), gán tag cho group, component hoặc mặt đang chọn, và xuất / nhập bộ tag bằng CSV (mở được trong Excel) hoặc JSON. Khi nhập, chọn thay thế toàn bộ hoặc gộp vào bộ hiện có. Bộ tag lưu trên máy này.

## Quy tắc phân loại

Trong tab **Phân loại**, mở **Quy tắc → Thêm quy tắc**: chọn loại nguồn, nhập tên nguồn cần khớp, chọn mẫu hoặc nhập thông tin, rồi **Lưu quy tắc**. Xuất / Nhập bộ quy tắc để dùng ở model khác. Mục dữ liệu kỹ thuật được thu gọn, không cần dùng cho thao tác thông thường.

## Cửa sổ và cập nhật

Nút **Sáng / Tối** lưu lựa chọn giao diện trên máy. Sau khi cài đè bản mới, dùng **Extensions → VGD → VGD_BIM · Tải lại code** để nạp lại mã mà không cần mở lại SketchUp; menu và toolbar mới chỉ có tác dụng sau khi mở lại SketchUp. Lưu file đang làm trước khi tải lại.
