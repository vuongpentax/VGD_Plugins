# Graph Report - VGD_Scenes  (2026-11-26)

## Corpus Check
- 53 files · ~48,095 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 7 file(s) not represented in the graph (top: .css 3, (none) 2, .woff2 2)

## Summary
- 718 nodes · 1264 edges · 54 communities (29 shown, 25 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 42 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6808f66b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- .dispatch
- dialog.js
- VGD::Scenes::ExportJob
- Geom::Vector3d
- VGD::Scenes::SceneTransfer
- UI::HtmlDialog
- VGD Scenes 1.6.2-beta.3 — SketchUp 2022–2026.2
- VGD::Scenes::SectionSet
- Sketchup
- Sketchup::Camera
- UI
- Bàn giao VGD Scenes
- Sketchup
- VGD::Scenes
- package.json
- Sketchup::Entity
- .apply
- VGD::Scenes::FrameTool
- check_ruby27.py
- Sketchup::SectionPlane
- Sketchup::Model
- Sketchup::Page
- test_cleanup_ui.cjs
- VGD Scenes
- check_ruby.cjs
- product
- test_flow_ui.cjs
- test_frame_ui.cjs
- test_refresh_ui.cjs
- test_scene_workflow_ui.cjs
- Nghiên cứu Smart Camera View 3 cho VGD Scenes
- vgd-theme.js
- test_ui.cjs
- VGD::Scenes::TitleBlock
- Sketchup::View
- test_sheet_layout.rb
- .entities
- VGD
- VGD
- RELEASE_NOTES_v1.5.3-beta.3.md
- RELEASE_NOTES_v1.5.3-beta.4.md
- RELEASE_NOTES_v1.6.0.md

## God Nodes (most connected - your core abstractions)
1. `VGD::Scenes::SceneStore` - 24 edges
2. `VGD::Scenes::SceneTransfer` - 24 edges
3. `VGD::Scenes` - 23 edges
4. `Geom::Vector3d` - 20 edges
5. `Sketchup` - 20 edges
6. `receive()` - 20 edges
7. `Bàn giao VGD Scenes` - 19 edges
8. `Sketchup::Camera` - 17 edges
9. `UI` - 16 edges
10. `VGD::Scenes::FrameTool` - 16 edges

## Surprising Connections (you probably didn't know these)
- `product()` --calls--> `Geom::Point3d`  [EXTRACTED]
  dev/test_engine.rb → dev/fixture.rb
- `product()` --calls--> `Geom::BoundingBox`  [EXTRACTED]
  dev/test_engine.rb → dev/fixture.rb
- `product()` --calls--> `Sketchup::Group`  [EXTRACTED]
  dev/test_engine.rb → dev/fixture.rb
- `product()` --calls--> `Sketchup::Definition`  [EXTRACTED]
  dev/test_engine.rb → dev/fixture.rb
- `product()` --calls--> `Sketchup::Entities`  [EXTRACTED]
  dev/test_engine.rb → dev/fixture.rb

## Import Cycles
- None detected.

## Communities (54 total, 25 thin omitted)

### Community 0 - ".dispatch"
Cohesion: 0.06
Nodes (12): VGD, VGD::Scenes, VGD::Scenes::SceneFrame, VGD::Scenes::Geometry, menu(), VGD, VGD::Scenes, VGD::Scenes::SaveGuard (+4 more)

### Community 1 - "dialog.js"
Cohesion: 0.07
Nodes (71): addCutRow(), applyCamera(), applyRatioInput(), applySetPreset(), cameraMode(), chipText(), clearTransfer(), closeModal() (+63 more)

### Community 2 - "VGD::Scenes::ExportJob"
Cohesion: 0.09
Nodes (15): Geom, Geom::Bounds2d, Layout, Layout::Document, Layout::Image, Layout::Page, Layout::PageInfo, Layout::Pages (+7 more)

### Community 3 - "Geom::Vector3d"
Cohesion: 0.09
Nodes (4): Geom::BoundingBox, Geom::Point3d, Geom::Transformation, Geom::Vector3d

### Community 4 - "VGD::Scenes::SceneTransfer"
Cohesion: 0.17
Nodes (3): VGD, VGD::Scenes, VGD::Scenes::SceneTransfer

### Community 5 - "UI::HtmlDialog"
Cohesion: 0.07
Nodes (5): UI, UI::Command, UI::HtmlDialog, UI::Menu, UI::Toolbar

### Community 6 - "VGD Scenes 1.6.2-beta.3 — SketchUp 2022–2026.2"
Cohesion: 0.07
Nodes (24): Clipping — thí nghiệm riêng, chưa tích hợp, Bỏ khung xám trước khi gửi SKP (1.2.1), Chuyển góc scene từ A sang B, Cách dùng, Cập nhật view bằng một nút, Dọn gọn và an toàn preview (1.5.2), Giao diện gọn và thao tác scene (1.5.0), Khung tự lưu và camera xem trước (1.3.0) (+16 more)

### Community 7 - "VGD::Scenes::SectionSet"
Cohesion: 0.12
Nodes (7): VGD, VGD::Scenes, VGD::Scenes::ScalePlan, VGD::Scenes::SectionSet, VGD, VGD::Scenes, VGD::Scenes::SheetLayout

### Community 8 - "Sketchup"
Cohesion: 0.08
Nodes (5): Geom, Numeric, Sketchup, Sketchup::FakeModel, SketchupExtension

### Community 9 - "Sketchup::Camera"
Cohesion: 0.10
Nodes (6): VGD, VGD::ScenesClippingLab, Sketchup::Camera, VGD, VGD::Scenes, VGD::Scenes::CameraControl

### Community 10 - "UI"
Cohesion: 0.09
Nodes (3): UI, UI::Command, UI::Toolbar

### Community 11 - "Bàn giao VGD Scenes"
Cohesion: 0.10
Nodes (20): 1.5.0 · Sidebar, preview mặt cắt, thao tác nhiều scene, 1.5.2 · Hợp nhất bản cài 1.5.1, dọn CSS/DOM và preview, Baseline lịch sử 1.2.2, Bàn giao VGD Scenes, Cài và phạm vi bảo vệ, Kiểm tra bản Claude ngày 04/10/2026, Kiểm tra và việc cần tiếp tục, Thay đổi 1.0.1 (+12 more)

### Community 12 - "Sketchup"
Cohesion: 0.16
Nodes (9): Sketchup, Sketchup::Axes, Sketchup::Drawingelement, Sketchup::Entities, Sketchup::Layer, Sketchup::Layers, Sketchup::ModelObserver, Sketchup::Selection (+1 more)

### Community 13 - "VGD::Scenes"
Cohesion: 0.18
Nodes (3): VGD, VGD::Scenes, VGD::Scenes::ViewState

### Community 14 - "package.json"
Cohesion: 0.16
Nodes (14): devDependencies, playwright@1.58.2, @ruby/3.2-wasm-wasi@2.10.1, @ruby/wasm-wasi@2.10.1, name, private, scripts, test (+6 more)

### Community 16 - ".apply"
Cohesion: 0.19
Nodes (6): VGD, VGD::Dim, VGD::Dim::SmartDim, VGD, VGD::Scenes, VGD::Scenes::DimBridge

### Community 19 - "Sketchup::SectionPlane"
Cohesion: 0.24
Nodes (4): Sketchup::ComponentInstance, Sketchup::Definition, Sketchup::Image, Sketchup::SectionPlane

### Community 22 - "test_cleanup_ui.cjs"
Cohesion: 0.22
Nodes (4): {chromium}, fs, path, {pathToFileURL}

### Community 23 - "VGD Scenes"
Cohesion: 0.25
Nodes (7): Cấu trúc, Kiểm thử, Quy tắc riêng, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD Scenes, Đóng gói

### Community 24 - "check_ruby.cjs"
Cohesion: 0.25
Nodes (5): fs, localDeps, path, {RubyVM}, {WASI}

### Community 25 - "product"
Cohesion: 0.25
Nodes (3): wardrobe_model(), product(), TestScenes

### Community 26 - "test_flow_ui.cjs"
Cohesion: 0.25
Nodes (4): {chromium}, fs, path, {pathToFileURL}

### Community 27 - "test_frame_ui.cjs"
Cohesion: 0.25
Nodes (4): {chromium}, fs, path, {pathToFileURL}

### Community 28 - "test_refresh_ui.cjs"
Cohesion: 0.25
Nodes (3): {chromium}, path, {pathToFileURL}

### Community 29 - "test_scene_workflow_ui.cjs"
Cohesion: 0.25
Nodes (4): {chromium}, fs, path, {pathToFileURL}

### Community 30 - "Nghiên cứu Smart Camera View 3 cho VGD Scenes"
Cohesion: 0.25
Nodes (7): Khác biệt cần thiết kế đúng, Khả năng API và giới hạn, Nghiên cứu Smart Camera View 3 cho VGD Scenes, Năm bổ sung nên ưu tiên, Phạm vi và bằng chứng, Điều kiện trước khi triển khai, Đối chiếu với bản hiện tại

### Community 31 - "vgd-theme.js"
Cohesion: 0.54
Nodes (7): apply(), current(), readSaved(), root(), start(), systemIsDark(), writeSaved()

### Community 32 - "test_ui.cjs"
Cohesion: 0.29
Nodes (4): {chromium}, fs, path, {pathToFileURL}

### Community 33 - "VGD::Scenes::TitleBlock"
Cohesion: 0.38
Nodes (3): VGD, VGD::Scenes, VGD::Scenes::TitleBlock

## Knowledge Gaps
- **25 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Sketchup` connect `Sketchup` to `VGD::Scenes::ExportJob`, `Sketchup::View`, `.entities`, `Sketchup::Camera`, `Sketchup::Entity`, `Sketchup::SectionPlane`, `Sketchup::Model`, `Sketchup::Page`?**
  _High betweenness centrality (0.090) - this node is a cross-community bridge._
- **Should `.dispatch` be split into smaller, more focused modules?**
  _Cohesion score 0.060855639441775335 - nodes in this community are weakly interconnected._
- **Why does `UI::HtmlDialog` connect `UI::HtmlDialog` to `.dispatch`?**
  _High betweenness centrality (0.085) - this node is a cross-community bridge._
- **Should `dialog.js` be split into smaller, more focused modules?**
  _Cohesion score 0.06553128470936691 - nodes in this community are weakly interconnected._
- **Why does `Sketchup::Camera` connect `Sketchup::Camera` to `.dispatch`, `Sketchup::View`, `Sketchup`, `VGD::Scenes::SceneTransfer`?**
  _High betweenness centrality (0.078) - this node is a cross-community bridge._
- **Should `VGD::Scenes::ExportJob` be split into smaller, more focused modules?**
  _Cohesion score 0.09388335704125178 - nodes in this community are weakly interconnected._
- **Should `Geom::Vector3d` be split into smaller, more focused modules?**
  _Cohesion score 0.09274193548387097 - nodes in this community are weakly interconnected._