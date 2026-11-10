# Kế hoạch: Làm animation hướng dẫn sử dụng phần mềm của tôi

## Mục tiêu
Tạo các đoạn animation ngắn hướng dẫn người dùng cách dùng từng tính năng chính
của phần mềm do tôi viết. Mỗi đoạn là một bước của quy trình, dễ hiểu cho người
không rành kỹ thuật.

## Quy tắc làm việc
- Trước mỗi bước lớn, hỏi tôi xác nhận rồi mới làm tiếp.
- Nếu có nhiều cách làm, đưa ra 2–3 lựa chọn kèm ưu, nhược điểm, rồi chờ tôi chọn.
- Nếu một bước có rủi ro (xóa file, ghi đè mã nguồn, cài thêm phần mềm lớn),
  báo trước và chờ tôi đồng ý.
- Viết câu trả lời bằng tiếng Việt, giải thích đơn giản, tránh thuật ngữ không cần thiết.
- Khi liệt kê, đánh số thứ tự để tôi dễ tham chiếu.

## Tài liệu tham khảo (skill)
- motion-design-skill (nguyên tắc chuyển động, dùng cho video hướng dẫn):
  https://github.com/LottieFiles/motion-design-skill
- gsap-skills (hiệu ứng trên web, chỉ cần nếu phần mềm chạy trên web):
  https://github.com/greensock/gsap-skills

Trước khi cài, hãy mở các link trên và đọc file SKILL.md để xem nội dung.

## Bước 1: Thu thập thông tin (chưa làm gì khác)
Hỏi tôi các câu sau, chờ trả lời đầy đủ:
1. Phần mềm chạy trên web, desktop (Windows/macOS), hay mobile?
2. Phần mềm viết bằng công nghệ gì (nếu biết)?
3. Video đầu ra là MP4 để đăng lên mạng, hay chạy trực tiếp trong web/app?
4. Danh sách 3–5 tính năng cần hướng dẫn đầu tiên là gì?
5. Có ảnh chụp màn hình hoặc thư mục mã nguồn để tham khảo không?
6. Độ dài mong muốn mỗi đoạn (ví dụ 15–30 giây)?
7. Có yêu cầu về màu sắc, logo, hoặc giọng điệu thương hiệu không?

## Bước 2: Chuẩn bị môi trường
1. Kiểm tra thư mục dự án hiện tại và xác nhận đây là nơi làm việc.
2. Cài skill `motion-design-skill` vào thư mục dự án (`.claude/skills/`), không cài toàn cục.
   Lệnh gợi ý: `npx skills add LottieFiles/motion-design-skill`
3. Đọc file `SKILL.md` của skill và tóm tắt cho tôi những gì nó hướng dẫn.
4. Nếu phần mềm là web: cài thêm `gsap-skills` theo cách tương tự.
5. Báo lại tôi cách xuất video đề xuất dựa trên câu trả lời ở Bước 1.
   Chờ tôi chọn trước khi cài bất kỳ công cụ nào.

## Bước 3: Lên kịch bản
1. Với mỗi tính năng, viết kịch bản gồm: mục đích, các bước thao tác, nội dung chữ
   hiển thị trên màn hình, thời lượng dự kiến.
2. Gộp các kịch bản thành một bảng để tôi duyệt.
3. Chờ tôi duyệt hoặc chỉnh sửa trước khi làm animation.

## Bước 4: Dựng animation
1. Làm từng đoạn một, bắt đầu từ đoạn đơn giản nhất để kiểm tra quy trình.
2. Sau mỗi đoạn, cho tôi xem kết quả (ảnh chụp, file xem trước, hoặc đường dẫn chạy thử)
   và chờ phản hồi.
3. Giữ phong cách nhất quán giữa các đoạn: cùng màu, cùng kiểu chuyển động, cùng tốc độ.

## Bước 5: Xuất file
1. Xuất đúng định dạng đã chọn ở Bước 1.
2. Đặt tên file theo thứ tự và tên tính năng, ví dụ `01-dang-nhap.mp4`.
3. Tạo một file `HUONG-DAN.md` ghi lại: danh sách file, cách chạy lại, và các thông số đã dùng.

## Bước 6: Kiểm tra cuối
1. Mở lại từng file xuất ra để kiểm tra chất lượng, độ dài, và chữ có bị cắt không.
2. Liệt kê những việc còn lại hoặc điểm cần cải thiện.
3. Báo cáo ngắn gọn cho tôi kết quả và đề xuất bước tiếp theo.

## Rủi ro cần lưu ý
- Skill chỉ hướng dẫn cách làm, không tự xuất video. Cần công cụ render riêng.
- Nếu cài nhiều skill, bộ nhớ làm việc của Claude sẽ đầy nhanh. Chỉ cài những gì cần dùng.
- Nội dung trong skill sẽ được AI làm theo. Đọc `SKILL.md` trước khi dùng.
- Với phần mềm nội bộ, không đưa mã nguồn hoặc thông tin nhạy cảm vào nơi công khai.
- Không đăng video lên mạng khi chưa được bạn xem và duyệt.

---

## Quyết định đã chốt (kết quả Bước 1 và Bước 2)

1. Phần mềm: plugin `VGD_Center` (SketchUp, giao diện `UI::HtmlDialog`).
2. Đầu ra: file MP4 và bản nhúng trong VGD Center. Mỗi đoạn 15–30 giây.
3. Hình ảnh: vẽ lại giao diện từ code HTML/CSS và theme VGD (chưa đối chiếu với SketchUp thật). Chỉ có chữ trên màn hình, tiếng Việt, không giọng đọc.
4. Phong cách: theme tối. Mẫu "làm tối nền, làm nổi vùng cần bấm" là chính; mẫu "phóng to, chữ lớn" dùng cho cảnh cần chú ý kỹ.
5. Chuyển động: dùng `motion-design-skill`, cài vào `.claude/skills/motion-design/` (không commit, theo quy tắc repo về mã tải từ ngoài). Chưa cài `gsap-skills`.
6. Cách xuất MP4: quay từng khung hình bằng Chromium/Playwright rồi ghép bằng ffmpeg. Không cài thêm công cụ.

## Kịch bản 7 đoạn (nháp chờ duyệt)

Chữ giao diện và hành vi lấy từ `plugins/VGD_Center/README.md`. Tên nút và vị trí chính xác cần đối chiếu với `dialog.html` khi dựng.

| # | Đoạn | Mục đích | Các bước thao tác | Chữ trên màn hình | Thời lượng |
|---|---|---|---|---|---|
| 1 | Cài plugin từ Kho | Cài một plugin VGD | Mở Kho plugin → bấm Cài đặt trên thẻ plugin → Center tải và xác minh SHA-256 → nhắc lưu model, khởi động lại SketchUp | "Chọn plugin trong Kho" / "Bấm Cài đặt" / "Center tự tải và kiểm tra gói" / "Lưu model rồi khởi động lại SketchUp" | 25 giây |
| 2 | Cập nhật và gỡ plugin | Cập nhật bản mới, gỡ plugin không dùng | Thẻ plugin có nút cập nhật → bấm cập nhật; bấm Gỡ → xác nhận → nhắc khởi động lại | "Có bản mới? Bấm cập nhật" / "Gỡ plugin cần xác nhận" | 25 giây |
| 3 | Mở Hướng dẫn | Xem hướng dẫn riêng của plugin | Bấm nút Hướng dẫn trên thẻ → trang hướng dẫn mở; có chế độ tối/sáng và in PDF | "Bấm Hướng dẫn trên thẻ plugin" / "Đổi sáng/tối hoặc in PDF" | 15 giây |
| 4 | Tab Quản lý: bật/tắt | Tắt hoặc bật plugin | Mở tab Quản lý → bật/tắt plugin → khởi động lại SketchUp, hoặc bấm Nạp ngay với plugin vừa bật | "Bật/tắt có hiệu lực sau khi khởi động lại" / "Nạp ngay: dùng luôn, không cần khởi động lại" | 25 giây |
| 5 | Chuyển plugin 2022 ↔ 2024 | Chuyển plugin giữa hai bản SketchUp | Tab Chuyển plugin → tìm theo tên → chọn plugin → (tick Ghi đè nếu cần) → chuyển → báo kết quả | "Chọn plugin cần chuyển" / "Không tick Ghi đè: bỏ qua nếu đã có" / "Plugin mã hóa (.rbe) cần cài lại bản đúng SketchUp" | 30 giây |
| 6 | Xuất gói RBZ tổng | Gom plugin thành một file cài | Tab Quản lý → chọn plugin → Xuất gói .rbz → chọn nơi lưu | "Chọn plugin cần gom" / "Xuất .rbz" | 20 giây |
| 7 | Cài đặt | Đổi ngôn ngữ, bật/tắt tự động cập nhật Center | Mở Cài đặt → chọn ngôn ngữ → bật/tắt tự cập nhật → xem lần kiểm tra gần nhất | "Chọn ngôn ngữ" / "Tự cập nhật Center khi mở SketchUp" | 15 giây |

Thứ tự làm đề xuất: làm thử đoạn 3 (đơn giản nhất) để kiểm tra quy trình xuất, rồi 1, 2, 4, 6, 7, cuối cùng đoạn 5.

Chưa xác minh: hộp thoại chọn file, dời file thật và hành vi trong SketchUp thật (README và test của plugin cũng ghi chưa xác minh trong SketchUp thật).

## Kết quả

Đã dựng đủ 7 đoạn. Mã nguồn, cách chạy lại và thông số: `tools/video-huong-dan/HUONG-DAN.md`. Chưa nhúng vào VGD Center, chưa đối chiếu với SketchUp thật.
