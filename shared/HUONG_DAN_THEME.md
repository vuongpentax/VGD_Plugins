# Hướng dẫn theme VGD cho các plugin

Gói này gồm: quy tắc thiết kế, bộ theme dùng chung (`shared/vgd-theme/`), quy tắc icon, và công cụ đồng bộ (`tools/sync_vgd_theme.py`). Nguồn gốc là repo `vuongpentax/VGD_Plugins`, thư mục `shared/` và `tools/`.

## 1. Nguyên tắc chung

- **Một nguồn duy nhất:** sửa theme ở `shared/vgd-theme/`, không sửa bản copy trong từng plugin.
- **Mỗi plugin giữ một bản copy** trong thư mục dialog của nó, vì plugin phải chạy được khi không có repo.
- **Lần đầu mở:** theo chế độ sáng/tối của Windows.
- **Người dùng bấm nút:** lựa chọn được lưu theo key riêng của plugin và giữ cho lần mở sau.
- **Nút đổi theme:** một ký hiệu, không chữ. Hiện `☾` khi đang sáng (bấm để sang tối), `☀` khi đang tối (bấm để sang sáng).

## 2. Bảng màu (token)

Tên token và giá trị khớp với `vgd-theme.css`.

| Token | Tối (mặc định) | Sáng | Dùng cho |
|---|---|---|---|
| `--vgd-bg` | `#121212` | `#F7F7F5` | Nền cửa sổ |
| `--vgd-surface` | `#1E1E1E` | `#FFFFFF` | Thẻ, panel, điều hướng |
| `--vgd-elevated` | `#2B2B2B` | `#F0EEE9` | Header, nút nổi |
| `--vgd-border` | `#3A3A3A` | `#E5E5E5` | Viền, đường chia |
| `--vgd-text` | `#E2E8F0` | `#222222` | Chữ chính |
| `--vgd-muted` | `#A7B0BD` | `#6F6F6F` | Nhãn, chú thích |
| `--vgd-accent` | `#B48963` | `#B48963` | Màu nhấn, nút chính |
| `--vgd-accent-strong` | `#C8A98A` | `#8E6B4C` | Chữ nhấn, hover |
| `--vgd-tint` | `#372C24` | `#F3ECE5` | Vùng đang chọn |
| `--vgd-danger` | `#E79C91` | `#A73D36` | Xóa, lỗi |
| `--vgd-success` | `#A8C69D` | `#507247` | Thành công |
| `--vgd-on-accent` | `#121212` | `#FFFFFF` | Chữ trên nền nhấn |

Quy tắc dùng: nút chính dùng màu nhấn; nút phụ dùng nền trung tính và viền; nút xóa dùng màu `danger` và không được giống nút chính. Viền focus 2 px màu nhấn.

## 3. Cách áp vào một dialog

1. Chạy `python tools/sync_vgd_theme.py` từ thư mục gốc repo. Lệnh này copy `vgd-theme/` vào các plugin đã khai báo trong `TARGETS`.
2. Trong file HTML, thêm **trước** CSS riêng và JS riêng:
   ```html
   <link rel="stylesheet" href="vgd-theme/vgd-theme.css">
   <script src="vgd-theme/vgd-theme.js"></script>
   ```
3. Thêm `class="vgd-ui"` vào `<body>`.
4. Đặt nút đổi theme (rỗng, JS sẽ điền ký hiệu):
   ```html
   <button class="vgd-theme-btn" id="theme" type="button" aria-pressed="false"></button>
   ```
5. Sau khi DOM sẵn sàng, gọi:
   ```js
   VGDTheme.start({ key: 'vgd.<plugin>.theme', button: document.getElementById('theme') });
   ```
   `VGDTheme.current()` trả về `'dark'` hoặc `'light'` nếu cần biết theme đang dùng. Sự kiện `vgdtheme` được gửi mỗi lần đổi.
6. Thay mọi màu cứng bằng `var(--vgd-…)`. Không để màu hex trong CSS riêng của plugin.
7. Kiểm tra cả hai theme ở kích thước cửa sổ SketchUp thường dùng.

Kit đã cung cấp sẵn: `color-scheme`, font Manrope (bundle sẵn, không cần mạng), cỡ chữ 13 px cho nội dung, 18 px cho tiêu đề dialog (`h1`), 15 px cho tiêu đề mục (`h2`).

## 4. Hiện trạng các plugin

| Plugin | File dialog | Key lưu theme | Nút |
|---|---|---|---|
| VGD Dim | `runtime/VGD_Dim/dialog.js` | `vgd.dim.theme` | `#theme` |
| VGD Cabinet Draw | `runtime/VGD_Cabinet_Draw/dialog.html` | `vgd.cabinet_draw.theme` | `#themeBtn` |
| VGD Center | `VGD_Center/dialog.html` | `vgd-center-theme` | `#themeBtn` |
| VGD Scenes | `runtime/vgd_scenes/dialog.js` | `VGD.Scenes.Theme` | `#theme` |
| VGD Library | `runtime/vgd_library/dialog.js` và `seamless.js` | `VGD.Library.Theme` | `#themeToggle` |
| VGD Image Importer | `runtime/vgd_image_importer/dialog.js` | `vgd.image_importer.theme` | `#theme` |
| VGD BIM Lite | `runtime/vgd_bim_lite/html/app.js` | `VGD_BIM_theme` | `#theme` |
| VGD Reference | `runtime/vgd_reference/ui/web/app.js` | `vgd.reference.theme` | `#appearanceSettings` |
| VGD Package | `VGD_Package/ui/dialog.js` | `vgd-package-theme` | `#themeButton` |

**Quy tắc về key (đã chốt):**
- Plugin đang có: giữ nguyên key cũ, không đổi tên. Đổi tên sẽ làm người dùng mất lựa chọn đã lưu: họ mở lại sẽ thấy theme mặc định của Windows.
- Plugin mới hoặc làm lại từ đầu: dùng `vgd.<tên_plugin>.theme`, ví dụ `vgd.cabinet_draw.theme`.

## 5. Việc còn lại theo hiện trạng

Các file còn màu hex cứng (không tính bản thử và `guides/`):

- `plugins/VGD_Cabinet_Draw/runtime/VGD_Cabinet_Draw/dialog.html`
- `plugins/VGD_Center/VGD_Center/dialog.html`
- `plugins/VGD_Dim/runtime/VGD_Dim/dialog.css`
- `plugins/VGD_Image_Importer/runtime/vgd_image_importer/dialog.css`
- `plugins/VGD_Library/runtime/vgd_library/dialog.css`
- `plugins/VGD_Library/runtime/vgd_library/seamless.html`
- `plugins/VGD_Reference/runtime/vgd_reference/ui/web/style.css`

Các file `VGD_Cabinet/` (cũ, v4.5.x) cũng còn màu cứng, nhưng plugin này được ghi là không đưa vào đợt theme chung.

Kiểm tra nhanh: `grep -rlE "#[0-9A-Fa-f]{6}\b" plugins --include=*.css --include=*.html --include=*.js`

## 6. Quyết định đã chốt và việc còn mở

1. **Màu nhấn: `#B48963`** cho cả UI và icon. Tài liệu icon và file preview đã đổi sang `#B48963`. Icon đang nằm trong plugin vẫn dùng `#A67C58`, chưa đổi, cần duyệt riêng từng plugin.
2. **Danh sách plugin trong tài liệu thiết kế:** để bổ sung sau. Hiện chưa ghi Cabinet Draw, Center, Package, Reference.
3. **Key lưu theme:** giữ nguyên key của các plugin đang có, không đổi tên. Plugin mới dùng chuẩn `vgd.<tên_plugin>.theme`.

## 7. Trước khi phát hành

- `python tools/sync_vgd_theme.py --check` phải báo đủ số bản copy khớp (hiện là 9/9).
- Mở dialog trong SketchUp ở cả hai theme. Ghi rõ đã thử thủ công hay chưa, và chưa thử thì không được ghi là đã thử.
- Kiểm tra icon ở cỡ thật trên toolbar (xem `VGD_ICON_SYSTEM_RULES.md`).

## 8. Icon (tóm tắt)

- SVG `viewBox="0 0 24 24"`, nét khoảng 1.8 px, đầu nét và góc nối bo tròn.
- Nét chính: `#292B2D` khi nền sáng, `#F1EDE6` khi nền tối. Điểm nhấn `#B48963` ở cả hai nền (quyết định 1).
- Icon đã có trong plugin (ví dụ Library, Scenes, Dim, Reference) vẫn dùng `#A67C58`. Đổi các icon này là việc riêng, làm từng plugin.
- Không nền, không khung trang trí. Nhận ra được ở 16–24 px.
- Chỉ đưa vào plugin sau khi đã duyệt trong `VGD_ICON_SYSTEM_PREVIEW.html`.
