# Graph Report - VGD_Cabinet_Draw  (2026-11-26)

## Corpus Check
- 71 files · ~122,820 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 5 file(s) not represented in the graph (top: .woff2 2, .css 2, (none) 1)

## Summary
- 1552 nodes · 3779 edges · 74 communities (39 shown, 35 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 50 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6808f66b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- VGD_Cabinet_Draw::ContextMenu
- VGD_Cabinet_Draw::Operations
- VGD_Cabinet_Draw::PresetHud
- .set_status
- VGD_Cabinet_Draw::Tools::SweepTool
- VGD_Cabinet_Draw::Tools::BoxTool
- VGD_Cabinet_Draw::Tools::PanelTool
- VGD_Cabinet_Draw::Tools::PickTool
- test_build.rb
- VGD_Cabinet_Draw::Tools::EditCabinetTool
- VGD_Cabinet_Draw::DoorLayout::Layout
- VGD_Cabinet_Draw
- VGD_Cabinet_Draw::Tools::ScaleTool
- .inner
- VGD_Cabinet_Draw::Rebuild
- .shell_for
- VGD_Cabinet_Draw::PanelModel
- VGD_Cabinet_Draw::Geometry
- Geom::Point3d
- VGD_Cabinet_Draw::Tools::FaceBoardTool
- VGD_Cabinet_Draw::Keys
- VGD_Cabinet_Draw::DrawerSlide
- VGD_Cabinet_Draw::PresetStore
- FakeMenu
- VGD_Cabinet_Draw::Tools::Base
- VGD_Cabinet_Draw::Tools::DrawerTool
- test_bay.rb
- VGD_Cabinet_Draw::Tools
- Face
- test_sweep_tool.rb
- .cabinets_from_box
- test_door_regions.rb
- test_drawers.rb
- Geom::Vector3d
- VGD Cabinet Draw 1.0.1
- Geom::Transformation
- test_command_flow.rb
- VGD_Dump_Part
- test_doorfit.rb
- FM
- VGD_Cabinet_Draw::Tools::CutTool
- Entity
- VGD_Check_Features
- VGD_Check_Solid
- transform_by_vectors
- VGD Cabinet Draw
- build_release.py
- Quan hệ giữa các công cụ và cấu kiện (VGD Cabinet Draw)
- VGD_Cabinet_Draw::DrawerParts
- vgd-theme.js
- test_back_modes.rb
- test_hud.rb
- test_mock.rb
- test_panel_model.rb
- test_rails.rb
- test_scale_tool.rb
- test_split.rb
- mock_su.rb
- test_theme.rb
- test_door_layout.rb
- test_textures.rb
- test_minibar.rb
- Dict
- test_screen_pick.rb
- RELEASE_NOTES_v1.0.0.md
- RELEASE_NOTES_v1.0.1.md
- vgd_cabinet_draw.rb

## God Nodes (most connected - your core abstractions)
1. `VGD_Cabinet_Draw::Rebuild` - 84 edges
2. `VGD_Cabinet_Draw::ContextMenu` - 76 edges
3. `VGD_Cabinet_Draw::Tools::DoorTool` - 68 edges
4. `Geom::Point3d` - 66 edges
5. `VGD_Cabinet_Draw::Tools::PanelTool` - 62 edges
6. `VGD_Cabinet_Draw::Tools::SweepTool` - 58 edges
7. `VGD_Cabinet_Draw::Operations` - 46 edges
8. `VGD_Cabinet_Draw::PresetHud` - 41 edges
9. `VGD_Cabinet_Draw::Tools::ScaleTool` - 40 edges
10. `VGD_Cabinet_Draw::DoorLayout::Layout` - 38 edges

## Surprising Connections (you probably didn't know these)
- `Co giãn khi Scale` --references--> `transform_by_vectors()`  [INFERRED]
  README.md → test/mock_su.rb
- `world_pt()` --calls--> `Geom::Point3d`  [EXTRACTED]
  test/test_door_regions.rb → test/mock_su.rb
- `mmpt()` --calls--> `Geom::Point3d`  [EXTRACTED]
  test/test_scale_tool.rb → test/mock_su.rb
- `scale_root()` --calls--> `Geom::Transformation`  [EXTRACTED]
  test/test_textures.rb → test/mock_su.rb
- `shelves()` --calls--> `parts_named()`  [INFERRED]
  test/test_removal.rb → test/test_build.rb

## Import Cycles
- None detected.

## Communities (74 total, 35 thin omitted)

### Community 0 - "VGD_Cabinet_Draw::ContextMenu"
Cohesion: 0.06
Nodes (4): VGD_Cabinet_Draw, VGD_Cabinet_Draw::ContextMenu, VGD_Cabinet_Draw, VGD_Cabinet_Draw::Schema

### Community 1 - "VGD_Cabinet_Draw::Operations"
Cohesion: 0.05
Nodes (5): VGD_Cabinet_Draw, VGD_Cabinet_Draw::Links, VGD_Cabinet_Draw::Operations, VGD_Cabinet_Draw::Tools::OpeningTool, VGD_Cabinet_Draw::Tools::SelectAndApplyTool

### Community 2 - "VGD_Cabinet_Draw::PresetHud"
Cohesion: 0.06
Nodes (6): VGD_Cabinet_Draw, VGD_Cabinet_Draw::PresetHud, VGD_Cabinet_Draw, VGD_Cabinet_Draw::Preview, VGD_Cabinet_Draw, VGD_Cabinet_Draw::Theme

### Community 3 - ".set_status"
Cohesion: 0.08
Nodes (3): VGD_Cabinet_Draw, VGD_Cabinet_Draw::DoorGeometry, VGD_Cabinet_Draw::Tools::DoorTool

### Community 4 - "VGD_Cabinet_Draw::Tools::SweepTool"
Cohesion: 0.07
Nodes (5): VGD_Cabinet_Draw, VGD_Cabinet_Draw::ScreenPick, VGD_Cabinet_Draw, VGD_Cabinet_Draw::Tools, VGD_Cabinet_Draw::Tools::SweepTool

### Community 5 - "VGD_Cabinet_Draw::Tools::BoxTool"
Cohesion: 0.06
Nodes (5): VGD_Cabinet_Draw, VGD_Cabinet_Draw::Dialog, VGD_Cabinet_Draw, VGD_Cabinet_Draw::ToolSettings, VGD_Cabinet_Draw::Tools::BoxTool

### Community 7 - "VGD_Cabinet_Draw::Tools::PickTool"
Cohesion: 0.07
Nodes (6): VGD_Cabinet_Draw, VGD_Cabinet_Draw::MiniBar, VGD_Cabinet_Draw::MiniBar::Bar, VGD_Cabinet_Draw::MiniBar::ToolMenu, VGD_Cabinet_Draw::Tools, VGD_Cabinet_Draw::Tools::PickTool

### Community 8 - "test_build.rb"
Cohesion: 0.05
Nodes (28): at(), bb(), cab(), clashes(), collinear_overlap?(), container(), groups(), hover_panel() (+20 more)

### Community 9 - "VGD_Cabinet_Draw::Tools::EditCabinetTool"
Cohesion: 0.07
Nodes (7): VGD_Cabinet_Draw, VGD_Cabinet_Draw::AutoStretch, VGD_Cabinet_Draw::AutoStretch::AppWatcher, VGD_Cabinet_Draw::AutoStretch::ModelWatcher, VGD_Cabinet_Draw, VGD_Cabinet_Draw::ModelData, VGD_Cabinet_Draw::Tools::EditCabinetTool

### Community 10 - "VGD_Cabinet_Draw::DoorLayout::Layout"
Cohesion: 0.08
Nodes (3): VGD_Cabinet_Draw, VGD_Cabinet_Draw::DoorLayout, VGD_Cabinet_Draw::DoorLayout::Layout

### Community 11 - "VGD_Cabinet_Draw"
Cohesion: 0.06
Nodes (7): menu(), VGD, VGD_Cabinet_Draw, VGD_Cabinet_Draw::PickModeObserver, VGD_Cabinet_Draw::PickSelectionObserver, VGD_Cabinet_Draw, VGD_Cabinet_Draw::PanelTools

### Community 12 - "VGD_Cabinet_Draw::Tools::ScaleTool"
Cohesion: 0.09
Nodes (5): VGD_Cabinet_Draw, VGD_Cabinet_Draw::Resize, VGD_Cabinet_Draw, VGD_Cabinet_Draw::Tools, VGD_Cabinet_Draw::Tools::ScaleTool

### Community 13 - ".inner"
Cohesion: 0.12
Nodes (6): VGD_Cabinet_Draw, VGD_Cabinet_Draw::DrawerBay, VGD_Cabinet_Draw, VGD_Cabinet_Draw::Interior, VGD_Cabinet_Draw::Interior::Cell, VGD_Cabinet_Draw::Interior::Side

### Community 16 - "VGD_Cabinet_Draw::PanelModel"
Cohesion: 0.12
Nodes (7): VGD_Cabinet_Draw, VGD_Cabinet_Draw::PanelModel, VGD_Cabinet_Draw::PanelModel::Part, VGD_Cabinet_Draw::PanelModel::Result, VGD_Cabinet_Draw, VGD_Cabinet_Draw::Split, VGD_Cabinet_Draw::Split::Piece

### Community 18 - "Geom::Point3d"
Cohesion: 0.16
Nodes (3): Bounds, Geom::Point3d, to_a()

### Community 21 - "VGD_Cabinet_Draw::Keys"
Cohesion: 0.18
Nodes (3): VGD_Cabinet_Draw::DoorFit, VGD_Cabinet_Draw, VGD_Cabinet_Draw::Keys

### Community 24 - "FakeMenu"
Cohesion: 0.17
Nodes (6): FakeMenu, menu_for_selection(), mk_box(), new_cabinet(), run_split(), run_wall()

### Community 27 - "test_bay.rb"
Cohesion: 0.23
Nodes (11): bay_group(), bay_part(), box_part(), boxes(), cab(), container(), fronts(), groups() (+3 more)

### Community 28 - "VGD_Cabinet_Draw::Tools"
Cohesion: 0.16
Nodes (3): VGD_Cabinet_Draw, VGD_Cabinet_Draw::Tools, VGD_Cabinet_Draw::Tools::NotchTool

### Community 30 - "test_sweep_tool.rb"
Cohesion: 0.15
Nodes (4): add_panel(), new_cab(), ortho!(), OrthoCamera

### Community 31 - ".cabinets_from_box"
Cohesion: 0.19
Nodes (4): VGD_Cabinet_DrawNativeSmoke, VGD_Cabinet_Draw, VGD_Cabinet_Draw::Geometry::BodyBounds, VGD_Cabinet_Draw::Geometry::Frame

### Community 33 - "test_door_regions.rb"
Cohesion: 0.18
Nodes (6): click(), fresh_cabinet(), hover(), mk_box(), pt(), world_pt()

### Community 34 - "test_drawers.rb"
Cohesion: 0.26
Nodes (10): bb(), box_part(), boxes(), cab(), container(), fronts(), groups(), make_drawers() (+2 more)

### Community 36 - "VGD Cabinet Draw 1.0.1"
Cohesion: 0.17
Nodes (11): Cài và đóng gói, Cánh, Công cụ và menu, Giao diện theo theme VGD, Kiểm thử, Lịch sử phiên bản, Quét & dời tấm, Thùng tủ, tủ quá khổ và xà (+3 more)

### Community 37 - "Geom::Transformation"
Cohesion: 0.23
Nodes (3): Geom, Geom::Transformation, length()

### Community 38 - "test_command_flow.rb"
Cohesion: 0.18
Nodes (3): cabinets_in_model(), click(), ModelData_ok()

### Community 40 - "test_doorfit.rb"
Cohesion: 0.25
Nodes (6): cab(), groups(), mk_box(), part(), shell(), trim_part()

### Community 41 - "FM"
Cohesion: 0.20
Nodes (3): FM, mk_box(), new_cabinet()

### Community 47 - "transform_by_vectors"
Cohesion: 0.25
Nodes (3): Co giãn khi Scale, transform_by_vectors(), Vertex

### Community 48 - "VGD Cabinet Draw"
Cohesion: 0.25
Nodes (7): Cấu trúc, Kiểm thử, Quy tắc riêng, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD Cabinet Draw, Đóng gói

### Community 49 - "build_release.py"
Cohesion: 0.43
Nodes (3): main(), packaged_files(), sha256()

### Community 50 - "Quan hệ giữa các công cụ và cấu kiện (VGD Cabinet Draw)"
Cohesion: 0.25
Nodes (7): 1. Dữ liệu gắn vào model, 2. Bước tạo và dựng lại, 3. Co giãn khi kéo Scale (`rebuild.rb`, `auto_stretch.rb`), 4. Liên kết (`links.rb`), 5. Các công cụ và nơi chúng nằm, 6. Việc còn lại đã biết, Quan hệ giữa các công cụ và cấu kiện (VGD Cabinet Draw)

### Community 52 - "vgd-theme.js"
Cohesion: 0.54
Nodes (7): apply(), current(), readSaved(), root(), start(), systemIsDark(), writeSaved()

### Community 53 - "test_back_modes.rb"
Cohesion: 0.32
Nodes (4): bounds_of(), close?(), part(), same_box?()

### Community 54 - "test_hud.rb"
Cohesion: 0.39
Nodes (6): drawer_run(), mk_box(), new_cabinet(), press(), pt(), rect_for()

### Community 56 - "test_panel_model.rb"
Cohesion: 0.32
Nodes (3): in_part?(), in_poly?(), sample()

### Community 57 - "test_rails.rb"
Cohesion: 0.32
Nodes (4): bounds_of(), close?(), part(), same_box?()

### Community 58 - "test_scale_tool.rb"
Cohesion: 0.29
Nodes (3): eye_ray(), mmpt(), move_ray()

### Community 62 - "test_door_layout.rb"
Cohesion: 0.40
Nodes (3): area(), tiled?(), VGD_Cabinet_Draw

## Knowledge Gaps
- **35 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Geom::Point3d` connect `Geom::Point3d` to `VGD_Cabinet_Draw::ContextMenu`, `VGD_Cabinet_Draw::Operations`, `VGD_Cabinet_Draw::PresetHud`, `.set_status`, `VGD_Cabinet_Draw::Tools::SweepTool`, `VGD_Cabinet_Draw::Tools::BoxTool`, `VGD_Cabinet_Draw::Tools::PanelTool`, `test_build.rb`, `VGD_Cabinet_Draw::Tools::EditCabinetTool`, `VGD_Cabinet_Draw::Tools::ScaleTool`, `.inner`, `VGD_Cabinet_Draw::Rebuild`, `VGD_Cabinet_Draw::Geometry`, `VGD_Cabinet_Draw::Tools::FaceBoardTool`, `VGD_Cabinet_Draw::Tools::Base`, `VGD_Cabinet_Draw::Tools::DrawerTool`, `test_sweep_tool.rb`, `.cabinets_from_box`, `test_door_regions.rb`, `Geom::Vector3d`, `Geom::Transformation`, `test_command_flow.rb`, `VGD_Cabinet_Draw::Tools::CutTool`, `transform_by_vectors`, `test_hud.rb`, `test_mock.rb`, `test_scale_tool.rb`?**
  _High betweenness centrality (0.229) - this node is a cross-community bridge._
- **Should `VGD_Cabinet_Draw::ContextMenu` be split into smaller, more focused modules?**
  _Cohesion score 0.05994397759103642 - nodes in this community are weakly interconnected._
- **Why does `VGD_Cabinet_Draw::Tools::SweepTool` connect `VGD_Cabinet_Draw::Tools::SweepTool` to `VGD_Cabinet_Draw::PresetHud`, `VGD_Cabinet_Draw`, `VGD_Cabinet_Draw::Keys`?**
  _High betweenness centrality (0.069) - this node is a cross-community bridge._
- **Should `VGD_Cabinet_Draw::Operations` be split into smaller, more focused modules?**
  _Cohesion score 0.05238095238095238 - nodes in this community are weakly interconnected._
- **Why does `at()` connect `test_build.rb` to `Geom::Point3d`?**
  _High betweenness centrality (0.054) - this node is a cross-community bridge._
- **Should `VGD_Cabinet_Draw::PresetHud` be split into smaller, more focused modules?**
  _Cohesion score 0.059876543209876544 - nodes in this community are weakly interconnected._
- **Should `.set_status` be split into smaller, more focused modules?**
  _Cohesion score 0.08105263157894736 - nodes in this community are weakly interconnected._