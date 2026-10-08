# VGD BIM Lite v0.1.3-alpha

Prerelease: tự kiểm tra cập nhật mỗi 24 giờ, có lệnh kiểm tra thủ công. SketchUp hỏi trước khi mở trang tải RBZ; cài bằng Extension Manager rồi khởi động lại.

Bản 0.1.1 dùng **một cửa sổ duy nhất**, giao diện màu nâu đồng bộ VGD Dim/Scenes và nhãn/thông báo tiếng Việt. Có hướng dẫn nhanh trong giao diện, màn hình quy tắc dễ nhập và mục **Xuất báo cáo** với bốn loại CSV mở được trong Excel. Đọc [hướng dẫn sử dụng](HUONG_DAN_SU_DUNG.md) để bắt đầu.

CSV là báo cáo dữ liệu/khối lượng gốc, không tính đơn giá/thành tiền. Mã schema vẫn giữ nguyên để các plugin VGD dùng chung; bản dịch áp dụng ở giao diện và báo cáo. Khởi động lại SketchUp sau cập nhật để đóng các cửa sổ cũ.

Plugin **VGD_BIM** cho SketchUp 2022+ / Windows. Phase 1: Core, Intake, Mapping và Validation. Namespace `VGD::BIM`; dữ liệu Group/ComponentInstance lưu trong dictionary `VGD_BIM` của file SKP.

## Cài đặt

Trong SketchUp, mở **Extensions → Extension Manager → Install Extension**, chọn `VGD_BIM_Lite_v0.1.3-alpha.rbz`. Khởi động lại SketchUp. Menu: **Extensions → VGD → BIM Lite**. Có toolbar hai nút và context menu cho Group/Component.

Hoặc chạy `dev/deploy.ps1` để cài nguồn runtime vào Plugins của SketchUp 2022. Script chỉ copy file plugin này, sao lưu file cũ và kiểm tra SHA256. `-PluginRoot` chọn bản SketchUp khác; `-VerifyOnly` kiểm tra cài đặt.

## Sử dụng

1. Chọn nhóm/đối tượng thành phần → **Thông tin**. Chọn mẫu hạng mục hoặc bật ô đánh dấu các trường cần đổi → **Áp dụng thông tin**. Trường không bật giữ nguyên; trường văn bản bật và để trống được xóa. Các đối tượng khóa được bỏ qua. **Xóa dữ liệu VGD** chỉ xóa metadata.
2. **Quét mô hình** đọc cả model, gồm đối tượng lồng nhau, mặt, cạnh và vật liệu kế thừa. Thống kê thành phần đếm lần xuất hiện thực tế. Rộng/sâu/cao theo trục của đối tượng sau biến đổi, dùng mm.
3. **Phân loại** gom theo định nghĩa và vật liệu. Gợi ý dựa trên VGD đã có → quy tắc → tên định nghĩa → tên đối tượng → thẻ → vật liệu. Từ khóa chỉ là gợi ý. **Chỉnh thông tin** → **Xem trước chuyển đổi** → **Xác nhận chuyển đổi** mới ghi dữ liệu. Dữ liệu VGD hiện có không bị convert ghi đè.
4. **Chuyển đổi lựa chọn** áp dụng bước xem trước cho các đối tượng đang chọn. Mỗi batch chỉ có một bước hoàn tác. Không sửa hình học, tên, thẻ hoặc vật liệu.
5. **Kiểm tra** chọn phạm vi toàn model hoặc đối tượng đang chọn. Kiểm tra schema, trường bắt buộc và đơn vị/cách đo. Bấm kết quả để chọn đúng đối tượng lồng nhau và phóng tới nó. Đối tượng bị xóa sau quét được báo và yêu cầu làm mới.
6. **Quy tắc** nhập/sửa bằng form và xuất/nhập giữa model. Rules lưu JSON trong dictionary model `VGD_BIM_RULES`, hỗ trợ hoàn tác và tồn tại cùng SKP. Phân loại vật liệu chỉ ghi rule, không gán BIM data vào từng mặt.
7. **Xuất báo cáo** chọn một trong bốn loại CSV: danh mục đối tượng, thống kê thành phần, diện tích vật liệu gốc hoặc kết quả kiểm tra. Báo cáo dùng tiếng Việt, UTF-8 BOM và dấu chấm phẩy. Tên đối tượng có ký tự công thức được xuất thành văn bản an toàn khi mở trong Excel.

## Ý nghĩa dữ liệu và giới hạn

- `SOURCE`: `VGD`, `MAPPED`, `RAW`, `MANUAL`. Source lưu trong metadata `_source`, tách khỏi schema nghiệp vụ v1.
- Raw faces/edges/material area là **RAW QUANTITY / RAW GEOMETRY**, chưa phải BOQ. Front area và back-painted area tách riêng để tránh cộng hai mặt thành một khối lượng. Area là diện tích hình học, chưa trừ phần che khuất/hao hụt.
- Nested entity trong shared component definition dùng chung metadata giữa các parent occurrences. Preview nói rõ số entity được ghi và số occurrences bị ảnh hưởng. Plugin không make_unique để giữ nguyên geometry. Nếu bất kỳ occurrence của entity có ancestor khóa, convert bỏ qua entity đó.
- `Scanner.all_entities` / `all_bim_entities` trả về entity duy nhất để đọc/ghi; `scan_model` / `scan_selection` trả occurrence records `{entity, path, transform, material, locked}`. Quantity tương lai phải dùng occurrence records để không thiếu repeated nested instances.
- `Geometry.dimensions(entity, record[:transform])` đo đúng nested occurrence. Không truyền transform thì dùng transformation của instance trong parent context; vì shared nested entity có nhiều đường dẫn, không tự suy đoán parent occurrence.
- W/D/H là độ dài bounding box local theo các trục đã transform, không phải world-aligned bounding box khi quay. Đây là kích thước thích hợp để nhận diện đồ nội thất.
- Scan chạy theo từng đợt qua timer, không scan toàn model khi selection thay đổi. Tổng hợp báo cáo diễn ra sau scan; model rất lớn vẫn có thể cần thời gian ở bước tổng hợp. Refresh hoặc đóng panel hủy scan hiện tại.
- Preset mặc định không gán description: người dùng cần nhập mô tả để đạt ready khi include_boq=true. Item type là chuỗi mở rộng.
- Plugin chưa ký phát hành; tuân theo chính sách loading extensions hiện tại của SketchUp.

Theo yêu cầu bổ sung ngày 04/10/2026, có xuất CSV với tiêu đề tiếng Việt để mở trong Excel. Chưa triển khai Quantity hoàn chỉnh, bảng khối lượng tính giá, workbook Excel, Pricing, IFC, room detection hoặc Cabinet BOM. Không sửa VGD Cabinet.

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

- `node dev/check_ruby.cjs`: compile Ruby và chạy test Core/affine geometry/scanner bằng Ruby WASM 3.2; simulation không thay thế SketchUp kernel. Dependency dùng lại dev toolchain trong repository Cabinet; runtime plugin không phụ thuộc thư viện ngoài.
- `dev/test_ui.cjs`: Playwright + Edge headless; biến `VGD_PLAYWRIGHT_MODULE` trỏ tới Playwright nếu không cài local.
- `dev/native_smoke.rb`: chạy trong **tiến trình SketchUp mới, model trống** qua `-RubyStartup`, hoặc `load` trong Ruby Console của model trống. Refuse model có geometry/path để bảo vệ file đang làm. Tạo model test theo đặc tả, kiểm tra Undo, geometry, nested selection, save/reopen, ghi `outputs/native_SU22/native_report.json` và SKP test.
- `dev/package.py`: tạo RBZ, kiểm tra từng byte trong archive và ghi SHA256.

Đọc `VALIDATION.md` để biết phần nào đã thực sự được kiểm chứng trong bản alpha này.
