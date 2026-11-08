# VGD_BIM — Hướng dẫn nhanh

Mở bằng **Extensions → VGD → VGD_BIM**: cửa sổ mở thẳng tab **Bảng khối lượng**. Cửa sổ có 5 tab: Bảng khối lượng · Thông tin · Quét & xuất · Phân loại · Soạn tag. Mọi tab nằm trong cùng một cửa sổ.

## Bóc khối lượng nhanh (Bảng khối lượng)

1. Chọn group hoặc component trong SketchUp. Bảng tự đọc đối tượng đang chọn, không quét cả model.
2. Chọn **preset cột** (Tất cả, Phần thô, Hoàn thiện, Đồ rời) hoặc tự chọn cột, kéo đổi thứ tự, kéo giãn độ rộng cột. Lưu bộ cột của bạn thành preset riêng; bảng nhớ lại cột và thứ tự khi mở lại SketchUp.
3. **Chọn nhiều dòng như Excel:** bấm = một dòng; giữ **Ctrl** và bấm = thêm hoặc bớt một dòng; giữ **Shift** và bấm = chọn cả dãy từ dòng đã bấm trước đó; **Ctrl + Shift** và bấm = thêm cả dãy; **Ctrl+A** = chọn hết các dòng đang hiện; **Esc** = bỏ chọn. SketchUp cũng chọn các đối tượng đó để bạn dùng tiếp ở tab Thông tin, Phân loại, Soạn tag. Nếu các dòng nằm ở cấp lồng khác nhau, SketchUp chỉ chọn dòng cuối (đổi tên vẫn áp dụng cho mọi dòng đã chọn).
4. **Bỏ chọn**: bấm vùng trống trong SketchUp (bảng giữ nguyên, chỉ bỏ khung đánh dấu) hoặc nhấn **Esc** trong bảng. Bảng chiếm hết chiều cao cửa sổ: các nút gạt tuỳ chọn ở dưới cùng và tiêu đề cột luôn hiện, chỉ các hàng cuộn.
5. Bấm một ô: đối tượng được đánh dấu trong SketchUp bằng khung nét đứt và khung tên. Bấm ô **Tên** thì khung hiện tên, bấm ô **Mô tả** thì hiện mô tả; bấm cả dòng thì hiện tên, mô tả, tình trạng và phân loại. Bỏ chọn thì khung tắt. Trên SketchUp 2023 trở lên, bạn chọn đối tượng bằng công cụ Select như bình thường (Shift/Ctrl chọn nhiều, kéo chọn, nhấp đúp vào group). Trên SketchUp 2022, khi khung đang bật các thao tác chọn nhiều đó không dùng được: nhấn **Esc** hoặc chọn công cụ khác rồi thao tác.
6. **Nhấp đúp** vào ô để sửa. **Tên**, **Mô tả**: gõ ngay trong ô, Enter để lưu, Esc để hủy. **Tình trạng** (Mới, Hiện hữu, Dùng lại, Tạm thời, Loại bỏ), **Tag**, **Vật liệu**: hiện bảng chọn có ô tìm kiếm, mục hiện tại có dấu ✓; Enter chọn mục đầu tiên; ở ô Tag gõ tên chưa có sẽ có mục **Tạo tag**. Muốn sửa nhiều đối tượng một lúc, chọn nhiều dòng (Ctrl / Shift) rồi nhấp đúp vào ô của một dòng trong vùng chọn. Đối tượng bị khóa được bỏ qua. Cả đợt là một bước hoàn tác (Ctrl+Z).
7. **Nhóm theo**: bấm nút **Nhóm theo** rồi chọn Cha, Loại, Tên họ, Tên, Vật liệu, Tag, Nhóm hạng mục hoặc Tình trạng. Mỗi nhóm có dòng tiêu đề (tên nhóm, số đối tượng, tổng); bấm mũi tên để thu gọn, bấm tiêu đề để chọn cả nhóm rồi sửa hoặc đổi tên hàng loạt. Tích **Gộp dòng giống nhau** để gộp các dòng giống hệt nhau thành một dòng (Số lượng, diện tích, thể tích cộng dồn).
8. **Độ cao hàng**: giữ Ctrl và lăn chuột giữa trên bảng để tăng / giảm độ cao hàng (28 đến 640 px); mọi hàng cao đều nhau, cột Ảnh tự rộng theo để ảnh to ra thật sự (vẫn kéo tay đổi độ rộng cột được), độ cao được nhớ cho lần mở sau. Ảnh trong bảng là ảnh gốc đã chụp. Chọn lại "Hàng: Gọn / Vừa / Thoáng" ở Chọn cột thì về độ cao theo mật độ. Số dòng đang chọn hiện ở chân trang, dưới dòng thông báo. Danh sách **Chọn cột** luôn ghi tên chuẩn của cột; nếu preset đổi tiêu đề thì có ghi chú "hiện trong bảng: ..." bên cạnh. Tuỳ chọn ở thanh công cụ: **Thu phóng**, **Cô lập đối tượng chọn** (tạm ẩn các đối tượng khác; tắt tuỳ chọn hoặc đóng cửa sổ để hiện lại, và đừng lưu file khi đang cô lập), **Chọn sâu bên trong** (đọc cả group / component nằm bên trong), dòng **Tổng cộng**, **Tổng chỉ cấp cao nhất** (không cộng trùng group lồng nhau).

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
5. **Nhập / Xuất** (menu ở chân trang): nhập hoặc xuất preset bằng file JSON (đọc được file preset của plugin tham khảo), hoặc xuất bảng đang hiện:
   - **Xuất Excel**: tạo file .xlsx đúng như bảng đang hiện (cột, thứ tự, tiêu đề, đơn vị, nhóm, dòng tổng), có ảnh món đồ trong ô. Muốn có ảnh, hãy bấm Cập nhật ảnh trước. Ảnh trong Excel và PDF là ảnh đầy đủ theo cỡ đã chụp (đặt trong bảng Preset), chỉ hiển thị thu nhỏ vừa ô; bấm vào ảnh trong Excel để xem rõ. Chụp cỡ lớn thì file xuất nặng hơn.
   - **In PDF**: tạo trang báo cáo rồi mở trong trình duyệt. Trang **không tự mở hộp in**; khi cần in, bấm nút **In / Lưu PDF** trên trang (hoặc Ctrl+P) và chọn **Lưu thành PDF**. Ô nào quá rộng thì kéo mép tiêu đề cột trên trang để chia lại độ rộng (cột bên cạnh hẹp đi tương ứng); nút **Đặt lại độ rộng cột** đưa về lúc đầu. Độ rộng ban đầu theo độ rộng cột bạn đã chỉnh trong bảng. Trang A4 ngang, tiêu đề cột lặp lại mỗi trang.
   - **Cầu nối dữ liệu**: đã có sẵn chỗ trong menu, sẽ làm sau.

Ảnh món đồ nằm trong cột **Ảnh** của Bảng khối lượng (bật trong **Chọn cột**: ngăn bên trái đẩy bảng sang phải, tick để hiện / ẩn cột, kéo biểu tượng ⠿ để đổi thứ tự; preset "Tất cả" đã có sẵn). Ảnh **chỉ được chụp khi bạn bấm**, plugin không tự chụp:

Ảnh được nhớ theo một mã cố định ghi trong file SketchUp, nên tắt và mở lại file vẫn còn ảnh (không phải chụp lại, không sinh thư mục ảnh mới). **Hãy lưu file SketchUp sau lần đầu dùng BIM** để mã này được giữ. Lưu thành bản khác (Save As) dùng chung thư mục ảnh với bản gốc. Ảnh đã chụp ở các bản trước (thư mục đặt theo mã tạm của SketchUp) không nối lại được; chỉ ảnh chụp trong phiên đang mở lúc cập nhật bản này được chuyển sang thư mục mới.

1. Bấm **Cập nhật ảnh**: hộp xác nhận cho biết sẽ chụp bao nhiêu đối tượng (đang chọn, hoặc tất cả đang hiện). Tích **Chỉ chụp đối tượng chưa có ảnh** để bỏ qua đối tượng đã có. Chụp nhiều thì có nút **Dừng**; mỗi lần tối đa 200 đối tượng.
2. Rê chuột vào một ô ảnh để chụp lại riêng dòng đó (↻), chọn file ảnh (⋯) hoặc xóa ảnh (×).
3. Trong bảng Preset, phần **Hình ảnh** chọn cỡ ảnh (rộng, cao), **góc nhìn** (Khung nhìn hiện tại, Phối cảnh iso, Chính diện), kiểu hiển thị (Màu có texture hoặc Kiểu hiện tại), nền (trong suốt hoặc trắng) và thư mục lưu ảnh. Khung nhìn hiện tại chụp đúng những gì đang thấy. Iso và Chính diện cô lập món đồ: tạm ẩn phần còn lại, đặt camera, chụp rồi trả model về như cũ, không để lại bước hoàn tác. Chính diện là nhìn từ phía -Y của model. Món đồ nằm trong thành phần dùng chung nhiều nơi thì không cô lập được; hãy dùng Khung nhìn hiện tại.
4. Muốn dùng ảnh của bạn: kéo thả file ảnh (PNG, JPG, WebP, BMP) vào ô ảnh, hoặc bấm ô rồi dán ảnh đã copy (**Ctrl+V**), hoặc nút ⋯. Ảnh được thu nhỏ vừa khung rộng x cao của preset.
5. Ảnh lưu thành file PNG ngoài file SketchUp, theo từng model và mã đối tượng. Chép file SKP sang máy khác thì ảnh không đi theo: hãy sao lưu thư mục ảnh cùng file SKP.

Nút ⚙ ở thanh đầu chỉ để chọn **ngôn ngữ** (Tiếng Việt / English). Đổi sẽ tải lại cửa sổ. Báo cáo CSV và hộp thoại gốc của SketchUp vẫn bằng tiếng Việt.

## Các cột mới của Bảng khối lượng

**Diện tích chiếu** (hình chiếu xuống mặt phẳng ngang, hợp cho phòng và khu vực; chỉ tính khi bật công tắc **Diện tích chiếu** ở chân trang, hoặc tự bật khi bạn hiện cột này), **Loại IFC** (đọc phân loại IFC có sẵn), **Xuất xứ**, **Liên kết** (nút ↗ mở bằng trình duyệt; chỉ nhận http hoặc https), **Quy cách**, **Đơn giá** (bạn tự nhập, chỉ số, ví dụ 1250000 hoặc 12,5) và **Thành tiền** (= đơn giá x số lượng, dòng tổng cộng cộng dồn). Nhấp đúp vào ô để nhập. Liên kết, Quy cách, Đơn giá được lưu riêng cho bảng, không đổi dữ liệu dùng chung với các plugin VGD khác.

## Số đo thân: bỏ tay nắm khỏi kích thước

Số đo Rộng / Dài / Cao trong Bảng khối lượng tính theo kích thước **đã phóng to (scale)** của đối tượng: khối dài 1 m kéo thành 2 m thì bảng ghi 2 m.

Phần phụ nhô ra (tay nắm...) hoặc thứ không thuộc thân (đá bếp...) làm tủ bị đo to hơn thân thật. Có hai cách loại khỏi Rộng / Dài / Cao:
1. **Loại trừ theo tag** (khuyên dùng): đặt những phần đó lên một tag riêng trong SketchUp, rồi bấm nút **Loại trừ tag** trên thanh công cụ của Bảng khối lượng. Ngăn bên liệt kê các tag của model; tick tag nào thì mọi thứ nằm trên tag đó không còn được tính vào kích thước. Bỏ tick là tính lại. Dùng được cho tay nắm, đá bếp hoặc bất cứ thứ gì có tag riêng.
2. **Từ khóa tên** (bảng **Preset** → **Số đo thân**): gõ vài từ như `tay nắm, handle, knob` (cách nhau dấu phẩy). Group, component hoặc tag có tên chứa từ đó sẽ không được tính. Không phân biệt hoa thường và dấu. Mặc định đã có `tay nắm, tay nam, handle, knob`.

Tag đã tick còn làm **dòng gắn tag đó biến khỏi bảng** (và các món nằm trong nó nếu bật Chọn sâu): ví dụ chọn cả công trình, tick tag Tường, Cửa, Rèm thì bảng chỉ còn nội thất và tổng cũng chỉ cộng nội thất. Dòng trên đầu bảng cho biết đã ẩn bao nhiêu đối tượng. Bỏ tick là hiện lại.

Bật cột **Ghi chú số đo** (Chọn cột) để xem plugin đã bỏ gì cho từng món, ví dụ `Bỏ 2 phần theo từ khóa hoặc tag (Tay nam trái, Mặt đá)`. Phần dính liền vào hình của cánh (không tách thành group / component hoặc tag riêng) thì không loại được: hãy tách riêng và đặt tag hoặc tên cho nó.

Chỉ Bảng khối lượng và file xuất từ bảng dùng số đo thân. Nếu thấy một món sai, xem Ghi chú số đo rồi chỉnh tag hoặc từ khóa.

## Mặt trước của món (bản thử)

Mặt trước giúp chụp ảnh và đo kích thước đồng bộ cho cả công trình, kể cả model lạ có trục xoay lung tung. Bước này **xác định và lưu** mặt trước, rồi ảnh chụp và số đo dùng nó; plugin chưa đổi trục của model.

1. Chọn các món trong bảng (hoặc không chọn gì để làm cho tất cả món đang hiện), bấm nút **Mặt trước** rồi **Phát hiện tự động**.
2. Bật cột **Độ tin cậy mặt trước**, hoặc **Nhóm theo → Mặt trước (độ tin cậy)**. Món **Cần duyệt** là món plugin chưa chắc; rê chuột vào ô để xem lý do.
3. Duyệt: chọn một dòng, nhìn **mũi tên trên mặt trên của món** trong SketchUp (nhìn từ trên xuống rất rõ; mũi tên chỉ hướng mặt trước). Muốn gọn thì tắt công tắc **Bảng tên trên model** ở chân trang (chỉ tắt bảng tên, mũi tên vẫn hiện). Đúng thì giữ. Sai thì: xoay camera nhìn thẳng vào mặt trước thật rồi bấm **Theo hướng nhìn hiện tại**, hoặc bấm **Xoay 90°** / **Đảo chiều** cho tới khi mũi tên đúng.
4. Món đã đặt tay sẽ không bị phát hiện tự động ghi đè (trừ khi tick **Ghi đè cả món đã đặt tay**).
5. Chụp ảnh (nút Cập nhật ảnh, góc Iso hoặc Chính diện) sẽ theo mặt trước: Iso chụp từ phía trước-phải-trên, Chính diện nhìn thẳng vào mặt trước. Món chưa có mặt trước vẫn chụp theo trục thế giới và được ghi chú sau khi chụp.
6. Cột **Rộng / Dài (Sâu) / Cao** của món có mặt trước đo theo mặt trước: Rộng là chiều ngang nhìn từ phía trước, Sâu là chiều theo hướng mặt trước. Nhãn cột vẫn ghi (X), (Y), (Z) nhưng với món có mặt trước thì (X) là ngang, (Y) là sâu.

### Sửa trục theo mặt trước (thay đổi model)

Khi đã duyệt xong mặt trước, bạn có thể đưa trục của các món về một chuẩn: mặt trước hướng **-Y**. Việc này **thay đổi hình học của model** (trục của group / component), nên hãy lưu file trước khi làm.

1. Chọn các dòng cần sửa trong bảng (không có chọn thì plugin không làm gì).
2. Trong bảng **Mặt trước**, bấm **Xem trước sửa trục**: plugin báo sẽ sửa bao nhiêu loại và bản sao, bao nhiêu loại đã đúng, và loại nào bị bỏ qua cùng lý do (chưa có mặt trước, component động, có bản sao bị khóa hoặc lật gương, là ảnh...).
3. Đúng ý thì bấm **Áp dụng sửa trục**. Plugin xoay nội dung của từng định nghĩa theo bội 90° quanh gốc tọa độ rồi bù cho **mọi bản sao**, nên hình trong model **không dịch chỗ**, chỉ có trục đổi. Gốc tọa độ giữ nguyên.
4. Sai ý thì **Ctrl+Z một lần** để hoàn tác cả hình học lẫn dữ liệu.

Lưu ý: component dùng chung một định nghĩa (nhiều bản sao) được sửa một lần cho tất cả bản sao, kể cả bản sao bạn không chọn. Nếu một bản sao bị khóa hoặc bị lật gương thì cả loại đó bị bỏ qua. Component động không được sửa. Nếu bạn dùng plugin khác tham chiếu trục của món (thư viện, bản vẽ tủ), hãy kiểm tra lại sau khi sửa.

Lưu ý: plugin đoán dựa vào tường gần món và độ nhiều chi tiết của từng mặt nên có thể sai với đồ đặt giữa phòng, kệ hở, đồ trang trí. Luôn xem lại các món Cần duyệt. Đồ nằm nghiêng, bị lật gương hoặc là component động không được tin cậy cao. Kết quả lưu trong file SketchUp (dữ liệu của định nghĩa); không đổi hình học. Đổi mặt trước làm số đo và ảnh chụp của món đó đổi theo (chụp lại ảnh nếu cần).

## Thay thế hàng loạt chữ

Gõ chữ vào ô **Tìm kiếm** thì hiện thêm ô **Thay bằng** và nút **Thay thế (n)** (n là số ô sẽ đổi). Chữ được thay trong các cột Tên, Mô tả, Xuất xứ, Quy cách đang hiện, ở các dòng đang lọc, không phân biệt hoa thường; cả đợt là một bước hoàn tác (Ctrl+Z) và đối tượng bị khóa được bỏ qua.

## Soạn tag

Tab **Soạn tag** để soạn bộ tag theo nhóm hạng mục (Phần thô, Hoàn thiện, Đồ rời, Thiết bị, Khác), gán tag cho group, component hoặc mặt đang chọn, và xuất / nhập bộ tag bằng CSV (mở được trong Excel) hoặc JSON. Khi nhập, chọn thay thế toàn bộ hoặc gộp vào bộ hiện có. Bộ tag lưu trên máy này.

### Gắn tag tự động theo tên

Thẻ **Gắn tag tự động theo tên** ở cuối tab Soạn tag gắn tag cho nhiều group / component một lúc theo từ khóa trong tên:
1. **Bảng luật**: mỗi dòng là "tên tag ← từ khóa" (nhiều từ khóa cách nhau dấu phẩy, ví dụ `cửa, door`). **Luật nằm trên thắng**: dùng ↑ ↓ để đổi thứ tự (đặt "Cửa sổ" trên "Cửa"). Khớp không phân biệt hoa thường và dấu, từ khóa chỉ cần nằm trong tên (nên "door" cũng khớp "Doorway": hãy xem trước). Tag chưa có trong model sẽ được tạo.
2. **Dựa theo**: tên bản sao, tên component, hoặc cả hai (mặc định). Group không có tên component riêng nên dùng tên group.
3. **Phạm vi**: đối tượng đang chọn (mặc định) hoặc cả model. **Gắn cả group / component bên trong** (tắt mặc định): đổi tag của mọi bản sao dùng chung định nghĩa. **Ghi đè tag đã có** (tắt mặc định): chỉ gắn đối tượng chưa có tag.
4. Bấm **Xem trước** để biết mỗi tag sẽ gắn cho bao nhiêu đối tượng (kèm vài tên mẫu), bao nhiêu đã đúng tag, giữ nguyên, không khớp luật nào, bị khóa. Sửa luật hay tùy chọn thì phải xem lại. Bấm **Áp dụng**: một bước Ctrl+Z hoàn tác cả đợt; đối tượng bị khóa không bao giờ bị đổi. Nếu tag đích đang tắt hiển thị thì đối tượng gắn vào sẽ bị ẩn (có báo).
5. **Lưu làm mặc định** giữ bộ luật trên máy này (`tag_rules.json`); **Đặt lại** về bộ mẫu (có hỏi); **Xuất / Nhập file luật** (JSON) để chia sẻ giữa các máy; nhập được cả file luật xuất từ 5D Auto Tag (lấy phần "names").

## Quy tắc phân loại

Trong tab **Phân loại**, mở **Quy tắc → Thêm quy tắc**: chọn loại nguồn, nhập tên nguồn cần khớp, chọn mẫu hoặc nhập thông tin, rồi **Lưu quy tắc**. Xuất / Nhập bộ quy tắc để dùng ở model khác. Mục dữ liệu kỹ thuật được thu gọn, không cần dùng cho thao tác thông thường.

## Cửa sổ và cập nhật

Nút **Sáng / Tối** lưu lựa chọn giao diện trên máy. Sau khi cài đè bản mới, dùng **Extensions → VGD → VGD_BIM · Tải lại code** để nạp lại mã mà không cần mở lại SketchUp; menu và toolbar mới chỉ có tác dụng sau khi mở lại SketchUp. Lưu file đang làm trước khi tải lại.
