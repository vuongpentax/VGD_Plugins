# VGD Structure 0.30.0 (beta)

- **Móng băng (H4):** tick "Móng băng dưới tường" ở bảng Móng của tầng móng (rộng, dày): dải móng dưới mọi tường ngang / dọc, tự cắt phần trùng đế cột nên không chồng khối. Tường xiên chưa hỗ trợ (có cảnh báo).
- **Loại móng có tên, chọn riêng từng cột:** "+ Thêm loại móng", rồi gán loại cho từng cột; cột để "Mặc định" dùng kích thước chung.
- **Móng giật cấp:** đế hai bậc, bậc trên nhỏ hơn hoặc bằng bậc dưới.
- **Mái bốn dốc (H5a, beta.2):** kiểu mái mới "Bốn dốc" ở nút Mái của bảng Tầng: cùng độ dốc bốn phía, nóc giữa khung theo phương dài (một điểm nếu khung vuông). Tường thu hồi, mái theo đường bao, xà gồ chưa làm.
- **Tường thu hồi (H5b, beta.3):** tùy chọn của mái một dốc và hai dốc (bảng Mái, tick "Tường thu hồi", chọn loại tường). Tường = giao của mặt phẳng đứng ở biên khung với đáy mái (đầu hồi tam giác, hai bên mái một dốc hình thang), đứng trên mặt sàn kết cấu, mặt ngoài trùng trục biên. Tường đặc, chưa có lỗ.
- **Mái theo đường bao (H5c, beta.4):** kiểu mái mới "Theo đường bao": chọn các giao điểm lưới tạo thành một đa giác LỒI (hình thang, tam giác, ngũ giác...), mọi cạnh cùng một độ dốc, mỗi cạnh một tấm. Chưa hỗ trợ đa giác lõm (chữ L, T, U), dốc riêng từng cạnh; không có tường thu hồi cho kiểu này.
- Dữ liệu cũ không đổi (khóa mới chỉ lưu khi dùng). VGD BIM không cần sửa: thể tích móng băng, bậc tính như cột.

Kiểm tra: test Ruby toàn bộ đạt (mới `dev/test_footing_strip.rb`, 41 kiểm tra), test giao diện 869 đạt (beta.3), test quy ước đạt. **Chưa thử trong SketchUp thật:** dựng móng băng / giật cấp, chỗ hở nhỏ cạnh đế cột hẹp hơn băng.
