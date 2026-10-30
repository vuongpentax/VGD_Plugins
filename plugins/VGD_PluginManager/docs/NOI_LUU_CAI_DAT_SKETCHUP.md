# Nơi SketchUp lưu phím tắt và layout

Khảo sát ngày 2026-10-30 trên một máy Windows 10 có SketchUp 2022 và 2024, bằng `reg query`, `reg export` và liệt kê tên khóa trong file JSON. Chỉ ghi kết quả quan sát được; phần suy đoán được đánh dấu rõ. Chưa kiểm tra trên máy khác hay phiên bản SketchUp khác.

## 1. Phím tắt (đã xác nhận, cả 2022 và 2024)

1. Nằm trong `%APPDATA%\SketchUp\SketchUp <năm>\SketchUp\SharedPreferences.json`, mục `/Windows Only/Settings`: khóa `Num_Shortcuts` (số nguyên) và `Shortcut_1` đến `Shortcut_N` (chuỗi).
2. Registry **không** chứa danh sách phím tắt (chỉ có cờ `MFCToolBarParameters\ShortcutKeys`). Khóa `...\Shortcuts` mà plugin beta.4 trở về trước dùng **không tồn tại**.
3. Định dạng chuỗi: `"<c1> <c2> <c3> <phím> <lệnh>"`, ví dụ `"0 0 1 Z viewZoomExtents:"`, `"0 1 1 9 Camera/Next"`.
   1. Đã xác nhận: cờ thứ 2 là Alt, cờ thứ 3 là Shift (gán thử Alt+Shift+9 ra `0 1 1 9`; Shift+Z ra `0 0 1 Z`).
   2. Suy đoán, chưa xác nhận: cờ thứ nhất là Ctrl.
   3. Phần lệnh là tên selector (`selectLineTool:`) hoặc đường dẫn menu (`Edit/Make Group`).
4. Hai bản dùng cùng định dạng, nhưng nội dung độc lập (cùng số lượng 24 nhưng khác lệnh ở `Shortcut_24`).
5. File có khóa `timestamp` (Int64) ở cấp cao nhất và mục tên "Shared for All Computers". Chưa biết SketchUp có đồng bộ qua tài khoản hay dùng `timestamp` để quyết định ghi đè hay không.

### 1b. File `.dat` do nút Export phím tắt của SketchUp xuất ra (đã xác nhận trên một file 2022)

1. Mã hóa UTF-16 little-endian có BOM, xuống dòng CRLF. Có hai mục: `[Accelerator]` và `[File Locations]`.
2. `[Accelerator]`: dòng `Count=<n>` rồi n dòng, **mỗi dòng đúng định dạng của `Shortcut_N`** trong `SharedPreferences.json`: `"<ctrl> <alt> <shift> <phím> <lệnh>"`. Mẫu cho thấy cờ thứ nhất là Ctrl (ví dụ `1 0 1 S File/Save Incremental`, `1 1 0 S File/Save As...`), cờ thứ hai là Alt, cờ thứ ba là Shift. Tên phím gồm chữ, số, `F2`..., `Space`, và ký tự như `` ` ``, `,`, `.`, `;`, `'`, `/`.
3. Lệnh là tên hàm (`selectLineTool:`) hoặc **đường dẫn menu**, kể cả lệnh của plugin (`Extensions/d95design.com/Super Paint`, `Tools/Curic/Mirror/Mirror Tool`). Lệnh có thể chứa ký tự tiếng Việt (`Tools/One Click Tools/Ẩn`), nên khi ghi phải dùng UTF-8.
4. `[File Locations]` chứa đường dẫn riêng của máy (thư mục model, component, vật liệu...). Nhập nguyên file bằng nút Import của SketchUp có thể ghi đè các đường dẫn này bằng đường dẫn của máy khác.
5. File mẫu (xuất từ một tài khoản Windows khác trên SketchUp 2022) có 85 phím tắt, trong đó khoảng 20 trỏ vào menu của plugin, trong khi `SharedPreferences.json` của máy khảo sát chỉ có 24 phím tắt mặc định (không có phím của plugin). Suy đoán, chưa xác nhận: SketchUp xóa phím tắt của plugin không được nạp lúc thoát, giống cách nó xóa vị trí thanh công cụ. Phím tắt lưu theo đường dẫn menu nên **không bị ảnh hưởng bởi thứ tự nạp plugin** (khác với ID thanh công cụ).

### 1c. Rủi ro khi ghi lại `SharedPreferences.json`

1. File chứa nhiều số thực dạng `24.0`, `150.0`, `1.0` (9 giá trị ở mỗi file mẫu). Đọc cả file rồi ghi lại bằng `JavaScriptSerializer` sẽ đổi chúng thành `24`, `150`, `1`. Nên chỉnh theo dòng: chỉ thay các dòng `Num_Shortcuts` và `Shortcut_N` (mỗi mục một dòng, thụt lề 12 khoảng trắng, khóa xếp theo thứ tự chữ), giữ nguyên mọi byte còn lại.
2. Khóa `timestamp` ở cấp cao nhất là thời điểm lưu cuối (mili giây từ 1970), do SketchUp ghi mỗi lần thoát. Chưa rõ có dùng để đồng bộ hay không.
3. Không sao chép cả mục `Windows Only`: `UserLibrariesComponentBrowser1` chứa đường dẫn riêng của từng bản. Chỉ chép các khóa phím tắt.

## 2. Layout SketchUp 2022

1. Registry `HKCU\Software\SketchUp\SketchUp 2022\`:
   1. `Workspace\MFCToolBar-<ID>`: thanh công cụ gốc (có `Name`, `Buttons`...).
   2. `Workspace\Pane-<ID>`, `BasePane-<ID>`, `DockingManager-127`, `ControlBars-Summary`, `WindowPlacement`: vị trí và dock.
   3. `RubyWorkspace\Pane-<ID>`, `BasePane-<ID>`: thanh công cụ của plugin Ruby. Mỗi mục có `ID`, `RectRecentDocked`, `RecentFrameAlignment`, `RecentRowIndex`, `IsFloating`, `MRUWidth`, `PinState`. **Khóa chỉ là số ID, không có tên plugin.**
2. `%LOCALAPPDATA%\SketchUp\SketchUp 2022\SketchUp\PrivatePreferences.json`, mục `/This Computer Only`: `RubyWorkspace\RubyToolBar-<ID>/DockBarId` và `Workspace\Trays\Tray-N\Pane-M/PaneId`.
3. Chưa biết chỗ nào là nguồn chính khi hai nơi khác nhau.

## 3. Layout SketchUp 2024

1. **Không có `Workspace` hay `RubyWorkspace` trong registry** (chỉ có `Recent File List`).
2. `%LOCALAPPDATA%\SketchUp\SketchUp 2024\SketchUp\PrivatePreferences.json`, mục `/This Computer Only`:
   1. `MainWindow/DockWidgetState`: chuỗi hex (khoảng 18 KB) giải mã ra văn bản JSON (đầu chuỗi `7b0a2020...` là `{`, xuống dòng).
   2. `MainWindow/ToolBarState` (khoảng 2,4 KB) và `ToolbarSettings/ToolbarState` (khoảng 4 KB): chuỗi hex nhị phân. Suy đoán, chưa xác nhận: dữ liệu trạng thái dock của Qt.
   3. `QtRubyWorkspace\RubyToolBar-<ID>/Tray`, `Workspace\Trays\Tray-N\Pane-M/PaneId`, `ToolbarSettings` (`LargeIcons`, `ToolTipEnabled`).
3. Phần "This Computer Only" cho thấy SketchUp chủ ý lưu layout riêng cho từng máy.

## 4. Vì sao layout bị lộn xộn khi bật/tắt plugin

1. **Quan sát (đã xác nhận trên 2022):** trước khi xóa plugin, `RubyWorkspace` có 96 mục `Pane` và 96 `BasePane`; sau khi mở và thoát SketchUp mà không có plugin, còn 3 mục mỗi loại. SketchUp xóa vị trí của thanh công cụ plugin không được nạp lúc thoát.
2. **Suy đoán (chưa xác nhận):** ID thanh công cụ Ruby được cấp theo thứ tự tạo, bắt đầu từ 59648 (trong JSON hiện tại 12 thanh công cụ có ID liên tiếp 59648 đến 59659 ở cả hai bản). Nếu đúng, tắt một plugin làm dịch ID của các plugin nạp sau nó, và vị trí gắn nhầm thanh công cụ.
3. Cách kiểm chứng: so sánh ID của cùng một thanh công cụ ở hai lần chạy với bộ plugin khác nhau.

## 5. Hệ quả cho plugin VGD_PluginManager

1. Code chuyển phím tắt và thanh công cụ ở bản beta.4 trở về trước dùng khóa registry sai, nên không có tác dụng. Cần làm lại theo mục 1 (phím tắt) và mục 2, 3 (layout).
2. SketchUp ghi đè các file này khi thoát, nên chỉ ghi được khi SketchUp đã đóng.
3. Ghi vào `PrivatePreferences.json` rủi ro hơn vì file chứa nhiều thiết lập khác; phải sao lưu và chỉ sửa đúng khóa cần thiết.
4. Layout là "chỉ cho máy này": chuyển sang máy khác có thể lệch (màn hình, bộ plugin, thứ tự nạp).
