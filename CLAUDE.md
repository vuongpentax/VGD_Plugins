# VGD Plugins — Quy định Repository

## Mục đích dự án

Repository này chứa hệ sinh thái công cụ và plugin SketchUp của VGD.

Mã nguồn các plugin VGD đã được chuyển vào repository này từ workspace cũ. Plugin còn lại (nếu có) được đưa vào dần dần, từng module một (xem "Chiến lược migrate code cũ").

Nền tảng mục tiêu chính:
- SketchUp 2022 trở lên.
- Windows là môi trường phát triển và kiểm thử chính.
- SketchUp Ruby API là nền tảng chính để phát triển plugin.
- HTML/CSS/JavaScript có thể được sử dụng cho giao diện `UI::HtmlDialog`.

Không được mặc định rằng cấu trúc, script, dependency hoặc quy ước của project cũ phải được giữ lại, trừ khi chúng được chủ động đưa vào repository này.

## Cấu trúc Repository

Cấu trúc cấp cao dự kiến:

```text
VGD_Plugins/
├── CLAUDE.md
├── README.md
├── .gitignore
├── docs/
├── plugins/
├── shared/
├── tools/
├── tests/
└── archive/
```

Tất cả plugin SketchUp dùng thực tế phải nằm trong thư mục `plugins/`.

`shared/` chứa tài nguyên dùng chung giữa các plugin (theme giao diện, chuẩn điều khiển và hiệu ứng `shared/vgd-ui/`, catalog và tài liệu của VGD Center, quy tắc icon).

Mỗi plugin nên được tổ chức tương đối độc lập. Danh sách plugin hiện có xem trực tiếp trong `plugins/`.

Mỗi plugin tự giữ test và script hỗ trợ trong thư mục riêng của nó (thường là `dev/`); `tests/` ở gốc dành cho kiểm thử dùng chung toàn repo và hiện chưa có bộ nào.

Không tự tạo plugin mới nếu chưa được yêu cầu hoặc chưa thực sự được chuyển vào.

### CLAUDE.md của từng plugin

Mỗi plugin có `CLAUDE.md` riêng ở thư mục gốc của plugin, cùng một mẫu: Thông tin plugin, Cấu trúc, Kiểm thử, Đóng gói, Tài liệu đọc trước khi sửa, Quy tắc riêng. File này chỉ ghi phần riêng của plugin và điều kiểm chứng được từ mã hoặc tài liệu của plugin; không lặp lại quy tắc chung và không ghi số phiên bản (chỉ ghi nơi giữ phiên bản).

Khi một thay đổi làm đổi thông tin đó (loader, namespace, lệnh test, cách đóng gói), cập nhật `CLAUDE.md` của plugin trong cùng commit.

Chỉ dùng tên `CLAUDE.md`. Không tạo `AGENTS.md`. Repo chỉ dùng Claude: không đặt tên file, biến môi trường hay đường dẫn theo công cụ AI khác ngoài Claude.

## Quy tắc làm việc

Trước khi thực hiện một thay đổi lớn:

1. Đọc các file liên quan hiện có.
2. Hiểu hành vi hiện tại.
3. Xác định rõ thay đổi dự định thực hiện.
4. Thực hiện thay đổi nhỏ nhất hợp lý.
5. Kiểm tra kết quả.
6. Báo cáo rõ đã thay đổi gì và phần nào chưa thể kiểm chứng.

Không viết lại các module đang hoạt động tốt nếu không cần thiết.

Không tự thêm framework, dependency, build system hoặc lớp kiến trúc mới nếu chúng không giải quyết một yêu cầu cụ thể.

Không tự phát triển các tính năng chưa được yêu cầu.

Không âm thầm thay đổi hành vi đang có, tên gọi, định dạng file, setting hoặc yêu cầu tương thích.

### Suy nghĩ trước khi viết code

- Nêu rõ các giả định trước khi làm. Không giấu chỗ chưa rõ.
- Nếu yêu cầu có nhiều cách hiểu, trình bày các cách hiểu và hỏi; không tự chọn một cách âm thầm. Với việc nhỏ, rõ ràng, dễ hoàn tác thì được làm theo cách hiểu hợp lý nhất, nhưng phải nói rõ cách hiểu đó trong báo cáo.
- Nếu có cách đơn giản hơn yêu cầu, hãy nói ra. Được phép phản biện khi có lý do.
- Nếu sau khi đã kiểm tra repository vẫn chưa rõ, dừng lại, nêu rõ điều gì chưa rõ rồi hỏi.

### Thay đổi có phạm vi hẹp

- Không "tiện tay" cải thiện code, comment hoặc định dạng xung quanh chỗ cần sửa.
- Gặp code chết hoặc vấn đề không liên quan: chỉ báo lại, không tự xóa hoặc sửa.
- Dọn những thứ thừa do chính thay đổi của mình tạo ra (import, biến, hàm không còn dùng). Không dọn thứ có sẵn từ trước.
- Mỗi dòng thay đổi phải lần ra được yêu cầu của người dùng.

## Tương thích SketchUp

Nếu một module không quy định khác thì mặc định:

- Phiên bản tối thiểu hỗ trợ: SketchUp 2022.
- Ưu tiên dùng API có sẵn từ SketchUp 2022 nếu có thể.
- Không dùng API chỉ có ở SketchUp mới hơn nếu chưa kiểm tra tương thích.
- Khi hợp lý, tách phần gọi SketchUp Ruby API khỏi logic xử lý chung.
- Không phụ thuộc vào hành vi không được SketchUp công bố chính thức.

Nếu chưa chắc về khả năng tương thích, phải nêu rõ điểm chưa chắc thay vì tự đoán.

## Nguyên tắc viết code

Ưu tiên:
- code đơn giản;
- hành vi rõ ràng;
- method nhỏ, tập trung vào một nhiệm vụ;
- tên biến, class, method dễ hiểu;
- tách rõ UI, phần tương tác với SketchUp và logic lõi;
- giữ tương thích ngược khi hợp lý.

Hạn chế:
- abstraction không cần thiết;
- logic bị lặp lại;
- global state khó kiểm soát;
- hằng số không có giải thích;
- refactor lớn không liên quan trong lúc sửa bug;
- tính năng, tuỳ chọn hoặc cấu hình "mềm dẻo" chưa ai yêu cầu;
- xử lý lỗi cho tình huống không thể xảy ra bên trong code. Vẫn phải kiểm tra tại ranh giới: dữ liệu người dùng, trạng thái model SketchUp, kết quả API, file, mạng.

Nếu module hiện tại đã có style riêng thì tuân theo style đó, kể cả khi bạn sẽ làm khác, trừ khi có lý do rõ ràng và nêu lý do đó.

Viết xong mà thấy có thể ngắn gọn hơn nhiều thì viết lại phần vừa viết. Quy tắc này không áp dụng cho code đang hoạt động có sẵn.

## Quy tắc giao diện

Các plugin VGD có thể sử dụng `UI::HtmlDialog`.

Khi chỉnh giao diện:
- giữ nguyên hành vi cũ nếu yêu cầu không nói phải thay đổi;
- giao diện nên gọn và thực dụng;
- không tự thiết kế lại những phần UI không liên quan;
- giao tiếp Ruby ↔ JavaScript phải rõ ràng;
- khi làm mới hoặc sửa lớn dialog HTML, theo chuẩn trong `shared/HUONG_DAN_THEME.md` mục 9 và `shared/vgd-ui/vgd-controls.css`: nút gạt 40 × 22 px, không hiện thanh cuộn dọc (chỉ giữ thanh ngang mảnh), hiệu ứng 150 / 180 / 220 ms đổi trên cùng một phần tử, ngăn trượt đẩy nội dung chứ không đè;
- phải kiểm tra dữ liệu người dùng trước khi áp dụng thay đổi lên model SketchUp.

## Kiểm thử và xác minh

Hiện tại chưa mặc định có một framework test chung cho toàn repository.

Với mỗi thay đổi, dùng phương pháp kiểm tra mạnh nhất có thể cho module đó.

Có thể bao gồm:
- kiểm tra cú pháp Ruby;
- unit test tự động;
- static check;
- script test riêng;
- kiểm tra thủ công trực tiếp trong SketchUp.

Không được nói rằng thay đổi đã được test trên SketchUp nếu thực tế chưa test trong SketchUp.

Luôn phân biệt rõ:
- đã xác minh tự động;
- đã xác minh thủ công;
- chưa xác minh.

### Tiêu chí thành công

Trước khi làm, xác định thế nào là xong và cách kiểm tra:

- Thêm validation: viết kiểm tra với dữ liệu sai trước, rồi làm cho đạt.
- Sửa bug: viết kiểm tra tái hiện lỗi trước, rồi sửa cho đạt. Nếu không khả thi (ví dụ chỉ tái hiện được trong SketchUp thật), nói rõ.
- Refactor: kiểm tra phải đạt cả trước và sau khi sửa.
- Kiểm tra là script hoặc test riêng của module, không thêm framework chung (xem "Quy tắc làm việc").
- Với việc nhiều bước, nêu kế hoạch ngắn, mỗi bước kèm cách kiểm tra: `1. [Bước] → kiểm tra: [cách]`. Lặp cho đến khi đạt.
- Phần chỉ kiểm được trong SketchUp thật thì ghi "chưa xác minh", không coi là đạt.

## Tài liệu

Tài liệu phải phản ánh đúng hành vi thực tế.

Các quyết định kiến trúc quan trọng nên được lưu trong `docs/`.

Không tạo tài liệu chỉ để tăng số lượng file. Ưu tiên ít tài liệu nhưng có giá trị, tránh nhiều file trùng lặp nội dung.

### Phiên bản, README và phát hành

- Mỗi lần gửi RBZ mới cho người dùng phải tăng phiên bản so với RBZ đã gửi trước đó, ví dụ 1.0.0 → 1.0.1; bản beta thì tăng số beta (beta.33 → beta.34). Không gửi hai RBZ khác nội dung mà cùng số phiên bản. Sửa số phiên bản ở mọi chỗ plugin ghi nó (xem mục "Thông tin plugin" trong `CLAUDE.md` của plugin).
- Plugin đã phát hành bản ổn định: bản gửi test cho thay đổi tiếp theo gắn hậu tố beta trên số phiên bản kế tiếp (1.2.2 → 1.2.3-beta.1, beta.2, …). Chỉ khi người dùng chốt mới bỏ hậu tố để thành bản ổn định (1.2.3), không tăng thêm số. Ghi chú phát hành và README dùng số phiên bản đích.
- Mỗi lần đổi phiên bản phải cập nhật `README.md` của plugin cho khớp (số phiên bản, tính năng, tên file cài, trạng thái kiểm thử) trong cùng commit.
- Mỗi lần cập nhật plugin xong (đã đạt kiểm tra) phải đóng gói và gửi RBZ cho người dùng test, kèm SHA-256; không chờ người dùng nhắc.
- Người dùng tự phát hành trên GitHub. Không tạo file hướng dẫn phát hành (kiểu `HOW_TO_RELEASE.md`) trong plugin.
- Khi hướng dẫn người dùng tạo Release, đưa **một link tạo Release điền sẵn** để họ chỉ việc mở link, kéo thả file RBZ rồi bấm Publish: `https://github.com/vuongpentax/VGD_Plugins/releases/new?tag=<tag>&target=main&title=<tiêu đề>&body=<nội dung RELEASE_NOTES_v<phiên bản>.md>` (mã hóa URL toàn bộ giá trị, kiểm tra giải mã lại đúng nội dung; ghi chú phải đã nằm trên `main`). GitHub không đính kèm file qua link nên phải nhắc kéo thả đúng tên file RBZ. Gửi kèm file RBZ, SHA-256 và gợi ý bước cuối (báo "xong" để cập nhật `center-update.json`/catalog).

## Quy tắc Git

Mỗi commit nên tập trung vào một thay đổi rõ ràng.

Commit message phải ngắn gọn và mô tả đúng thay đổi.

Không commit:
- mật khẩu hoặc thông tin đăng nhập;
- file tạm;
- package sinh tự động nếu không có lý do rõ ràng;
- cache cục bộ;
- output từ test;
- dependency tải về từ bên ngoài.

Sau khi hoàn thành một thay đổi và đã kiểm tra, tự commit và push lên nhánh làm việc được chỉ định. Không cần chờ yêu cầu riêng. Không push sang nhánh khác.

Chỉ tạo pull request khi được yêu cầu.

Không tự merge vào nhánh chính, phát hành (release), xóa nhánh hoặc rewrite lịch sử Git nếu chưa được yêu cầu rõ ràng.

## Quy tắc an toàn

Trước các thao tác có tính phá huỷ hoặc phạm vi lớn, phải dừng lại và kiểm tra trước.

Không được:
- xóa hàng loạt file khi chưa có lý do rõ ràng;
- ghi đè code cũ đã migrate một cách mù quáng;
- đổi tên hàng loạt file trong lúc làm một việc không liên quan;
- chỉnh nhiều plugin không cần thiết;
- xoá hoặc bỏ các thay đổi hiện có mà không phải do task hiện tại tạo ra.

Nếu phát hiện đang có thay đổi chưa commit, phải bảo toàn chúng trừ khi được yêu cầu rõ ràng.

## Chiến lược migrate code cũ

Các project VGD cũ phải được đưa vào repository từng plugin một.

Với mỗi plugin:

1. Đưa source code vào.
2. Audit cấu trúc hiện tại.
3. Xác định dependency.
4. Thiết lập baseline.
5. Kiểm tra hành vi hiện tại nếu có thể.
6. Chỉ dọn dẹp những gì thực sự cần thiết.
7. Commit một baseline ổn định.
8. Sau đó mới tiếp tục phát triển.

Không đưa toàn bộ code VGD cũ vào một lần.

## Hành vi của Agent

Khi yêu cầu chưa rõ, phải kiểm tra repository và dùng context hiện có của project trước khi tự suy đoán. Nếu vẫn chưa rõ thì hỏi (xem "Suy nghĩ trước khi viết code").

Với task lớn, ưu tiên quy trình:

```text
ĐỌC → LẬP KẾ HOẠCH → CHỈNH SỬA → KIỂM TRA → REVIEW
```

Với lỗi nhỏ, rõ ràng thì không cần tạo quy trình quá phức tạp.

Luôn ưu tiên:
- bảo toàn hành vi đang hoạt động;
- giữ repository sạch;
- giữ cấu trúc dễ hiểu;
- tránh thay đổi ngoài phạm vi yêu cầu.