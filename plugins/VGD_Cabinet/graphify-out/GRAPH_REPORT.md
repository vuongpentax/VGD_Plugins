# Graph Report - VGD_Cabinet  (2026-11-26)

## Corpus Check
- 61 files · ~53,010 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 2 file(s) not represented in the graph (top: (none) 1, .css 1)

## Summary
- 779 nodes · 1224 edges · 58 communities (28 shown, 30 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6808f66b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- VGD_Cabinet
- redesign_ui.cjs
- Geom::Vector3d
- VGD_Cabinet::PreviewMesh
- VGD_Cabinet::GeometryEngine
- VGD_Cabinet::BoxToCabinetTool
- menu.js
- VGD_Cabinet::Modeling
- VGD_Cabinet::PlacementTool
- VGD_Cabinet::RailJoinery
- UI::HtmlDialog
- VGD_Cabinet::PresetStore
- VGD_Cabinet::CabinetDrawTool
- test_deploy.py
- VGD_Cabinet — bàn giao trạng thái 4.5.2
- VGD_Cabinet::LibraryStore
- Sketchup
- package.json
- ref_fs
- .each
- test_dom.cjs
- test_reload.rb
- VGD_Cabinet::Development
- Sketchup::Layers
- Sketchup::Model
- test_payload.cjs
- Entity
- Sketchup::Entity
- Sketchup::Entity
- test_description.cjs
- .apply
- VGD_Cabinet
- check_ruby.cjs
- Sketchup
- Sketchup::Selection
- .fixture_copy
- dependencies.cjs
- el
- Sketchup::Entities
- sketchup_ui_stub.rb
- Sketchup::Entities
- Sketchup::ConstructionLine
- Sketchup::PolygonMesh
- Sketchup::InputPoint
- VGD Cabinet 4.5 · Cánh và preview
- field
- vgd_cabinet.rb
- PANO_RESEARCH.md
- RELEASE_NOTES_v4.5.0-beta.4.md
- RELEASE_NOTES_v4.5.0-beta.5.md
- RELEASE_NOTES_v4.5.0-beta.6.md
- RELEASE_NOTES_v4.5.1.md
- RELEASE_NOTES_v4.5.2.md
- RELEASE_NOTES_v4.5.4.md

## God Nodes (most connected - your core abstractions)
1. `VGD_Cabinet` - 44 edges
2. `VGD_Cabinet::PresetStore` - 22 edges
3. `Geom::Vector3d` - 21 edges
4. `VGD_Cabinet::CabinetDrawTool` - 21 edges
5. `Sketchup` - 20 edges
6. `Sketchup` - 19 edges
7. `VGD_Cabinet::PreviewMesh` - 17 edges
8. `VGD_Cabinet::BoxToCabinetTool` - 16 edges
9. `VGD_Cabinet::RailJoinery` - 16 edges
10. `VGD_Cabinet::LibraryStore` - 14 edges

## Surprising Connections (you probably didn't know these)
- `playwright@1.64.0` --declares--> `playwright`  [EXTRACTED]
  cabinet_dev/package.json → cabinet_dev/package.json  _Bridges community 17 → community 18_
- `Sketchup::Face` --inherits--> `Entity`  [EXTRACTED]
  cabinet_dev/sketchup_stub.rb →   _Bridges community 2 → community 26_
- `Sketchup::ConstructionLine` --inherits--> `Entity`  [EXTRACTED]
  cabinet_dev/sketchup_stub.rb →   _Bridges community 26 → community 41_
- `Sketchup::Definition` --inherits--> `Entity`  [EXTRACTED]
  cabinet_dev/sketchup_ui_stub.rb →   _Bridges community 35 → community 16_
- `Sketchup::Entities` --inherits--> `Array`  [EXTRACTED]
  cabinet_dev/sketchup_ui_stub.rb →   _Bridges community 40 → community 34_

## Import Cycles
- None detected.

## Communities (58 total, 30 thin omitted)

### Community 0 - "VGD_Cabinet"
Cohesion: 0.08
Nodes (9): VGD_Cabinet, menu(), VGD, VGD_Cabinet, VGD_Cabinet::CabinetSelectionObserver, VGD_Cabinet, VGD_Cabinet::ModelData, VGD_Cabinet (+1 more)

### Community 1 - "redesign_ui.cjs"
Cohesion: 0.04
Nodes (52): actions, bevel, box, boxAction, c, content, context, css (+44 more)

### Community 2 - "Geom::Vector3d"
Cohesion: 0.06
Nodes (11): Geom, Geom::Point3d, Geom::Transformation, Geom::Vector3d, Numeric, Sketchup::Face, Sketchup::Vertex, UI (+3 more)

### Community 3 - "VGD_Cabinet::PreviewMesh"
Cohesion: 0.06
Nodes (10): Sketchup::Definition, VGD_Cabinet, VGD_Cabinet::PreviewMesh, VGD_Cabinet::PreviewMesh::Entities, VGD_Cabinet::PreviewMesh::Face, VGD_Cabinet::PreviewMesh::Group, VGD_Cabinet::PreviewMesh::Guide, VGD_Cabinet::PreviewMesh::Model (+2 more)

### Community 4 - "VGD_Cabinet::GeometryEngine"
Cohesion: 0.08
Nodes (15): description_packet(), description_rejected(), DescriptionDialogFixture, partial_rejected(), assert(), build(), panels(), rejected() (+7 more)

### Community 5 - "VGD_Cabinet::BoxToCabinetTool"
Cohesion: 0.07
Nodes (6): VGDCabinetNativeUpgrade, Geom::BoundingBox, VGD_Cabinet, VGD_Cabinet::BoxToCabinetTool, VGD_Cabinet::BoxToCabinetTool::Record, VGD_Cabinet::BatchUpdatePreviewTool

### Community 6 - "menu.js"
Cohesion: 0.09
Nodes (13): applyDescriptionDraft(), checkDescription(), chooseFrameDivision(), initMenu(), insertDescriptionExample(), invalidateDescriptionPreview(), receiveDescriptionPreview(), receiveLibrary() (+5 more)

### Community 7 - "VGD_Cabinet::Modeling"
Cohesion: 0.16
Nodes (4): VGD_Cabinet, VGD_Cabinet::Modeling, VGD_Cabinet, VGD_Cabinet::Modeling

### Community 8 - "VGD_Cabinet::PlacementTool"
Cohesion: 0.10
Nodes (4): Sketchup::Color, VGD_Cabinet::PlacementTool, VGD_Cabinet::UpdatePreviewTool, VGD_Cabinet::ModelingRules::Invalid

### Community 9 - "VGD_Cabinet::RailJoinery"
Cohesion: 0.16
Nodes (4): VGD_Cabinet, VGD_Cabinet::FrameDivisions, VGD_Cabinet, VGD_Cabinet::RailJoinery

### Community 10 - "UI::HtmlDialog"
Cohesion: 0.09
Nodes (5): UI, UI::Command, UI::HtmlDialog, UI::Menu, UI::Toolbar

### Community 13 - "test_deploy.py"
Cohesion: 0.14
Nodes (3): deploy(), quoted(), with_prefix()

### Community 14 - "VGD_Cabinet — bàn giao trạng thái 4.5.2"
Cohesion: 0.12
Nodes (13): Baseline và cấu trúc, Hồ sơ xác minh, Kế thừa từ native 4.5.1, Phạm vi chưa triển khai và lưu ý triển khai, Quy tắc dữ liệu và hình học, Riêng 4.5.2 còn chờ native, VGD_Cabinet — bàn giao trạng thái 4.5.2, Đã ghi nhận qua kiểm thử tự động (+5 more)

### Community 16 - "Sketchup"
Cohesion: 0.22
Nodes (9): Sketchup, Sketchup::ComponentInstance, Sketchup::ConstructionLine, Sketchup::ConstructionPoint, Sketchup::Container, Sketchup::Edge, Sketchup::Face, Sketchup::Group (+1 more)

### Community 17 - "package.json"
Cohesion: 0.21
Nodes (11): devDependencies, jsdom@26.1.0, playwright@1.64.0, @ruby/3.2-wasm-wasi@2.10.1, @ruby/wasm-wasi@2.10.1, name, private, version (+3 more)

### Community 18 - "ref_fs"
Cohesion: 0.22
Nodes (7): {chromium}, fs, {chromium}, fs, {chromium}, fs, playwright

### Community 20 - "test_dom.cjs"
Cohesion: 0.20
Nodes (8): defaults, dom, errors, fs, html, {JSDOM,VirtualConsole}, presets, vc

### Community 23 - "Sketchup::Layers"
Cohesion: 0.25
Nodes (3): Sketchup::Layers, Sketchup::Materials, Sketchup::Model

### Community 24 - "Sketchup::Model"
Cohesion: 0.22
Nodes (3): Sketchup::Layer, Sketchup::Model, Sketchup::View

### Community 25 - "test_payload.cjs"
Cohesion: 0.22
Nodes (7): assert, defaults, fs, {JSDOM}, now, old, presets

### Community 26 - "Entity"
Cohesion: 0.25
Nodes (3): Sketchup::Definition, Sketchup::Edge, Sketchup::Group

### Community 29 - "test_description.cjs"
Cohesion: 0.25
Nodes (6): assert, defaults, dom, fs, html, {JSDOM}

### Community 31 - "VGD_Cabinet"
Cohesion: 0.25
Nodes (7): Cấu trúc, Kiểm thử, Quy tắc riêng, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD_Cabinet, Đóng gói

### Community 32 - "check_ruby.cjs"
Cohesion: 0.29
Nodes (5): {DefaultRubyVM}, fs, path, {RubyVM}, {WASI}

### Community 33 - "Sketchup"
Cohesion: 0.29
Nodes (4): Sketchup, Sketchup::ComponentInstance, Sketchup::Material, Sketchup::SelectionObserver

### Community 37 - "el"
Cohesion: 0.33
Nodes (6): details(), el(), menuButton(), navIcon(), section(), tabs()

### Community 39 - "sketchup_ui_stub.rb"
Cohesion: 0.33
Nodes (3): Geom, Geom::Point3d, Geom::Transformation

### Community 44 - "VGD Cabinet 4.5 · Cánh và preview"
Cohesion: 0.50
Nodes (3): Shaker và chia khung, SketchUp 2022, VGD Cabinet 4.5 · Cánh và preview

## Knowledge Gaps
- **30 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `VGD_Cabinet` connect `VGD_Cabinet` to `VGD_Cabinet::PlacementTool`, `VGD_Cabinet::BoxToCabinetTool`, `VGD_Cabinet::LibraryStore`?**
  _High betweenness centrality (0.108) - this node is a cross-community bridge._
- **Should `VGD_Cabinet` be split into smaller, more focused modules?**
  _Cohesion score 0.07740384615384616 - nodes in this community are weakly interconnected._
- **Why does `VGD_Cabinet::PreviewMesh` connect `VGD_Cabinet::PreviewMesh` to `VGD_Cabinet`, `VGD_Cabinet::CabinetDrawTool`, `VGD_Cabinet::BoxToCabinetTool`?**
  _High betweenness centrality (0.080) - this node is a cross-community bridge._
- **Should `redesign_ui.cjs` be split into smaller, more focused modules?**
  _Cohesion score 0.03636363636363636 - nodes in this community are weakly interconnected._
- **Why does `Sketchup` connect `Sketchup` to `Geom::Vector3d`, `Sketchup::Entities`, `VGD_Cabinet::PlacementTool`, `Sketchup::ConstructionLine`, `Sketchup::PolygonMesh`, `Sketchup::InputPoint`, `Sketchup::Layers`, `Entity`, `Sketchup::Entity`?**
  _High betweenness centrality (0.080) - this node is a cross-community bridge._
- **Should `Geom::Vector3d` be split into smaller, more focused modules?**
  _Cohesion score 0.05647058823529412 - nodes in this community are weakly interconnected._
- **Should `VGD_Cabinet::PreviewMesh` be split into smaller, more focused modules?**
  _Cohesion score 0.05735430157261795 - nodes in this community are weakly interconnected._