# Đánh giá SketchUp 2022 cho VGD Reference beta.6

## Quyết định cho gói hiện tại

Minimum vẫn là **SketchUp 2023**. **SU2022 chưa được hỗ trợ.** Fallback bằng Tool mới có probe phát triển; chưa có backend ổn định để giữ ảnh thụ động khi người dùng dựng hình bằng công cụ native. Theo chỉ đạo mới, đóng gói beta.6 với mức hỗ trợ hiện có và tiếp tục SU2022 sau đó.

## API đã đối chiếu

| Phần | SU2022 | SU2024 / runtime hiện tại |
| --- | --- | --- |
| `Sketchup::Overlay`, `Model#overlays` | Chưa có | Có; tạo lớp phủ độc lập với công cụ đang dùng |
| `UI::HtmlDialog` | Có; thuộc dòng CEF 88 | Có; cần xác minh khác biệt CEF theo build |
| `View#draw2d` có texture/UV | Có từ SU2020 | Đang dùng; bản sửa UV mảng đã được xác nhận trên SU24 |
| `View#load_texture` | Yêu cầu có Ruby Tool trên stack; tự dọn texture khi Ruby Tool cuối cùng rời stack | Bỏ cơ chế tự dọn từ SU2023 để Overlay có thể vẽ |
| `Tool#draw` | Vẽ đồ họa khi Tool hoạt động | Edit Tool hiện tại có draw rỗng vì Overlay đảm nhiệm vẽ |
| Ruby | Dòng 2.7.2 kế thừa SU2021.1 | SU2024 nâng lên 3.2.2 |

Nguồn chính thức: [Overlay](https://ruby.sketchup.com/Sketchup/Overlay.html), [Model#overlays](https://ruby.sketchup.com/Sketchup/Model.html#overlays-instance_method), [View#load_texture](https://ruby.sketchup.com/Sketchup/View.html#load_texture-instance_method), [Tool#draw](https://ruby.sketchup.com/Sketchup/Tool.html#draw-instance_method), [release notes SU2021–2024](https://ruby.sketchup.com/file.ReleaseNotes.html).

## Vì sao không chỉ đổi minimum xuống 22

Runtime kế thừa trực tiếp `Sketchup::Overlay`, đăng ký `model.overlays` khi mở model, và tải texture ngay cả khi không có Edit Tool. Hạ min đơn thuần sẽ lỗi ở lớp Overlay hoặc tải texture. Sau khi thoát Edit, SU2022 còn có thể tự giải phóng texture mà cache không biết. Giữ hoặc tự kích hoạt lại Ruby Tool để vẽ có thể chiếm công cụ dựng hình của người dùng; đây chưa phải cách giữ quy trình hiện tại.

`core/compatibility.rb` kiểm tra phiên bản và capability; loader/main chặn nạp backend Overlay trên SU2022. Fixture khẳng định minimum 23 và từ chối model thiếu `overlays`.

## Probe và hướng làm tiếp

`dev/su2022_tool_probe.rb` độc lập với plugin runtime. Nạp script chỉ định nghĩa probe. Trên model trống trong SU2022, chạy:

```ruby
load('C:/Users/TUNG/Documents/Codex/VGD_Plugins/VGD_Reference/dev/su2022_tool_probe.rb')
VGDReferenceSU2022Probe.run
```

Kiểm tra ô bốn màu, Orbit bằng chuột giữa, chuyển sang Line/Select, rồi Esc. Báo cáo `outputs/su2022-probe/report.json` ghi version, Ruby/CEF, texture ID, draw và vòng đời Tool cùng số entity/trạng thái modified. Đối chiếu bằng ảnh chụp native; báo cáo không tự xác nhận GPU hiển thị đúng.

Bước tiếp theo là tách bộ vẽ khỏi subclass Overlay, tạo backend Tool riêng, tải lại cache khi Tool activate/resume, dọn khi deactivate và thông báo rõ phạm vi hiển thị trong chế độ tương thích. Nếu ảnh phải biến mất khi dùng công cụ dựng hình, cần chốt việc thay đổi quy trình trước khi gọi đó là hỗ trợ SU2022.

## Phạm vi đã xác minh

- Có thư mục cài `C:/Program Files/SketchUp/SketchUp 2022` trên máy. Chưa chạy probe trong ứng dụng; chưa biết build/Ruby thực tế của bản cài này.
- Cú pháp runtime/probe và fixture được kiểm tra bằng Ruby 3.2 WASM. Không coi đây là xác minh bằng Ruby 2.7 của SU2022.
- GUI beta.6 kiểm tra bằng Edge headless; hiển thị ảnh thật đã được người dùng xác nhận trong SU24 ở bản sửa beta.5.
