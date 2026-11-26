# Graph Report - VGD_Library  (2026-11-26)

## Corpus Check
- 41 files · ~23,960 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 8 file(s) not represented in the graph (top: .css 4, (none) 2, .woff2 2)

## Summary
- 544 nodes · 878 edges · 31 communities (23 shown, 8 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 6 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6808f66b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- .dispatch
- inspect_catalog.cjs
- test_engine.rb
- VGD::Library::Pixels
- UI::HtmlDialog
- test_advanced.rb
- Geom::Point3d
- Sketchup
- Sketchup
- VGD::Library::Models::PlacementTool
- VGD::Library::ShellSync
- dialog.js
- VGD Library 1.2.1
- test_preferences_timers.rb
- .onLButtonDown
- Sketchup::Face
- package.json
- UI
- VGD Library
- seamless.js
- vgd-theme.js
- VGD
- VGD::Library::Storage
- VGD
- menu
- RELEASE_NOTES_v1.1.2-beta.4.md
- RELEASE_NOTES_v1.1.2-beta.5.md
- RELEASE_NOTES_v1.1.2-beta.6.md
- RELEASE_NOTES_v1.2.0.md

## God Nodes (most connected - your core abstractions)
1. `render()` - 17 edges
2. `VGD::Library` - 17 edges
3. `Sketchup` - 14 edges
4. `VGD::Library::Models::PlacementTool` - 14 edges
5. `VGD::Library::Pixels` - 14 edges
6. `Geom::Point3d` - 13 edges
7. `VGD::Library::Online` - 13 edges
8. `UI::HtmlDialog` - 12 edges
9. `VGD::Library::Catalog` - 12 edges
10. `VGD::Library::Geometry` - 11 edges

## Surprising Connections (you probably didn't know these)
- `FlowEdge` --inherits--> `Edge`  [EXTRACTED]
  dev/test_advanced.rb → dev/test_engine.rb
- `TestDefinition` --inherits--> `Definition`  [EXTRACTED]
  dev/test_advanced.rb → dev/test_engine.rb

## Import Cycles
- None detected.

## Communities (31 total, 8 thin omitted)

### Community 0 - ".dispatch"
Cohesion: 0.08
Nodes (9): VGD::Library::Catalog, VGD, VGD::Library, VGD::Library::Drive, VGD::Library, VGD::Library::Materials, VGD, VGD::Library (+1 more)

### Community 1 - "inspect_catalog.cjs"
Cohesion: 0.05
Nodes (34): fs, path, { RubyVM }, { WASI }, fs, path, resolve(), fs (+26 more)

### Community 2 - "test_engine.rb"
Cohesion: 0.06
Nodes (13): FlowEdge, FlowFace, assert(), CatalogFixtureDirs, CatalogFixtureFiles, Edge, Loop, Model (+5 more)

### Community 3 - "VGD::Library::Pixels"
Cohesion: 0.13
Nodes (7): VGD, VGD::Library, VGD::Library::Pixels, VGD::Library::Pixels::Image, VGD, VGD::Library, VGD::Library::Seamless

### Community 4 - "UI::HtmlDialog"
Cohesion: 0.07
Nodes (5): UI, UI::Command, UI::HtmlDialog, UI::Menu, UI::Toolbar

### Community 5 - "test_advanced.rb"
Cohesion: 0.07
Nodes (7): Model, Sketchup, Sketchup::ComponentInstance, Sketchup::Face, Sketchup::ImageRep, TestBounds, TestMaterial

### Community 6 - "Geom::Point3d"
Cohesion: 0.15
Nodes (7): Geom::Point3d, VGD, VGD::Library, VGD::Library::Advanced, VGD, VGD::Library, VGD::Library::Geometry

### Community 7 - "Sketchup"
Cohesion: 0.08
Nodes (7): TestDefinition, Definition, Sketchup, Sketchup::ComponentInstance, Sketchup::EntityObserver, Sketchup::Group, Sketchup::ModelObserver

### Community 8 - "Sketchup"
Cohesion: 0.08
Nodes (5): Geom, Numeric, Sketchup, Sketchup::FakeModel, SketchupExtension

### Community 9 - "VGD::Library::Models::PlacementTool"
Cohesion: 0.12
Nodes (6): Geom, Geom::Transformation, VGD, VGD::Library, VGD::Library::Models, VGD::Library::Models::PlacementTool

### Community 10 - "VGD::Library::ShellSync"
Cohesion: 0.13
Nodes (5): VGD, VGD::Library, VGD::Library::ShellSync, VGD::Library::ShellSync::EntityObserver, VGD::Library::ShellSync::ModelObserver

### Community 11 - "dialog.js"
Cohesion: 0.23
Nodes (21): append(), apply(), audit(), begin(), button(), categories(), displayName(), favorites() (+13 more)

### Community 12 - "VGD Library 1.2.1"
Cohesion: 0.10
Nodes (16): Đối chiếu N-TEXTURE 2.0.19 → VGD_Library 1.1.2-beta.1, Bàn giao VGD_Library, Cấu trúc, Native checklist còn cần, Sửa lỗi HTML Drive phủ cửa sổ — 1.1.2-beta.1, Sửa lỗi ngày 05/10/2026 — 1.1.1-beta.1, Trạng thái, Cài đặt và nối kho của bạn (+8 more)

### Community 13 - "test_preferences_timers.rb"
Cohesion: 0.12
Nodes (6): RegressionDialog, RegressionFailedScanner, RegressionScanner, scan(), Sketchup, UI

### Community 14 - ".onLButtonDown"
Cohesion: 0.18
Nodes (5): VGD, VGD::Library, VGD::Library::Replacement, VGD::Library::Tools, VGD::Library::Tools::ClickTool

### Community 15 - "Sketchup::Face"
Cohesion: 0.12
Nodes (3): Geom, Geom::Vector3d, Sketchup::Face

### Community 16 - "package.json"
Cohesion: 0.16
Nodes (15): devDependencies, jszip@3.10.1, playwright@1.58.2, @ruby/3.2-wasm-wasi@2.10.1, @ruby/wasm-wasi@2.10.1, name, private, scripts (+7 more)

### Community 17 - "UI"
Cohesion: 0.14
Nodes (4): UI, UI::Command, UI::Menu, UI::Toolbar

### Community 18 - "VGD Library"
Cohesion: 0.25
Nodes (7): Cấu trúc, Kiểm thử, Quy tắc riêng, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD Library, Đóng gói

### Community 19 - "seamless.js"
Cohesion: 0.46
Nodes (7): idle(), later(), message(), options(), preview(), send(), start()

### Community 20 - "vgd-theme.js"
Cohesion: 0.54
Nodes (7): apply(), current(), readSaved(), root(), start(), systemIsDark(), writeSaved()

### Community 21 - "VGD"
Cohesion: 0.27
Nodes (4): VGD, VGD::Library, VGD, VGD::Library

### Community 22 - "VGD::Library::Storage"
Cohesion: 0.40
Nodes (3): VGD, VGD::Library, VGD::Library::Storage

## Knowledge Gaps
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Geom::Point3d` connect `Geom::Point3d` to `test_engine.rb`, `VGD::Library::Pixels`, `test_advanced.rb`, `VGD::Library::Models::PlacementTool`, `Sketchup::Face`?**
  _High betweenness centrality (0.171) - this node is a cross-community bridge._
- **Should `.dispatch` be split into smaller, more focused modules?**
  _Cohesion score 0.08269230769230769 - nodes in this community are weakly interconnected._
- **Why does `UI::HtmlDialog` connect `UI::HtmlDialog` to `.dispatch`, `VGD::Library::Pixels`?**
  _High betweenness centrality (0.121) - this node is a cross-community bridge._
- **Should `inspect_catalog.cjs` be split into smaller, more focused modules?**
  _Cohesion score 0.0549645390070922 - nodes in this community are weakly interconnected._
- **Why does `UI` connect `UI::HtmlDialog` to `Sketchup`?**
  _High betweenness centrality (0.102) - this node is a cross-community bridge._
- **Should `test_engine.rb` be split into smaller, more focused modules?**
  _Cohesion score 0.059743954480796585 - nodes in this community are weakly interconnected._
- **Should `VGD::Library::Pixels` be split into smaller, more focused modules?**
  _Cohesion score 0.13333333333333333 - nodes in this community are weakly interconnected._