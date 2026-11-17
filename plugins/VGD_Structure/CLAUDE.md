# VGD Structure

Quy tắc chung của repo: xem `CLAUDE.md` ở gốc repo. File này chỉ ghi phần riêng của plugin, và chỉ ghi điều kiểm chứng được từ mã hoặc tài liệu của plugin. Số phiên bản không ghi ở đây vì dễ lỗi thời: xem nơi giữ phiên bản ở mục "Thông tin plugin".

## Thông tin plugin

- Tên extension: VGD Structure. Namespace: `VGD::Structure`. Id dự kiến trong catalog của Center: `structure` (chưa thêm, thêm khi phát hành).
- Loader: `runtime/vgd_structure.rb` (nạp `vgd_structure/loader`).
- Phiên bản: hằng `VERSION` trong `runtime/vgd_structure.rb`. Tiêu đề README phải khớp. Đóng gói cần `RELEASE_NOTES_v<x.y.z>.md` (bản beta dùng chung ghi chú của bản chốt).
- SketchUp tối thiểu: 2022. Dữ liệu lưu mm.
- Dữ liệu trong model: dictionary `VGD_STRUCT` (dữ liệu nguồn của plugin và dữ liệu riêng trên khối dựng ra), cộng `VGD_BIM_ID` / `VGD_BIM_SOURCE` theo hợp đồng cầu nối (`docs/vgd_bim/BRIDGE.md`).

## Cấu trúc

- `runtime/vgd_structure/loader.rb` giữ danh sách `FILES` (thứ tự nạp, dùng chung cho lúc mở SketchUp và `VGD::Structure.reload`); `core/` logic thuần (`schema.rb` hằng số hợp đồng, `grid.rb` lưới / giao điểm / nhịp / ô, `axis_symbol.rb` kế hoạch ký hiệu trục); `column_types.rb` loại cột, `levels.rb` tầng (và sao chép lựa chọn), `column_plan.rb` kế hoạch cột (vị trí, cao độ, cảnh báo), `beam_types.rb` loại dầm, `beam_plan.rb` kế hoạch dầm, `state.rb` gộp và kiểm tra toàn bộ dữ liệu, `preview.rb` dữ liệu xem trước cho giao diện); `model_store.rb` đọc / ghi `VGD_STRUCT` trong model; `tag_store.rb` tạo tag theo bộ tag mẫu BIM; `grid_tag.rb` tag `!grid` và nét; `grid_builder.rb` vẽ lưới; `column_builder.rb` dựng cột; `beam_builder.rb` dựng dầm; `panel.rb` cửa sổ HtmlDialog; `html/` giao diện (`vgd-theme/` là bản sao của `shared/vgd-theme`, đồng bộ bằng `tools/sync_vgd_theme.py`); `assets/icons/`.
- `dev/`: `run_tests.rb` (chạy các test Ruby), `test_reload.rb`, `test_grid.rb`, `test_columns_plan.rb`, `test_grid_builder.rb`, `test_beams_plan.rb`, `test_column_builder.rb`, `test_beam_builder.rb`, `test_panel.rb`, `test_ui.cjs` (Playwright), `fake_sketchup.rb` (SketchUp giả lập), `ui_fixture.rb`, `package.py`, `stubs/` (bản giả `sketchup.rb`, `extensions.rb`).
- Kế hoạch và đặc tả: `docs/vgd_structure/PLAN.md`, `docs/vgd_structure/SPEC.md`.

## Kiểm thử

Từ `plugins/VGD_Structure`: `ruby dev/run_tests.rb`, và `node dev/test_ui.cjs` (Playwright, đặt `VGD_PLAYWRIGHT_MODULE` nếu cần). Test dùng SketchUp giả lập; phần dựng hình thật chưa xác minh trong SketchUp.

## Đóng gói

Từ gốc repo: `python plugins/VGD_Structure/dev/package.py <phiên bản>`. File `.rbz` và `outputs/` không đưa vào git.

## Tài liệu đọc trước khi sửa

- `docs/vgd_structure/PLAN.md` (kế hoạch, quyết định đã chốt), `docs/vgd_structure/SPEC.md` (dữ liệu và quy tắc hình học), `docs/vgd_bim/BRIDGE.md` (hợp đồng cầu nối).

## Quy tắc riêng

- Quy tắc hình học (vị trí cột lọt trong khung lưới: cột giữa tâm trên giao điểm, cột biên và cột góc tiếp giáp trục biên; dầm treo dưới sàn; không chồng khối) nằm ở `docs/vgd_structure/SPEC.md` mục 4 và 5; khi viết mã chỉ giữ ở MỘT bảng hằng số có giải thích, không rải trong nhiều chỗ.
- Mỗi tầng là riêng (cao độ, quy cách, phần đề xuất); không gom tầng giống nhau.
- Mỗi lần dựng là MỘT thao tác hoàn tác; kiểm tra lại mọi dữ liệu người dùng trước khi ghi vào model; không đụng dictionary của plugin khác; VGD ID do VGD_BIM cấp, plugin không tự sinh.
- Dữ liệu `VGD_STRUCT` là nguồn đúng; dựng lại thì hình theo dữ liệu, giữ VGD ID cũ.
- Lưới trục: `x_axes` là trục có VỊ TRÍ theo X (đường thẳng đứng trên mặt bằng, đánh số), `y_axes` theo Y (đường ngang, đánh chữ). Tên trục tối đa 4 ký tự, không trùng giữa cả hai phương (không phân biệt hoa thường). Giao diện chỉ gom dữ liệu; mọi dữ liệu qua `Grid.normalize!` / `AxisSymbol.options!` trước khi đụng model, tính xem trước cũng ở Ruby (một nguồn).
- Tag lưới là `!grid` theo bộ tag mẫu của VGD BIM (`Schema::GRID_TAG`: tên, màu, thư mục `! INFORMATION`); nét gạch dài - chấm chỉ đặt khi tag còn nét liền, không ghi đè nét người dùng đã chọn. Không dùng tag khác cho lưới nếu chưa được yêu cầu.
- Ký hiệu trục: vòng tròn 10 mm trên giấy nhân tỉ lệ (`AxisSymbol`), chữ 3D phẳng căn giữa theo hộp bao. Phần vẽ trong SketchUp (`GridBuilder`, `GridTag`) chưa xác minh trong SketchUp thật: `add_3d_text`, `Layer#line_style=`, `layers.add_folder` cần thử thật.
- Cột (cột mốc 2): tầng trên cùng chỉ có sàn (không có cột); cột tầng i cao từ cao độ sàn tầng i đến ĐÁY sàn tầng kế trên (`ColumnPlan`). Vị trí từng phương: auto (theo quy ước biên / giữa), center, min, max; `Levels` chỉ lưu phần khác mặc định. Mọi dữ liệu từ giao diện qua `State.normalize!` trước khi đụng model; lập kế hoạch toàn bộ TRƯỚC khi mở thao tác. Mỗi tầng một Group "Cột - <tên tầng>" (kind `columns`, mã tầng); cột là ComponentInstance dùng chung định nghĩa theo (rộng, sâu, cao). Tag theo bộ tag mẫu của BIM (`Schema::TAGS`), tag đã có giữ nguyên. Không đổi dữ liệu đã chốt: quy ước cột giữ / biên / góc, mỗi tầng riêng (không gom), dầm treo dưới sàn.
- Dựng cột dọn nhóm cột của tầng đã bị xóa khỏi danh sách (bỏ qua nhóm bị khóa). `ColumnBuilder` lưu luôn toàn bộ dữ liệu giao diện gửi lên (`ModelStore.write`); `GridBuilder` chỉ thay lưới và ký hiệu, giữ tầng và loại cột đã lưu (`ModelStore.write_grid`).
- Phần dựng trong SketchUp chưa xác minh trong SketchUp thật: `definitions.add`, `add_instance`, `pushpull`, chiều mặt đáy.
- Dầm (cột mốc 3): dầm TREO dưới sàn tầng kế trên (đỉnh dầm = đáy sàn = đỉnh cột, xuống `h`); tầng trên cùng không có dầm. Hai đầu dầm dừng ở MẶT CỘT của cột được chọn ở nút đó (cùng tầng); nút không có cột: dầm X tới trục, dầm Y dừng ở mặt dầm X chạm nút (xa nhất, `BeamPlan.end_of`). Vị trí ngang `p` (auto: trục biên đầu min, cuối max, giữa center; mặt ngoài dầm biên tiếp giáp trục biên). Picks dầm theo mã nhịp (`Grid.spans`: `x:<trục ngang>:<a>-<b>` / `y:<trục đứng>:<a>-<b>`, kèm `side`, `from_ref`, `to_ref`). Cột và dầm là hai nhóm riêng của mỗi tầng (kind `columns` / `beams`): dựng hoặc dọn mồ côi của loại này không đụng loại kia. Dầm dùng chung định nghĩa theo (phương, rộng, cao, dài), gốc ở tâm đầu dầm.
- Dữ liệu cột mốc 1 và 2 (chưa có `beam_types`, `beam_type`, `picks.beams`) phải vẫn đọc được: `State.normalize!` bổ sung mặc định. Thêm loại phần tử mới theo cùng cách (types + picks + plan + builder + preview + tab).
