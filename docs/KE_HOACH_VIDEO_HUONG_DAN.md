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
3. Hình ảnh: chạy chính giao diện VGD Center thật (`dialog.html`, trang hướng dẫn thật) trong trình duyệt, phía Ruby được mô phỏng; chưa đối chiếu với SketchUp thật. Chỉ có chữ trên màn hình, tiếng Việt, không giọng đọc.
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

## Quyết định: đưa hoạt ảnh vào hướng dẫn của Center

Ưu tiên: Center nhẹ nhất, hạn chế phát hành Center mới, thêm hướng dẫn cho plugin mới không cần cập nhật Center.

- Hoạt ảnh và giao diện mô phỏng đặt trên GitHub Pages của repo, không đóng gói trong Center. Quy tắc chặn script của trang hướng dẫn chữ (`valid_guide_html?`) giữ nguyên, không nới.
- Center (một lần, bản sau) đọc `guide_url` trong `catalog.json` và mở trang đó trong cửa sổ hướng dẫn; không có mạng hoặc lỗi thì dùng trang hướng dẫn chữ sẵn có. Cửa sổ này không đăng ký callback Ruby, nên trang trên mạng không điều khiển được SketchUp. Cần danh sách tên miền được phép trong Center.
- Đã làm: trang `guides/center/`, `build_site.py`, workflow Pages. Chưa làm: sửa Center đọc `guide_url`, kiểm tra trong SketchUp thật (HtmlDialog SketchUp 2022 có chạy trọn đoạn mã này không).


## Kế hoạch: hướng dẫn tương tác cho các plugin còn lại

Phạm vi: 8 plugin có hướng dẫn chữ (Dim, Cabinet, Library, Image Importer, Scenes, BIM, Reference, Cabinet Draw), khoảng 29 chương (mỗi chương của hướng dẫn chữ là một đoạn hoạt ảnh). DC Exporter, Room, Package không có hướng dẫn chữ và không nằm trong catalog nên không làm.

Đã chốt: phần diễn ra trong khung nhìn 3D chỉ thể hiện bằng chú thích kết quả trên màn hình, hoạt ảnh chạy trên hộp thoại thật của plugin; làm thử Image Importer trước.

### Mức độ (ước lượng, chưa mở thử cả 8 hộp thoại trong trình duyệt)

| Plugin | Hộp thoại HTML | Chương | Mức |
|---|---|---|---|
| Image Importer | 7 KB | 2 | Dễ |
| Reference | bảng nhỏ | 2 | Vừa |
| Library | 12 KB + trang map; tải dữ liệu ngoài | 3 | Vừa |
| Dim | 18 KB | 4 | Vừa |
| Scenes | 26 KB | 3 | Vừa |
| BIM | bảng nhiều tab, 8.400 dòng Ruby | 3 | Khó |
| Cabinet | 121 KB, 18 lệnh gọi Ruby | 3 | Khó |
| Cabinet Draw | 38 KB, phần lớn là công cụ trong khung nhìn | 9 | Khó nhất |

### Các giai đoạn

0. **Khung dùng chung (một lần).** Tách phần riêng của Center trong `common.js` thành bộ nhúng hộp thoại cho plugin bất kỳ (mô phỏng phía Ruby bằng dữ liệu theo thời gian); mỗi plugin có `chapters.json`, `build_site.py` sinh `guides/<id>/index.html` từ một mẫu chung và chép thư mục web của plugin. → kiểm tra: hình 7 đoạn của Center giống hệt trước khi tách; build và test trình duyệt đạt.
1. **Làm thử Image Importer** (2 chương). → kiểm tra: kịch bản được duyệt, xem khung hình, chạy trong trình duyệt theo đường dẫn con của Pages; rồi chỉnh khung dùng chung nếu cần.
2. **Reference, Library, Dim, Scenes.**
3. **BIM, Cabinet.**
4. **Cabinet Draw** (chia thành 2–3 đợt vì 9 chương).

### Quy trình cho mỗi plugin

1. Đọc hướng dẫn chữ, README và hộp thoại; liệt kê các lệnh gọi Ruby cần mô phỏng.
2. Viết bảng kịch bản (mục đích, thao tác, chữ trên màn hình, thời lượng) → bạn duyệt.
3. Dựng từng chương, xem khung hình, bạn xem và phản hồi.
4. Thêm `guides/<id>/`, dựng thử `_site`, kiểm tra trình duyệt.
5. Sau khi Center 1.2.6 đã phát hành và Pages đã chạy: thêm `guide_url` vào mục catalog (file này có hiệu lực ngay với người dùng Center 1.2.6 trở lên, bản cũ bỏ qua).

### Rủi ro và việc chưa rõ

- Mỗi hộp thoại gọi Ruby theo cách riêng nên phải đọc mã từng plugin; mức khó chỉ là ước lượng.
- Library tải dữ liệu từ ngoài: dùng dữ liệu mẫu.
- Hoạt ảnh là bản chụp giao diện lúc đăng; plugin đổi giao diện thì phải đăng lại. Có thể thêm bước kiểm tra tự động khi plugin đổi (chưa làm).
- Chưa kiểm tra trong SketchUp thật; phụ thuộc kết quả thử Center 1.2.6-beta.1.
- Chưa quyết: có xuất thêm MP4 cho từng plugin không (hiện chỉ làm bản tương tác); có làm bản tiếng Anh không.

### Image Importer: kịch bản (đã duyệt, đã dựng)

Chữ lấy từ `dialog.html`, `dialog.js`, `main.rb`, `conversion.rb` của plugin. Hộp thoại chạy thật; phía Ruby (danh sách ảnh, kết quả nhập) mô phỏng bằng `VGDImporter.receive`. Hộp chọn thư mục của Windows và kết quả trong model được thể hiện bằng khung vẽ thêm và chú thích. Ảnh mẫu là hình đơn giản do tôi vẽ, không phải ảnh thật của bạn.

| # | Chương (theo hướng dẫn chữ) | Thao tác | Chữ trên màn hình | Dài |
|---|---|---|---|---|
| 1 | Chọn ảnh và cách đặt | Hộp thoại trống ("Chọn ảnh để bắt đầu.") → bấm **Chọn thư mục** → hộp chọn thư mục của Windows → danh sách 5 ảnh, "5 ảnh", nút **Nhập 5 ảnh** sáng → đổi kiểu **Component 2D** / **Ảnh nằm phẳng** / **Vật liệu** → nhập **Milimét / pixel** (hoặc chiều cao cố định) → **Nhập 5 ảnh** → "Đã nhập 5 ảnh / vật liệu." | "Chọn thư mục hoặc kéo ảnh vào" / "Chọn kiểu nhập" / "Đặt kích thước thật: luôn giữ tỉ lệ ảnh" / "Ảnh được xếp theo hàng tại gốc tọa độ của vùng đang chỉnh sửa; Ctrl+Z hoàn tác cả lượt nhập" | 30 giây |
| 2 | Định dạng và vị trí | Danh sách ảnh nhiều đuôi (JPG, PNG, WEBP, TIFF, HEIC) → **Nhập** → hộp **Kết quả nhập ảnh**: "Đã nhập 4 ảnh / vật liệu · 1 ảnh lỗi." kèm dòng lỗi HEIC | "Hỗ trợ JPG, PNG, WebP, TIFF, TGA và nhiều định dạng khác" / "Một ảnh lỗi không chặn các ảnh khác" / "HEIC cần codec HEIF của Windows" / "Muốn nhập ở cấp model: thoát Group/Component trước" | 20 giây |

Giả định cần bạn xác nhận: dùng chữ "Nhập 5 ảnh" và 5 ảnh mẫu; tên file mẫu (ví dụ `cay1.png`, `nguoi2.jpg`) là minh họa. Chưa xác minh trong SketchUp thật.

Trạng thái: giai đoạn 0 xong (tách `center.js`, trang sinh từ mẫu chung; hình 7 đoạn Center giống hệt trước khi tách). Giai đoạn 1: đã dựng 2 chương Image Importer, trang `guides/image_importer/` chạy trên site dựng thử. Chưa thêm `guide_url` vào catalog (chờ Center 1.2.6 phát hành và Pages chạy). Chờ bạn xem video và phản hồi trước khi sang giai đoạn 2.


### Giai đoạn 2: kịch bản nháp Reference, Library, Dim, Scenes (chờ duyệt)

Mỗi chương theo một mục của hướng dẫn chữ; nút và nhãn lấy từ hộp thoại thật. Ruby được mô phỏng qua hàm thật của từng hộp thoại (`VGDReference.render`, `VGD.begin/append/model`, `VGD.<hàm>`, `VGDScenes.receive`); phần diễn ra trong khung nhìn 3D chỉ có chú thích. Tên vật liệu, ảnh và scene mẫu là minh họa; chữ trạng thái/kết quả sẽ đọc từ mã Ruby của từng plugin khi dựng.

| Plugin | # | Chương | Thao tác chính (nút thật) | Dài |
|---|---|---|---|---|
| Reference | 1 | Thêm và quản lý ảnh | **Thêm** / **Dán** / kéo file vào bảng → chọn ảnh, chỉnh mức hiển thị, **Cắt ảnh**, khóa → **Ẩn tất cả**, **Xóa tất cả** | 25 giây |
| Reference | 2 | Lưu ý | Chú thích: ảnh là lớp phủ theo màn hình, không tạo hình học, không lưu vào model; đóng hoặc đổi model thì mất danh sách | 15 giây |
| Library | 1 | Tìm và tô vật liệu | **Thêm thư mục vật liệu** → tìm, lọc, yêu thích → chọn mẫu xem trước → nhập Rộng × Cao (mm) → **Tô lên vùng chọn** | 30 giây |
| Library | 2 | Đặt model và lưu mẫu | Tab **Thư viện model** → chọn SKP (đặt bằng chuột, mũi tên xoay 90°, Esc hủy) → **Lưu model vào thư viện** | 25 giây |
| Library | 3 | Công cụ map | **Chỉnh map & tô từng mặt**: **Xoay 90°**, **Dịch vân**, **Fit map**, **AUTO SCALE**, **Phục hồi cỡ thật**; mục **Bộ công cụ** | 25 giây |
| Dim | 1 | Tạo Smart Dim | Tab **Smart Dim** → phạm vi → **Mặt theo trục tủ**, Dim ngang/đứng, **Cách tủ (mm)** → **Smart Dim cho tủ đang chọn** → dòng trạng thái | 30 giây |
| Dim | 2 | Chỉnh kiểu dáng | Tab **Kiểu dáng**: phạm vi, màu, mũi tên, hướng chữ → **Áp style theo phạm vi** | 20 giây |
| Dim | 3 | Font, cỡ chữ và preset | **Font & cỡ chữ** (Model Info) → **Làm mới Dimension theo phạm vi** → **Preset**: **Lưu** | 20 giây |
| Dim | 4 | Đơn vị và Animation | **Bật animation** / **Tắt animation**; **Áp đơn vị cho toàn model**; chú thích: không có Undo, kiểm tra trước khi xác nhận | 20 giây |
| Scenes | 1 | Tạo bộ view | **Tạo view**: ISO/TOP/FRONT/RIGHT, mẫu tên → **Tạo / cập nhật scene** → tab **Scenes** (danh sách, chuyển camera, lưu camera) | 30 giây |
| Scenes | 2 | Mặt cắt và khung hình | Tab **Mặt cắt**: trục, vị trí %, **Xem trước**, **Tắt xem trước** → tab **Canh view** | 25 giây |
| Scenes | 3 | Xuất ảnh hoặc PDF | Tab **Xuất file**: chọn scene, PNG/JPG hoặc PDF, khổ giấy, nền trong suốt → xuất | 25 giây |

Thứ tự dựng: Reference → Library → Dim → Scenes; mỗi plugin xong thì gửi video để bạn xem rồi mới sang plugin kế. Chưa xác minh trong SketchUp thật.

Giai đoạn 2, tiến độ: Reference đã dựng (2 chương), chờ bạn xem; kế tiếp Library, Dim, Scenes.
