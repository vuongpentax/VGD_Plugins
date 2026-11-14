# Kiểm thử và xác minh

Thư mục dành cho kiểm thử dùng chung toàn repo. Bộ chung hiện có: `test_vgd_conventions.rb` (quy ước tên, menu, toolbar của mọi plugin; chạy `ruby tests/test_vgd_conventions.rb` từ gốc repo, đọc mã nên không cần SketchUp). Ngoài ra mỗi plugin tự có thư mục kiểm thử riêng (ví dụ `plugins/VGD_Dim/dev/`, `plugins/VGD_Cabinet/cabinet_dev/`); xem README của từng plugin để biết lệnh chạy.

Khi bổ sung kiểm thử, ghi rõ cách chạy. Phân biệt kết quả kiểm tra tự động, kiểm tra thủ công và phần chưa xác minh. Chỉ ghi nhận đã kiểm thử trong SketchUp khi thực sự thực hiện.
