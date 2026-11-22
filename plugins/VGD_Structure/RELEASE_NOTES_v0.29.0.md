# VGD Structure 0.29.0 (beta)

- **Mặt đứng che khuất đúng, nét đậm nhạt (beta.2):** z-buffer theo điểm ảnh thay cho tô theo độ sâu trung bình; viền ngoài đậm, ranh giới đối tượng vừa, nếp trong mảnh. Kéo / cuộn mượt (ảnh tạm), dừng tay mới vẽ lại.
- **Cốt tầng và kích thước trên mặt đứng, mặt cắt (beta.2):** ký hiệu cốt ±0.000, chuỗi chiều cao tầng, tổng chiều cao, khoảng trục, tổng chiều dài.
- **Mặt cắt có hatch theo vật liệu (beta.2):** bê tông, gạch, hoàn thiện; viền cắt nét đậm.
- **Ký hiệu mặt đứng trên mặt bằng (beta.2):** bấm để mở mặt đứng hướng đó.
- **Cây dự án có nhánh Bản vẽ (beta.2):** mặt bằng, mặt đứng, mặt cắt (đổi tên, xóa), thống kê.
- **Móng đơn (beta.1):** bảng Tầng có cột Móng đơn (dài × rộng × dày); mọi cột của tầng có đế móng ngay dưới chân cột. Thêm tầng móng dưới tầng trệt: cột là cổ cột, dầm là giằng móng; đề xuất tự động cho tầng móng chỉ gồm cột và dầm. Cảnh báo đế chồng nhau hoặc nhỏ hơn cột. Tag S. FOOTING; VGD BIM tính thể tích.
- **Mái (beta.1):** mái bằng, một dốc, hai dốc phủ khung lưới cộng phần chìa; chọn độ dốc, hướng, dày, chìa mái, cao độ chân mái. Tag A. ROOF; VGD BIM tính diện tích nghiêng và thể tích. Chưa có mái bốn dốc, tường thu hồi.
- **Lỗ sàn cầu thang (beta.1):** sàn tầng trên tự khoét lỗ theo cầu thang tầng dưới khi cầu thang nằm trọn trong một tấm sàn; vắt qua mép tấm thì cảnh báo.
- Mặt bằng vẽ đế móng và viền mái; bảng Tầng cuộn ngang, ô nhập không còn bị bóp nhỏ.

Kiểm tra beta.2: test Ruby mặt phẳng độ sâu (`dev/test_elevation_geometry.rb`), test giao diện che khuất z-buffer, nét viền, ký hiệu mặt đứng, nhánh Bản vẽ, hatch mặt cắt (845 kiểm tra đạt). Chưa thử trong SketchUp thật: tốc độ z-buffer trong HtmlDialog với model thật.

Kiểm tra beta.1: tự động (test Ruby mới `dev/test_footing.rb`, `dev/test_roof.rb`, `dev/test_stair_hole.rb`; test giao diện thêm phần Móng đơn và Mái; test cũ vẫn đạt). **Chưa thử trong SketchUp thật:** dựng mái bằng mặt 3D nghiêng (chiều pháp tuyến), lỗ cầu thang trên sàn theo ô, đế móng.
