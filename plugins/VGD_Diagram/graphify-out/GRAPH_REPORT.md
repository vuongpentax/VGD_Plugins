# Graph Report - VGD_Diagram  (2026-11-28)

## Corpus Check
- 21 files · ~23,372 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 7 file(s) not represented in the graph (top: .css 3, (none) 2, .woff2 2)

## Summary
- 341 nodes · 577 edges · 21 communities (14 shown, 7 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 10 edges (avg confidence: 0.9)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `99dde021`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Sketchup
- UI::HtmlDialog
- VGD::Diagram::Tree
- VGD::Diagram::Dialog
- VGD::Diagram::ModelIO
- VGD Diagram — hướng dẫn cho Claude
- VGD::Diagram
- test_ui.cjs
- vgd-theme.js
- VGD Diagram 0.10.5-beta.1
- VGD
- dialog.js
- VGD
- VGD
- Sketchup
- VGD::Diagram::Ffmpeg
- UI::HtmlDialog
- test_formats.rb

## God Nodes (most connected - your core abstractions)
1. `VGD::Diagram::Dialog` - 31 edges
2. `VGD::Diagram::Tree` - 23 edges
3. `exportImages()` - 16 edges
4. `drawTimelineFrame()` - 12 edges
5. `VGD::Diagram::Ffmpeg` - 12 edges
6. `VGD::Diagram::ModelIO` - 11 edges
7. `UI::HtmlDialog` - 9 edges
8. `UI::HtmlDialog` - 9 edges
9. `Sketchup` - 8 edges
10. `renderNode()` - 8 edges

## Surprising Connections (you probably didn't know these)
- `Quy tắc riêng` --references--> `explodedOffset()`  [INFERRED]
  CLAUDE.md → runtime/vgd_diagram/dialog.js
- `Quy tắc riêng` --references--> `releaseRenderer()`  [INFERRED]
  CLAUDE.md → runtime/vgd_diagram/dialog.js
- `Quy tắc riêng` --references--> `exportFrames()`  [INFERRED]
  CLAUDE.md → runtime/vgd_diagram/dialog.js

## Import Cycles
- None detected.

## Communities (21 total, 7 thin omitted)

### Community 0 - "Sketchup"
Cohesion: 0.07
Nodes (7): Sketchup, Sketchup::ComponentDefinition, Sketchup::ComponentInstance, Sketchup::Entity, Sketchup::FakeModel, Sketchup::FakeSelection, Sketchup::Group

### Community 1 - "UI::HtmlDialog"
Cohesion: 0.07
Nodes (6): Sketchup, UI, UI::Command, UI::HtmlDialog, UI::Menu, UI::Toolbar

### Community 2 - "VGD::Diagram::Tree"
Cohesion: 0.14
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Tree

### Community 3 - "VGD::Diagram::Dialog"
Cohesion: 0.15
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Dialog

### Community 4 - "VGD::Diagram::ModelIO"
Cohesion: 0.14
Nodes (6): VGD, VGD::Diagram, VGD::Diagram::ModelIO, VGD, VGD::Diagram, VGD::Diagram::Scene

### Community 5 - "VGD Diagram — hướng dẫn cho Claude"
Cohesion: 0.29
Nodes (6): Cấu trúc, Kiểm thử, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD Diagram — hướng dẫn cho Claude, Đóng gói

### Community 6 - "VGD::Diagram"
Cohesion: 0.29
Nodes (3): menu(), VGD, VGD::Diagram

### Community 7 - "test_ui.cjs"
Cohesion: 0.22
Nodes (4): { chromium }, failed, path, sample

### Community 8 - "vgd-theme.js"
Cohesion: 0.54
Nodes (7): apply(), current(), readSaved(), root(), start(), systemIsDark(), writeSaved()

### Community 9 - "VGD Diagram 0.10.5-beta.1"
Cohesion: 0.25
Nodes (7): Cài đặt và tải lại, Cách dùng, Kiểm thử, Mô hình 3D, Quy tắc gom và thứ tự (giả định cần xác nhận), Trạng thái, VGD Diagram 0.10.5-beta.1

### Community 12 - "dialog.js"
Cohesion: 0.09
Nodes (61): Quy tắc riêng, addArrow(), advancePlayback(), applyOrder(), bindExplodeControls(), bindOrbit(), captureView(), changeScope() (+53 more)

### Community 28 - "Sketchup"
Cohesion: 0.07
Nodes (11): Geom, Geom::Point3d, Geom::Transformation, Sketchup, Sketchup::ComponentDefinition, Sketchup::ComponentInstance, Sketchup::Entity, Sketchup::Face (+3 more)

### Community 52 - "VGD::Diagram::Ffmpeg"
Cohesion: 0.20
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Ffmpeg

### Community 73 - "UI::HtmlDialog"
Cohesion: 0.07
Nodes (7): Geom, Geom::Transformation, Sketchup, Sketchup::FakeModel, Sketchup::FakeSelection, UI, UI::HtmlDialog

## Knowledge Gaps
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Quy tắc riêng` connect `dialog.js` to `UI::HtmlDialog`, `VGD::Diagram::Dialog`, `VGD Diagram — hướng dẫn cho Claude`?**
  _High betweenness centrality (0.223) - this node is a cross-community bridge._
- **Should `Sketchup` be split into smaller, more focused modules?**
  _Cohesion score 0.07142857142857142 - nodes in this community are weakly interconnected._
- **Why does `VGD::Diagram::Dialog` connect `VGD::Diagram::Dialog` to `VGD::Diagram`?**
  _High betweenness centrality (0.199) - this node is a cross-community bridge._
- **Should `UI::HtmlDialog` be split into smaller, more focused modules?**
  _Cohesion score 0.06896551724137931 - nodes in this community are weakly interconnected._
- **Should `VGD::Diagram::Tree` be split into smaller, more focused modules?**
  _Cohesion score 0.14 - nodes in this community are weakly interconnected._
- **Should `VGD::Diagram::ModelIO` be split into smaller, more focused modules?**
  _Cohesion score 0.1422924901185771 - nodes in this community are weakly interconnected._
- **Should `dialog.js` be split into smaller, more focused modules?**
  _Cohesion score 0.08725542041248018 - nodes in this community are weakly interconnected._