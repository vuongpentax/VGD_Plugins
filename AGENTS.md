# VGD Plugins — Quy định Repository

## Mục đích dự án

Repository này chứa hệ sinh thái công cụ và plugin SketchUp của VGD.

Repository đang được xây dựng lại từ một workspace sạch. Các plugin VGD cũ sẽ được đưa vào repository này dần dần, từng module một.

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
├── AGENTS.md
├── README.md
├── .gitignore
├── docs/
├── plugins/
├── tools/
├── tests/
└── archive/
```

Tất cả plugin SketchUp dùng thực tế phải nằm trong thư mục `plugins/`.

Mỗi plugin nên được tổ chức tương đối độc lập.

Ví dụ các module có thể được đưa vào sau này:
- VGD_Cabinet
- VGD_Dim
- VGD_Scenes
- VGD_BIM
- VGD_Library

Không tự tạo các module này nếu chúng chưa thực sự được chuyển vào hoặc bắt đầu phát triển.

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
- refactor lớn không liên quan trong lúc sửa bug.

Nếu module hiện tại đã có style riêng thì ưu tiên tuân theo style đó, trừ khi có lý do rõ ràng để thay đổi.

## Quy tắc giao diện

Các plugin VGD có thể sử dụng `UI::HtmlDialog`.

Khi chỉnh giao diện:
- giữ nguyên hành vi cũ nếu yêu cầu không nói phải thay đổi;
- giao diện nên gọn và thực dụng;
- không tự thiết kế lại những phần UI không liên quan;
- giao tiếp Ruby ↔ JavaScript phải rõ ràng;
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

Khi sửa bug, nên có kiểm tra hồi quy nếu khả thi.

## Tài liệu

Tài liệu phải phản ánh đúng hành vi thực tế.

Các quyết định kiến trúc quan trọng nên được lưu trong `docs/`.

Không tạo tài liệu chỉ để tăng số lượng file. Ưu tiên ít tài liệu nhưng có giá trị, tránh nhiều file trùng lặp nội dung.

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

Không tự commit hoặc push nếu chưa được yêu cầu rõ ràng.

Không rewrite lịch sử Git nếu chưa được yêu cầu rõ ràng.

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

Khi yêu cầu chưa rõ, phải kiểm tra repository và dùng context hiện có của project trước khi tự suy đoán.

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