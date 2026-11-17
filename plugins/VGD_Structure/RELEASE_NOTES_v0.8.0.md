# VGD Structure 0.8.0 (beta)

Cột mốc 7: **nối với VGD BIM** (cần VGD BIM 1.1.1-beta.6 trở lên).

- **VGD ID**: phần tử mới dựng nhận ID từ VGD BIM qua cầu nối; dựng lại giữ nguyên ID của đúng phần tử. Chưa cài BIM thì để trống.
- Mỗi phần tử ghi thêm tên tầng và cao độ tầng để BIM hiển thị; BIM dùng kích thước chính xác của plugin để lập bảng khối lượng.
- **Sửa từ BIM**: VGD Structure đăng ký lệnh `edit` (cầu nối `structure_element`); BIM mở plugin ở đúng tab, tầng và phần tử.
- Dữ liệu các cột mốc trước vẫn mở được. Chưa xác minh trong SketchUp thật.
