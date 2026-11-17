# VGD Structure 0.11.0 (beta)

Tab **Mặt bằng** (cột mốc P1 đến P5, P4b-1; bản beta 0.10.0 gộp vào đây): tab **Mặt bằng** (cửa sổ vẽ mặt bằng kiểu CAD, giai đoạn 2).

- Bố cục theo cửa sổ mặt bằng của VTBim: thanh trên, tab theo tầng, cột công cụ bên trái chia nhóm, bảng Thuộc tính (bấm phần tử để xem), thanh trạng thái.
- Canvas hiển thị mặt bằng tầng đang chọn: lưới trục, sàn, trần, dầm, tường, cửa đi (cánh mở và cung quay) / cửa sổ, cột; màu theo bộ tag mẫu BIM.
- Thao tác: cuộn để thu phóng quanh con trỏ, chuột giữa hoặc H để kéo, F vừa khung, Space về công cụ Chọn; bật / tắt từng lớp; đổi tầng bằng tab (đồng bộ với các tab khác); rê chuột để xem thông tin phần tử và tọa độ.
- Công cụ vẽ kết cấu và sửa kiểu CAD đã bố trí sẵn nhưng khóa; làm ở các cột mốc sau. Chưa sửa dữ liệu từ mặt bằng.
- P2: **chọn** bằng khung (trong / cắt), Shift, Ctrl+A; **bắt điểm** (đầu mút, giao điểm, trung điểm, trên cạnh / trục / đường gióng); **đo** khoảng cách, Δx, Δy, góc (Shift khóa ngang / dọc, gõ số + Enter); **đường gióng** song song hoặc qua hai điểm (riêng từng tầng, chỉ để xem, không lưu).
- **Phím tắt kiểu Revit** (gõ liên tiếp các chữ: WA, DR, WN, CL, BM, GR, ZE, ME, RP, MV, CO, RO...), bảng Phím tắt sửa được và lưu theo máy; **quy ước chọn của Revit** (Ctrl thêm, Shift bớt, Tab chuyển phần tử chồng nhau). Phím Revit ghi theo trí nhớ, chưa đối chiếu với Revit thật.
- P3: **vẽ kết cấu trên mặt bằng** (cột, dầm theo chuỗi nhịp, tường, sàn, trần, cửa đi, cửa sổ, lưới trục) với **thanh tùy chọn**; **bảng Thuộc tính sửa được** (đổi loại, vị trí); **xóa** (Delete / DE); **hoàn tác / làm lại** (Ctrl+Z / Ctrl+Y, chỉ cho thay đổi trên mặt bằng). Dữ liệu ghi vào lựa chọn của tầng như các tab Cột, Dầm, Tường...; Ruby vẫn kiểm tra và tính xem trước.
- P4: **sửa kiểu Revit trên lưới**: Move (MV), Copy (CO), Array (AR), Mirror (MM qua một trục), Match (MA); bước dịch theo ô lưới, tường đi kèm cửa; **kích thước tạm thời** (cửa sửa được: bấm số, gõ giá trị). Rotate, Offset, Trim, Align để cột mốc P4b (cần phần tử tự do ngoài lưới).
- P5: **Cây dự án** (Project Browser) trong tab Mặt bằng: tầng → nhóm → phần tử, loại, lưới trục; lọc; bấm để chuyển tầng và chọn phần tử (kể cả ở tầng khác); tô sáng theo lựa chọn trên mặt bằng.
- **P4b-1: phần tử TỰ DO ngoài lưới (vuông góc)**: cột (xoay 0 / 90°), dầm, tường nằm ngang / dọc đặt ở tọa độ bất kỳ (khóa `free` trong lựa chọn của tầng; dữ liệu cũ theo lưới đọc y nguyên; mã fc_ / fb_ / fw_). Vẽ tự do (thanh tùy chọn "Vị trí: Tự do", bắt điểm, gõ độ dài), **Mở khóa lưới** (UL), Move / Copy / Array / Mirror bằng điểm bất kỳ, **Offset, Align, Trim (nối góc L), Rotate 90 / 180 / 270°**, thuộc tính và kích thước tạm thời sửa được; Ruby có kế hoạch, kiểm tra chồng và dựng cho phần tử tự do (BIM đọc như phần tử thường).
- Chưa xác minh trong SketchUp thật (cửa sổ HtmlDialog thật, dựng cột / dầm / tường tự do trong model thật, hiệu năng canvas với nhiều phần tử).
