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

File MP4 không lưu trong git. Phần dùng chung: `common.css`, `common.js`. Script quay: `render.js`.

## Chạy lại

Cần Node.js, Playwright (có Chromium) và ffmpeg. Từ gốc repo:

```bash
node tools/video-huong-dan/render.js tools/video-huong-dan/scene-03-huong-dan.html 03-mo-huong-dan.mp4 30
```

Tham số: file HTML, file MP4 đầu ra, số khung hình mỗi giây (mặc định 30). Mỗi đoạn mất khoảng 1–3 phút.

Xem trực tiếp (bản nhúng): mở file HTML trong trình duyệt và thêm `?play` vào đường dẫn; đoạn tự chạy lặp. Chưa nhúng vào VGD Center.

## Thông số

- Video: 1920×1080, 30 khung/giây, H.264 (yuv420p, crf 18). Trang vẽ ở 1280×720 và quay với hệ số 1,5.
- Giao diện: theme tối của VGD (`shared/vgd-theme`), font Manrope bundle sẵn.
- Chuyển động: phong cách Corporate của `motion-design-skill`, easing `cubic-bezier(0.2, 0, 0, 1)`, không nảy.
- Chỉ chữ trên màn hình (tiếng Việt), không giọng đọc, không nhạc.
- Làm tối nền để làm nổi vùng cần bấm; phóng to khi cần chú ý kỹ.

## Giới hạn

- Giao diện được vẽ lại từ mã nguồn plugin, chưa đối chiếu với SketchUp thật. Icon plugin là ô trống. Số liệu trong khung kết quả (ví dụ `Đã chép: 4 mục`, tên `TenPlugin`) chỉ là ví dụ.
- Hộp thoại gốc của SketchUp và Windows (xác nhận gỡ, Nạp ngay, lưu file) vẽ gần giống; chữ nút (Có/Không, Lưu/Hủy) phụ thuộc ngôn ngữ hệ điều hành.
- Chữ trong khung kết quả lấy từ `manager/text.rb`, `dialog.html`. Giao diện Center đổi thì phải sửa lại đoạn tương ứng.
- Tên và phiên bản của plugin trong ví dụ (VGD Dim, VGD Scenes...) không phải dữ liệu thật của catalog.
