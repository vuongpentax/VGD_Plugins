# VGD Structure 0.29.0 (beta)

- **Móng đơn (beta.1):** bảng Tầng có cột Móng đơn (dài × rộng × dày); mọi cột của tầng có đế móng ngay dưới chân cột. Thêm tầng móng dưới tầng trệt: cột là cổ cột, dầm là giằng móng; đề xuất tự động cho tầng móng chỉ gồm cột và dầm. Cảnh báo đế chồng nhau hoặc nhỏ hơn cột. Tag S. FOOTING; VGD BIM tính thể tích.
- **Mái (beta.1):** mái bằng, một dốc, hai dốc phủ khung lưới cộng phần chìa; chọn độ dốc, hướng, dày, chìa mái, cao độ chân mái. Tag A. ROOF; VGD BIM tính diện tích nghiêng và thể tích. Chưa có mái bốn dốc, tường thu hồi.
- **Lỗ sàn cầu thang (beta.1):** sàn tầng trên tự khoét lỗ theo cầu thang tầng dưới khi cầu thang nằm trọn trong một tấm sàn; vắt qua mép tấm thì cảnh báo.
- Mặt bằng vẽ đế móng và viền mái; bảng Tầng cuộn ngang, ô nhập không còn bị bóp nhỏ.

Kiểm tra: tự động (test Ruby mới `dev/test_footing.rb`, `dev/test_roof.rb`, `dev/test_stair_hole.rb`; test giao diện thêm phần Móng đơn và Mái; test cũ vẫn đạt). **Chưa thử trong SketchUp thật:** dựng mái bằng mặt 3D nghiêng (chiều pháp tuyến), lỗ cầu thang trên sàn theo ô, đế móng.
