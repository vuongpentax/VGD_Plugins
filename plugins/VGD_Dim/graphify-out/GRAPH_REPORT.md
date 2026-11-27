# Graph Report - VGD_Dim  (2026-11-26)

## Corpus Check
- 49 files · ~26,387 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 6 file(s) not represented in the graph (top: .css 3, .woff2 2, (none) 1)

## Summary
- 668 nodes · 1073 edges · 42 communities (23 shown, 19 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 7 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6808f66b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- .show
- Geom::Point3d
- VGD::Dim::NativeStyle::Job
- Sketchup
- Sketchup
- .run
- VGD::Dim::AutoStyle
- UI
- VGD::Dim::Regions
- ANNOTATION_REQUIREMENTS.md
- test_fixture.rb
- Entity
- VGD::Dim::ManualDim::Tool
- ComponentInstance
- Entities
- run_regression_tests
- VGD Dim · 4.0.2
- test_deploy.py
- test_ui.cjs
- Layer
- initialize
- DimensionLinear
- VGD Dim
- vgd-theme.js
- FakeStyleAdapter
- Page
- VGD
- test_engine.rb
- VGD
- VGD
- VGD
- FEATURE_STATUS.md
- FONT_NOTES.md
- RELEASE_NOTES_v3.3.0-beta.5.md
- RELEASE_NOTES_v3.3.0-beta.6.md
- RELEASE_NOTES_v3.3.0-beta.7.md
- RELEASE_NOTES_v3.3.0-beta.8.md
- RELEASE_NOTES_v4.0.1.md
- SELECTION_REQUIREMENTS.md

## God Nodes (most connected - your core abstractions)
1. `VGD::Dim::SmartDim` - 25 edges
2. `Geom::Point3d` - 24 edges
3. `VGD::Dim::AutoStyle` - 24 edges
4. `Geom::Vector3d` - 23 edges
5. `Entity` - 20 edges
6. `VGD::Dim::Core` - 19 edges
7. `run_regression_tests()` - 18 edges
8. `VGD::Dim::ManualDim::Tool` - 18 edges
9. `VGD::Dim::Regions` - 17 edges
10. `Entities` - 16 edges

## Surprising Connections (you probably didn't know these)
- `run_service_tests()` --calls--> `VGD::Dim::AutoStyle::AppWatch`  [EXTRACTED]
  dev/test_core.rb → runtime/vgd_dim/autostyle.rb
- `VGD::Dim::AutoStyle::EntityWatch` --inherits--> `EntitiesObserver`  [EXTRACTED]
  runtime/vgd_dim/autostyle.rb → dev/test_fixture.rb
- `VGD::Dim::AutoStyle::ModelWatch` --inherits--> `ModelObserver`  [EXTRACTED]
  runtime/vgd_dim/autostyle.rb → dev/test_fixture.rb
- `VGD::Dim::AutoStyle::AppWatch` --inherits--> `AppObserver`  [EXTRACTED]
  runtime/vgd_dim/autostyle.rb → dev/test_fixture.rb
- `VGD::Dim::AutoStyle::DefinitionWatch` --inherits--> `DefinitionsObserver`  [EXTRACTED]
  runtime/vgd_dim/autostyle.rb → dev/test_fixture.rb

## Import Cycles
- None detected.

## Communities (42 total, 19 thin omitted)

### Community 0 - ".show"
Cohesion: 0.05
Nodes (18): VGD, VGD::Dim, VGD::Dim::Animation, VGD, VGD::Dim, VGD::Dim::Core, VGD, VGD::Dim (+10 more)

### Community 1 - "Geom::Point3d"
Cohesion: 0.06
Nodes (15): Camera, camera(), edit_transform(), Geom, Geom::Bounds, Geom::Point3d, Geom::PolygonMesh, Geom::Transformation (+7 more)

### Community 2 - "VGD::Dim::NativeStyle::Job"
Cohesion: 0.08
Nodes (10): VGDDimNativeSmoke, VGD, VGD::Dim, VGD::Dim::Engine, VGD, VGD::Dim, VGD::Dim::NativeStyle, VGD::Dim::NativeStyle::Job (+2 more)

### Community 3 - "Sketchup"
Cohesion: 0.04
Nodes (9): Geom, Numeric, Sketchup, SketchupExtension, UI, UI::Command, UI::HtmlDialog, UI::Menu (+1 more)

### Community 4 - "Sketchup"
Cohesion: 0.05
Nodes (9): Geom, Numeric, Sketchup, SketchupExtension, UI, UI::Command, UI::HtmlDialog, UI::Menu (+1 more)

### Community 5 - ".run"
Cohesion: 0.10
Nodes (7): Geom::BoundingBox, VGD, VGD::Dim, VGD::Dim::Managed, VGD, VGD::Dim, VGD::Dim::SmartDim

### Community 6 - "VGD::Dim::AutoStyle"
Cohesion: 0.09
Nodes (12): run_core_tests(), run_service_tests(), AppObserver, ModelObserver, run_store_tests(), VGD, VGD::Dim, VGD::Dim::AutoStyle (+4 more)

### Community 7 - "UI"
Cohesion: 0.07
Nodes (4): UI, UI::Command, UI::HtmlDialog, UI::Toolbar

### Community 8 - "VGD::Dim::Regions"
Cohesion: 0.12
Nodes (4): VGD, VGD::Dim, VGD::Dim::Regions, VGD::Dim::Regions::PickTool

### Community 9 - "ANNOTATION_REQUIREMENTS.md"
Cohesion: 0.08
Nodes (23): 10. NGUYÊN TẮC XỬ LÝ, 11. UNDO, 12. MỤC TIÊU CUỐI, 1. DIMENSION SETTINGS, 2. TEXT SETTINGS, 3. LABEL SETTINGS, 4. NORMALIZE ANNOTATIONS, 5. PHẠM VI ÁP DỤNG (+15 more)

### Community 10 - "test_fixture.rb"
Cohesion: 0.11
Nodes (6): Color, DefinitionsObserver, EntitiesObserver, Length, Material, SelectionObserver

### Community 11 - "Entity"
Cohesion: 0.12
Nodes (3): Entity, guid(), SectionPlane

### Community 12 - "VGD::Dim::ManualDim::Tool"
Cohesion: 0.18
Nodes (4): VGD, VGD::Dim, VGD::Dim::ManualDim, VGD::Dim::ManualDim::Tool

### Community 13 - "ComponentInstance"
Cohesion: 0.19
Nodes (4): active_entities(), ComponentInstance, Definition, Group

### Community 14 - "Entities"
Cohesion: 0.16
Nodes (3): Edge, Entities, Face

### Community 15 - "run_regression_tests"
Cohesion: 0.21
Nodes (6): RegressionBrokenModel, RegressionErasedDefinition, RegressionErasedGroup, RegressionErasedOwnerEntities, RegressionIdentityEntities, run_regression_tests()

### Community 16 - "VGD Dim · 4.0.2"
Cohesion: 0.13
Nodes (12): Acceptance native trên model thử riêng, Các điểm đã sửa, Giới hạn cần biết, VGD Dim · rà soát và tiếp tục phát triển, Cài / chạy, Cập nhật online pilot, Kiểm tra, Mã nhập (+4 more)

### Community 18 - "test_ui.cjs"
Cohesion: 0.17
Nodes (7): {DefaultRubyVM}, fs, path, {chromium}, fs, path, {pathToFileURL}

### Community 20 - "initialize"
Cohesion: 0.20
Nodes (5): Definitions, initialize(), Materials, Pages, Selection

### Community 21 - "DimensionLinear"
Cohesion: 0.20
Nodes (3): Dimension, DimensionLinear, DimensionRadial

### Community 22 - "VGD Dim"
Cohesion: 0.25
Nodes (7): Cấu trúc, Kiểm thử, Quy tắc riêng, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD Dim, Đóng gói

### Community 23 - "vgd-theme.js"
Cohesion: 0.54
Nodes (7): apply(), current(), readSaved(), root(), start(), systemIsDark(), writeSaved()

### Community 26 - "VGD"
Cohesion: 0.50
Nodes (3): VGD, VGD::Dim, VGD::Dim::Probe

## Knowledge Gaps
- **19 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `run_regression_tests()` connect `run_regression_tests` to `.show`, `Geom::Point3d`, `VGD::Dim::NativeStyle::Job`, `VGD::Dim::AutoStyle`, `VGD::Dim::Regions`, `VGD::Dim::ManualDim::Tool`?**
  _High betweenness centrality (0.085) - this node is a cross-community bridge._
- **Should `.show` be split into smaller, more focused modules?**
  _Cohesion score 0.05370843989769821 - nodes in this community are weakly interconnected._
- **Why does `Geom` connect `Geom::Point3d` to `test_fixture.rb`, `.run`?**
  _High betweenness centrality (0.081) - this node is a cross-community bridge._
- **Should `Geom::Point3d` be split into smaller, more focused modules?**
  _Cohesion score 0.05844155844155844 - nodes in this community are weakly interconnected._
- **Why does `Geom::Point3d` connect `Geom::Point3d` to `.run`, `VGD::Dim::AutoStyle`, `VGD::Dim::Regions`, `ComponentInstance`, `Entities`, `run_regression_tests`?**
  _High betweenness centrality (0.072) - this node is a cross-community bridge._
- **Should `VGD::Dim::NativeStyle::Job` be split into smaller, more focused modules?**
  _Cohesion score 0.08078231292517007 - nodes in this community are weakly interconnected._
- **Should `Sketchup` be split into smaller, more focused modules?**
  _Cohesion score 0.0425531914893617 - nodes in this community are weakly interconnected._