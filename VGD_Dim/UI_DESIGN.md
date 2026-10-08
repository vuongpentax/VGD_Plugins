# VGD Dim · giao diện 3.3

Sidebar rộng 190 px; trên cửa sổ ≤620 px dùng rail icon 58 px. Main độc lập cuộn; footer trạng thái cố định. Phạm vi là một DOM card duy nhất, chuyển giữa sidebar và đầu main khi đổi kích thước; lựa chọn không mất khi đổi tab.

| Tab | Bảng và tùy chọn | Phạm vi | Lệnh chính |
|---|---|---|---|
| Smart Dim | Mặt theo trục tủ; mặt cắt đang bật; ngang/đứng; offset 2 cấp; lọc; gắn Scene | Group/Component đang chọn | Smart Dim cho tủ đang chọn |
| Font & cỡ chữ | Model Info Dimensions/Text; làm mới Dim; native Update selected | Card chung cho rebuild; chọn trực tiếp cho native | Làm mới / áp mẫu |
| Kiểu dáng | Loại Dim/Text/Label; bật màu; endpoint; hướng/vị trí chữ; leader; Auto-Style | Card chung | Áp style |
| Preset | Chọn, đặt tên, lưu; xóa bằng bấm lại | Trên máy | Lưu |
| Animation | Thời gian chuyển/dừng, loop, bật/tắt | Toàn model | Bật / tắt |
| Đơn vị | inch/feet/mm/cm/m, số lẻ, ký hiệu, mở chữ Dim dạng số | Toàn model | Áp đơn vị |

## Tokens

- Palette T+ / VGD: copper `--accent`, nút `--solid`, hover `--solid-h`.
- Sidebar/header: `--rail`, `--rail-ink`, `--rail-mute`, `--rail-line`, `--rail-field`.
- Main/card: `--paper`, `--panel`, `--ink`, `--mute`, `--line`, `--field`, `--wash`.
- Trạng thái: `--bad`, `--warn`, `--focus`. Radius 6 px cho card, 4 px cho control.
- Sáng: main #f7f7f5, card trắng, sidebar #2b2b2b. Tối: main #20201e, card #2a2926, sidebar #161715. Không dùng color-mix; phù hợp CEF cũ của SU2022.

Tab có SVG dạng nét, nhãn/title, aria-controls/selected, roving tabindex. Arrow/Home/End đổi tab; Tab tiếp tục vào control. Các input có label. Busy khóa nút thao tác; báo lỗi/kết quả inline, không popup. Theme lưu localStorage riêng `vgd.dim.theme`.

## Kiểm tra

Edge headless kiểm tra click/keyboard, callback payload, scope chung, busy, theme lưu lại, 6 bảng ở 760×760 / 540×700 / 360×600. Screenshot nằm ở outputs/vgd_dim_sidebar_*.png. Đã xem giao diện Smart sáng desktop/mobile và Style tối. Main/aside có cuộn khi cửa sổ nhỏ; không hứa toàn bộ control cùng hiện trên một màn hình.
