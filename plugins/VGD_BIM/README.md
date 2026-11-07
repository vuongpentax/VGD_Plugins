# VGD_BIM 1.1.0-beta.7

Bản thử của 1.1.0 (bản ổn định gần nhất là 1.0.0, tên cũ "VGD BIM Lite"). Cài bản mới bằng Extension Manager rồi khởi động lại SketchUp. Plugin không tự hiện popup cập nhật: VGD Center báo bản mới.

Plugin **VGD_BIM** cho SketchUp 2022+ / Windows: bóc khối lượng từ group / component, gắn dữ liệu hạng mục, quét và xuất báo cáo CSV mở được trong Excel. Namespace `VGD::BIM`; dữ liệu Group/ComponentInstance lưu trong dictionary `VGD_BIM` của file SKP. Giao diện dùng **một cửa sổ duy nhất**, màu nâu đồng bộ các plugin VGD, nhãn và thông báo tiếng Việt. Đọc [hướng dẫn sử dụng](HUONG_DAN_SU_DUNG.md) để bắt đầu.

CSV là báo cáo dữ liệu/khối lượng gốc, không tính đơn giá/thành tiền. Mã schema giữ nguyên để các plugin VGD dùng chung; bản dịch áp dụng ở giao diện và báo cáo.

## Cài đặt

Trong SketchUp, mở **Extensions → Extension Manager → Install Extension**, chọn file `VGD_BIM_v<phiên bản>.rbz`. Khởi động lại SketchUp. Menu: **Extensions → VGD → VGD_BIM** mở thẳng Bảng khối lượng; **VGD_BIM · Tải lại code** nạp lại mã sau khi cài đè bản mới (menu và toolbar mới chỉ có tác dụng sau khi mở lại SketchUp). Có toolbar một nút và mục "VGD_BIM · Thông tin đối tượng" trong context menu của Group/Component.

Cài đè lên 1.0.0: tên extension đổi từ "VGD BIM Lite" thành "VGD_BIM", thư mục `vgd_bim_lite` giữ nguyên. Các file lớp bao hộp thoại cũ của 1.0.0 (`ui/information_dialog.rb`, `mapping_dialog.rb`, `scan_dialog.rb`, `validation_dialog.rb`) không còn được nạp; nếu còn nằm trong Plugins thì có thể xóa tay.

Hoặc chạy `dev/deploy.ps1` để cài nguồn runtime vào Plugins của SketchUp 2022. Script chỉ copy file plugin này, sao lưu file cũ và kiểm tra SHA256. `-PluginRoot` chọn bản SketchUp khác; `-VerifyOnly` kiểm tra cài đặt.

## Sử dụng

Cửa sổ có 5 tab:

1. **Bảng khối lượng** (mở đầu tiên): chọn group / component trong SketchUp, bảng tự đọc đối tượng đang chọn (không quét cả model). Có 20 cột; chọn cột, kéo đổi thứ tự, co giãn cột, dòng tổng cộng, preset cột (Tất cả / Phần thô / Hoàn thiện / Đồ rời và preset tự tạo). Bấm một ô để đánh dấu đối tượng trong SketchUp bằng khung nét đứt và khung tên; sửa trực tiếp **Tên**, **Mô tả**, **Tình trạng**. Tuỳ chọn: thu phóng tới đối tượng, cô lập đối tượng chọn, chọn sâu bên trong, chỉ cộng tổng cấp cao nhất. **Cô lập** tạm ẩn các đối tượng khác bằng thuộc tính ẩn của SketchUp ngoài một bước hoàn tác riêng: tắt Cô lập hoặc đóng cửa sổ để hiện lại, và đừng lưu file khi đang cô lập (các đối tượng ẩn sẽ được lưu ở trạng thái ẩn). Tình trạng có 5 mức (Mới, Hiện hữu, Dùng lại, Tạm thời, Loại bỏ); ô trống hiểu là Mới. Nút **Đổi tên** mở panel đổi tên hàng loạt (xem bên dưới).
   **Đổi tên hàng loạt** áp dụng cho mọi dòng đang có trong bảng và chỉ đổi tên đối tượng (instance), không đổi tên định nghĩa dùng chung, hình học hay dữ liệu hạng mục. Mẫu tên ghép từ `{tên}` (tên hiện tại, trống thì lấy tên họ), `{họ}` (tên định nghĩa), `{phân loại}` (tag), `{nhóm}` (nhóm hạng mục) và `{số}` (số thứ tự); sau đó tìm và thay chữ (đúng nguyên văn, không phải biểu thức chính quy), đổi kiểu chữ, thêm tiền tố / hậu tố. Số thứ tự bắt đầu từ số cho trước, có số chữ số (đệm 0) và bước nhảy, đánh theo thứ tự trong bảng, theo vị trí (X, rồi Y, rồi Z, tính từ góc nhỏ nhất của khung bao) hoặc theo tên hiện tại (T2 đứng trước T10). **Xem trước** liệt kê tên cũ và tên mới, báo đối tượng bị khóa (bỏ qua, không chiếm số), tên trống, tên quá dài (trên 200 ký tự) và tên trùng nhau trong đợt (vẫn cho đổi). **Áp dụng** tính lại từ dữ liệu hiện tại và đổi tên cả đợt trong một bước hoàn tác.
2. **Thông tin**: sửa chi tiết dữ liệu VGD của đối tượng đang chọn. Chọn mẫu hạng mục hoặc bật ô đánh dấu các trường cần đổi → **Áp dụng thông tin**. Trường không bật giữ nguyên; trường văn bản bật và để trống được xóa. Các đối tượng khóa được bỏ qua. **Xóa dữ liệu VGD** chỉ xóa metadata.
3. **Quét & xuất**: quét model (gồm đối tượng lồng nhau, mặt và vật liệu kế thừa; không đọc cạnh), thống kê thành phần đếm lần xuất hiện thực tế, rộng/sâu/cao theo trục của đối tượng sau biến đổi (mm). Phần xuất file chọn một trong bốn loại CSV: danh mục đối tượng, thống kê thành phần, diện tích vật liệu gốc hoặc kết quả kiểm tra. Báo cáo dùng tiếng Việt, UTF-8 BOM và dấu chấm phẩy. Tên đối tượng có ký tự công thức được xuất thành văn bản an toàn khi mở trong Excel.
4. **Phân loại** có ba tab con:
   - **Phân loại** gom theo định nghĩa và vật liệu. Gợi ý dựa trên VGD đã có → quy tắc → tên định nghĩa → tên đối tượng → thẻ → vật liệu. Từ khóa chỉ là gợi ý. **Chỉnh thông tin** → **Xem trước chuyển đổi** → **Xác nhận chuyển đổi** mới ghi dữ liệu. Dữ liệu VGD hiện có không bị convert ghi đè. Mỗi batch chỉ có một bước hoàn tác và không sửa hình học, tên, thẻ hoặc vật liệu.
   - **Quy tắc** nhập/sửa bằng form và xuất/nhập giữa model. Rules lưu JSON trong dictionary model `VGD_BIM_RULES`, hỗ trợ hoàn tác và tồn tại cùng SKP. Phân loại vật liệu chỉ ghi rule, không gán BIM data vào từng mặt.
   - **Kiểm tra** chọn phạm vi toàn model hoặc đối tượng đang chọn. Kiểm tra schema, trường bắt buộc và đơn vị/cách đo. Bấm kết quả để chọn đúng đối tượng lồng nhau và phóng tới nó. Đối tượng bị xóa sau quét được báo và yêu cầu làm mới.
5. **Soạn tag**: soạn bộ tag (không có đơn vị) theo nhóm hạng mục, gán tag cho group / component / mặt đang chọn, xuất / nhập bộ tag bằng CSV (mở được trong Excel) hoặc JSON.

## Dữ liệu lưu trên máy

Cài đặt của người dùng lưu thành file JSON trong `%APPDATA%\VGD\VGD_BIM\` (máy không phải Windows: `~/VGD/VGD_BIM`; biến môi trường `VGD_BIM_DATA_DIR` đổi thư mục, dùng khi test): `tag_set.json` (bộ tag), `table_presets.json` (preset cột tự tạo), `table_view.json` (trạng thái bảng). Lần đầu chạy, plugin vẫn thử đọc dữ liệu cũ lưu bằng `Sketchup.read_default`. File JSON thay cho `write_default` vì chuỗi có dấu ngoặc kép hoặc tiếng Việt từng bị hỏng khi đọc lại.

## Ý nghĩa dữ liệu và giới hạn

- `SOURCE`: `VGD`, `MAPPED`, `RAW`, `MANUAL`. Source lưu trong metadata `_source`, tách khỏi schema nghiệp vụ v1. Trường `status` (tình trạng) nằm trong schema từ 1.1.0.
- Raw faces/material area là **RAW QUANTITY / RAW GEOMETRY**, chưa phải BOQ. Từ 1.1.0 plugin không đếm cạnh (edge) và chiều dài cạnh. Front area và back-painted area tách riêng để tránh cộng hai mặt thành một khối lượng. Area là diện tích hình học, chưa trừ phần che khuất/hao hụt.
- Thể tích trong bảng chỉ tính cho group kín. Khung đánh dấu và diện tích X*Z, X*Y theo khung bao (bounding box), không theo cạnh thật của hình.
- Nested entity trong shared component definition dùng chung metadata giữa các parent occurrences. Preview nói rõ số entity được ghi và số occurrences bị ảnh hưởng. Plugin không make_unique để giữ nguyên geometry. Nếu bất kỳ occurrence của entity có ancestor khóa, convert bỏ qua entity đó.
- `Scanner.all_entities` / `all_bim_entities` trả về entity duy nhất để đọc/ghi; `scan_model` / `scan_selection` trả occurrence records `{entity, path, transform, material, locked}`. Quantity tương lai phải dùng occurrence records để không thiếu repeated nested instances.
- `Geometry.dimensions(entity, record[:transform])` đo đúng nested occurrence. Không truyền transform thì dùng transformation của instance trong parent context; vì shared nested entity có nhiều đường dẫn, không tự suy đoán parent occurrence.
- W/D/H là độ dài bounding box local theo các trục đã transform, không phải world-aligned bounding box khi quay. Đây là kích thước thích hợp để nhận diện đồ nội thất.
- Chọn đối tượng không quét toàn model; chỉ tab Quét & xuất, Phân loại và Kiểm tra quét model, và chỉ khi mở tab hoặc bấm làm mới. Bảng khối lượng chỉ đọc sâu bên trong khi bật "Chọn sâu bên trong".
- Khung đánh dấu: từ SketchUp 2023 vẽ bằng lớp phủ (Overlay, hiện trong danh sách Overlays của SketchUp) nên không chiếm công cụ đang dùng: chọn nhiều bằng Shift/Ctrl, kéo chọn và nhấp đúp vào group là của SketchUp như mặc định. SketchUp 2022 không có lớp phủ nên khung là công cụ vẽ tạm: click vẫn chọn được đối tượng nhưng Shift/Ctrl-chọn nhiều, kéo chọn và nhấp đúp vào group bị chặn, chọn công cụ khác thì khung tự gỡ. Nếu lớp phủ báo lỗi, plugin quay về cách công cụ. Khung vẽ bằng tọa độ màn hình; chiều rộng khung tên ước lượng theo số ký tự, nên có thể hụt hoặc dư; trên màn hình độ phân giải cao tọa độ 2D có thể lệch. Tô mặt giới hạn 60.000 điểm. Với cách công cụ (SketchUp 2022), nhấn Esc để tắt khung; với lớp phủ, bỏ chọn là khung tắt.
- Preset mặc định không gán description: người dùng cần nhập mô tả để đạt ready khi include_boq=true. Item type là chuỗi mở rộng.
- Plugin chưa ký phát hành; tuân theo chính sách loading extensions hiện tại của SketchUp.

Chưa triển khai Quantity hoàn chỉnh, bảng khối lượng tính giá, workbook Excel, Pricing, IFC, room detection hoặc Cabinet BOM. Không sửa VGD Cabinet.

## API

```ruby
VGD::BIM::Data.update(entity, category: 'furniture', item_type: 'wardrobe',
  description: 'Tủ áo Master', unit: 'set', quantity_method: 'assembly')
VGD::BIM::Data.get(entity, :category)
VGD::BIM::Data.read(entity)
VGD::BIM::Data.has_data?(entity)
VGD::BIM::Data.valid?(entity)
VGD::BIM::Data.clear(entity)

VGD::BIM::Scanner.scan_model.each do |record|
  next unless VGD::BIM::Data.has_data?(record[:entity])
  dimensions = VGD::BIM::Geometry.dimensions(record[:entity], record[:transform])
end
```

`Data.update/set/clear` tạo operation riêng. API batch nội bộ dùng `Data.transaction { Data.write(...) }` để chỉ có một Undo; tránh lồng operations. UI chỉ truy cập BIM attributes qua Data API.

## Kiểm thử

Chạy từ `plugins/VGD_BIM`:

- `ruby dev/run_tests.rb`: kiểm tra cú pháp mọi file Ruby và chạy các `dev/test_*.rb` (lõi/schema, hình học, báo cáo, cửa sổ, bảng khối lượng, lưu cài đặt, soạn tag, menu, khung đánh dấu) bằng Ruby thường. Đây là mô phỏng, không thay thế SketchUp.
- `dev/test_ui.cjs`: Playwright + trình duyệt headless kiểm tra giao diện HTML; biến `VGD_PLAYWRIGHT_MODULE` trỏ tới Playwright nếu không cài local, `VGD_BROWSER_CHANNEL=msedge` để dùng Edge.
- `dev/native_smoke.rb`: chạy trong **tiến trình SketchUp mới, model trống** qua `-RubyStartup`, hoặc `load` trong Ruby Console của model trống. Refuse model có geometry/path để bảo vệ file đang làm. Ghi `outputs/native_SU22/native_report.json`. Chưa bao phủ bảng khối lượng, soạn tag và khung đánh dấu.
- `python3 dev/make_preview.py`: tạo trang HTML xem trước giao diện với dữ liệu mẫu (`outputs/VGD_BIM_giao_dien.html`).
- `python plugins/VGD_BIM/dev/package.py <phiên bản>` (từ gốc repo): tạo RBZ trong `outputs/local_release_<phiên bản>/`, kiểm tra từng byte trong archive và in SHA-256.

Bản 1.1.0-beta.7 được kiểm tra tự động bằng mô phỏng, chưa kiểm thử thủ công trong SketchUp thật. `VALIDATION.md` ghi chi tiết phần đã và chưa kiểm chứng.
