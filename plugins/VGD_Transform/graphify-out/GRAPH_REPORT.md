# Graph Report - VGD_Transform  (2026-11-26)

## Corpus Check
- 27 files · ~25,255 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 6 file(s) not represented in the graph (top: .css 3, .woff2 2, (none) 1)

## Summary
- 380 nodes · 558 edges · 27 communities (17 shown, 10 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 7 edges (avg confidence: 0.88)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6808f66b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- test_model_ops.rb
- app.js
- VGD::Transform::RotateScale
- VGD::Transform::Panel
- test_reload.rb
- VGD::Transform::ModelOps
- Kiểm tra VGD Transform
- UI
- .build
- UI::HtmlDialog
- .changed
- Geom::Transformation
- Cách dùng
- VGD::Transform::Steps
- test_transform.rb
- VGD::Transform::LiveQueue
- vgd-theme.js
- package.py
- test_ui.cjs
- VGD::Transform
- VGD
- RELEASE_NOTES_v0.1.0.md

## God Nodes (most connected - your core abstractions)
1. `VGD::Transform::Panel` - 30 edges
2. `VGD::Transform::ModelOps` - 25 edges
3. `VGD::Transform::RotateScale` - 13 edges
4. `UI` - 12 edges
5. `enhanceSpinner()` - 12 edges
6. `Sketchup` - 10 edges
7. `UI::HtmlDialog` - 10 edges
8. `Geom::Transformation` - 9 edges
9. `VGD::Transform::Steps` - 9 edges
10. `receive()` - 9 edges

## Surprising Connections (you probably didn't know these)
- `panel_with_clock()` --calls--> `VGD::Transform::Panel`  [EXTRACTED]
  dev/test_model_ops.rb → runtime/vgd_transform/ui/panel.rb

## Import Cycles
- None detected.

## Communities (27 total, 10 thin omitted)

### Community 0 - "test_model_ops.rb"
Cohesion: 0.05
Nodes (13): BoundingBox, CountingModel, NoRotateGroup, panel_with_clock(), Sketchup, Sketchup::ComponentInstance, Sketchup::Edge, Sketchup::Group (+5 more)

### Community 1 - "app.js"
Cohesion: 0.11
Nodes (34): apply(), boxOf(), call(), COORD_TEXT, dirtyXyz(), enhanceSpinner(), fillAbsolute(), fmt() (+26 more)

### Community 2 - "VGD::Transform::RotateScale"
Cohesion: 0.10
Nodes (10): VGD, VGD::Transform, VGD::Transform::Items, VGD::Transform::NothingToDo, VGD, VGD::Transform, VGD::Transform::RotateScale, VGD (+2 more)

### Community 3 - "VGD::Transform::Panel"
Cohesion: 0.16
Nodes (3): VGD, VGD::Transform, VGD::Transform::Panel

### Community 4 - "test_reload.rb"
Cohesion: 0.07
Nodes (12): BusyPanel, Geom, Geom::Point3d, Geom::Transformation, Geom::Vector3d, Sketchup, Sketchup::ComponentInstance, Sketchup::Group (+4 more)

### Community 5 - "VGD::Transform::ModelOps"
Cohesion: 0.14
Nodes (3): VGD, VGD::Transform, VGD::Transform::ModelOps

### Community 6 - "Kiểm tra VGD Transform"
Cohesion: 0.11
Nodes (16): Cấu trúc, Kiểm thử, Quy tắc riêng, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD_Transform, Đóng gói, Bản 0.1.0-beta.10: đã kiểm tra tự động (+8 more)

### Community 7 - "UI"
Cohesion: 0.11
Nodes (5): UI, UI::Command, UI::HtmlDialog, UI::MenuNode, UI::Toolbar

### Community 8 - ".build"
Cohesion: 0.17
Nodes (6): VGD, VGD::Transform, VGD::Transform::Plan, VGD, VGD::Transform, VGD::Transform::Units

### Community 11 - "Geom::Transformation"
Cohesion: 0.17
Nodes (4): Geom, Geom::Point3d, Geom::Transformation, Geom::Vector3d

### Community 12 - "Cách dùng"
Cohesion: 0.15
Nodes (12): Cách dùng, Dời, Giới hạn của bản thử, Khóa (như Lock của SketchUp), Scale, Tâm và hệ trục, Tải lại code, VGD Transform 0.1.0-beta.13 (+4 more)

### Community 13 - "VGD::Transform::Steps"
Cohesion: 0.32
Nodes (3): VGD, VGD::Transform, VGD::Transform::Steps

### Community 14 - "test_transform.rb"
Cohesion: 0.28
Nodes (4): axes_after(), near(), same_axes?(), spin()

### Community 15 - "VGD::Transform::LiveQueue"
Cohesion: 0.25
Nodes (3): VGD, VGD::Transform, VGD::Transform::LiveQueue

### Community 16 - "vgd-theme.js"
Cohesion: 0.54
Nodes (7): apply(), current(), readSaved(), root(), start(), systemIsDark(), writeSaved()

### Community 18 - "test_ui.cjs"
Cohesion: 0.29
Nodes (3): { chromium }, path, { pathToFileURL }

### Community 19 - "VGD::Transform"
Cohesion: 0.33
Nodes (3): menu(), VGD, VGD::Transform

## Knowledge Gaps
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `VGD::Transform::Panel` connect `VGD::Transform::Panel` to `test_model_ops.rb`, `VGD::Transform::RotateScale`, `VGD::Transform::ModelOps`, `.changed`, `VGD::Transform`?**
  _High betweenness centrality (0.248) - this node is a cross-community bridge._
- **Should `test_model_ops.rb` be split into smaller, more focused modules?**
  _Cohesion score 0.04983388704318937 - nodes in this community are weakly interconnected._
- **Why does `panel_with_clock()` connect `test_model_ops.rb` to `VGD::Transform::Panel`?**
  _High betweenness centrality (0.188) - this node is a cross-community bridge._
- **Should `app.js` be split into smaller, more focused modules?**
  _Cohesion score 0.11428571428571428 - nodes in this community are weakly interconnected._
- **Why does `Sketchup` connect `test_model_ops.rb` to `Kiểm tra VGD Transform`?**
  _High betweenness centrality (0.105) - this node is a cross-community bridge._
- **Should `VGD::Transform::RotateScale` be split into smaller, more focused modules?**
  _Cohesion score 0.09915966386554621 - nodes in this community are weakly interconnected._
- **Should `test_reload.rb` be split into smaller, more focused modules?**
  _Cohesion score 0.07407407407407407 - nodes in this community are weakly interconnected._