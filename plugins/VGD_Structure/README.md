# VGD Structure 0.4.0-beta.1

Plugin SketchUp dựng **phần thô** (cột, dầm, tường, sàn, trần) theo **lưới trục** và **tầng**, nối với VGD BIM để tính khối lượng. Kế hoạch: `docs/vgd_structure/PLAN.md`. Đặc tả dữ liệu: `docs/vgd_structure/SPEC.md`.

## Trạng thái

**Cột mốc 3: dầm** (trên nền lưới trục, tầng và cột). Chưa dựng tường, sàn, trần (các cột mốc sau, xem kế hoạch).

**Lưới trục** (menu Extensions → VGD → VGD Structure → Lưới trục, hoặc nút trên thanh công cụ VGD STR):
- Nhập **trục đứng** (đánh số 1, 2, 3...) và **trục ngang** (đánh chữ A, B, C...; bỏ I và O) với khoảng cách giữa các trục, từng trục sửa được tên và nhịp. Gõ nhanh "4200, 3600*2" rồi bấm Tạo trục từ nhịp (dấu phẩy hoặc khoảng trắng ngăn cách, số lẻ dùng dấu chấm, `*` hoặc `x` là lặp). 2 đến 60 trục mỗi phương, tên tối đa 4 ký tự, nhịp tối thiểu 100 mm.
- Xem trước mặt bằng và tóm tắt (số giao điểm, nhịp, ô, khung lưới) do Ruby tính.
- **Vẽ lưới trục**: một nhóm "Lưới trục" trên tag **!grid** (tên và màu tím theo bộ tag mẫu của VGD BIM; nét gạch dài - chấm được đặt cho tag khi tag còn nét liền, cần SketchUp 2021 trở lên và model có kiểu nét gạch chấm). Mỗi trục là đường kéo dài quá trục biên, ký hiệu trục là vòng tròn 10 mm trên giấy theo **tỉ lệ bản vẽ** (1:100 = vòng 1000 mm) có tên trục ở giữa: ở đầu dưới trục đứng và đầu trái trục ngang, tùy chọn cả hai đầu. Một bước hoàn tác; vẽ lại thì thay nhóm cũ (nhóm cũ bị khóa thì báo, không đụng).
- **Xóa lưới khỏi model** (có hỏi xác nhận); dữ liệu lưới vẫn giữ trong model để vẽ lại.
- Dữ liệu lưới lưu trong model (dictionary `VGD_STRUCT`), mở lại cửa sổ là nạp lại.

**Tầng và loại cột** (tab "Tầng và loại cột"):
- **Loại cột** dùng lại (ví dụ C30x30, C40x60): tên, rộng theo X, sâu theo Y (100 đến 3000 mm); bản đầu chỉ có cột chữ nhật.
- **Tầng** (mỗi tầng riêng): tên, **cao độ mặt sàn** (mm tuyệt đối theo trục Z của model), dày sàn, loại cột mặc định. Cột tầng này chạy từ mặt sàn lên **đáy sàn tầng kế trên**; ô ghi chú hiện chiều cao cột. **Tầng trên cùng** (đỉnh nhà, mái) chỉ có sàn, không có cột. Tầng sau phải cao hơn tầng dưới ít nhất 500 mm.

**Cột** (tab "Cột"): chọn tầng, bấm các giao điểm trên mặt bằng để chọn cột (hoặc **Chọn mọi giao điểm**). Quy ước vị trí (đã chốt): cột giữa tâm đúng giao điểm; cột biên có mặt ngoài tiếp giáp trục biên; cột góc tiếp giáp hai trục biên, nên cột luôn lọt trong khung lưới. Bấm một cột đã chọn để đổi **loại cột** riêng và **vị trí theo X / Y** (theo quy ước, tâm trên trục, hoặc một cạnh tại trục). Cột đặt tâm trên trục biên (nhô ra ngoài) hoặc chồng nhau được cảnh báo. **Sao chép lựa chọn từ tầng khác** (thay lựa chọn cột của tầng đích; vẫn sửa riêng được). **Dựng cột tầng này / mọi tầng**: mỗi tầng một nhóm "Cột - <tên tầng>" trên tag **S. COLUMN** (theo bộ tag mẫu của VGD BIM: tên, màu, thư mục S. STRUCTURAL), mỗi cột là một ComponentInstance dùng chung định nghĩa theo rộng × sâu × cao, mang dữ liệu để VGD BIM đọc (nguồn plugin, loại, kích thước, tầng). Một bước hoàn tác; dựng lại thì thay nhóm cũ; dựng hơn 500 cột thì hỏi xác nhận, tối đa 5000. Xóa tầng khỏi danh sách rồi dựng lại thì nhóm cột của tầng đó được dọn (nhóm bị khóa thì giữ). **Xóa cột tầng này** có sẵn.

**Dầm** (tab "Dầm"; loại dầm trong tab "Tầng và loại cột": tên, rộng 100 đến 1500, cao 100 đến 2000 mm; mỗi tầng có loại dầm mặc định):
- Chọn tầng, bấm các **nhịp** (đoạn trục giữa hai giao điểm) trên mặt bằng để chọn dầm; có **Chọn mọi nhịp**, **Chọn nhịp biên**, **Sao chép lựa chọn dầm từ tầng khác**. Bấm dầm đã chọn để đổi loại và vị trí ngang (theo quy ước, tâm trên trục, hoặc một cạnh tại trục).
- **Dầm treo dưới sàn tầng trên**: đỉnh dầm bằng đáy sàn (cùng cao độ đỉnh cột), cao `h` xuống dưới, nên không chồng sàn. Tầng trên cùng chỉ có sàn nên không có dầm.
- **Hai đầu dầm dừng ở mặt cột** (cột được chọn ở giao điểm đó, cùng tầng). Nút không có cột: dầm theo X chạy tới trục, dầm theo Y dừng ở mặt dầm X chạm nút đó (không chồng nhau); không có dầm X thì tới trục.
- Quy ước vị trí ngang: dầm trên trục biên có **mặt ngoài tiếp giáp trục biên** (tâm dời vào nửa bề rộng), dầm nhịp giữa tâm trên trục. Cảnh báo dầm nhô ra ngoài khung lưới, chồng nhau hoặc chồng cột; nhịp có khoảng hở nhỏ hơn 100 mm giữa hai cột thì bỏ và báo.
- **Dựng dầm tầng này / mọi tầng**: mỗi tầng một nhóm "Dầm - <tên tầng>" trên tag **S. BEAM** (theo bộ tag mẫu BIM), mỗi dầm là ComponentInstance dùng chung định nghĩa theo (phương, rộng, cao, dài), kèm dữ liệu cho VGD BIM. Một bước hoàn tác; dựng lại thay nhóm cũ; có xóa dầm; hỏi xác nhận khi dựng hơn 500 dầm, tối đa 8000.

Dữ liệu lưu trong model (dictionary `VGD_STRUCT`). VGD BIM chưa đọc cột mốc này (cột mốc 7): cột vẫn hiện trong bảng khối lượng như đối tượng thường.

Menu và thanh công cụ chỉ có hiệu lực sau khi mở lại SketchUp; **Tải lại code** nạp lại mã mà không cần mở lại (đóng và mở lại cửa sổ nếu đang mở).

## Cài đặt

Cài file `VGD_Structure_v0.4.0-beta.1.rbz` bằng Extension Manager của SketchUp (SketchUp 2022 trở lên), rồi mở lại SketchUp.

## Kiểm thử

- Tự động (mô phỏng, ngoài SketchUp): `ruby dev/run_tests.rb` từ `plugins/VGD_Structure`; kiểm tra cú pháp, menu và toolbar, Tải lại code, logic lưới trục và ký hiệu, vẽ lưới bằng SketchUp giả lập, cửa sổ. Giao diện: `node dev/test_ui.cjs` (Playwright; đặt `VGD_PLAYWRIGHT_MODULE` nếu cần).
- **Chưa xác minh trong SketchUp thật.**
