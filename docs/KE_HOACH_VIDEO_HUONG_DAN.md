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
