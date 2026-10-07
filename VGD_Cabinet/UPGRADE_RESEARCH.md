# VGD Cabinet 4.5 · Cánh và preview

Ngày đối chiếu: 2026-10-08. Nguồn dưới đây là tài liệu của nhà sản xuất và SketchUp; các kích thước trong plugin là cấu hình có thể sửa.

## Shaker và chia khung

[Rockler — Shaker 5 Piece Flat Panel Door](https://www.rockler.com/shaker-5-piece-flat-panel-door-custom-sizes-and-materials) mô tả cửa năm phần, cạnh vuông, tấm giữa phẳng lõm. Kích thước sản phẩm tham khảo là khung dày 3/4 inch, tấm 1/4 inch, bản khung 2-1/4 inch. VGD giữ bộ tham số mm chung với Pano (20/6/60) và thêm độ lõm 6 mm có thể sửa; đây là lựa chọn thiết kế, không phải quy chuẩn cho mọi cửa.

[Rockler — How to Make Shaker Cabinet Doors](https://www.rockler.com/learn/how-to-make-shaker-cabinet-doors) là tham khảo cho khung và rãnh giữ tấm phẳng. VGD dựng rãnh thẳng và tấm có phần ngậm trừ khe co giãn; không tự chọn khe theo loài gỗ hoặc độ ẩm. Xem thêm PANO_RESEARCH.md.

[WalzCraft — Mitered Cabinet Door Stile/Rail Profiles](https://walzcraft.com/wp-content/uploads/2011/07/E9-Mitered-Cabinet-Door-Stile-Rail-Profiles-MP600-Series-Web-3-4-15.pdf) và [C&C Mullions — Style 19](https://candcmullions.com/style-19-oversize-mullion-up-to-26-x-65/) là tham khảo về thanh chia và bố cục chéo trên cửa. Triển khai VGD chọn bốn kiểu dễ dùng: không chia, ngang, dọc, chéo X. Ngang/dọc 2–6 ô chia đều; kính tách ô riêng. Với Pano/Shaker, X là thanh đắp trên một tấm lõm, giao nhau được chia hình học để không chồng khối. Plugin chưa dựng mộng góc hoặc rãnh xiên cho các tấm gỗ tam giác.

## SketchUp 2022

- [View#draw / draw2d](https://ruby.sketchup.com/Sketchup/View.html): preview gọi trong Tool#draw; dùng alpha và thứ tự xa đến gần, không bật chế độ X-ray toàn model. getExtents gồm cả chiều cao preview.
- [Geom.tesselate](https://ruby.sketchup.com/Geom.html#tesselate-class_method): có từ SketchUp 2020, dùng vòng ngoài CCW. Các điểm chiếu được đưa về z=0, đổi winding, bỏ mặt chiếu thành đường thẳng.
- [Group#to_component](https://ruby.sketchup.com/Sketchup/Group.html#to_component-instance_method): đổi cấu kiện thành component và chia sẻ definition theo hình học/vật liệu/tên loại; trái/phải tách nhóm. Đây là component dùng chung theo xác nhận của người dùng.
- [ComponentDefinition export](https://ruby.sketchup.com/Sketchup/ComponentDefinition.html): lưu hình học đã sửa tay bằng save_copy nếu có, fallback save_as; save_thumbnail cho ảnh mẫu.
- [DefinitionList#load](https://ruby.sketchup.com/Sketchup/DefinitionList.html#load-instance_method): trước SketchUp 2023, load lại cùng đường dẫn có thể trả definition đã có trong model. VGD copy asset sang đường dẫn tạm duy nhất khi đặt, rồi dọn bản copy.

Kiểm tra ở đây gồm Ruby WASM với fixture hình học, file IO thật và Edge. Native SketchUp chưa chạy được do công cụ chụp màn hình/nhập tọa độ lỗi; native_upgrade.rb được chuẩn bị để kiểm tra riêng. VALIDATION.json phân biệt rõ các kết quả này.
