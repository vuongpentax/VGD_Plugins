# VGD Structure 0.30.0 (beta)

- **Móng băng (H4):** tick "Móng băng dưới tường" ở bảng Móng của tầng móng (rộng, dày): dải móng dưới mọi tường ngang / dọc, tự cắt phần trùng đế cột nên không chồng khối. Tường xiên chưa hỗ trợ (có cảnh báo).
- **Loại móng có tên, chọn riêng từng cột:** "+ Thêm loại móng", rồi gán loại cho từng cột; cột để "Mặc định" dùng kích thước chung.
- **Móng giật cấp:** đế hai bậc, bậc trên nhỏ hơn hoặc bằng bậc dưới.
- **Mái bốn dốc (H5a, beta.2):** kiểu mái mới "Bốn dốc" ở nút Mái của bảng Tầng: cùng độ dốc bốn phía, nóc giữa khung theo phương dài (một điểm nếu khung vuông). Tường thu hồi, mái theo đường bao, xà gồ chưa làm.
- Dữ liệu cũ không đổi (khóa mới chỉ lưu khi dùng). VGD BIM không cần sửa: thể tích móng băng, bậc tính như cột.

Kiểm tra: test Ruby toàn bộ đạt (mới `dev/test_footing_strip.rb`, 41 kiểm tra), test giao diện 863 đạt (beta.2), test quy ước đạt. **Chưa thử trong SketchUp thật:** dựng móng băng / giật cấp, chỗ hở nhỏ cạnh đế cột hẹp hơn băng.
