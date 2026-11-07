'use strict';
// Dịch giao diện sang tiếng Anh. Mã nguồn vẫn viết tiếng Việt; khi Cài đặt chọn English, mọi chữ hiện ra trong cửa sổ
// (nội dung, ô gợi ý, chú thích, nhãn trợ năng) được đổi tại chỗ qua từ điển bên dưới. Chữ chưa có trong từ điển giữ nguyên tiếng Việt.
// Chuỗi có số / tên xen vào dùng các mẫu (rule). Báo cáo CSV và hộp thoại gốc của SketchUp không đi qua đây.
// Khoá của từ điển là chữ đã cắt khoảng trắng đầu / cuối (translateText tự cắt rồi ghép lại).
const VGD_I18N=(()=>{
  const EN={
    // --- Khung, tab, thanh trạng thái ---
    'Chuyển sang giao diện tối':'Switch to dark theme','Chuyển sang giao diện sáng':'Switch to light theme',
    'Dữ liệu mô hình nội thất':'Interior model data','Bảng khối lượng':'Quantity table','Thông tin':'Information','Quét & xuất':'Scan & export',
    'Phân loại':'Classify','Soạn tag':'Tag editor','Hình ảnh':'Images','Cài đặt':'Settings','Chức năng':'Functions',
    'Cách dùng nhanh · Bắt đầu từ đâu?':'Quick start · Where to begin?','Bóc khối lượng:':'Take off quantities:',
    'Bảng khối lượng → chọn group / component trong SketchUp → bảng tự đọc → chọn preset cột → sửa Tên, Mô tả ngay trong bảng.':'Quantity table → select groups / components in SketchUp → the table reads them → pick a column preset → edit Name and Description right in the table.',
    'Model từ đối tác:':'Model from a partner:',
    'Quét & xuất để xem tổng quan → Phân loại → sửa gợi ý → Xem trước → Xác nhận. Kiểm tra nằm trong tab Phân loại.':'Scan & export for an overview → Classify → adjust suggestions → Preview → Confirm. Checks are in the Classify tab.',
    'Ảnh món đồ:':'Item photos:','Hình ảnh → Cập nhật ảnh (chỉ chụp khi bạn bấm) → hoặc kéo thả / dán ảnh riêng. Thư mục và cách chụp nằm trong Cài đặt.':'Images → Update photos (only shoots when you press it) → or drop / paste your own image. Folder and capture mode are in Settings.',
    'Xuất Excel:':'Export to Excel:','Quét & xuất → chọn báo cáo → lưu file CSV. Plugin giữ nguyên hình học của model.':'Scan & export → choose a report → save the CSV file. The plugin leaves the model geometry untouched.',
    'Dữ liệu mô hình · VGD':'Model data · VGD','Hủy':'Cancel','Xác nhận chuyển đổi':'Confirm conversion','Xem trước chuyển đổi':'Preview conversion',
    'Sẵn sàng.':'Ready.','Đang đọc dữ liệu…':'Reading data…',
    // --- Chung ---
    'Có':'Yes','Không':'No','Chưa có dữ liệu để hiển thị.':'No data to show.','Tất cả':'All','cái':'pcs','Đóng':'Close','Xóa':'Delete','Sửa':'Edit','Bỏ qua':'Skip','Thao tác':'Actions',
    'Chưa đặt tên':'Unnamed','Chưa có vật liệu':'No material','Chưa phân loại':'Unclassified','Nhóm':'Group','Thành phần':'Component','Trạng thái':'Status',
    // --- Thông tin ---
    'Mẫu hạng mục':'Item template','Chọn mẫu hạng mục…':'Choose an item template…','Thông tin bổ sung · Hoàn thiện, hãng, sản phẩm, ghi chú':'More info · Finish, manufacturer, product, note',
    'Cập nhật':'Update','Nhiều giá trị · Giữ nguyên':'Multiple values · Keep as is','Chưa chọn':'Not selected',
    'Ví dụ: Tủ áo phòng ngủ chính':'Example: Master bedroom wardrobe','Ví dụ: Phòng khách':'Example: Living room','Ví dụ: Tầng 1':'Example: Floor 1',
    'Đánh dấu các trường cần sửa. Trường không đánh dấu sẽ giữ nguyên; đánh dấu và để trống để xóa nội dung.':'Tick the fields to change. Unticked fields stay as they are; tick and leave empty to clear a field.',
    'Hãy chọn Có hoặc Không cho mục đưa vào bảng khối lượng.':'Choose Yes or No for "Include in quantity table".',
    'Thông tin đối tượng':'Object information','Hãy chọn nhóm hoặc đồ nội thất trong SketchUp để bắt đầu.':'Select a group or furniture in SketchUp to begin.',
    'Áp dụng thông tin':'Apply information','Xóa dữ liệu VGD':'Clear VGD data','Thông tin từ SketchUp · Chỉ xem':'Information from SketchUp · View only',
    'Loại / Nguồn':'Type / Source','Tên đối tượng / Định nghĩa':'Object name / Definition','Thẻ / Vật liệu':'Tag / Material',
    'Rộng × Sâu × Cao (mm)':'Width × Depth × Height (mm)',
    // --- Quét & xuất ---
    'Phạm vi quét':'Scan scope','Toàn bộ model':'Whole model','Group / đối tượng đang chọn':'Selected groups / objects',
    'Quét cả mặt (để tính m²)':'Scan faces too (to compute m²)',
    'Quét cả mặt sẽ chậm hơn với model lớn. Tắt nếu chỉ cần đếm group / component.':'Scanning faces is slower on large models. Turn it off if you only need to count groups / components.',
    'Đang tắt quét mặt: diện tích và số liệu theo mặt sẽ để trống.':'Face scanning is off: areas and face-based figures stay empty.',
    'Thống kê thành phần của mô hình':'Model component statistics','Tên định nghĩa':'Definition name','Tên đối tượng':'Object name','Số lượng':'Quantity',
    'Rộng × Sâu × Cao mẫu (mm)':'Sample width × depth × height (mm)',
    'Diện tích vật liệu · Khối lượng hình học gốc':'Material area · Raw geometry quantity',
    'Diện tích mặt trước có tính vật liệu kế thừa. Mặt sau có sơn được báo riêng. Số liệu chưa trừ hao hụt hoặc phần che khuất.':'Front-face area includes inherited materials. Painted back faces are reported separately. Figures do not subtract waste or hidden parts.',
    'Vật liệu':'Material','Mặt trước (m²)':'Front faces (m²)','Mặt sau có sơn (m²)':'Painted back faces (m²)','Số mặt trước':'Front face count',
    'Xuất báo cáo để mở trong Excel':'Export reports to open in Excel','Danh mục đối tượng':'Object list',
    'Mã, mô tả, nhóm hạng mục, khu vực, tầng, đơn vị, kích thước và nguồn dữ liệu.':'Code, description, item group, zone, floor, unit, size and data source.',
    'Thống kê thành phần':'Component statistics','Số lần xuất hiện theo định nghĩa, tên, thẻ, vật liệu và kích thước mẫu.':'Occurrences by definition, name, tag, material and sample size.',
    'Diện tích vật liệu gốc':'Raw material area','Diện tích mặt trước và mặt sau có sơn. Chưa phải khối lượng báo giá đã kiểm duyệt.':'Front and painted back face areas. Not a reviewed quotation quantity.',
    'Kết quả kiểm tra':'Check results','Danh sách thông tin thiếu, lỗi đơn vị và cảnh báo cần xem lại.':'Missing information, unit errors and warnings to review.',
    'Báo cáo chưa tính đơn giá hoặc thành tiền. File CSV dùng tiếng Việt UTF-8, dấu chấm phẩy tách cột và dấu phẩy thập phân. Nếu Excel chưa tách cột, vào Dữ liệu → Từ văn bản/CSV, chọn UTF-8 và dấu chấm phẩy.':'Reports do not include unit prices or amounts. CSV files are UTF-8 Vietnamese, with semicolon-separated columns and decimal commas. If Excel does not split the columns, use Data → From Text/CSV and choose UTF-8 and semicolon.',
    // --- Phân loại, quy tắc, kiểm tra ---
    'Quy tắc':'Rules','Kiểm tra':'Check','Phân loại / Chuyển đổi mô hình':'Classify / Convert model','Lưu quy tắc để dùng lại':'Save rule for reuse',
    'Xem trước quy tắc vật liệu':'Preview material rule',
    'Chọn một dòng → sửa thông tin → xem trước → xác nhận. Dữ liệu VGD đã có được giữ nguyên. Với vật liệu, chỉ lưu quy tắc phân loại.':'Pick a row → edit the information → preview → confirm. Existing VGD data is kept. For materials, only the classification rule is saved.',
    'Tìm tên đối tượng hoặc vật liệu…':'Search object or material name…','Nguồn':'Source','Số lượng / Có thể ghi':'Count / Writable','Gợi ý hạng mục':'Suggested item',
    'Độ tin cậy / Căn cứ':'Confidence / Basis','Chưa có gợi ý':'No suggestion','Chỉnh thông tin':'Edit information',
    'Toàn bộ mô hình':'Whole model','Đối tượng đang chọn':'Selected objects','Đối tượng đã quét':'Scanned objects','Sẵn sàng':'Ready','Cảnh báo':'Warnings','Có lỗi':'Errors',
    'Bấm vào dòng kết quả để chọn và phóng tới đúng đối tượng trong SketchUp. Đối tượng chưa phân loại không bị coi là lỗi.':'Click a result row to select and zoom to that object in SketchUp. Unclassified objects are not treated as errors.',
    'Đối tượng / Đường dẫn':'Object / Path','Nội dung kiểm tra':'Check details','Xuất kết quả kiểm tra':'Export check results',
    'Thêm quy tắc phân loại':'Add classification rule','Sửa quy tắc phân loại':'Edit classification rule','Dựa trên':'Based on','Tên nguồn cần khớp':'Source name to match',
    'Lưu quy tắc':'Save rule','Hãy nhập tên nguồn cần khớp.':'Enter the source name to match.','Quy tắc phân loại':'Classification rules',
    'Lưu cách phân loại theo tên để dùng lại. Quy tắc nằm trong file SketchUp; xuất / nhập để dùng ở model khác.':'Save name-based classification to reuse. Rules live in the SketchUp file; export / import to use them in other models.',
    'Tên nguồn':'Source name','Hạng mục':'Item','Thêm quy tắc':'Add rule','Xuất bộ quy tắc':'Export rule set','Nhập bộ quy tắc':'Import rule set',
    'Nâng cao · Chỉnh dữ liệu kỹ thuật':'Advanced · Edit technical data','Tên trường kỹ thuật giữ nguyên để các plugin VGD dùng chung dữ liệu.':'Technical field names stay unchanged so VGD plugins share the same data.',
    'Lưu dữ liệu kỹ thuật':'Save technical data','Dữ liệu kỹ thuật không đúng định dạng.':'The technical data is not in a valid format.',
    'Xem trước':'Preview',
    'Chỉ lưu quy tắc vật liệu; các mặt hình học không được chuyển thành đối tượng BIM.':'Only the material rule is saved; geometry faces are not converted into BIM objects.',
    'Đối tượng lồng trong định nghĩa dùng chung sẽ nhận cùng dữ liệu ở mọi lần xuất hiện.':'Objects nested in a shared definition receive the same data at every occurrence.',
    'Quy tắc phân loại sẽ được lưu để dùng lại.':'The classification rule will be saved for reuse.','Giữ nguyên hình học, tên, thẻ và vật liệu.':'Geometry, names, tags and materials stay unchanged.',
    // --- Soạn tag ---
    'Soạn bộ tag một lần rồi dùng lại cho mọi model. Tên không phân biệt chữ hoa, chữ thường. Bộ tag lưu trên máy này, không nằm trong file model.':'Build a tag set once and reuse it in every model. Names are not case sensitive. The tag set is stored on this computer, not in the model file.',
    'Tên tag':'Tag name','Mới':'New','Có trong model':'In model','Có trong model · đang ẩn':'In model · hidden','Chưa có trong model':'Not in model',
    'Thêm tag':'Add tag','Lưu bộ tag':'Save tag set','Nhập Excel (CSV)':'Import Excel (CSV)','Nhập JSON':'Import JSON','Xuất Excel (CSV)':'Export Excel (CSV)','Xuất JSON':'Export JSON',
    'Xuất / nhập áp dụng cho bộ tag đã lưu. Excel dùng file CSV, mở và lưu được bằng Excel. Nếu Excel báo lỗi, hãy lưu lại file dưới dạng CSV UTF-8.':'Export / import applies to the saved tag set. Excel uses CSV files that open and save in Excel. If Excel reports an error, save the file again as CSV UTF-8.',
    'Gán tag cho đối tượng đang chọn':'Assign a tag to the selection','Chọn tag':'Choose tag','Gán tag':'Assign tag','Hãy lưu bộ tag trước, rồi chọn tag để gán.':'Save the tag set first, then choose a tag to assign.',
    'Gán tag cho các đối tượng được chọn trực tiếp. Nếu tag đang tắt hiển thị, các đối tượng gán vào sẽ bị ẩn.':'Assigns the tag directly to the selected objects. If the tag is hidden, the assigned objects will be hidden.',
    'Nhóm hạng mục':'Item group','Phần thô':'Rough work','Hoàn thiện':'Finishing','Đồ rời':'Loose furniture','Thiết bị':'Equipment','Khác':'Other',
    // --- Bảng khối lượng ---
    'Chọn cột':'Choose columns','Tìm kiếm...':'Search...','Tìm trong bảng':'Search in table','Tất cả nhóm':'All groups','Đổi tên':'Rename','Chụp ảnh':'Take photo',
    'Chụp ảnh các dòng đang chọn (chỉ chụp khi bạn bấm nút này)':'Take photos of the selected rows (only runs when you press this button)',
    'Chọn tất cả cột':'Select all columns','Bỏ chọn tất cả':'Deselect all','Tìm cột...':'Search columns...','Tạo mới...':'Create new...',
    'Tên preset mới':'New preset name','Hãy nhập tên preset.':'Enter a preset name.','Khôi phục cột gốc của preset':'Restore the preset\'s original columns','Xóa preset':'Delete preset','Preset':'Preset',
    'Preset lưu cột đang hiển thị, thứ tự cột và nhóm hạng mục, lưu trên máy này. Đang dùng preset tự tạo thì đổi cột sẽ tự cập nhật vào preset đó.':'A preset stores the visible columns, their order and the item group, on this computer. While a custom preset is active, changing columns updates it automatically.',
    'Thu phóng đối tượng':'Zoom to object','Cô lập đối tượng chọn':'Isolate selected object','Chọn sâu bên trong':'Select nested objects','Hiển thị dòng tính tổng':'Show totals row','Tổng chỉ cấp cao nhất':'Total top level only',
    'Độ cao hàng':'Row height','Hàng: Vừa':'Rows: Normal','Hàng: Gọn':'Rows: Compact','Hàng: Thoáng':'Rows: Roomy',
    'Chọn đối tượng trong SketchUp là bảng tự đọc. Bấm một ô để đánh dấu đối tượng và hiện nội dung ô đó; giữ Shift hoặc Ctrl để chọn nhiều dòng, Ctrl+A chọn hết. Nhấp đúp vào ô để sửa: Tên, Mô tả (gõ), Tình trạng, Tag, Vật liệu (chọn từ danh sách).':'Select objects in SketchUp and the table reads them. Click a cell to mark the object and show that cell\'s content; hold Shift or Ctrl to select several rows, Ctrl+A selects all. Double-click a cell to edit: Name and Description (type), Status, Tag and Material (pick from a list).',
    'Chưa chọn đối tượng nào. Chọn group hoặc component trong SketchUp, bảng sẽ tự đọc.':'Nothing selected. Select a group or component in SketchUp and the table reads it.',
    'Bỏ chọn':'Deselect','(Không có tag)':'(No tag)','(Không vật liệu)':'(No material)','Tìm...':'Search...','Tìm trong danh sách':'Search in list','Không có mục nào khớp.':'No matching items.',
    'Đối tượng đang bị khóa nên không sửa được.':'The object is locked and cannot be edited.','Không nhóm':'No grouping','Cha (Parent)':'Parent','Loại (Entity)':'Type (Entity)',
    'Tên họ (Definition)':'Family name (Definition)','Tên (Instance)':'Name (Instance)','Tag':'Tag','Tình trạng':'Status','(Gốc)':'(Root)','(Chưa đặt tên)':'(Unnamed)','(Chưa phân loại)':'(Unclassified)','(Untagged)':'(Untagged)',
    'Bấm để sắp xếp':'Click to sort','Tổng cộng':'Total','Bấm để chọn cả nhóm':'Click to select the whole group','Mở nhóm':'Expand group','Thu gọn nhóm':'Collapse group',
    'Không có đối tượng nào khớp bộ lọc.':'No objects match the filter.','Nhóm theo':'Group by','Gộp dòng giống nhau':'Merge identical rows',
    'Chỉ đổi cách hiển thị. Dòng gộp: Số lượng, diện tích, thể tích là tổng của các dòng gộp.':'Display only. On merged rows, quantity, area and volume are the sum of the merged rows.',
    // --- Cột bảng (Ruby gửi) ---
    'Ảnh':'Photo','Loại':'Type','Họ':'Family','Tên':'Name','Mô tả':'Description','Rộng (X) mm':'Width (X) mm','Dài (Y) mm':'Length (Y) mm','Cao (Z) mm':'Height (Z) mm',
    '(X) x (Z) mm':'(X) x (Z) mm','(X) x (Y) mm':'(X) x (Y) mm','(X) x (Y) x (Z) mm':'(X) x (Y) x (Z) mm','Diện tích (X*Z) m²':'Area (X*Z) m²','Diện tích (X*Y) m²':'Area (X*Y) m²',
    'Diện tích mặt m²':'Face area m²','Thể tích m³':'Volume m³','Phân loại thẻ':'Tag classification','Hiện hữu':'Existing','Dùng lại':'Reused','Tạm thời':'Temporary','Loại bỏ':'Removed',
    // --- Đổi tên hàng loạt ---
    'Sẽ đổi':'Will change','Giữ nguyên':'Unchanged','Bị khóa':'Locked','Tên trống':'Empty name','Quá dài':'Too long','(trống)':'(empty)','Đổi tên hàng loạt':'Batch rename',
    '. Chỉ đổi tên đối tượng, không đổi tên định nghĩa, hình học hay dữ liệu hạng mục. Cả đợt là một bước hoàn tác.':'. Only object names change, not definition names, geometry or item data. The whole batch is one undo step.',
    'Áp dụng':'Apply','Mẫu tên':'Name template','Tìm':'Find','Thay bằng':'Replace with','Tiền tố':'Prefix','Hậu tố':'Suffix','Số bắt đầu':'Start number','Số chữ số':'Digits','Bước nhảy':'Step',
    'Kiểu chữ':'Letter case','CHỮ HOA':'UPPERCASE','chữ thường':'lowercase','Viết Hoa Chữ Đầu':'Title Case','Đánh số theo':'Number by','Thứ tự trong bảng':'Table order','Vị trí (X, rồi Y, rồi Z)':'Position (X, then Y, then Z)','Tên hiện tại':'Current name',
    // --- Cài đặt ---
    'Chung':'General','Cài đặt lưu trên máy này và áp dụng cho mọi model. Mỗi thay đổi được lưu ngay.':'Settings are stored on this computer and apply to every model. Each change is saved immediately.',
    'Ngôn ngữ':'Language','Tiếng Việt':'Tiếng Việt','Đổi ngôn ngữ sẽ tải lại cửa sổ. Báo cáo CSV luôn xuất bằng tiếng Việt.':'Changing the language reloads the window. CSV reports are always exported in Vietnamese.',
    'Đơn vị chiều dài':'Length unit','Milimét (mm)':'Millimetre (mm)','Xentimét (cm)':'Centimetre (cm)','Mét (m)':'Metre (m)',
    'Áp dụng cho kích thước hiện trong cửa sổ. Diện tích luôn là m², thể tích là m³; báo cáo CSV giữ nguyên mm.':'Applies to sizes shown in this window. Area is always m² and volume m³; CSV reports stay in mm.',
    'Ảnh chỉ được chụp khi bạn bấm nút trong tab Hình ảnh hoặc Bảng khối lượng. Plugin không tự chụp.':'Photos are only taken when you press a button in the Images tab or the Quantity table. The plugin never takes photos on its own.',
    'Thư mục lưu ảnh':'Image folder','Chọn thư mục…':'Choose folder…','Mở thư mục':'Open folder',
    'Để trống để dùng thư mục mặc định. Ảnh nằm trong thư mục con theo từng model, không ghi vào file SketchUp.':'Leave empty to use the default folder. Images go in a sub-folder per model and are not written into the SketchUp file.',
    '(chưa có, sẽ được tạo khi chụp ảnh đầu tiên)':'(does not exist yet; it will be created with the first photo)',
    'Cách chụp':'Capture mode','Cô lập món đồ rồi chụp':'Isolate the item, then shoot','Chụp đúng khung nhìn hiện tại':'Shoot the current view as is',
    'Cô lập: ẩn tạm phần còn lại của model, zoom vào món đồ, chụp ảnh vuông rồi trả model về như cũ. Khung nhìn hiện tại: chụp đúng những gì đang thấy, không đổi gì.':'Isolate: temporarily hides the rest of the model, zooms to the item, takes a square photo and restores the model. Current view: shoots exactly what you see and changes nothing.',
    'Cỡ ảnh':'Image size','Cạnh dài của ảnh. Ảnh lớn đẹp hơn nhưng chụp lâu hơn và tốn dung lượng.':'Longest side of the image. Larger images look better but take longer and use more space.',
    'Nền ảnh':'Image background','Trong suốt':'Transparent','Trắng':'White','Nền trắng tạm tắt mặt đất và chân trời khi chụp rồi trả lại.':'A white background temporarily turns off the ground and horizon while shooting, then restores them.',
    // --- Hình ảnh ---
    'Kéo thả ảnh vào đây hoặc chọn ô rồi dán (Ctrl+V)':'Drop an image here, or select the cell and paste (Ctrl+V)',
    'Hãy dùng file ảnh PNG, JPG, WebP hoặc BMP.':'Use a PNG, JPG, WebP or BMP image file.','Ảnh quá lớn (tối đa 20 MB).':'Image too large (20 MB maximum).','Không đọc được ảnh.':'Could not read the image.',
    'Hãy thả file ảnh PNG, JPG, WebP hoặc BMP.':'Drop a PNG, JPG, WebP or BMP image file.','Hãy chọn đúng một đối tượng (hoặc bấm vào ô ảnh của nó) rồi dán ảnh.':'Select exactly one object (or click its photo cell), then paste.',
    'Ảnh chỉ được chụp khi bạn bấm "Cập nhật ảnh". Muốn dùng ảnh riêng: kéo thả file ảnh vào ô, bấm ô rồi dán (Ctrl+V), hoặc bấm "Chọn ảnh…".':'Photos are only taken when you press "Update photos". To use your own image: drop an image file onto a cell, click a cell and paste (Ctrl+V), or press "Choose image…".',
    'Cập nhật ảnh':'Update photos','Chỉ chụp đối tượng chưa có ảnh':'Only objects without a photo','Dừng':'Stop','Mở thư mục ảnh':'Open image folder',
    'Chưa có ảnh':'No photo','Kéo thả ảnh vào đây hoặc dán (Ctrl+V)':'Drop an image here or paste (Ctrl+V)','Chụp lại':'Retake','Chọn ảnh…':'Choose image…','Xóa ảnh':'Delete photo','Không đọc được file ảnh':'Could not read the image file',
    'Chưa chọn đối tượng nào. Chọn group hoặc component trong SketchUp để xem và chụp ảnh.':'Nothing selected. Select a group or component in SketchUp to view and photograph it.',
    // --- Thông báo từ Ruby ---
    'Đã lưu cài đặt.':'Settings saved.','Đã đổi thư mục lưu ảnh.':'Image folder changed.','Đã lưu ảnh cho đối tượng.':'Photo saved for the object.','Đã xóa ảnh của đối tượng.':'Photo deleted for the object.',
    'Bản SketchUp này không có hộp chọn thư mục. Hãy gõ đường dẫn thư mục vào ô.':'This SketchUp version has no folder picker. Type the folder path into the box.',
    'Đang chụp ảnh. Hãy đợi xong hoặc bấm Dừng.':'A capture is running. Wait for it to finish or press Stop.','Bảng đã cũ. Hãy làm mới bảng.':'The table is out of date. Refresh the table.',
    'Không có đối tượng nào cần chụp.':'No objects need photographing.','Danh sách ảnh không hợp lệ.':'Invalid image list.','Đối tượng không còn trong bảng. Hãy làm mới bảng.':'The object is no longer in the table. Refresh the table.',
    'không ghi được file ảnh, kiểm tra thư mục lưu ảnh.':'could not write the image file; check the image folder.','không chụp được.':'could not take the photo.',
    'SketchUp không chụp được ảnh. Kiểm tra thư mục lưu ảnh trong Cài đặt.':'SketchUp could not take the photo. Check the image folder in Settings.',
    'SketchUp không tạo được ảnh. Kiểm tra thư mục lưu ảnh trong Cài đặt.':'SketchUp could not create the image. Check the image folder in Settings.',
    'Đối tượng không còn tồn tại. Hãy làm mới bảng.':'The object no longer exists. Refresh the table.','Mã đối tượng không hợp lệ.':'Invalid object ID.','Dữ liệu không phải ảnh PNG.':'The data is not a PNG image.',
    'Cài đặt không hợp lệ.':'Invalid settings.','Ngôn ngữ không hợp lệ.':'Invalid language.','Cách chụp không hợp lệ.':'Invalid capture mode.','Nền ảnh không hợp lệ.':'Invalid image background.','Đơn vị chiều dài không hợp lệ.':'Invalid length unit.',
    'Đường dẫn thư mục ảnh không hợp lệ.':'Invalid image folder path.','Thư mục ảnh phải là đường dẫn đầy đủ (ví dụ C:\\Anh\\NoiThat).':'The image folder must be a full path (for example C:\\Images\\Interior).',
    'Đã lưu quy tắc phân loại.':'Classification rule saved.','Đã lưu bộ tag trên máy này.':'Tag set saved on this computer.','Tính năng không hợp lệ.':'Invalid function.',
    'Không thực hiện được thao tác. Hãy làm mới dữ liệu và thử lại.':'The action could not be completed. Refresh the data and try again.',
    'Không ghi được tệp. Kiểm tra vị trí lưu và đóng tệp nếu đang mở trong Excel.':'Could not write the file. Check the location and close the file if it is open in Excel.',
    'Mô hình đã thay đổi. Hãy làm mới trước khi tiếp tục.':'The model has changed. Refresh before continuing.','Hãy chọn group hoặc đối tượng cần quét trong SketchUp.':'Select the group or object to scan in SketchUp.',
    'Hãy chọn nhóm hoặc đối tượng thành phần trong SketchUp trước.':'Select a group or component in SketchUp first.','Hãy đánh dấu ít nhất một trường cần cập nhật.':'Tick at least one field to update.',
    'Các dòng nằm ở cấp lồng khác nhau nên SketchUp chỉ chọn dòng cuối. Đổi tên vẫn áp dụng cho mọi dòng đã chọn trong bảng.':'The rows are at different nesting levels, so SketchUp selects only the last row. Renaming still applies to every selected row in the table.',
    'Hãy chọn ít nhất một dòng trong bảng.':'Select at least one row in the table.','Chỉ số dòng không hợp lệ.':'Invalid row index.','Ô này không sửa được trong bảng.':'This cell cannot be edited in the table.',
    'Vật liệu này không có trong model.':'This material is not in the model.','Đã xóa preset.':'Preset deleted.','Thao tác preset không hợp lệ.':'Invalid preset action.',
    'Bảng chưa có dòng nào. Hãy chọn group hoặc component trong SketchUp.':'The table has no rows. Select a group or component in SketchUp.','Có đối tượng không còn tồn tại. Hãy làm mới bảng.':'Some objects no longer exist. Refresh the table.',
    'Không có đối tượng nào cần đổi tên.':'No objects need renaming.','Hãy chọn đối tượng hoặc mặt trong SketchUp trước khi gán tag.':'Select objects or faces in SketchUp before assigning a tag.',
    'Lựa chọn đã thay đổi. Hãy làm mới trước khi áp dụng.':'The selection has changed. Refresh before applying.','Bản xem trước đã hết hiệu lực. Hãy xem trước lại.':'The preview has expired. Preview again.',
    'Đối tượng không còn tồn tại. Hãy chạy kiểm tra lại.':'The object no longer exists. Run the check again.','Hãy đợi quét xong trước khi xuất báo cáo.':'Wait for the scan to finish before exporting a report.',
    'Loại báo cáo không hợp lệ.':'Invalid report type.','Đối tượng nằm trong thành phần dùng chung nhiều nơi nên không cô lập được.':'The object is inside a component shared in several places, so it cannot be isolated.',
    'Đối tượng đang bị khóa.':'The object is locked.','Đối tượng không hỗ trợ dữ liệu VGD hoặc không còn tồn tại.':'The object does not support VGD data or no longer exists.',
    'Preset không hợp lệ.':'Invalid preset.','Tên preset không được để trống.':'The preset name cannot be empty.','Tên preset quá dài (tối đa 40 ký tự).':'The preset name is too long (40 characters maximum).',
    'Preset phải có ít nhất một cột.':'A preset needs at least one column.','Tên này trùng với preset có sẵn. Hãy đặt tên khác.':'This name matches a built-in preset. Choose another name.','Trạng thái bảng không hợp lệ.':'Invalid table state.',
    'Một ô chữ dài quá 400 ký tự.':'A text box is longer than 400 characters.','Thứ tự đánh số không hợp lệ.':'Invalid numbering order.','Kiểu chữ không hợp lệ.':'Invalid letter case.',
    'Bộ tag phải là một danh sách.':'The tag set must be a list.','Mỗi tag phải là một mục hợp lệ.':'Each tag must be a valid entry.','Tên tag không được để trống.':'The tag name cannot be empty.',
    'Tên "Untagged" là tên mặc định của SketchUp, hãy chọn tên khác.':'"Untagged" is SketchUp\'s default name; choose another name.','File này là Excel (.xlsx). Hãy lưu lại dưới dạng CSV UTF-8 rồi nhập lại.':'This file is Excel (.xlsx). Save it as CSV UTF-8 and import again.',
    'File không có dữ liệu.':'The file has no data.','Thiếu cột "Tên tag" trong file.':'The file is missing the "Tên tag" column.','File không có tag nào.':'The file has no tags.','File JSON không có tag nào.':'The JSON file has no tags.',
    'File JSON không đúng định dạng.':'The JSON file is not in a valid format.','Hãy chọn một tag.':'Choose a tag.','Tên "Untagged" không dùng để gán.':'"Untagged" cannot be assigned.',
    'Mục đưa vào bảng khối lượng phải là Có hoặc Không.':'"Include in quantity table" must be Yes or No.','Mục đưa vào bảng khối lượng phải là Có hoặc Không':'"Include in quantity table" must be Yes or No',
    'Phiên bản dữ liệu chưa được hỗ trợ.':'This data version is not supported.','Phiên bản dữ liệu chưa được hỗ trợ':'This data version is not supported',
    'Quy tắc phải là một danh sách.':'Rules must be a list.','Loại nguồn phân loại không hợp lệ.':'Invalid classification source type.',
    'Đối tượng không còn tồn tại':'The object no longer exists','Chưa nhập mã hạng mục':'Item code not entered','Chưa gán khu vực / phòng':'Zone / room not assigned','Không đọc được dữ liệu BIM':'Could not read BIM data',
    'Đếm số lượng cần đơn vị cái / bộ / lô':'Counting needs a unit of pcs / set / lot','Thông tin hợp lệ':'Valid information',
    'Xóa dữ liệu VGD của các đối tượng đang chọn? Hình học vẫn được giữ nguyên.':'Clear VGD data of the selected objects? Geometry stays unchanged.'
  };
  const MM_UNIT=/ (cm|m)$|\((cm|m)\)$/;
  const patterns=[];
  const rule=(re,fn)=>patterns.push([re,fn]);
  let lang='vi',names={};
  const N=(group,value)=>((names[group]||{})[value])||value;
  const lower=s=>s.toLocaleLowerCase('en');
  // Tra từ điển; kích thước theo đơn vị cm / m được tra như mm rồi đổi lại đơn vị.
  function lookup(text){
    if(Object.prototype.hasOwnProperty.call(EN,text))return EN[text];
    const unit=text.match(MM_UNIT);
    if(unit){
      const u=unit[1]||unit[2],base=text.replace(MM_UNIT,m=>m.replace(u,'mm'));
      if(Object.prototype.hasOwnProperty.call(EN,base))return EN[base].replace(/mm(\)?)$/,u+'$1');
    }
    return undefined;
  }
  const T=text=>{const hit=lookup(text);return hit===undefined?text:hit;};
  const plural=(n,one,many)=>`${n} ${Number(String(n).replace(/\D/g,''))===1?one:many}`;
  const SKIPPED=/ Bỏ qua (\d+) đối tượng bị khóa\./;
  // ---- Mẫu cho chuỗi có số / tên xen vào ----
  rule(/^Đang chọn ([\d.,]+) đối tượng trong SketchUp\.$/,(m,n)=>`${plural(n,'object','objects')} selected in SketchUp.`);
  rule(/^Đang chọn ([\d.,]+) đối tượng hoặc mặt trong SketchUp\.$/,(m,n)=>`${plural(n,'object or face','objects or faces')} selected in SketchUp.`);
  rule(/\((\d+) biến thể\)/,(m,n)=>`(${n} variants)`);
  rule(/^([\d.,]+) lần xuất hiện · ([\d.,]+) đối tượng có thể ghi · ([\d.,]+) lần xuất hiện được bảo vệ\.$/,(m,a,b,c)=>`${a} occurrences · ${b} writable objects · ${c} protected occurrences.`);
  rule(/^Phân loại: (.*)$/,(m,n)=>`Classify: ${T(n)}`);
  rule(/^(.*) \((vật liệu|đối tượng)\)$/,(m,n,k)=>`${T(n)} (${k==='vật liệu'?'material':'object'})`);
  rule(/^Đã chọn (\d+) \/ (\d+) dòng$/,(m,a,b)=>`Selected ${a} / ${b} rows`);
  rule(/^Nhóm theo: (.*) ▾$/,(m,g)=>`Group by: ${T(g)} ▾`);
  rule(/^(.+) ▾$/,(m,g)=>lookup(g)===undefined?m:`${T(g)} ▾`);
  rule(/^Cập nhật (.+)$/,(m,f)=>`Update ${f}`);
  rule(/^(Khôi phục cột gốc của preset|Xóa preset): (.+)$/,(m,a,n)=>`${T(a)}: ${T(n)}`);
  rule(/^Tổng cộng · (\d+) đối tượng$/,(m,n)=>`Total · ${plural(n,'object','objects')}`);
  rule(/^(.*) · (\d+)$/,(m,label,n)=>lookup(label)===undefined?m:`${T(label)} · ${n}`);
  rule(/^Sẽ đổi (\d+) · giữ nguyên (\d+) · bị khóa (\d+)(.*)$/,(m,a,b,c,rest)=>`Will change ${a} · unchanged ${b} · locked ${c}${rest.replace(/ · tên trống (\d+)/,' · empty name $1').replace(/ · quá dài (\d+)/,' · too long $1').replace(/ · trùng tên (\d+)/,' · duplicate name $1')}`);
  rule(/^(Sẽ đổi|Giữ nguyên|Bị khóa|Tên trống|Quá dài)( · trùng)?$/,(m,s,d)=>T(s)+(d?' · duplicate':''));
  rule(/^Chỉ hiện 200 dòng đầu trong (\d+) dòng\.$/,(m,n)=>`Showing only the first 200 of ${n} rows.`);
  rule(/^Áp dụng cho (\d+) dòng đang chọn trong bảng(\..*)$/,(m,n,rest)=>`Applies to ${plural(n,'selected row','selected rows')} in the table${T(rest)}`);
  rule(/^Áp dụng cho mọi (\d+) dòng trong bảng \(chưa chọn dòng nào\)(\..*)$/,(m,n,rest)=>`Applies to all ${n} rows in the table (no row selected)${T(rest)}`);
  rule(/^Đơn vị: (mm|cm|m) \(chiều dài\), m² \(diện tích\), m³ \(thể tích\), cái \(số lượng\)\. Diện tích \(X\*Z\), \(X\*Y\) theo khung bao quanh\. Thể tích chỉ có cho group kín\. Số liệu chưa trừ hao hụt hoặc phần che khuất\.$/,
    (m,u)=>`Units: ${u} (length), m² (area), m³ (volume), pcs (quantity). Areas (X*Z) and (X*Y) use the bounding box. Volume exists only for closed groups. Figures do not subtract waste or hidden parts.`);
  rule(/^Đang quét… ([\d.,]+) đối tượng hình học\.$/,(m,n)=>`Scanning… ${n} geometry objects.`);
  rule(/^Tạo tag "(.*)"$/,(m,n)=>`Create tag "${n}"`);
  rule(/^Đã quét ([\d.,]+) đối tượng và ([\d.,]+) mặt hình học\. Chọn báo cáo, rồi chọn nơi lưu file\. Tiêu đề và hạng mục xuất bằng tiếng Việt\.$/,(m,a,b)=>`Scanned ${a} objects and ${b} geometry faces. Choose a report, then choose where to save the file. Headings and items are exported in Vietnamese.`);
  rule(/^Xuất CSV · (.*)$/,(m,n)=>`Export CSV · ${T(n)}`);
  rule(/^Sẽ ghi dữ liệu cho (\d+) đối tượng \((\d+) lần xuất hiện\)\. Bỏ qua (\d+) lần xuất hiện\.$/,(m,a,b,c)=>`Will write data for ${a} objects (${b} occurrences). Skipping ${c} occurrences.`);
  rule(/^Đang dùng: (.*?)( \(chưa có, sẽ được tạo khi chụp ảnh đầu tiên\))?$/,(m,dir,note)=>`In use: ${dir}${note?' '+T(note.trim()):''}`);
  rule(/^Đang chụp (\d+)\/(\d+)…$/,(m,a,b)=>`Taking photo ${a}/${b}…`);
  rule(/^Đang chụp ảnh (\d+)\/(\d+)…$/,(m,a,b)=>`Taking photos ${a}/${b}…`);
  rule(/^Đã dừng: chụp được (\d+)\/(\d+) ảnh\.(.*)$/,(m,a,b,rest)=>`Stopped: ${a}/${b} photos taken.${rest.replace(' Lỗi: ',' Errors: ')}`);
  rule(/^Đã chụp (\d+)\/(\d+) ảnh\.(.*)$/,(m,a,b,rest)=>`Took ${a}/${b} photos.${rest.replace(' Lỗi: ',' Errors: ')}`);
  rule(/^Hiện thêm \((\d+) đối tượng nữa\)$/,(m,n)=>`Show more (${n} more)`);
  rule(/^Mỗi lần chỉ chụp tối đa (\d+) đối tượng\. Hãy chọn ít hơn\.$/,(m,n)=>`Photograph at most ${n} objects at a time. Select fewer.`);
  rule(/^Ảnh quá lớn \(tối đa (\d+) MB\)\.$/,(m,n)=>`Image too large (${n} MB maximum).`);
  rule(/^Cỡ ảnh phải từ (\d+) đến (\d+) điểm ảnh\.$/,(m,a,b)=>`Image size must be between ${a} and ${b} pixels.`);
  rule(/^Đã cập nhật (\d+) đối tượng; bỏ qua (\d+) đối tượng bị khóa\.$/,(m,a,b)=>`Updated ${plural(a,'object','objects')}; skipped ${b} locked.`);
  rule(/^Đã sửa (tên|mô tả|tình trạng|tag|vật liệu) cho (\d+) đối tượng\.(.*)$/,(m,f,n,rest)=>`Changed ${({'tên':'name','mô tả':'description','tình trạng':'status','tag':'tag','vật liệu':'material'})[f]} for ${plural(n,'object','objects')}.${rest.replace(SKIPPED,' Skipped $1 locked.')}`);
  rule(/^Đã lưu preset "(.*)"\.$/,(m,n)=>`Saved preset "${n}".`);
  rule(/^Đã đổi tên (\d+) đối tượng\.(.*)$/,(m,n,rest)=>`Renamed ${plural(n,'object','objects')}.${rest.replace(SKIPPED,' Skipped $1 locked.').replace(/ Có (\d+) dòng trùng tên\./,' $1 rows have duplicate names.')}`);
  rule(/^Đã gán tag "(.*)" cho (\d+) đối tượng\.(.*)$/,(m,t,n,rest)=>`Assigned tag "${t}" to ${plural(n,'object','objects')}.${rest.replace(SKIPPED,' Skipped $1 locked.').replace(' Tag này đang tắt hiển thị nên các đối tượng gán vào sẽ bị ẩn.',' This tag is hidden, so the assigned objects will be hidden.')}`);
  rule(/^Đã xuất (\d+) tag: (.*)$/,(m,n,p)=>`Exported ${n} tags: ${p}`);
  rule(/^Đã nhập (\d+) tag\. Bộ tag hiện có (\d+) tag\.$/,(m,a,b)=>`Imported ${a} tags. The tag set now has ${b} tags.`);
  rule(/^Đã chuyển đổi (\d+) đối tượng\.(.*)$/,(m,n,rest)=>`Converted ${plural(n,'object','objects')}.${rest.replace(' Đã lưu quy tắc phân loại.',' Classification rule saved.')}`);
  rule(/^Đã xuất (\d+) dòng\. Mở bằng Excel: (.*)$/,(m,n,p)=>`Exported ${n} rows. Open in Excel: ${p}`);
  rule(/^Đã xuất quy tắc: (.*)$/,(m,p)=>`Exported rules: ${p}`);
  rule(/^Dòng (\d+): (.*)$/,(m,n,rest)=>`Row ${n}: ${translateText(rest)}`);
  rule(/^(.+?): (không ghi được file ảnh, kiểm tra thư mục lưu ảnh\.|không chụp được\.)$/,(m,n,why)=>`${n}: ${T(why)}`);
  rule(/^Tên tag quá dài \(tối đa (\d+) ký tự\): (.*)$/,(m,n,t)=>`Tag name too long (${n} characters maximum): ${t}`);
  rule(/^Tên tag bị trùng: (.*)$/,(m,t)=>`Duplicate tag name: ${t}`);
  rule(/^Nhóm không hợp lệ: (.*)$/,(m,t)=>`Invalid group: ${t}`);
  rule(/^Nhóm hạng mục không hợp lệ: (.*)$/,(m,t)=>`Invalid item group: ${t}`);
  rule(/^Trường dữ liệu không hợp lệ: (.*)$/,(m,t)=>`Invalid data field: ${t}`);
  rule(/^(.+) phải là số nguyên từ (\d+) đến (\d+)\.$/,(m,l,a,b)=>`${T(l)} must be a whole number from ${a} to ${b}.`);
  rule(/^Lớp phủ lỗi, dùng công cụ vẽ khung: (.*)$/,(m,e)=>`Overlay failed, using the outline tool: ${e}`);
  // Thông báo kiểm tra có tên trường / cách đo / đơn vị (bảng tên do Ruby gửi khi chọn English)
  rule(/^Thiếu (.+)$/,(m,f)=>{const hit=Object.entries(names.fields||{}).find(([vi])=>vi.toLocaleLowerCase('vi')===f);return hit?`Missing ${lower(hit[1])}`:m;});
  rule(/^(.+) phải là văn bản\.?$/,(m,f)=>(names.fields||{})[f]?`${N('fields',f)} must be text.`:m);
  rule(/^Giá trị (.+) không hợp lệ: (.*)$/,(m,f,v)=>(names.fields||{})[f]?`Invalid ${lower(N('fields',f))}: ${v}`:m);
  rule(/^(.+) không hợp lệ$/,(m,f)=>(names.fields||{})[f]?`${N('fields',f)} is invalid`:m);
  rule(/^(.+) cần đơn vị (.+)$/,(m,method,units)=>(names.quantity_method||{})[method]?`${N('quantity_method',method)} needs unit ${units.split(' / ').map(u=>N('unit',u)).join(' / ')}`:m);

  rule(/^(.+) \/ (.+)$/,(m,a,b)=>`${translateText(a)} / ${translateText(b)}`);

  function translateText(text){
    const lead=text.match(/^\s*/)[0],trail=text.match(/\s*$/)[0],core=text.trim();
    if(!core)return text;
    const hit=lookup(core);
    if(hit!==undefined)return lead+hit+trail;
    for(const [re,fn] of patterns){
      if(re.test(core)){const out=core.replace(re,fn);if(out!==core)return lead+out+trail;}
    }
    return text;
  }
  const ATTRS=['placeholder','title','aria-label','alt'];
  const SKIP='script,style,textarea,[data-no-i18n]';
  function walk(root){
    if(root.nodeType===Node.TEXT_NODE){translateNode(root);return;}
    if(root.nodeType!==Node.ELEMENT_NODE||root.matches(SKIP))return;
    ATTRS.forEach(a=>{if(root.hasAttribute(a)){const v=root.getAttribute(a),t=translateText(v);if(t!==v)root.setAttribute(a,t);}});
    root.childNodes.forEach(walk);
  }
  function translateNode(node){
    if(node.parentElement&&node.parentElement.closest(SKIP))return;
    const t=translateText(node.nodeValue);if(t!==node.nodeValue)node.nodeValue=t;
  }
  let observer=null,scheduled=false;
  function schedule(){if(scheduled)return;scheduled=true;queueMicrotask(()=>{scheduled=false;walk(document.body);document.title=translateText(document.title);});}
  function setLanguage(next,viEn){
    lang=next==='en'?'en':'vi';names=viEn||{};
    document.documentElement.lang=lang;
    if(lang!=='en'){if(observer){observer.disconnect();observer=null;}return;}
    walk(document.body);
    if(!observer){observer=new MutationObserver(schedule);observer.observe(document.body,{childList:true,subtree:true,characterData:true,attributes:true,attributeFilter:ATTRS});}
  }
  return {setLanguage,translateText,get language(){return lang;}};
})();
