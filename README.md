# VGD Plugins

Kho mã các công cụ và plugin SketchUp thuộc hệ sinh thái VGD, hướng tới SketchUp 2022 trở lên. Windows là môi trường phát triển và kiểm thử chính.

## Trạng thái hiện tại

Kho mã hiện chứa mã nguồn của 10 plugin trong `plugins/`, được chuyển từ workspace cũ. Mỗi plugin có README, ghi chú phát hành và bộ kiểm tra riêng; xem README của từng plugin để biết cách chạy và trạng thái xác minh.

File `.rbz` (gói cài đặt) không được lưu trong git. Build lại bằng script của từng plugin hoặc lấy từ nơi phát hành.

## Cấu trúc

- `plugins/`: các plugin SketchUp dùng trong thực tế.
- `docs/`: tài liệu dự án và các quyết định kiến trúc quan trọng.
- `tools/`: công cụ hỗ trợ phát triển và bảo trì.
- `tests/`: kiểm thử và tài nguyên phục vụ xác minh.
- `archive/`: tài liệu và mã cũ được lưu trữ.

Đọc [AGENTS.md](AGENTS.md) trước khi đóng góp. Chỉ bổ sung module và công cụ khi có nhu cầu cụ thể.
