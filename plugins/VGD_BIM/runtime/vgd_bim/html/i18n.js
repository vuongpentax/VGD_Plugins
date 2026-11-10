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
    
    'Tên tag':'Tag name','Mới':'New','Có trong model':'In model','Có trong model · đang ẩn':'In model · hidden','Chưa có trong model':'Not in model',
    'Thêm tag':'Add tag','Lưu bộ tag':'Save tag set','Nhập Excel (CSV)':'Import Excel (CSV)','Nhập JSON':'Import JSON','Xuất Excel (CSV)':'Export Excel (CSV)','Xuất JSON':'Export JSON',
    
    'Chọn tag':'Choose tag','Gán tag':'Assign tag','Hãy lưu bộ tag trước, rồi chọn tag để gán.':'Save the tag set first, then choose a tag to assign.',
    
    'Nhóm hạng mục':'Item group','Phần thô':'Rough work','Hoàn thiện':'Finishing','Đồ rời':'Loose furniture','Thiết bị':'Equipment','Khác':'Other',
    // --- Bảng khối lượng ---
    'Chọn cột':'Choose columns','Tìm kiếm...':'Search...','Tìm trong bảng':'Search in table','Tất cả nhóm':'All groups','Đổi tên':'Rename','Chụp ảnh':'Take photo',

    'Chọn tất cả cột':'Select all columns','Chọn tất cả':'Select all','Tìm cột':'Search columns','Ẩn danh sách cột':'Hide column list','Bỏ chọn tất cả':'Deselect all','Tìm cột...':'Search columns...','Tạo mới...':'Create new...',
    'Tên preset mới':'New preset name','Hãy nhập tên preset.':'Enter a preset name.','Xóa preset':'Delete preset','Preset':'Preset',

    'Thu phóng đối tượng':'Zoom to object','Cô lập đối tượng chọn':'Isolate selected object','Chọn sâu bên trong':'Select nested objects','Hiển thị dòng tính tổng':'Show totals row','Tổng chỉ cấp cao nhất':'Total top level only',
    'Độ cao hàng':'Row height','Hàng: Vừa':'Rows: Normal','Hàng: Gọn':'Rows: Compact','Hàng: Thoáng':'Rows: Roomy',

    'Chưa chọn đối tượng nào. Chọn group hoặc component trong SketchUp, bảng sẽ tự đọc.':'Nothing selected. Select a group or component in SketchUp and the table reads it.',
    'Bỏ chọn':'Deselect','(Không có tag)':'(No tag)','(Không vật liệu)':'(No material)','Tìm...':'Search...','Tìm trong danh sách':'Search in list','Không có mục nào khớp.':'No matching items.',
    'Đối tượng đang bị khóa nên không sửa được.':'The object is locked and cannot be edited.','Không nhóm':'No grouping','Cha (Parent)':'Parent','Loại (Entity)':'Type (Entity)',
    'Tên họ (Definition)':'Family name (Definition)','Tên (Instance)':'Name (Instance)','Tag':'Tag','Tình trạng':'Status','(Gốc)':'(Root)','(Chưa đặt tên)':'(Unnamed)','(Chưa phân loại)':'(Unclassified)','(Untagged)':'(Untagged)',
'Tổng cộng':'Total','Bấm để chọn cả nhóm':'Click to select the whole group','Mở nhóm':'Expand group','Thu gọn nhóm':'Collapse group',
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

    'Ngôn ngữ':'Language','Tiếng Việt':'Tiếng Việt','Đổi ngôn ngữ sẽ tải lại cửa sổ. Báo cáo CSV luôn xuất bằng tiếng Việt.':'Changing the language reloads the window. CSV reports are always exported in Vietnamese.',
    'Đơn vị chiều dài':'Length unit',


    'Thư mục lưu ảnh':'Image folder','Mở thư mục':'Open folder',

    '(chưa có, sẽ được tạo khi chụp ảnh đầu tiên)':'(does not exist yet; it will be created with the first photo)',


    'Cỡ ảnh':'Image size',
    'Nền ảnh':'Image background',
    // --- Hình ảnh ---
    'Kéo thả ảnh vào đây hoặc chọn ô rồi dán (Ctrl+V)':'Drop an image here, or select the cell and paste (Ctrl+V)',
    'Hãy dùng file ảnh PNG, JPG, WebP hoặc BMP.':'Use a PNG, JPG, WebP or BMP image file.','Ảnh quá lớn (tối đa 20 MB).':'Image too large (20 MB maximum).','Không đọc được ảnh.':'Could not read the image.',
    'Hãy thả file ảnh PNG, JPG, WebP hoặc BMP.':'Drop a PNG, JPG, WebP or BMP image file.','Hãy chọn đúng một đối tượng (hoặc bấm vào ô ảnh của nó) rồi dán ảnh.':'Select exactly one object (or click its photo cell), then paste.',

    'Cập nhật ảnh':'Update photos','Chỉ chụp đối tượng chưa có ảnh':'Only objects without a photo','Dừng':'Stop','Mở thư mục ảnh':'Open image folder',
'Chụp lại':'Retake','Chọn ảnh…':'Choose image…','Xóa ảnh':'Delete photo',

    // --- Thông báo từ Ruby ---
    'Đã lưu cài đặt.':'Settings saved.','Đã đổi thư mục lưu ảnh.':'Image folder changed.','Đã lưu ảnh cho đối tượng.':'Photo saved for the object.','Đã xóa ảnh của đối tượng.':'Photo deleted for the object.',
    'Bản SketchUp này không có hộp chọn thư mục. Hãy gõ đường dẫn thư mục vào ô.':'This SketchUp version has no folder picker. Type the folder path into the box.',
    'Đang chụp ảnh. Hãy đợi xong hoặc bấm Dừng.':'A capture is running. Wait for it to finish or press Stop.','Bảng đã cũ. Hãy làm mới bảng.':'The table is out of date. Refresh the table.',
    'Không có đối tượng nào cần chụp.':'No objects need photographing.','Danh sách ảnh không hợp lệ.':'Invalid image list.','Đối tượng không còn trong bảng. Hãy làm mới bảng.':'The object is no longer in the table. Refresh the table.',
    'không ghi được file ảnh, kiểm tra thư mục lưu ảnh.':'could not write the image file; check the image folder.','không chụp được.':'could not take the photo.',

    'Đối tượng không còn tồn tại. Hãy làm mới bảng.':'The object no longer exists. Refresh the table.','Mã đối tượng không hợp lệ.':'Invalid object ID.','Dữ liệu không phải ảnh PNG.':'The data is not a PNG image.',
    'Cài đặt không hợp lệ.':'Invalid settings.','Ngôn ngữ không hợp lệ.':'Invalid language.','Nền ảnh không hợp lệ.':'Invalid image background.','Đơn vị chiều dài không hợp lệ.':'Invalid length unit.',
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
    'Xóa dữ liệu VGD của các đối tượng đang chọn? Hình học vẫn được giữ nguyên.':'Clear VGD data of the selected objects? Geometry stays unchanged.',
    // --- Thanh đầu, bảng preset, bánh răng ---
    'Preset: cột, đơn vị và ảnh của bảng':'Preset: columns, units and photos of the table',
    'Đơn vị':'Units','Hình ảnh':'Images','Chiều dài':'Length','Diện tích':'Area','Thể tích':'Volume','Tiền tệ':'Currency','Dấu thập phân':'Decimal separator',
    'Chiều dài: số lẻ':'Length: decimals','Chiều dài: đơn vị':'Length: unit','Diện tích: số lẻ':'Area: decimals','Diện tích: đơn vị':'Area: unit','Thể tích: số lẻ':'Volume: decimals','Thể tích: đơn vị':'Volume: unit',
    'Chiều rộng ảnh':'Image width','Chiều cao ảnh':'Image height','Góc nhìn ảnh':'Image view','Kiểu hiển thị ảnh':'Image style',
    'Khung nhìn hiện tại':'Current view','Phối cảnh iso':'Isometric view','Chính diện':'Front view','Màu (có texture)':'Color (textured)','Kiểu hiện tại':'Current style','Nền trong suốt':'Transparent background','Nền trắng':'White background',
    'Thư mục lưu ảnh (dùng chung mọi preset). Để trống để dùng thư mục mặc định.':'Image folder (shared by all presets). Leave empty to use the default folder.',
    'Chọn thư mục lưu ảnh':'Choose image folder','Tạo preset từ bảng hiện tại':'Create a preset from the current table',
    'Khôi phục cột, tiêu đề và thiết lập gốc của preset':'Restore the preset\'s original columns, headers and settings',
    'Preset lưu cột hiển thị, thứ tự, tiêu đề cột, đơn vị và cách chụp ảnh, trên máy này. Đang dùng preset tự tạo thì mọi thay đổi tự cập nhật vào preset đó.':'A preset stores the visible columns, their order, column headers, units and photo settings, on this computer. While a custom preset is active, every change updates it automatically.',
    'Mặc định':'Default','Phòng & Khu vực':'Rooms & Zones','Cửa & Cửa sổ':'Doors & Windows','Nội thất':'Furniture','Thiết bị & Phụ kiện':'Fixtures & Fittings','Chiếu sáng':'Lighting','Vật liệu':'Material',
    'Mã phòng':'Room code','Tên phòng':'Room name','Rộng':'Width','Dài':'Length','Diện tích phòng':'Room area','STT':'No.','Ảnh vật liệu':'Material photo','Tên vật liệu':'Material name','Diện tích mặt':'Face area',
    'Mã hạng mục':'Item code','Loại':'Type','Hoàn thiện & phụ kiện':'Finish & hardware','Rộng x Cao':'Width x Height','Diện tích (R x C)':'Area (W x H)','Kích thước (R x S x C)':'Size (W x D x H)','Thương hiệu':'Brand','Thông số':'Specifications',
    'Ngôn ngữ':'Language',
    // --- Thanh công cụ, chân trang, cột mới ---
    'Thay thế':'Replace','Thay bằng...':'Replace with...','Xóa chữ tìm':'Clear search',
    'Thay chữ đang tìm trong các cột Tên, Mô tả, Xuất xứ, Quy cách đang hiện (một bước hoàn tác)':'Replaces the searched text in the visible Name, Description, Brand and Size columns (one undo step)',
    'Hãy hiện ít nhất một cột Tên, Mô tả, Hãng hoặc Cỡ':'Show at least one Name, Description, Brand or Size column',

    'Nhấp để sắp xếp · nhấp đúp để đổi tên cột':'Click to sort · double-click to rename the column','Tên cột':'Column name',
    'SketchUp không chụp được ảnh. Kiểm tra thư mục lưu ảnh.':'SketchUp could not take the photo. Check the image folder.','SketchUp không tạo được ảnh. Kiểm tra thư mục lưu ảnh trong bảng Preset.':'SketchUp could not create the image. Check the image folder in the Preset panel.',
    'nền trong suốt không dùng được trên máy này nên ảnh dùng cách thay thế':'transparent background is not available on this computer, so the image uses a normal background','khử răng cưa không dùng được trên máy này nên ảnh dùng cách thay thế':'anti-aliasing is not available on this computer, so the image uses a fallback','nền trong suốt và khử răng cưa không dùng được trên máy này nên ảnh dùng cách thay thế':'transparent background and anti-aliasing are not available on this computer, so the image uses a fallback',
    'Chụp':'Shoot','Chụp ảnh':'Take photo','Chụp lại':'Retake','Xóa ảnh':'Delete photo','Chọn ảnh…':'Choose image…','Mở thư mục ảnh':'Open image folder','Mở link':'Open link','Dừng':'Stop','Cập nhật ảnh':'Update photos',
    'Chỉ chụp đối tượng chưa có ảnh':'Only objects without a photo','Đổi trong bảng preset.':'Change it in the preset panel.',
    'Diện tích chiếu':'Projected area','Nhập / Xuất':'Import / Export','Cầu nối dữ liệu':'Data bridge','Gắn tag tự động theo tên':'Auto-tag by name','Thư viện tag mẫu (Auto Tag)':'Sample tag library (Auto Tag)','Nhập':'Import','Hãy tick ít nhất một cụm.':'Tick at least one cluster.',
    'Tick các cụm cần dùng rồi bấm Nhập: tag của cụm được thêm vào bộ tag của BIM và tạo sẵn trong model đang mở (chỉ tên tag, không đổi đối tượng nào). Bấm vào tên cụm để xem các tag trong cụm.':'Tick the clusters you need, then click Import: the cluster tags are added to the BIM tag set and created in the open model (tag names only, no object is changed). Click a cluster name to see its tags.','Chừa lề (%)':'Margin (%)','Chừa lề quanh món khi chụp ảnh Iso / Chính diện, tính theo %: 0 = ôm sát món, 20 = chừa 20%.':'Margin around the object when taking Isometric / Front photos, in %: 0 = tight, 20 = 20% margin.','Chụp Iso từ bên trái':'Capture isometric from the left','Chụp Iso từ bên phải':'Capture isometric from the right','Lề ảnh phải từ 0 đến 100 (%).':'The image margin must be between 0 and 100 (%).','Bên của góc Iso không hợp lệ.':'The isometric side is not valid.','Hãy chọn bên Iso là trái hoặc phải.':'Choose the isometric side: left or right.',
    'Mỗi luật là "tên tag ← từ khóa trong tên group / component" (nhiều từ khóa cách nhau dấu phẩy). Luật nằm trên thắng. Không phân biệt hoa thường và dấu tiếng Việt; từ khóa chỉ cần nằm trong tên (ví dụ "door" cũng khớp "Doorway"), nên hãy Xem trước rồi mới Áp dụng.':'Each rule is "tag name ← keywords in the group / component name" (separate several keywords with commas). The rule on top wins. Case and Vietnamese accents are ignored; a keyword only has to appear inside the name (for example "door" also matches "Doorway"), so Preview first and then Apply.',
    'Từ khóa trong tên':'Keywords in name','Lên trên':'Move up','Xuống dưới':'Move down','Thêm luật':'Add rule','Lưu làm mặc định':'Save as default','Đặt lại':'Reset',
    'Nhập file luật':'Import rules file','Xuất file luật':'Export rules file','Dựa theo':'Based on','Phạm vi':'Scope',
    'Cả tên bản sao và tên component':'Instance and component names','Tên bản sao':'Instance name','Tên component':'Component name','Đối tượng đang chọn':'Selected objects','Cả model':'Whole model',
    'Gắn cả group / component bên trong (đổi tag của mọi bản sao dùng chung định nghĩa)':'Also tag groups / components inside (changes the tag of every copy sharing the definition)',
    'Ghi đè tag đã có (mặc định chỉ gắn đối tượng chưa có tag)':'Overwrite existing tags (by default only untagged objects are tagged)',
    'Bấm Xem trước để biết sẽ gắn tag cho những đối tượng nào.':'Click Preview to see which objects will be tagged.','Luật hoặc tùy chọn đã đổi: bấm Xem trước lại.':'Rules or options changed: click Preview again.',
    'Sẽ gắn tag cho các đối tượng sau:':'These objects will be tagged:','Không có đối tượng nào cần gắn tag.':'No object needs tagging.',
    'Tổng đã xét':'Examined','Sẽ gắn':'To tag','Đã đúng tag sẵn':'Already correct','Giữ nguyên (đã có tag khác)':'Kept (already has another tag)','Không khớp luật nào':'No rule matched',
    'Đã lưu bộ luật gắn tag tự động làm mặc định.':'Saved the auto-tag rules as the default.','Đã đặt lại bộ luật về mặc định.':'Reset the rules to the default.',
    'Chưa có luật nào. Hãy thêm ít nhất một luật.':'There are no rules. Add at least one rule.','Hãy chọn group hoặc component trong SketchUp trước, hoặc bật "Cả model".':'Select a group or component in SketchUp first, or choose "Whole model".',
    'Không có đối tượng nào cần gắn tag. Bấm Xem trước để biết lý do.':'No object needs tagging. Click Preview to see why.','Tùy chọn "Dựa theo" không hợp lệ.':'The "Based on" option is not valid.','Tùy chọn "Phạm vi" không hợp lệ.':'The "Scope" option is not valid.',
    'Danh sách luật phải là một danh sách.':'The rules must be a list.','Mỗi luật phải là một mục hợp lệ.':'Each rule must be a valid entry.','Cần ít nhất một từ khóa.':'At least one keyword is needed.','File luật không đúng định dạng.':'The rules file is not in a valid format.','File không có luật nào.':'The file has no rules.',
    'Xếp tag vào thư mục (Auto Tag)':'Arrange tags into folders (Auto Tag)','Tên thư mục':'Folder name','Từ khóa trong tên tag':'Keywords in tag name',
    'Mỗi luật là "tên thư mục ← từ khóa trong TÊN TAG" (nhiều từ khóa cách nhau dấu phẩy). Luật nằm trên thắng; tag không khớp luật nào giữ nguyên chỗ cũ. Tag được xếp vào thư mục tag của SketchUp (cần SketchUp 2021 trở lên), thư mục chưa có sẽ được tạo. Hãy Xem trước rồi mới Áp dụng.':'Each rule is "folder name ← keywords in the TAG NAME" (separate several keywords with commas). The rule on top wins; tags that match no rule stay where they are. Tags are placed into SketchUp tag folders (SketchUp 2021 or newer), and missing folders are created. Preview first and then Apply.',
    'Ghi đè thư mục đã có (mặc định chỉ xếp tag chưa nằm trong thư mục nào)':'Overwrite existing folders (by default only tags not in any folder are arranged)',
    'Bấm Xem trước để biết sẽ xếp những tag nào vào thư mục nào.':'Click Preview to see which tags will go into which folders.','Sẽ xếp các tag sau vào thư mục:':'These tags will be placed into folders:','Không có tag nào cần xếp vào thư mục.':'No tag needs to be placed into a folder.',
    'Tổng tag đã xét':'Tags examined','Sẽ xếp':'To arrange','Đã đúng thư mục sẵn':'Already in place','Giữ nguyên (đã ở thư mục khác)':'Kept (already in another folder)',
    'Đã lưu bộ luật xếp thư mục làm mặc định.':'Saved the folder rules as the default.','Đã đặt lại bộ luật xếp thư mục về mặc định.':'Reset the folder rules to the default.',
    'Đặt lại bộ luật xếp thư mục về mặc định? Bộ luật đã lưu trên máy này sẽ bị xóa.':'Reset the folder rules to the default? The rules saved on this computer will be deleted.',
    'Phiên bản SketchUp này chưa có thư mục tag (cần SketchUp 2021 trở lên).':'This SketchUp version has no tag folders (SketchUp 2021 or newer is required).',
    'Chưa có tag nào trong model ngoài Untagged. Hãy nhập tag mẫu hoặc gán tag trước.':'The model has no tags other than Untagged. Import sample tags or assign tags first.',
    'Không có tag nào cần xếp vào thư mục. Bấm Xem trước để biết lý do.':'No tag needs to be placed into a folder. Click Preview to see why.',
    'Hãy nhập tên thư mục.':'Enter a folder name.','Tên thư mục không hợp lệ.':'The folder name is not valid.',
    'Kéo để đổi độ rộng':'Drag to resize',
    'Tô màu theo tag':'Color by tag','Bật / tắt chế độ tô màu theo tag của SketchUp (Color by Tag)':'Turn the SketchUp Color by Tag display mode on or off','Màu tag':'Tag color','Kiểu nét':'Line style','(mặc định)':'(default)',
    'Màu không hợp lệ.':'The color is not valid.','Kiểu nét không có trong model.':'This line style is not in the model.','Phiên bản SketchUp này chưa có kiểu nét cho tag (cần SketchUp 2021 trở lên).':'This SketchUp version has no tag line styles (SketchUp 2021 or newer is required).','Giá trị không hợp lệ.':'The value is not valid.',
    'Lưu ý: SketchUp báo vị trí group đang mở khác với vị trí tính từ các group cha. VGD_BIM dùng vị trí tính từ các group cha.':'Note: SketchUp reports a different position for the open group than the one computed from its parent groups. VGD_BIM uses the position computed from the parent groups.',
    'Ảnh vị trí':'Location photo','Kéo thả ảnh vào đây để dùng làm ảnh vị trí':'Drop an image here to use it as the location photo','Chụp vị trí từ bên trái (Iso)':'Capture location from the left (isometric)','Chụp vị trí từ bên phải (Iso)':'Capture location from the right (isometric)','Xóa ảnh vị trí':'Delete location photo',
    'Vùng nhìn ảnh vị trí (lần)':'Location photo view area (times)','Ảnh vị trí nhìn vùng quanh món rộng gấp bao nhiêu lần kích thước món: 2 = gần, 4 = vừa, 10 = xa (thấy cả căn phòng).':'How many times wider than the item the location photo looks: 2 = close, 4 = medium, 10 = far (shows the whole room).',
    'Ảnh vị trí trong công trình':'Location photo in the building','◣ Trái':'◣ Left','◢ Phải':'◢ Right','Chụp cảnh quanh món (không cô lập) theo góc Iso trái / phải, lưu vào cột Ảnh vị trí':'Captures the scene around the item (not isolated) from an isometric left / right angle and saves it to the Location photo column',
    'Đã xóa ảnh vị trí của đối tượng.':'Deleted the location photo of the object.','Loại ảnh không hợp lệ.':'The image type is not valid.','Vùng nhìn của ảnh vị trí phải từ 2 đến 20 lần kích thước món.':'The location photo view area must be between 2 and 20 times the item size.',
    'Đã ghim':'Pinned','Gần đây':'Recent','Ghim tag':'Pin tag','Bỏ ghim tag':'Unpin tag','Chọn tag này cho nút Gán tag':'Choose this tag for the Assign tag button',
    'Bấm tên để chọn tag cho nút Gán tag · kéo thả vào thư mục để chuyển':'Click the name to choose the tag for the Assign tag button · drag and drop onto a folder to move it','Thả vào đây để đưa tag ra ngoài thư mục (gốc)':'Drop here to move the tag out of its folder (root)',
    'Tag đã nằm sẵn ở đó.':'The tag is already there.','Tag Untagged không xếp vào thư mục được.':'The Untagged tag cannot be placed in a folder.','Mã thư mục không hợp lệ.':'The folder id is not valid.',
    'Lấy mẫu':'Sample','Bấm vào một đối tượng trong view để lấy tag của nó (Esc để hủy)':'Click an object in the view to pick up its tag (Esc to cancel)','Xóa tag (các đối tượng đang dùng sẽ chuyển sang tag khác)':'Delete tag (objects using it are moved to another tag)',
    'Không bấm trúng đối tượng nào.':'No object was clicked.','Đối tượng này chưa có tag (Untagged).':'This object has no tag (Untagged).',
    'Chuyển các đối tượng sang tag:':'Move the objects to tag:','Chuyển các đối tượng sang tag':'Move the objects to tag','Untagged (không có tag)':'Untagged (no tag)','Xóa tag':'Delete tag',
    'Không đối tượng nào bị xóa: chỉ đổi tag của chúng rồi gỡ tag.':'No object is deleted: their tag is changed and then the tag is removed.',
    'Bấm vào một đối tượng trong view để lấy tag của nó (Esc để hủy).':'Click an object in the view to pick up its tag (Esc to cancel).',
    'Mã tag nhận không hợp lệ.':'The receiving tag id is not valid.','Không tìm thấy tag nhận. Hãy làm mới danh sách.':'The receiving tag was not found. Refresh the list.','Tag nhận phải khác tag cần xóa.':'The receiving tag must differ from the tag to delete.','Tag Untagged không xóa được.':'The Untagged tag cannot be deleted.',
    'Nhập Excel':'Import Excel','Nhập tag (kèm màu, kiểu nét, thư mục) từ file Excel .xlsx':'Import tags (with color, line style and folder) from an Excel .xlsx file','Nhập tag từ Excel':'Import tags from Excel','Đã có':'Exists','Màu':'Color','Thư mục':'Folder',
    'Cập nhật cả tag đã có (màu, kiểu nét, thư mục); mặc định chỉ tạo tag mới':'Also update tags that already exist (color, line style, folder); by default only new tags are created',
    'Hãy chọn file Excel đuôi .xlsx.':'Choose an Excel file ending in .xlsx.','Chưa chọn tag nào để nhập.':'No tag is selected to import.',
    'File Excel quá lớn (tối đa 5 MB).':'The Excel file is too large (5 MB at most).','File không phải Excel (.xlsx) hợp lệ.':'The file is not a valid Excel (.xlsx) file.','File Excel có quá nhiều phần.':'The Excel file has too many parts.','File Excel có mã hóa, chưa đọc được.':'The Excel file is encrypted and cannot be read yet.',
    'File Excel có phần quá lớn.':'The Excel file has a part that is too large.','File Excel dùng kiểu nén chưa hỗ trợ.':'The Excel file uses an unsupported compression type.','File Excel bị hỏng (không giải nén được).':'The Excel file is damaged (cannot be unzipped).','Không đọc được trang tính đầu tiên.':'The first worksheet cannot be read.',
    'File Excel không có dữ liệu.':'The Excel file has no data.','Không tìm thấy dòng tiêu đề. Dòng đầu của bảng cần có cột "Name" (hoặc "Tên tag").':'No header row was found. The table needs a column named "Name" (or "Tag name") in its first row.','File không có tag nào để nhập.':'The file has no tags to import.','Danh sách tag không hợp lệ.':'The tag list is not valid.',
    'Tên tag không được để trống.':'The tag name cannot be empty.',
    'Trong model':'In model','Mở hết':'Expand all','Gập hết':'Collapse all','Làm mới':'Refresh','Mở':'Expand','Gập':'Collapse','Khôi phục hiển thị':'Restore visibility','Bỏ cô lập':'Remove isolation',
    'Tìm tag hoặc thư mục...':'Find tag or folder...','Tìm tag hoặc thư mục':'Find tag or folder','Model chưa có tag nào.':'The model has no tags yet.','Không có tag hoặc thư mục nào khớp.':'No tag or folder matches.',
    'Ẩn tag':'Hide tag','Hiện tag':'Show tag','Ẩn thư mục':'Hide folder','Hiện thư mục':'Show folder','Cô lập tag':'Isolate tag','Cô lập thư mục':'Isolate folder',
    'Mắt ẩn / hiện tag hoặc cả thư mục trong model; nút tròn cô lập: chỉ hiện mục đó, ẩn mọi thứ còn lại, bấm lại để trả hiển thị như cũ. Mỗi thao tác là một bước hoàn tác.':'The eye shows or hides a tag or a whole folder in the model; the round button isolates: only that item stays visible, everything else is hidden, and clicking again restores the previous visibility. Each action is one undo step.',
    'Phiên bản SketchUp này chưa có thư mục tag (cần SketchUp 2021 trở lên). Chỉ hiện danh sách tag.':'This SketchUp version has no tag folders (SketchUp 2021 or newer is required). Only the tag list is shown.',
    'Đã khôi phục hiển thị tag như trước khi cô lập.':'Restored tag visibility as it was before isolating.','Giá trị hiển thị không hợp lệ.':'The visibility value is not valid.',
    'Không tìm thấy tag hoặc thư mục này. Hãy làm mới danh sách.':'This tag or folder was not found. Refresh the list.','Không tìm thấy tag này. Hãy làm mới danh sách.':'This tag was not found. Refresh the list.','Không tìm thấy thư mục này. Hãy làm mới danh sách.':'This folder was not found. Refresh the list.',
    'Chưa cô lập gì để khôi phục.':'Nothing is isolated, so there is nothing to restore.','Mã tag hoặc thư mục không hợp lệ.':'The tag or folder id is not valid.','Loại mục không hợp lệ.':'The item type is not valid.',
    'Bộ tag':'Tag set','Tự động':'Automatic','Thư viện mẫu':'Sample library','Lọc theo nhóm':'Filter by group','Tất cả nhóm':'All groups','Bảng luật':'Rules table','Chưa có thư viện tag mẫu.':'No sample tag library.',
    'Chưa có tag nào. Bấm Thêm tag, nhập file, hoặc nhập cụm tag ở tab Thư viện mẫu.':'There are no tags yet. Click Add tag, import a file, or import tag clusters from the Sample library tab.',
    'Bộ tag lưu trên máy này, dùng lại cho mọi model; tên không phân biệt chữ hoa, chữ thường. Excel dùng file CSV; nếu Excel báo lỗi, hãy lưu lại dưới dạng CSV UTF-8.':'The tag set is saved on this computer and reused for every model; names are not case sensitive. Excel uses CSV files; if Excel reports an error, save the file again as CSV UTF-8.',
    'Nếu tag đang tắt hiển thị, các đối tượng gán vào sẽ bị ẩn.':'If the tag is hidden, the objects assigned to it will be hidden.',
    'Giữ Ctrl và lăn chuột giữa trên bảng để đổi độ cao hàng (ảnh to ra theo).':'Hold Ctrl and scroll the mouse wheel over the table to change the row height (images grow with it).','Đặt lại độ rộng cột':'Reset column widths','Kéo mép tiêu đề cột để chỉnh độ rộng.':'Drag the edge of a column header to resize it.','Độ rộng cột phải là số từ 20 đến 2000.':'Column width must be a number from 20 to 2000.','Loại trừ tag':'Exclude tags','Chọn các tag không tính vào Rộng / Dài / Cao':'Pick the tags that are not counted in Width / Length / Height','Tìm tag...':'Find tag...','Tìm tag':'Find tag','Ẩn danh sách tag':'Hide tag list','Chọn tất cả tag':'Select all tags','Phần nằm trên tag được tick không tính vào Rộng / Dài / Cao của Bảng khối lượng.':'Parts on a ticked tag are not counted in Width / Length / Height of the quantity table.','(không có trong model)':'(not in this model)','Không có tag nào khớp.':'No tag matches.','Không có tag nào trong model.':'There are no tags in this model.','Danh sách tag loại trừ không hợp lệ.':'Invalid list of excluded tags.','Tối đa 300 tag loại trừ, mỗi tên không quá 100 ký tự.':'At most 300 excluded tags, each name at most 100 characters.','Số đo thân':'Body size','Ghi chú số đo':'Measurement note','Bỏ khỏi Rộng / Dài / Cao các phần có tên hoặc tag chứa từ khóa (xem cột Ghi chú số đo).':'Leaves out of Width / Length / Height the parts whose name or tag contains a keyword (see the Measurement note column).','Từ khóa loại trừ khỏi số đo':'Keywords left out of measurements','Group, component hoặc tag có tên chứa một trong các từ này (cách nhau dấu phẩy, không phân biệt hoa thường và dấu) không được tính vào Rộng / Dài / Cao.':'Groups, components or tags whose name contains one of these words (separated by commas, case and accent insensitive) are not counted in Width / Length / Height.','Danh sách từ khóa tối đa 200 ký tự.':'The keyword list is at most 200 characters.','Tối đa 12 từ khóa, mỗi từ không quá 40 ký tự.':'At most 12 keywords, each at most 40 characters.','Sửa trục theo mặt trước':'Fix axes by front','Xem trước sửa trục':'Preview axis fix','Áp dụng sửa trục':'Apply axis fix','Xoay nội dung của món (bội của 90°) để mặt trước thành hướng -Y và bù cho mọi bản sao, nên hình trong model không đổi chỗ. Đây là thay đổi hình học; Ctrl+Z hoàn tác một lần. Chỉ áp dụng cho các dòng đang chọn.':'Rotates the contents of the item (in multiples of 90°) so the front becomes the -Y direction, and compensates every copy, so the geometry in the model does not move. This changes geometry; Ctrl+Z undoes it in one step. Applies only to the selected rows.','Không có món nào cần sửa trục.':'No item needs an axis fix.','chưa có mặt trước':'no front set','là ảnh':'is an image','không có hình bên trong':'has no geometry inside','không có bản sao nào trong model':'has no copies in the model','có bản sao bị khóa':'a copy is locked','có bản sao bị lật gương':'a copy is mirrored','nằm trong đối tượng bị khóa':'is inside a locked object','Hãy chọn các món cần sửa trục trong bảng.':'Select the items to fix in the table.','Không có món nào cần sửa trục. Bấm Xem trước để biết lý do.':'No item needs an axis fix. Click Preview to see why.','Cách đặt mặt trước không hợp lệ.':'Invalid way to set the front.','Hướng mặt trước không hợp lệ.':'Invalid front direction.','Đối tượng đang bị khóa nên không đặt được mặt trước.':'The objects are locked, so the front cannot be set.','Đối tượng đang bị khóa nên không xóa được mặt trước.':'The objects are locked, so the front cannot be cleared.','Các bản sao của cùng một component đang cho hướng khác nhau. Hãy chọn từng bản sao.':'Copies of the same component give different directions. Select the copies one by one.','Không xác định được hướng nhìn ngang của camera. Hãy xoay camera nhìn vào mặt trước của món (không nhìn thẳng từ trên xuống).':'Could not determine the camera horizontal direction. Orbit the camera to look at the front of the item (not straight down).','Chưa có mặt trước để xoay / đảo. Hãy phát hiện hoặc đặt tay trước.':'There is no front to rotate or reverse yet. Detect or set it by hand first.','Chưa có đối tượng nào trong bảng.':'There are no objects in the table.','ở góc tường (hai mặt kề sát tường)':'in a wall corner (two adjacent sides against walls)','kẹp giữa hai tường, không dùng được bằng chứng tường':'between two walls, wall evidence is not usable','mặt có nhiều chi tiết nhất':'side with the most detail','chưa đủ bằng chứng, cần duyệt':'not enough evidence, needs review','món không đứng thẳng (trục Z không hướng lên)':'item is not upright (Z axis does not point up)','món bị lật gương':'item is mirrored','component động':'dynamic component','món lệch góc so với trục, mặt trước chỉ gần đúng':'item is rotated off its axes, the front is only approximate','các bản sao cho kết quả khác nhau: cần duyệt':'copies gave different results: needs review','Mặt trước':'Front','Bảng tên trên model':'Name label in the model','món chưa có mặt trước nên chụp theo trục thế giới':'item has no front set, so it was shot along the world axes','Độ tin cậy mặt trước':'Front confidence','Mặt trước (độ tin cậy)':'Front (confidence)','(Chưa có mặt trước)':'(No front set)','Thủ công':'Manual','Tự động · cao':'Auto · high','Tự động · trung bình':'Auto · medium','Cần duyệt':'Needs review','Phát hiện tự động':'Detect automatically','Theo hướng nhìn hiện tại':'Use current view direction','Xoay 90°':'Rotate 90°','Đảo chiều':'Reverse','Xóa mặt trước':'Clear front','Ghi đè cả món đã đặt tay':'Also overwrite manually set items','Hãy chọn đối tượng trong bảng trước.':'Select objects in the table first.','Mặt trước là hướng ra của món theo trục riêng của nó. Khi chọn món, mũi tên trong SketchUp chỉ hướng này.':'The front is the direction the item faces, along its own axes. When an item is selected, an arrow in SketchUp shows this direction.','Xoay camera nhìn thẳng vào mặt trước của món rồi bấm nút này':'Orbit the camera to look straight at the front of the item, then click this button','Món tin cậy "Cần duyệt" nên được xem lại: chọn dòng, nhìn mũi tên trong SketchUp, đúng thì giữ, sai thì xoay hoặc đảo.':'Items marked "Needs review" should be checked: select the row, look at the arrow in SketchUp, keep it if right, rotate or reverse it if wrong.','Định dạng xuất không hợp lệ.':'Invalid export format.','Dữ liệu bảng không hợp lệ.':'Invalid table data.','Bảng chưa có dòng nào. Hãy chọn group hoặc component trong SketchUp.':'The table has no rows yet. Select groups or components in SketchUp.','Số lẻ không hợp lệ.':'Invalid number of decimals.','Sắp có':'Coming soon','Xuất Excel':'Export Excel','In PDF':'Print PDF','Mô hình':'Model','Ngày':'Date','In / Lưu PDF':'Print / Save PDF','Nhập preset (JSON)':'Import presets (JSON)','Xuất preset (JSON)':'Export presets (JSON)',
    'Diện tích chiếu bằng m²':'Projected area m²','Loại IFC':'IFC type','Xuất xứ':'Origin','Liên kết':'Link','Quy cách':'Specification','Đơn giá':'Unit price','Thành tiền':'Total',
    'Bảng quá lớn để xuất.':'The table is too large to export.','Dữ liệu bảng không hợp lệ.':'Invalid table data.',
    'Link không hợp lệ.':'Invalid link.','Tệp preset không đúng định dạng.':'The preset file is not in a valid format.','Phiên bản tệp preset chưa được hỗ trợ.':'This preset file version is not supported.','Tệp không có preset hợp lệ nào.':'The file has no valid presets.',
    'File preset quá lớn.':'The preset file is too large.','File không phải JSON hợp lệ.':'The file is not valid JSON.','Thiết lập của preset không hợp lệ.':'Invalid preset settings.',
    'Đơn vị diện tích không hợp lệ.':'Invalid area unit.','Đơn vị thể tích không hợp lệ.':'Invalid volume unit.','Dấu thập phân không hợp lệ.':'Invalid decimal separator.','Tiền tệ không hợp lệ.':'Invalid currency.',
    'Góc nhìn của ảnh không hợp lệ.':'Invalid image view.','Kiểu hiển thị của ảnh không hợp lệ.':'Invalid image style.','Tiêu đề cột không hợp lệ.':'Invalid column header.','Tiêu đề cột phải là chữ.':'The column header must be text.',
    'Chưa có preset tự tạo để xuất. Bấm + trong bảng preset để lưu một preset.':'There are no custom presets to export. Press + in the preset panel to save one.',
    'Hãy chọn cột cần thay: chỉ có Tên, Mô tả, Xuất xứ, Quy cách.':'Choose the columns to replace in: only Name, Description, Origin and Specification.','Không có ô nào chứa chữ cần tìm.':'No cell contains the searched text.','Hãy nhập chữ cần tìm.':'Enter the text to search for.'
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
  rule(/^Chụp ảnh cho tất cả (\d+) đối tượng đang hiện\?$/,(m,n)=>`Take photos of all ${plural(n,'visible object','visible objects')}?`);
  rule(/^Chụp ảnh cho (\d+) đối tượng đang chọn\?$/,(m,n)=>`Take photos of the ${plural(n,'selected object','selected objects')}?`);
  rule(/^Cỡ (\d+) x (\d+), (.+)\. Đổi trong bảng preset\.$/,(m,w,h,v)=>`Size ${w} x ${h}, ${T(v)}. Change it in the preset panel.`);
  rule(/^Thay thế \((\d+)\)$/,(m,n)=>`Replace (${n})`);
  rule(/^Đã thay chữ trong (\d+) ô của (\d+) đối tượng\.(.*)$/,(m,c,n,rest)=>`Replaced text in ${plural(c,'cell','cells')} of ${plural(n,'object','objects')}.${rest.replace(SKIPPED,' Skipped $1 locked.')}`);
  rule(/^Đã nhập (\d+) preset\.$/,(m,n)=>`Imported ${plural(n,'preset','presets')}.`);
  rule(/^Đã xuất (\d+) preset: (.*)$/,(m,n,p)=>`Exported ${plural(n,'preset','presets')}: ${p}`);
  rule(/^Quá nhiều preset \(tối đa (\d+)\)\.$/,(m,n)=>`Too many presets (${n} maximum).`);
  rule(/^Tiêu đề cột tối đa (\d+) ký tự\.$/,(m,n)=>`A column header is at most ${n} characters.`);
  rule(/^Số chữ số lẻ phải từ (\d+) đến (\d+)\.$/,(m,a,b)=>`Decimals must be from ${a} to ${b}.`);
  rule(/^Cỡ tối đa (\d+) ký tự\.$/,(m,n)=>`Size is at most ${n} characters.`);
  rule(/^Chữ cần tìm hoặc chữ thay thế quá dài \(tối đa (\d+) ký tự\)\.$/,(m,n)=>`The search or replacement text is too long (${n} characters maximum).`);
  rule(/^Link phải bắt đầu bằng http:\/\/ hoặc https:\/\/, không có khoảng trắng, tối đa (\d+) ký tự\.$/,(m,n)=>`A link must start with http:// or https://, contain no spaces, and be at most ${n} characters.`);
  rule(/^Đơn giá phải là số không âm, ví dụ 1250000 hoặc 12,5 \(không dùng dấu chấm ngăn cách hàng nghìn\)\.$/,()=>'The unit price must be a non-negative number, for example 1250000 or 12,5 (no thousands separator).');
  rule(/^(.*?)( Lưu ý: (.+)\.)$/,(m,head,note,list)=>`${translateText(head)} Note: ${list.split('; ').map(T).join('; ')}.`);
  rule(/^Không ghi được vào thư mục ảnh (.+)\. Hãy chọn thư mục khác trong bảng Preset\.$/,(m,d)=>`Cannot write to the image folder ${d}. Choose another folder in the Preset panel.`);
  rule(/^SketchUp không chụp được ảnh \(đã thử (\d+) cách\)\. File: (.+), cỡ (\d+) x (\d+)\. Kiểm tra thư mục lưu ảnh và quyền ghi\.$/,(m,n,f,w,h)=>`SketchUp could not take the photo (tried ${n} ways). File: ${f}, size ${w} x ${h}. Check the image folder and write permission.`);
  rule(/^lỗi (\w+): (.+) \(chi tiết trong capture\.log\)$/,(m,c,msg)=>`error ${c}: ${msg} (details in capture.log)`);
  rule(/^Phân loại: (.*)$/,(m,n)=>`Classify: ${T(n)}`);
  rule(/^(.*) \((vật liệu|đối tượng)\)$/,(m,n,k)=>`${T(n)} (${k==='vật liệu'?'material':'object'})`);
  rule(/^Đã chọn (\d+) \/ (\d+) dòng$/,(m,a,b)=>`Selected ${a} / ${b} rows`);
  rule(/^Nhóm theo: (.*) ▾$/,(m,g)=>`Group by: ${T(g)} ▾`);
  rule(/^(.+) ▾$/,(m,g)=>lookup(g)===undefined?m:`${T(g)} ▾`);
  rule(/^Cập nhật (.+)$/,(m,f)=>`Update ${f}`);
  rule(/^Tổng cộng · (\d+) đối tượng$/,(m,n)=>`Total · ${plural(n,'object','objects')}`);
  rule(/^(.*) · (\d+)$/,(m,label,n)=>lookup(label)===undefined?m:`${T(label)} · ${n}`);
  rule(/^Sẽ đổi (\d+) · giữ nguyên (\d+) · bị khóa (\d+)(.*)$/,(m,a,b,c,rest)=>`Will change ${a} · unchanged ${b} · locked ${c}${rest.replace(/ · tên trống (\d+)/,' · empty name $1').replace(/ · quá dài (\d+)/,' · too long $1').replace(/ · trùng tên (\d+)/,' · duplicate name $1')}`);
  rule(/^(Sẽ đổi|Giữ nguyên|Bị khóa|Tên trống|Quá dài)( · trùng)?$/,(m,s,d)=>T(s)+(d?' · duplicate':''));
  rule(/^Chỉ hiện 200 dòng đầu trong (\d+) dòng\.$/,(m,n)=>`Showing only the first 200 of ${n} rows.`);
  rule(/^Áp dụng cho (\d+) dòng đang chọn trong bảng(\..*)$/,(m,n,rest)=>`Applies to ${plural(n,'selected row','selected rows')} in the table${T(rest)}`);
  rule(/^Áp dụng cho mọi (\d+) dòng trong bảng \(chưa chọn dòng nào\)(\..*)$/,(m,n,rest)=>`Applies to all ${n} rows in the table (no row selected)${T(rest)}`);
  rule(/^Đang quét… ([\d.,]+) đối tượng hình học\.$/,(m,n)=>`Scanning… ${n} geometry objects.`);
  rule(/^Tạo tag "(.*)"$/,(m,n)=>`Create tag "${n}"`);
  rule(/^Đã quét ([\d.,]+) đối tượng và ([\d.,]+) mặt hình học\. Chọn báo cáo, rồi chọn nơi lưu file\. Tiêu đề và hạng mục xuất bằng tiếng Việt\.$/,(m,a,b)=>`Scanned ${a} objects and ${b} geometry faces. Choose a report, then choose where to save the file. Headings and items are exported in Vietnamese.`);
  rule(/^Xuất CSV · (.*)$/,(m,n)=>`Export CSV · ${T(n)}`);
  rule(/^Sẽ ghi dữ liệu cho (\d+) đối tượng \((\d+) lần xuất hiện\)\. Bỏ qua (\d+) lần xuất hiện\.$/,(m,a,b,c)=>`Will write data for ${a} objects (${b} occurrences). Skipping ${c} occurrences.`);
  rule(/^Đang dùng: (.*?)( \(chưa có, sẽ được tạo khi chụp ảnh đầu tiên\))?$/,(m,dir,note)=>`In use: ${dir}${note?' '+T(note.trim()):''}`);
  rule(/^Đang chụp (\d+)\/(\d+)…$/,(m,a,b)=>`Taking photo ${a}/${b}…`);
  rule(/^Đang chụp ảnh (\d+)\/(\d+)…$/,(m,a,b)=>`Taking photos ${a}/${b}…`);
  // Danh sách lỗi sau kết quả chụp: "<tên>: <nội dung>" cách nhau bằng " | "; nội dung được dịch từng mục.
  const errorsTail=rest=>rest.startsWith(' Lỗi: ')?' Errors: '+rest.slice(6).split(' | ').map(item=>item.replace(/^(.+?): (.+)$/,(x,n,msg)=>`${n}: ${translateText(msg)}`)).join(' | '):rest;
  rule(/^Đã dừng: chụp được (\d+)\/(\d+) ảnh\.(.*)$/,(m,a,b,rest)=>`Stopped: ${a}/${b} photos taken.${errorsTail(rest)}`);
  rule(/^Đã chụp (\d+)\/(\d+) ảnh\.(.*)$/,(m,a,b,rest)=>`Took ${a}/${b} photos.${errorsTail(rest)}`);
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
  rule(/^Đã xuất (\d+) dòng(?: và (\d+) ảnh)? ra Excel: (.*)$/,(m,n,i,p)=>`Exported ${plural(n,'row','rows')}${i?` and ${plural(i,'image','images')}`:''} to Excel: ${p}`);
  rule(/^Đã tạo trang báo cáo (\d+) dòng và mở trong trình duyệt\. Khi cần in, bấm nút In \/ Lưu PDF trên trang rồi chọn Lưu thành PDF\.$/,(m,n)=>`Created a report page with ${plural(n,'row','rows')} and opened it in the browser. When you want to print, click the Print / Save PDF button on the page, then choose Save as PDF.`);
  rule(/^Đã xuất quy tắc: (.*)$/,(m,p)=>`Exported rules: ${p}`);
  rule(/^Áp dụng cho (\d+) đối tượng đang chọn\.$/,(m,n)=>`Applies to the ${plural(n,'selected object','selected objects')}.`);
  rule(/^Chưa chọn dòng nào: phát hiện tự động cho tất cả (\d+) đối tượng đang hiện\.$/,(m,n)=>`No row selected: detect automatically for all ${plural(n,'visible object','visible objects')}.`);
  rule(/^Mỗi lần phát hiện tối đa (\d+) đối tượng\. Hãy chọn ít hơn\.$/,(m,n)=>`Detect at most ${n} objects at a time. Select fewer.`);
  const frontTail=tail=>tail
    .replace(/ Chưa xác định được (\d+) loại \(cần đặt tay\)\./,(x,n)=>` Could not determine ${plural(n,'type','types')} (set by hand).`)
    .replace(/ Bỏ qua (\d+) đối tượng đã đặt tay\./,(x,n)=>` Skipped ${plural(n,'object','objects')} set by hand.`)
    .replace(/ Bỏ qua (\d+) đối tượng bị khóa\./,(x,n)=>` Skipped ${plural(n,'locked object','locked objects')}.`)
    .replace(/ Bỏ qua (\d+) đối tượng chưa có mặt trước\./,(x,n)=>` Skipped ${plural(n,'object','objects')} without a front.`)
    .replace(/ \((\d+) đối tượng được xem xét\)/,(x,n)=>` (${plural(n,'object','objects')} examined)`);
  rule(/^Đã xác định mặt trước cho (\d+) loại: tin cậy cao (\d+), trung bình (\d+), cần duyệt (\d+)\.(.*)$/,(m,n,a,b,c,tail)=>`Front found for ${plural(n,'type','types')}: high confidence ${a}, medium ${b}, needs review ${c}.${frontTail(tail)}`);
  rule(/^Đã đặt mặt trước cho (\d+) loại \(thủ công\)\.(.*)$/,(m,n,tail)=>`Front set for ${plural(n,'type','types')} (manual).${frontTail(tail)}`);
  rule(/^Đã xóa mặt trước của (\d+) loại\.$/,(m,n)=>`Cleared the front of ${plural(n,'type','types')}.`);
  rule(/^Sẽ sửa trục (\d+) loại \((\d+) bản sao\)\.$/,(m,n,k)=>`Will fix the axes of ${plural(n,'type','types')} (${plural(k,'copy','copies')}).`);
  rule(/^Gồm: (.*)$/,(m,names)=>`Includes: ${names}`);
  rule(/^Đã có mặt trước -Y: (\d+) loại\.$/,(m,n)=>`Front is already -Y: ${plural(n,'type','types')}.`);
  rule(/^Bỏ qua (\d+) loại: (.*)\.$/,(m,n,reason)=>`Skipped ${plural(n,'type','types')}: ${translateText(reason)}.`);
  rule(/^Đã sửa trục cho (\d+) loại \((\d+) bản sao\): mặt trước giờ là -Y, hình trong model không đổi chỗ\.( Bỏ qua (\d+) loại\.)?$/,(m,n,k,x,s)=>`Fixed the axes of ${plural(n,'type','types')} (${plural(k,'copy','copies')}): the front is now -Y and the geometry in the model did not move.${s?` Skipped ${plural(s,'type','types')}.`:''}`);
  rule(/^Mỗi lần sửa trục tối đa (\d+) đối tượng\. Hãy chọn ít hơn\.$/,(m,n)=>`Fix at most ${n} objects at a time. Select fewer.`);
  rule(/^Bỏ (\d+) phần theo từ khóa hoặc tag \((.*)\)$/,(m,n,names)=>`Left out ${plural(n,'part','parts')} by keyword or tag (${names})`);
  rule(/^Đã ẩn (\d+) đối tượng thuộc tag loại trừ\.$/,(m,n)=>`Hid ${plural(n,'object','objects')} on excluded tags.`);
  rule(/^Đã xuất (\d+) luật: (.*)$/,(m,n,p)=>`Exported ${plural(n,'rule','rules')}: ${p}`);
  rule(/^Đã nhập (\d+) luật từ file\. Bộ luật chưa lưu làm mặc định\.$/,(m,n)=>`Imported ${plural(n,'rule','rules')} from the file. The rules are not saved as the default yet.`);
  rule(/^Đã gắn tag tự động cho (\d+) đối tượng \((\d+) tag\)\.(.*)$/,(m,n,k,tail)=>`Auto-tagged ${plural(n,'object','objects')} (${plural(k,'tag','tags')}).${tail
    .replace(/ Đã đúng tag sẵn: (\d+)\./,' Already correct: $1.').replace(/ Giữ nguyên (\d+) đối tượng đã có tag khác\./,' Kept $1 objects that already have another tag.')
    .replace(/ Bỏ qua (\d+) đối tượng bị khóa\./,' Skipped $1 locked.').replace(/ Tag đang tắt hiển thị nên đối tượng gắn vào sẽ bị ẩn: (.*)\./,' The tag is hidden, so the tagged objects will be hidden: $1.')}`);
  rule(/^Quá nhiều đối tượng \(tối đa (\d+)\)\. Hãy chọn ít hơn\.$/,(m,n)=>`Too many objects (${n} at most). Select fewer.`);
  rule(/^Tên thư mục quá dài \(tối đa (\d+) ký tự\): (.*)$/,(m,n,t)=>`Folder name too long (${n} characters maximum): ${t}`);
  rule(/^Đã xếp (\d+) tag vào (\d+) thư mục \((\d+) thư mục mới tạo\)\.(.*)$/,(m,n,k,c,tail)=>`Placed ${plural(n,'tag','tags')} into ${plural(k,'folder','folders')} (${plural(c,'new folder','new folders')} created).${tail
    .replace(/ Đã đúng thư mục sẵn: (\d+)\./,' Already in place: $1.').replace(/ Giữ nguyên (\d+) tag đã nằm trong thư mục khác\./,' Kept $1 tags that are already in another folder.')}`);
  rule(/^Tối đa (\d+) luật\.$/,(m,n)=>`At most ${n} rules.`);
  rule(/^Từ khóa phải có ít nhất (\d+) ký tự\.$/,(m,n)=>`A keyword needs at least ${n} characters.`);
  rule(/^Mỗi luật tối đa (\d+) từ khóa, mỗi từ khóa không quá (\d+) ký tự\.$/,(m,a,b)=>`Each rule allows at most ${a} keywords of ${b} characters.`);
  rule(/^(\d+) đối tượng( · .*)?$/,(m,n,rest)=>`${plural(n,'object','objects')}${rest||''}`);
  rule(/^Nhập (\d+) cụm \((\d+) tag\)$/,(m,a,b)=>`Import ${plural(a,'cluster','clusters')} (${plural(b,'tag','tags')})`);
  rule(/^Đã chuyển tag "(.*)" (vào thư mục "(.*)"|ra ngoài thư mục)\.$/,(m,name,where,folder)=>`Moved tag "${name}" ${folder?`into folder "${folder}"`:'out of its folder'}.`);
  rule(/^Đã lấy tag "(.*)"\. Chọn đối tượng rồi bấm Gán tag để gán\.$/,(m,name)=>`Picked up tag "${name}". Select objects and click Assign tag to assign it.`);
  rule(/^: (\d+) đối tượng đang dùng tag này$/,(m,n)=>`: ${plural(n,'object uses','objects use')} this tag`);
  rule(/^Đã xóa tag "([^"]*)"\.( Đã chuyển (\d+) đối tượng sang tag "([^"]*)"\.)?( Các đối tượng đang dùng tag này đã về Untagged\.)?$/,(m,name,moved,n,target,back)=>`Deleted tag "${name}".${moved?` Moved ${plural(n,'object','objects')} to tag "${target}".`:''}${back?' The objects that used this tag are now Untagged.':''}`);
  rule(/^Nhập (\d+) tag$/,(m,n)=>`Import ${plural(n,'tag','tags')}`);
  rule(/^File Excel có quá nhiều dòng \(tối đa (\d+)\)\.$/,(m,n)=>`The Excel file has too many rows (${n} at most).`);
  rule(/^Quá nhiều tag \(tối đa (\d+)\)\.$/,(m,n)=>`Too many tags (${n} at most).`);
  rule(/^Tên tag không hợp lệ: (.*)$/,(m,t)=>`The tag name is not valid: ${t}`);
  rule(/^Màu của tag "(.*)" không hợp lệ\.$/,(m,t)=>`The color of tag "${t}" is not valid.`);
  rule(/^Kiểu nét của tag "(.*)" không hợp lệ\.$/,(m,t)=>`The line style of tag "${t}" is not valid.`);
  rule(/^Tên thư mục của tag "(.*)" không hợp lệ\.$/,(m,t)=>`The folder name of tag "${t}" is not valid.`);
  rule(/^thiếu tên tag, bỏ qua\.$/,()=>'missing tag name, skipped.');
  rule(/^tên tag quá dài \(tối đa (\d+) ký tự\), bỏ qua\.$/,(m,n)=>`tag name too long (${n} characters at most), skipped.`);
  rule(/^Untagged là tag mặc định của SketchUp, bỏ qua\.$/,()=>'Untagged is SketchUp\'s default tag, skipped.');
  rule(/^tag "(.*)" bị trùng, bỏ qua\.$/,(m,t)=>`tag "${t}" is duplicated, skipped.`);
  rule(/^màu "(.*)" không đọc được, bỏ qua màu\.$/,(m,t)=>`color "${t}" cannot be read, color skipped.`);
  rule(/^tên thư mục không hợp lệ, bỏ thư mục\.$/,()=>'invalid folder name, folder skipped.');
  rule(/^… và (\d+) cảnh báo khác$/,(m,n)=>`… and ${plural(n,'more warning','more warnings')}`);
  rule(/^(\d+) dòng · (\d+) đã có trong model$/,(m,a,b)=>`${plural(a,'row','rows')} · ${b} already in the model`);
  rule(/^Đã nhập (\d+) tag từ Excel \((\d+) mới tạo, (\d+) cập nhật\)\.( Bỏ qua (\d+) tag đã có trong model\.)?( Đã tạo (\d+) thư mục tag\.)?( Kiểu nét không nhận ra, đã bỏ qua: (.*)\.)?$/,(m,n,c,u,sk,skn,fo,fn,st,names)=>`Imported ${plural(n,'tag','tags')} from Excel (${c} new, ${u} updated).${sk?` Skipped ${skn} tags that already exist in the model.`:''}${fo?` Created ${plural(fn,'tag folder','tag folders')}.`:''}${st?` Line styles not recognized and skipped: ${names}.`:''}`);
  rule(/^Đang cô lập: (.*)$/,(m,name)=>`Isolated: ${name}`);
  rule(/^Đã cô lập (tag|thư mục) "(.*)" \(ẩn (\d+) tag khác\)\. Bấm lại để khôi phục hiển thị\.$/,(m,kind,name,n)=>`Isolated ${kind==='tag'?'tag':'folder'} "${name}" (${plural(n,'other tag','other tags')} hidden). Click again to restore visibility.`);
  rule(/^(\d+) luật$/,(m,n)=>plural(n,'rule','rules'));
  rule(/^(\d+) \/ (\d+) tag$/,(m,a,b)=>`${a} / ${plural(b,'tag','tags')}`);
  rule(/^(\d+) tag( · .*)?$/,(m,n,rest)=>`${plural(n,'tag','tags')}${rest||''}`);
  rule(/^Đã nhập (\d+) tag từ (\d+) cụm vào bộ tag \((\d+) tag mới tạo trong model\)\.$/,(m,n,k,c)=>`Imported ${plural(n,'tag','tags')} from ${plural(k,'cluster','clusters')} into the tag set (${plural(c,'new tag','new tags')} created in the model).`);
  rule(/^Cụm không hợp lệ: (.*)$/,(m,g)=>`Invalid cluster: ${g}`);
  rule(/^hiện trong bảng: (.*)$/,(m,p)=>`shown in the table as: ${p}`);
  rule(/^Loại trừ tag \((\d+)\)$/,(m,n)=>`Exclude tags (${n})`);
  rule(/^(.+) \(không có trong model\)$/,(m,name)=>`${name} (not in this model)`);
  rule(/^sát tường phía ([+-][xy])$/,(m,d)=>`against a wall on the ${d} side`);
  rule(/^tường chỉ ([+-][xy]) nhưng chi tiết hình học chỉ ([+-][xy]): cần duyệt$/,(m,a,b)=>`wall evidence says ${a} but geometry detail says ${b}: needs review`);
  rule(/^chỉ đọc (\d+) mặt đầu tiên của món \(lấy mẫu\)$/,(m,n)=>`only the first ${n} faces were read (sampled)`);
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

  // Mẫu chung "<chữ có trong từ điển>: <giá trị>" (nhãn trợ năng kèm tên preset...): đặt sau các mẫu cụ thể.
  rule(/^(.+): (.+)$/,(m,a,b)=>lookup(a)===undefined?m:`${T(a)}: ${T(b)}`);
  rule(/^(.+) \/ (.+)$/,(m,a,b)=>`${translateText(a)} / ${translateText(b)}`);

  rule(/^(.+?); (.+)$/,(m,a,b)=>`${translateText(a)}; ${translateText(b)}`); // ghi chú mặt trước ghép bằng "; "
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
