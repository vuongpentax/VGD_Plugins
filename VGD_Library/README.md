# VGD_Library 1.1.2-beta.2

Prerelease: tự kiểm tra cập nhật mỗi 24 giờ và có lệnh thủ công. SketchUp hỏi trước khi mở trang tải RBZ; cài qua Extension Manager rồi khởi động lại. Nguồn JSON cập nhật tự cấu hình vẫn độc lập.

Plugin SketchUp độc lập của VGD: thư viện vật liệu **ảnh/SKM**, thư viện model **SKP**, kho Drive đồng bộ và bộ công cụ map. Yêu cầu **SketchUp 2022 trở lên**. Đây là bản beta: phép tính và giao diện đã kiểm tra tự động, **chưa kiểm chứng trong SketchUp thực tế hoặc trên macOS**.

## Cài đặt và nối kho của bạn

1. Vào **Extensions → Extension Manager → Install Extension**, chọn `VGD_Library_v1.1.2-beta.2.rbz`.
2. Nếu đã cài bản cũ, lưu bản vẽ, đóng tất cả cửa sổ SketchUp và mở lại sau khi cập nhật.
3. Mở **Extensions → VGD_Library → Thư viện vật liệu**; bật toolbar VGD_Library trong View → Toolbars nếu cần.
4. Bấm **+ Kho vật liệu Drive 03 MTL**. Plugin dùng đường dẫn đồng bộ đã xác minh trên máy hiện tại:

   `G:\Other computers\My Computer\00 BO CAI HE THONG\02 SU\03 MTL`

   Nếu đường dẫn không có trên máy khác, plugin mở hộp chọn thư mục Drive đã đồng bộ. Google Drive for desktop phải đang chạy; tệp cần truy cập được để tô. Có thể đặt thư mục khả dụng offline từ Drive for desktop.
5. Thêm kho model bằng nút **+** tại Thư mục nguồn, chọn thư mục chứa SKP rồi chuyển sang **Thư viện model**.

[Kho Drive 03 MTL](https://drive.google.com/drive/folders/1kv6qYmOVx0es-3KGNiFExvkZhj4f_j-k) hiện chỉ chứa vật liệu. Kiểm kê metadata ngày 04/10/2026: **5.594 tệp hỗ trợ** (2.241 SKM, 1.788 PNG, 1.558 JPG, 7 JPEG), 19 nhóm cấp đầu, 2 gói RAR/ZIP. Đây là số tệp, có thể gồm preview/bản trùng; không phải số vật liệu duy nhất. Không tải nội dung các gói nén để kiểm kê.

RAR/ZIP/7Z được báo là chưa giải nén và không xuất hiện thành mẫu để tô. Bạn tự giải nén/sắp xếp sau, rồi bấm **Làm mới**; nhóm tự lấy theo thư mục con. Nếu đổi vị trí gốc, bỏ nguồn cũ và thêm nguồn mới. Yêu thích gắn với đường dẫn, nên tệp đổi đường dẫn có thể cần đánh dấu lại. Bỏ nguồn chỉ bỏ khỏi plugin.

Plugin không đổi chia sẻ, giải nén hay sắp xếp kho Drive. Tài khoản Drive của Codex không chuyển sang SketchUp; kho riêng tư được đọc qua Drive for desktop. RBZ chứa cấu hình đường dẫn dự kiến, không chứa kho vật liệu của bạn.

## Thư viện

- Nhiều nguồn local/Drive; quét thư mục con theo đợt; tìm tên/mã/nhóm không dấu; lọc nhóm, sắp xếp, yêu thích, phân trang 60 mẫu; giới hạn 20.000 tệp mỗi lần quét. Bỏ thư mục ẩn/symlink, loại trùng nguồn lồng nhau.
- JPG/JPEG, PNG, BMP, TIF/TIFF, SKM và SKP. SKM đọc thumbnail trong ZIP hoặc ảnh cạnh tệp; SKP dùng thumbnail API SketchUp. TIFF/tệp lỗi có thể thiếu preview nhưng vẫn có thể thử tải bằng SketchUp.
- Tô vùng chọn hoặc bật xô sơn nếu chưa chọn đối tượng; tô lại; tô từng mặt trong group; vật liệu sẵn trong bản vẽ; đổi cỡ thật bằng mm; lưu SKM.
- Đặt SKP bằng chuột với nét preview; ←/→ xoay 90°, Esc thoát. Lưu một group/component thành SKP và thumbnail cạnh tệp. SKP lưu bởi phiên bản mới hơn có thể không mở được trong SketchUp 2022.
- Nguồn online riêng qua JSON HTTPS hoặc danh mục JSON local có URL tải HTTPS; tải khi dùng, kiểm tra SHA-256, lưu cache. Chưa có máy chủ VGD mặc định.

## Công cụ

Toolbar có 18 lệnh: thư viện vật liệu/model, tô lại, xoay 90°/từng mặt/random, random đoạn vân, thay vật liệu/đối tượng, xóa vật liệu, AUTO SCALE, phục hồi, Fix lồng map, Flowmap, Convert line, seamless, xuất ảnh phụ và làm mới danh mục. Bảng **Bộ công cụ** có thông số bổ sung.

- **Map:** góc nhập, random 0/90/180/270°, dịch vân giữ hướng, fit một ô ảnh theo khung mặt dọc cạnh dài nhất, phục hồi cỡ thật, reset UV mặc định. Xoay từng mặt: Ctrl+bấm nhập góc. UV chỉnh mặt trước; cỡ theo definition, scale instance tác động như trong SketchUp.
- **Thay vật liệu:** bấm A muốn giữ rồi B cần thay, selection/model; thay front/back/vỏ. Inspector cũng có thay nguồn bằng vật liệu hiện tại.
- **Thay đối tượng:** bấm A rồi B; thay B hoặc các đối tượng cùng mẫu. Giữ vị trí/tag/tên/thuộc tính instance, tùy chọn giữ kích thước. Sao chép giá trị DC tương thích và redraw khi Dynamic Components có sẵn; chưa bảo đảm mọi công thức DC riêng.
- **Fix lồng map:** kiểm tra mặt khác vật liệu vỏ; chọn mặt theo vỏ hoặc giữ ngoại hình của mặt rồi bỏ vỏ. Group VGD đã tô có observer theo dõi thay đổi vật liệu vỏ bằng công cụ native, hoạt động sau khi mở thư viện hoặc tô VGD; cần native QA Undo/timer.
- **Flowmap:** mở phẳng qua cạnh chung, mặt kề cùng vật liệu; tối đa 10.000 mặt; vòng kín có đường cắt UV. Không nối hai definition/group tách rời. Hướng bắt đầu lấy cạnh dài nhất của mặt đầu.
- **Convert line:** chọn ảnh Import, lượng tử màu/bỏ nền nối mép/dò đường kín/đơn giản hóa rồi dựng mặt màu trong group riêng. 128/256/512 pixel; giữ ảnh gốc, tùy chọn ẩn. Phù hợp logo/chữ/hình ít màu; polygon, không Bézier/PowerTRACE.
- **Seamless:** preview 3×3 ô, khử loang sáng/hòa viền, preset nhẹ/vừa/mạnh, bỏ qua ảnh đã liền, một/nhiều vật liệu, giữ cỡ thật. Có thể đổi vân; lệch viền 0 chỉ đánh giá pixel hai mép, không bảo đảm hoa văn hoàn hảo. 2048px cần đo hiệu năng native.
- **Ảnh phụ:** PNG Displacement, Specular, Normal OpenGL, Normal DirectX, AO; tham số gỗ/đá/vải/kim loại, relief và độ phân giải. Ước lượng từ ảnh màu, không phải bộ PBR đo đạc hoặc dữ liệu nhà sản xuất.

Lệnh sửa model dùng operation/Undo. Instance sửa được tách definition để bảo vệ bản không chọn; bỏ ẩn/khóa. Đang edit trong component dùng chung: đóng chế độ sửa rồi chọn vỏ. Đổi model khi dialog mở: bấm **Làm mới**; thao tác cũ bị chặn. Đổi cỡ/seamless trên một vật liệu ảnh hưởng mọi mặt dùng vật liệu đó.

## Danh mục online riêng

**+ Nguồn online** nhận URL JSON HTTPS; **Nhập danh mục online** nhận JSON local. Link thư mục Drive 03 MTL được chuyển sang kho local đã đồng bộ; các link thư mục Drive khác hiện hướng dẫn thêm thư mục đồng bộ. Plugin không tải trang Drive làm danh mục JSON. Nguồn trả HTML hoặc JSON lỗi chỉ hiện thông báo ngắn, giữ nguyên vùng thư viện. Schema ví dụ (phải thay URL/hash bằng dữ liệu thật):

```json
{
  "name": "Kho VGD",
  "items": [{
    "name": "Tên mẫu", "brand": "VGD", "category": "Gỗ", "format": "PNG",
    "url": "https://your-host.example/maps/wood.png",
    "sha256": "SHA-256 64 ký tự hex của tệp thật",
    "preview": "https://your-host.example/previews/wood.png",
    "width_mm": 1220, "height_mm": 2440
  }]
}
```

`format`, `url`, `sha256` bắt buộc; preview/brand/category/kích thước tùy chọn. SKP/SKM dùng cùng schema. Danh mục tối đa 5 MB/20.000 mẫu, download tối đa 250 MB; URL trả tệp trực tiếp, không phải trang xem Drive/trang đăng nhập. Kiểm tra cập nhật VGD cần mục `extension: {"version":"...","url":"https://...rbz"}` trong nguồn HTTPS tự cấu hình; chỉ mở link tải khi người dùng chọn, không auto-install.

Cache thumbnail/download/seamless: `%LOCALAPPDATA%\VGD_Library` hoặc `~/Library/Application Support/VGD_Library` trên macOS. Preferences `VGD_Library`, namespace `VGD::Library`.

## Phạm vi và kiểm chứng

Đã đối chiếu các nhóm tìm thấy trong N-TEXTURE-2.0.19. **Mã VGD mới độc lập**; lõi Texture/Seamless/DLL không đủ trong RBZ nên không xác nhận hành vi giống 100%. Xem [FEATURE_PARITY.md](FEATURE_PARITY.md). Không gọi server, sao chép account/license, tải/eval code hoặc kèm DLL/icon/giao diện N-TEXTURE.

Ruby: syntax 14 files; mô phỏng UV chữ nhật/fit/restore, kế thừa/isolation/locks/rollback/stale model, catalog Unicode/dedupe/RAR/favorites, Drive sync/cancel, Flowmap góc 90°, thay đối tượng/DC, audit/fix/swap, BGR/padding, seam boundary, Normal/AO phẳng, contours/logo có lỗ, schema online, SKM ZIP stored/deflate/CRC. Catalog WASI dùng cây tệp mô phỏng do giới hạn directory API Windows.

UI Playwright/Edge: library/model/online, pagination/search/HTML safety/favorites/actions/settings/Drive, 1120/720px, seamless preview/apply/preset. QA ảnh `outputs/` dùng dữ liệu mô phỏng. Kho thật được kiểm kê metadata bằng Node, chưa tô toàn bộ trong SketchUp. Checklist native: [CODEX_HANDOFF.md](CODEX_HANDOFF.md).

```powershell
node VGD_Library/dev/check_ruby.cjs
node VGD_Library/dev/test_ui.cjs
node VGD_Library/dev/package.cjs
```

Dependency từ `dev/node_modules`, VGD_Scenes/Cabinet, runtime Codex hoặc biến `VGD_NODE_MODULES`. Nếu thiếu, cài theo `dev/package.json`; RBZ không cần Node. `VGD_BROWSER_EXECUTABLE` chọn Chromium khác. Không tự cài/commit/push hoặc sửa dự án VGD khác.

API chính thức đã đối chiếu: [Face/UV](https://ruby.sketchup.com/Sketchup/Face.html), [ImageRep/pixel và UV sampling](https://ruby.sketchup.com/Sketchup/ImageRep.html), [ComponentDefinition/save_copy](https://ruby.sketchup.com/Sketchup/ComponentDefinition.html), [HTTP](https://ruby.sketchup.com/Sketchup/Http/Request.html).

## Sửa lỗi ngày 05/10/2026 — 1.1.1-beta.1

- Sửa SyntaxError khi đọc JSON có dấu nháy qua `Sketchup.read_default`: lưu JSON dưới dạng Base64 có prefix và key `json2_*`. Khôi phục các giá trị cũ từ đúng section VGD_Library trong PrivatePreferences.json trên Windows bằng JSON.parse, không eval dữ liệu đó. Bảo toàn folder, online sources, favorites và update URL nếu dữ liệu cũ còn hợp lệ.
- Callback mở picker được đánh dấu đã chạy và dừng timer trước khi xử lý, nên không mở thêm hộp thoại khi SketchUp gọi lại trong lúc modal còn mở. Callback download, seamless và observer cũng dùng cùng helper.
- Bộ quét chặn reentrant/stale callback, dừng timer và kết thúc trạng thái loading khi có lỗi, thay vì báo lỗi liên tục.
- Test regression tái hiện quoted-literal SyntaxError, cấu hình Unicode/quotes/backslashes, callback picker tái nhập và callback scan bị lỗi/stale. Ruby WASI không hỗ trợ Enumerator#next fibers: traversal thật được consume bằng to_a rồi adapter đưa entry cho timer orchestration.

Sau khi cập nhật, lưu bản vẽ, đóng tất cả cửa sổ SketchUp rồi mở lại. Không cần xóa cấu hình hoặc thư viện. Bản RBZ mới là `VGD_Library_v1.1.1-beta.1.rbz`.
