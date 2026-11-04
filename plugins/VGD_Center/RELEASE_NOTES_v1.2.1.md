# VGD Center 1.2.1

- Thêm tab **Quản lý**: bật/tắt plugin bằng nút gạt (plugin tắt được cất vào thư mục riêng, không bị xóa, có hiệu lực sau khi khởi động lại SketchUp), bộ plugin để bật/tắt cùng lúc, chuyển plugin giữa SketchUp 2022 và 2024 (có sao lưu thư mục đích), xuất gói `.rbz` tổng. Áp dụng cho mọi plugin trong thư mục Plugins, không chỉ plugin VGD.
- Tab Quản lý có đầy đủ tiếng Anh: giao diện, thông báo, hộp xác nhận và hộp chọn file đổi theo ngôn ngữ trong Cài đặt.
- Giao diện đồng bộ: Tổng quan có câu giới thiệu mới và nút **Quản lý plugin**; tab Quản lý có hàng số liệu (đang bật, đã tắt, số bộ, thư mục đang quản lý) và bố cục giống các trang khác.
- VGD Center và VGD Plugin Manager không bao giờ bị tắt hay chuyển, kể cả khi tên thư mục khác hoa thường.
- Không đổi file trong Plugins khi VGD Center đang cài hoặc gỡ plugin.
- **VGD Plugin Manager được thay bằng tab Quản lý** và không còn trong Kho plugin. Bản Plugin Manager đã cài vẫn chạy nhưng Center không còn cập nhật hay gỡ giúp.
- **Dữ liệu plugin đã tắt và bộ plugin nay nằm trong `Plugins/VGD_Center/data`** (trước đây ở `VGD_PluginManager/data`). Center tự chuyển dữ liệu cũ sang chỗ mới khi SketchUp khởi động và khi mở tab Quản lý, không ghi đè và không xóa gì còn nội dung; mục trùng tên được giữ ở chỗ cũ và báo cho bạn. Nhờ vậy gỡ Plugin Manager cũ không làm mất plugin đang tắt.
- Nếu còn cài Plugin Manager cũ: sau khi dữ liệu đã chuyển, nó không còn thấy các plugin đã tắt. Hãy gỡ nó bằng Extension Manager. Bản cũ (beta.17) vẫn có thể tắt nhầm VGD Center cho tới khi gỡ.
- Sửa lỗi cửa sổ VGD Center (và cửa sổ hướng dẫn) tự biến mất sau mỗi thao tác hoặc khi bấm ra ngoài: chuyển sang kiểu cửa sổ `STYLE_DIALOG` như các plugin VGD khác, luôn nằm trên cửa sổ SketchUp. Cửa sổ Center không còn thu nhỏ/phóng to riêng như cửa sổ độc lập.
- Nhật ký lỗi của tab Quản lý: `%APPDATA%\SketchUp\VGD_Center\manager.log`.

Kiểm tra: tự động (6 bộ test trong `dev/`, 267 kiểm tra, trong đó 208 cho tab Quản lý gồm tiếng Anh và việc chuyển dữ liệu cũ; cú pháp Ruby và JavaScript; dựng giao diện trong trình duyệt ở hai theme, hai ngôn ngữ). Chưa kiểm thử thủ công trong SketchUp: hộp thoại, hộp chọn file, mở thư mục và việc dời file plugin thật chưa chạy trong SketchUp.
