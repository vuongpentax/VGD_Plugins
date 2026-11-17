# VGD Structure 0.2.0-beta.1

Plugin SketchUp dựng **phần thô** (cột, dầm, tường, sàn, trần) theo **lưới trục** và **tầng**, nối với VGD BIM để tính khối lượng. Kế hoạch: `docs/vgd_structure/PLAN.md`. Đặc tả dữ liệu: `docs/vgd_structure/SPEC.md`.

## Trạng thái

**Cột mốc 1: lưới trục.** Chưa dựng cột, dầm, tường, sàn, trần (các cột mốc sau, xem kế hoạch).

**Lưới trục** (menu Extensions → VGD → VGD Structure → Lưới trục, hoặc nút trên thanh công cụ VGD STR):
- Nhập **trục đứng** (đánh số 1, 2, 3...) và **trục ngang** (đánh chữ A, B, C...; bỏ I và O) với khoảng cách giữa các trục, từng trục sửa được tên và nhịp. Gõ nhanh "4200, 3600*2" rồi bấm Tạo trục từ nhịp (dấu phẩy hoặc khoảng trắng ngăn cách, số lẻ dùng dấu chấm, `*` hoặc `x` là lặp). 2 đến 60 trục mỗi phương, tên tối đa 4 ký tự, nhịp tối thiểu 100 mm.
- Xem trước mặt bằng và tóm tắt (số giao điểm, nhịp, ô, khung lưới) do Ruby tính.
- **Vẽ lưới trục**: một nhóm "Lưới trục" trên tag **!grid** (tên và màu tím theo bộ tag mẫu của VGD BIM; nét gạch dài - chấm được đặt cho tag khi tag còn nét liền, cần SketchUp 2021 trở lên và model có kiểu nét gạch chấm). Mỗi trục là đường kéo dài quá trục biên, ký hiệu trục là vòng tròn 10 mm trên giấy theo **tỉ lệ bản vẽ** (1:100 = vòng 1000 mm) có tên trục ở giữa: ở đầu dưới trục đứng và đầu trái trục ngang, tùy chọn cả hai đầu. Một bước hoàn tác; vẽ lại thì thay nhóm cũ (nhóm cũ bị khóa thì báo, không đụng).
- **Xóa lưới khỏi model** (có hỏi xác nhận); dữ liệu lưới vẫn giữ trong model để vẽ lại.
- Dữ liệu lưới lưu trong model (dictionary `VGD_STRUCT`), mở lại cửa sổ là nạp lại.

Menu và thanh công cụ chỉ có hiệu lực sau khi mở lại SketchUp; **Tải lại code** nạp lại mã mà không cần mở lại (đóng và mở lại cửa sổ nếu đang mở).

## Cài đặt

Cài file `VGD_Structure_v0.2.0-beta.1.rbz` bằng Extension Manager của SketchUp (SketchUp 2022 trở lên), rồi mở lại SketchUp.

## Kiểm thử

- Tự động (mô phỏng, ngoài SketchUp): `ruby dev/run_tests.rb` từ `plugins/VGD_Structure`; kiểm tra cú pháp, menu và toolbar, Tải lại code, logic lưới trục và ký hiệu, vẽ lưới bằng SketchUp giả lập, cửa sổ. Giao diện: `node dev/test_ui.cjs` (Playwright; đặt `VGD_PLAYWRIGHT_MODULE` nếu cần).
- **Chưa xác minh trong SketchUp thật.**
