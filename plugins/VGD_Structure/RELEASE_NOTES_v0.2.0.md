# VGD Structure 0.2.0 (beta)

Cột mốc 1: **lưới trục**.

- Cửa sổ **Extensions → VGD → VGD Structure → Lưới trục** (và nút trên thanh công cụ **VGD STR**): nhập trục đứng (đánh số 1, 2, 3...) và trục ngang (đánh chữ A, B, C...; bỏ chữ I và O) kèm khoảng cách các nhịp, hoặc gõ nhanh "4200, 3600*2". Có xem trước mặt bằng và tóm tắt số giao điểm, nhịp, ô.
- Vẽ lưới vào model: một nhóm "Lưới trục" trên tag **!grid** (theo bộ tag mẫu của VGD BIM, màu tím) với đường trục **nét gạch dài - chấm** và **ký hiệu trục** theo thông lệ bản vẽ quốc tế (vòng tròn 10 mm trên giấy theo tỉ lệ 1:20 đến 1:500, tên trục ở giữa; ký hiệu ở đầu dưới trục đứng và đầu trái trục ngang, tùy chọn cả hai đầu). Một bước hoàn tác; vẽ lại thì thay nhóm cũ; có nút xóa lưới khỏi model.
- Dữ liệu lưới lưu trong model (VGD_STRUCT) để mở lại sửa tiếp.
- Chưa dựng cột, dầm, tường, sàn, trần (các cột mốc sau). Chưa xác minh trong SketchUp thật.
