# VGD Structure 0.10.0-beta.2

Plugin SketchUp dựng **phần thô** (cột, dầm, tường, sàn, trần) theo **lưới trục** và **tầng**, nối với VGD BIM để tính khối lượng. Kế hoạch: `docs/vgd_structure/PLAN.md`. Đặc tả dữ liệu: `docs/vgd_structure/SPEC.md`.

## Trạng thái

**Cột mốc P1: tab Mặt bằng** (cửa sổ vẽ mặt bằng, giai đoạn 2, `docs/vgd_structure/PLAN.md` mục 12). Hiện mới **xem**, bố cục theo cửa sổ mặt bằng của VTBim: thanh trên (hoàn tác, Chọn và đo, Sửa, Hiển thị lớp, Vừa khung, ẩn / hiện Thuộc tính), **tab theo từng tầng**, cột công cụ bên trái chia nhóm (Thiết kế, Vẽ 2D, Ghi chú), bảng **Thuộc tính** (bấm một phần tử để xem loại, kích thước; chưa chọn thì hiện thông tin tầng), thanh trạng thái (gợi ý, tọa độ con trỏ mm, tỉ lệ, ô nhập số). Canvas vẽ lưới trục, sàn, trần (mặc định ẩn), dầm, tường, cửa (có cánh mở), cột. **Cuộn = thu phóng quanh con trỏ**, **chuột giữa hoặc H = kéo**, **F = vừa khung**, Space = công cụ Chọn, Esc bỏ chọn. Các công cụ vẽ kết cấu, vẽ 2D, ghi chú, sửa, hoàn tác và ô nhập số đã bố trí sẵn nhưng khóa, làm ở cột mốc P2 đến P5. Chưa sửa được dữ liệu từ mặt bằng.

**Cột mốc 8: cửa đi và cửa sổ** (trên nền lưới trục, tầng, cột, dầm, tường, sàn, trần, đề xuất, dựng tất cả và nối VGD BIM). Còn phải làm trước khi phát hành: tường nhiều lớp và nối góc, hoàn thiện, cầu thang, mái... (kế hoạch giai đoạn 2, `docs/vgd_structure/PLAN.md` mục 11).

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

**Tường** (tab "Tường"; loại tường trong tab "Tầng và loại cột": tên, bề dày 50 đến 1000 mm; mỗi tầng có loại tường mặc định). Bản đầu là tường đặc, **chưa khoét cửa**, chưa nối góc L / T, chưa có lớp cấu tạo:
- Chọn tầng, bấm các nhịp trên mặt bằng để chọn tường (như dầm): Chọn mọi nhịp, Chọn nhịp biên, sao chép lựa chọn tường từ tầng khác; bấm tường đã chọn để đổi loại và vị trí ngang.
- **Cao từ mặt sàn tầng này lên đáy dầm** của nhịp đó nếu nhịp có dầm được chọn cùng tầng (dầm thấp hơn thì tường thấp theo), không có dầm thì lên **đáy sàn tầng trên**. Nên tường, dầm, sàn không chồng nhau.
- Hai đầu tường dừng ở mặt cột; nút không có cột thì tường X chạy tới trục, tường Y dừng ở mặt tường X. Tường trên trục biên có mặt ngoài tiếp giáp trục biên, nhịp giữa tâm trên trục. Cảnh báo tường nhô ra ngoài khung lưới, chồng nhau hoặc chồng cột.
- **Dựng tường tầng này / mọi tầng**: mỗi tầng một nhóm "Tường - <tên tầng>" trên tag **A. WALL** (theo bộ tag mẫu BIM, thư mục A. ARCHITECTURAL), tường dùng chung định nghĩa theo (phương, dày, cao, dài), kèm dữ liệu cho VGD BIM (kể cả tường dưới dầm). Một bước hoàn tác; dựng lại thay nhóm cũ; có xóa tường; hỏi xác nhận khi dựng hơn 500 tường.
- Nếu sửa dầm của một nhịp sau khi đã dựng tường thì cần **dựng lại tường** để tường theo chiều cao mới.

**Cửa đi và cửa sổ** (tab "Cửa"; loại cửa trong tab "Tầng và loại cột": tên, kiểu cửa đi / cửa sổ, rộng 300 đến 5000, cao 300 đến 4000, cao ngưỡng 0 đến 3000 mm; mặc định D900x2100 và W1200x1200 cao ngưỡng 900):
- Chọn tầng, **bấm một tường** (tường đã chọn ở tab Tường) rồi **+ Cửa đi / + Cửa sổ**: cửa mới đặt ở giữa tường hoặc chỗ trống gần nhất (cách cửa khác ít nhất 50 mm). Mỗi cửa có loại, **vị trí tâm cách đầu tường** (mm), **đổi mặt** (cánh cửa đi ở mặt kia của tường) và nút xóa. Đầu tường là mặt cột hoặc trục ở đầu nhịp.
- Cửa phải nằm trọn trong chiều dài và chiều cao tường (tính cả cao ngưỡng, và tường dưới dầm thì thấp hơn) và không chồng cửa khác: cửa sai bị **bỏ và báo** (cửa còn lại vẫn dựng), không làm hỏng việc dựng.
- **Tường tự khoét lỗ cửa khi dựng tường** (mặt đứng có lỗ chữ nhật rồi đùn theo bề dày): **sau khi đặt, sửa hay xóa cửa phải dựng lại tường** (dựng tất cả làm cả hai). **Cửa** (khung và cánh) dựng ở tab Cửa: cửa đi có khung chữ U (khung 50 mm, không có ngưỡng) và cánh đặc 40 mm thụt 20 mm so với mặt tường; cửa sổ có khung vòng kín 50 mm và kính 6 mm giữa bề dày tường. Mỗi tầng một nhóm "Cửa - <tên tầng>", cửa đi trên tag **A. DOOR**, cửa sổ trên tag **A. WINDOW** (theo bộ tag mẫu BIM). Cũng có sao chép cửa từ tầng khác (cửa nhận mã mới), một bước hoàn tác, dựng lại thay nhóm cũ (giữ ID), xóa cửa. Đề xuất bán tự động chưa đặt cửa.
- VGD BIM (1.1.1-beta.7 trở lên): cửa đếm theo cái, **diện tích và thể tích tường đã trừ lỗ cửa**.

**Sàn** (tab "Sàn"; dày sàn nhập ở bảng tầng): bấm các **ô** (vùng giữa hai trục đứng và hai trục ngang liền nhau) để chọn sàn; Chọn mọi ô, Bỏ chọn hết, sao chép lựa chọn sàn từ tầng khác. Sàn phủ trọn ô (từ trục tới trục, kể cả phía trên cột và dầm tầng dưới), **mặt trên tại cao độ sàn của tầng, dày xuống dưới**; cột và dầm tầng dưới dừng ở đáy sàn nên không chồng khối. **Tầng trên cùng cũng có sàn** (sàn mái). Mỗi tầng một nhóm "Sàn - <tên tầng>" trên tag **S. SLAB**.

**Trần** (tab "Trần"; **cao trần** và **dày trần** nhập ở bảng tầng, mặc định 2800 và 9 mm): chọn ô như sàn. Trần là tấm mỏng, **mặt dưới ở cao độ sàn + cao trần**; **lùi tới mặt tường** ở cạnh ô có tường được chọn cùng tầng (cạnh không có tường tới trục), **khoét góc theo cột** (đa giác chữ L / U...) nên không chồng cột. Báo lỗi nếu mặt trên trần vượt đáy sàn tầng trên; cảnh báo trần chạm đáy dầm; ô bị tường hoặc cột chiếm hết thì bỏ và báo. Tầng trên cùng không có trần. Mỗi tầng một nhóm "Trần - <tên tầng>" trên tag **A. FINISHING CEILING** (thư mục A. ARCHITECTURAL).

Sàn và trần cũng: một bước hoàn tác, dựng lại thay nhóm cũ, có xóa, hỏi xác nhận khi dựng hơn 500 ô, dựng chung định nghĩa theo (đa giác, dày), dữ liệu cho VGD BIM (kind slab / ceiling, dày, diện tích). Chưa có lỗ mở trên sàn (cầu thang, giếng trời), chưa có dốc, chưa có sàn lệch cao độ riêng từng ô; trần phẳng, chưa có khung treo.

**Tổng hợp và dựng** (tab "Tổng hợp và dựng"):
- **Đề xuất bán tự động** cho một tầng hoặc mọi tầng: chọn sẵn **cột ở mọi giao điểm, dầm ở mọi nhịp, tường ở các nhịp biên, sàn và trần ở mọi ô**; tầng trên cùng chỉ đề xuất sàn. Chỉ **thêm phần còn thiếu**, không bao giờ đổi hay xóa lựa chọn bạn đã có (kể cả loại và vị trí riêng), nên bấm lại không thêm gì nữa. Sau đó xem lại ở từng tab (mặt bằng xem trước), bỏ bớt hoặc thêm rồi dựng. Xem trước trong model (overlay) chưa làm: mặt bằng trong cửa sổ là bản xem trước.
- **Bảng tổng hợp** số lựa chọn từng loại của mỗi tầng, kèm các loại đã dựng trong model.
- **Kiểm tra kết cấu** (chỉ đọc, không đổi model): gom lỗi (ví dụ cột cao dưới 300 mm, trần cao hơn đáy sàn tầng trên) và cảnh báo (nhô ra ngoài khung lưới, chồng khối, trần chạm dầm, **dầm có đầu không có cột để gối**, tầng trên cùng có lựa chọn sẽ bị bỏ qua) của mọi tầng. Kết quả cũ biến mất khi bạn sửa dữ liệu.
- **Dựng tất cả tầng đang chọn / mọi tầng**: cột, dầm, tường, sàn, trần trong **một bước hoàn tác duy nhất**. Kiểm tra và lập kế hoạch cho cả năm loại trước khi đụng model: có lỗi ở bất kỳ loại nào thì không dựng gì cả và báo loại nào bị lỗi; nhóm đang bị khóa cũng chặn từ đầu. Hỏi xác nhận khi dựng hơn 500 đối tượng, tối đa 20000 mỗi lần.

**Nối với VGD BIM** (cần VGD BIM 1.1.1-beta.6 trở lên cho các phần dưới; plugin vẫn chạy độc lập khi chưa cài BIM):
- **VGD ID:** phần tử mới dựng nhận VGD ID từ BIM qua cầu nối; **dựng lại giữ nguyên ID** của đúng phần tử (theo mã vị trí), phần tử bị bỏ thì mất ID. Chưa cài BIM thì để trống, BIM gán sau bằng nút Gán VGD ID.
- **Bảng khối lượng đúng:** mỗi phần tử ghi tên tầng, cao độ tầng, loại và kích thước chính xác để BIM lập bảng (thể tích cột, dầm, sàn; diện tích tường, trần), không đoán từ khối bao. Chọn các nhóm "Cột - Tầng 1", "Dầm - ..."... trong SketchUp rồi mở Bảng khối lượng của BIM: nhóm chứa và lưới trục không thành dòng, các phần tử bên trong là dòng.
- **Sửa từ BIM:** chọn một dòng trong Bảng khối lượng của BIM, **Công cụ → Sửa bằng plugin dựng hình**: VGD Structure mở đúng tab, tầng và phần tử đó (cần VGD BIM cài và dòng là phần tử do plugin dựng). Khi đã sửa dữ liệu thì dựng lại tại tab tương ứng (ID giữ nguyên).

Menu và thanh công cụ chỉ có hiệu lực sau khi mở lại SketchUp; **Tải lại code** nạp lại mã mà không cần mở lại (đóng và mở lại cửa sổ nếu đang mở).

## Cài đặt

Cài file `VGD_Structure_v0.10.0-beta.2.rbz` bằng Extension Manager của SketchUp (SketchUp 2022 trở lên), rồi mở lại SketchUp.

## Kiểm thử

- Tự động (mô phỏng, ngoài SketchUp): `ruby dev/run_tests.rb` từ `plugins/VGD_Structure`; kiểm tra cú pháp, menu và toolbar, Tải lại code, logic lưới trục và ký hiệu, vẽ lưới bằng SketchUp giả lập, cửa sổ. Giao diện: `node dev/test_ui.cjs` (Playwright; đặt `VGD_PLAYWRIGHT_MODULE` nếu cần).
- **Chưa xác minh trong SketchUp thật.**
