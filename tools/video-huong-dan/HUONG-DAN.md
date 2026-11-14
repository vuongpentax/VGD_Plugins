# Animation hướng dẫn VGD Center

Bảy đoạn animation ngắn hướng dẫn dùng VGD Center. Mỗi đoạn là một trang HTML tự chạy theo thời gian; MP4 được tạo bằng cách quay từng khung hình rồi ghép bằng ffmpeg. Kế hoạch và các quyết định: `docs/KE_HOACH_VIDEO_HUONG_DAN.md`.

## Danh sách đoạn

| File xuất | Mã nguồn | Nội dung | Dài |
|---|---|---|---|
| `01-cai-plugin.mp4` | `scene-01-cai-plugin.html` | Cài plugin từ Kho | 25 giây |
| `02-cap-nhat-go.mp4` | `scene-02-cap-nhat-go.html` | Cập nhật và gỡ plugin | 25 giây |
| `03-mo-huong-dan.mp4` | `scene-03-huong-dan.html` | Mở Hướng dẫn của plugin | 15 giây |
| `04-quan-ly-bat-tat.mp4` | `scene-04-quan-ly-bat-tat.html` | Tab Quản lý: bật/tắt, Nạp ngay | 25 giây |
| `05-chuyen-plugin.mp4` | `scene-05-chuyen-plugin.html` | Chuyển plugin giữa hai bản SketchUp | 30 giây |
| `06-xuat-rbz.mp4` | `scene-06-xuat-rbz.html` | Xuất gói .rbz tổng | 20 giây |
| `07-cai-dat.mp4` | `scene-07-cai-dat.html` | Cài đặt: ngôn ngữ, tự cập nhật | 15 giây |

Hoạt ảnh của các plugin khác nằm trong thư mục riêng, đăng cùng trang `guides/<id>/`:

| File xuất | Mã nguồn | Nội dung | Dài |
|---|---|---|---|
| `image_importer-01-chon-anh.mp4` | `image_importer/scene-01-nhap-anh.html` | Image Importer: chọn ảnh và cách đặt | 30 giây |
| `image_importer-02-dinh-dang.mp4` | `image_importer/scene-02-dinh-dang.html` | Image Importer: định dạng và vị trí | 20 giây |
| `reference-01-them-anh.mp4` | `reference/scene-01-them-anh.html` | Reference: thêm và quản lý ảnh | 30 giây |
| `reference-02-chinh-anh.mp4` | `reference/scene-02-chinh-anh.html` | Reference: di chuyển, xoay và đổi kích thước ảnh | 30 giây |
| `reference-03-luu-y.mp4` | `reference/scene-03-luu-y.html` | Reference: lưu ý | 15 giây |
| `library-01-tim-to-vat-lieu.mp4` | `library/scene-01-tim-to.html` | Library: tìm và tô vật liệu | 30 giây |
| `library-02-dat-model.mp4` | `library/scene-02-dat-model.html` | Library: đặt model và lưu mẫu | 25 giây |
| `library-03-cong-cu-map.mp4` | `library/scene-03-cong-cu-map.html` | Library: công cụ map | 26 giây |

Ảnh mẫu là hình đơn giản dùng chung trong `samples/`; Ruby được mô phỏng qua `image_importer/ii.js` và `reference/ref.js` và `library/lib.js` (vân vật liệu mẫu là SVG đơn giản `samples/vl_*.svg`). Reference có thêm khung "khung nhìn SketchUp (minh họa)" vì ảnh nổi trên khung nhìn chứ không nằm trong bảng.

File MP4 không lưu trong git. Phần dùng chung: `common.css`, `common.js`. Script quay: `render.js`.

## Chạy lại

Cần Node.js, Playwright (có Chromium) và ffmpeg. Từ gốc repo:

```bash
node tools/video-huong-dan/render.js tools/video-huong-dan/scene-03-huong-dan.html 03-mo-huong-dan.mp4 30
```

Tham số: file HTML, file MP4 đầu ra, số khung hình mỗi giây (mặc định 30). Mỗi đoạn mất khoảng 1–3 phút. Script tự mở một máy chủ HTTP tạm ở gốc repo vì các trang nhúng giao diện Center thật bằng iframe (mở thẳng bằng `file://` sẽ không chạy).

Xem trực tiếp (bản nhúng): chạy `python3 -m http.server 8000` ở gốc repo, rồi mở `http://localhost:8000/tools/video-huong-dan/scene-03-huong-dan.html?play` trong trình duyệt; đoạn tự chạy lặp. Chưa nhúng vào VGD Center.

Giao diện Center đổi thì chỉ cần quay lại: video lấy hình trực tiếp từ mã hiện tại của plugin.

## Đăng lên GitHub Pages (hướng dẫn tương tác)

Mỗi plugin có một thư mục `tools/video-huong-dan/guides/<id>/chapters.json` (id trùng id trong `catalog.json`) liệt kê tiêu đề, các chương (đoạn hoạt ảnh và thời lượng) và, nếu cần, thư mục web của plugin (`web`) để chép lên site. Trang `index.html` được sinh từ mẫu chung `guides/_template.html`, nên không phải viết lại giao diện cho từng plugin. Hiện có `guides/center/`: 7 chương, bấm chương nào thì hoạt ảnh chạy trực tiếp trên giao diện Center, có `?bai=<số>` để mở thẳng một chương.

Mã dùng chung: `common.js` (sân khấu, camera, con trỏ, chú thích, nhúng giao diện thật của một plugin bằng `mountApp`) và `center.js` (phần riêng của Center). Mỗi plugin khác có đoạn hoạt ảnh trong `tools/video-huong-dan/<tên thư mục>/`.

- Dựng thử: `python3 tools/video-huong-dan/build_site.py` tạo thư mục `_site/` (không commit). Script chỉ chép file web cần chạy và giữ nguyên đường dẫn tương đối, nên luôn khớp với mã hiện tại của Center.
- Đăng: `.github/workflows/pages.yml` tự dựng và đăng khi có thay đổi trên `main`. Bật một lần: Settings → Pages → Source: GitHub Actions. Địa chỉ: `https://vuongpentax.github.io/VGD_Plugins/guides/<id>/`.
- Thêm hướng dẫn cho plugin mới: tạo `guides/<id>/chapters.json` cùng các đoạn hoạt ảnh; không cần phát hành lại Center khi Center đã biết đọc `guide_url` trong `catalog.json` (phần này chưa làm).
- Cần có mạng để xem. Trang chạy script, nên chỉ nên mở trong cửa sổ không nối với Ruby (như cửa sổ hướng dẫn của Center).

## Thông số

- Video: 1920×1080, 30 khung/giây, H.264 (yuv420p, crf 18). Trang vẽ ở 1280×720 và quay với hệ số 1,5.
- Giao diện: chính `plugins/VGD_Center/vgd_center/dialog.html` (chế độ xem trước, theme tối, font Manrope bundle sẵn) và trang `guides/dim.html`, danh sách plugin lấy từ `catalog.json`. Chỉ con trỏ, chú thích, hộp thoại gốc của SketchUp/Windows và phần làm tối nền là vẽ thêm.
- Chuyển động: phong cách Corporate của `motion-design-skill`, easing `cubic-bezier(0.2, 0, 0, 1)`, không nảy.
- Chỉ chữ trên màn hình (tiếng Việt), không giọng đọc, không nhạc.
- Làm tối nền để làm nổi vùng cần bấm; phóng to khi cần chú ý kỹ.

## Giới hạn

- Trạng thái minh họa: phía Ruby của Center được mô phỏng bằng dữ liệu theo thời gian (ví dụ plugin nào đã cài, cái nào có bản mới, danh sách plugin ở tab Quản lý, bản cũ khi cập nhật). Cài, tải, gỡ, chuyển file không chạy thật. Số liệu trong khung kết quả (ví dụ `Đã chép: 4 mục`, tên `TenPlugin`) chỉ là ví dụ.
- Cửa sổ Center rộng 860 để vừa khung 16:9; kích thước mặc định thật là 560×700.
- Chưa đối chiếu với SketchUp thật. Hộp thoại gốc của SketchUp và Windows (xác nhận gỡ, Nạp ngay, lưu file) vẽ gần giống; chữ nút (Có/Không, Lưu/Hủy) phụ thuộc ngôn ngữ hệ điều hành. Chữ trong các hộp này lấy từ `manager/text.rb` và `main.rb`.
- Logo trong trang hướng dẫn hiện thiếu nét (ảnh `icon.svg` dùng làm thẻ `<img>` thiếu biến màu): đây là hành vi của chính trang hướng dẫn, chưa được sửa ở đây.
