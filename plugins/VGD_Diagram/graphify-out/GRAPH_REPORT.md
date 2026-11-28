# Graph Report - VGD_Diagram  (2026-11-28)

## Corpus Check
- 21 files · ~26,999 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 7 file(s) not represented in the graph (top: .css 3, (none) 2, .woff2 2)

## Summary
- 372 nodes · 637 edges · 22 communities (12 shown, 10 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 12 edges (avg confidence: 0.91)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b3c59d78`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Sketchup
- UI::HtmlDialog
- VGD::Diagram::Tree
- VGD::Diagram::Dialog
- VGD::Diagram::ModelIO
- UI::HtmlDialog
- menu
- test_ui.cjs
- vgd-theme.js
- VGD Diagram 0.10.5-beta.1
- VGD
- dialog.js
- VGD
- VGD
- VGD
- Sketchup
- VGD::Diagram::Ffmpeg
- UI::HtmlDialog
- test_formats.rb

## God Nodes (most connected - your core abstractions)
1. `VGD::Diagram::Dialog` - 38 edges
2. `VGD::Diagram::Tree` - 23 edges
3. `VGD::Diagram::Ffmpeg` - 17 edges
4. `exportImages()` - 16 edges
5. `drawTimelineFrame()` - 12 edges
6. `VGD::Diagram::ModelIO` - 12 edges
7. `Sketchup` - 10 edges
8. `UI::HtmlDialog` - 9 edges
9. `UI::HtmlDialog` - 9 edges
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

## Communities (22 total, 10 thin omitted)

### Community 0 - "Sketchup"
Cohesion: 0.07
Nodes (7): Sketchup, Sketchup::ComponentDefinition, Sketchup::ComponentInstance, Sketchup::Entity, Sketchup::FakeModel, Sketchup::FakeSelection, Sketchup::Group

### Community 1 - "UI::HtmlDialog"
Cohesion: 0.07
Nodes (6): Sketchup, UI, UI::Command, UI::HtmlDialog, UI::Menu, UI::Toolbar

### Community 2 - "VGD::Diagram::Tree"
Cohesion: 0.14
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Tree

### Community 4 - "VGD::Diagram::ModelIO"
Cohesion: 0.13
Nodes (6): VGD, VGD::Diagram, VGD::Diagram::ModelIO, VGD, VGD::Diagram, VGD::Diagram::Scene

### Community 5 - "UI::HtmlDialog"
Cohesion: 0.09
Nodes (8): Cấu trúc, Kiểm thử, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD Diagram — hướng dẫn cho Claude, Đóng gói, UI, UI::HtmlDialog

### Community 7 - "test_ui.cjs"
Cohesion: 0.25
Nodes (4): { chromium }, failed, path, sample

### Community 8 - "vgd-theme.js"
Cohesion: 0.54
Nodes (7): apply(), current(), readSaved(), root(), start(), systemIsDark(), writeSaved()

### Community 9 - "VGD Diagram 0.10.5-beta.1"
Cohesion: 0.25
Nodes (7): Cài đặt và tải lại, Cách dùng, Kiểm thử, Mô hình 3D, Quy tắc gom và thứ tự (giả định cần xác nhận), Trạng thái, VGD Diagram 0.10.6-beta.1

### Community 12 - "dialog.js"
Cohesion: 0.09
Nodes (61): Quy tắc riêng, addArrow(), advancePlayback(), applyOrder(), bindExplodeControls(), bindOrbit(), captureView(), changeScope() (+53 more)

### Community 28 - "Sketchup"
Cohesion: 0.06
Nodes (14): Geom, Geom::Point3d, Geom::Transformation, Sketchup, Sketchup::ComponentDefinition, Sketchup::ComponentInstance, Sketchup::Entity, Sketchup::Face (+6 more)

### Community 52 - "VGD::Diagram::Ffmpeg"
Cohesion: 0.16
Nodes (4): VGD, VGD::Diagram, VGD::Diagram::Ffmpeg, VGD::Diagram::Ffmpeg::Job

### Community 73 - "UI::HtmlDialog"
Cohesion: 0.09
Nodes (6): Geom, Geom::Transformation, OpenDialogStub, Sketchup, Sketchup::FakeModel, Sketchup::FakeSelection

## Knowledge Gaps
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Quy tắc riêng` connect `dialog.js` to `UI::HtmlDialog`, `VGD::Diagram::Dialog`, `UI::HtmlDialog`?**
  _High betweenness centrality (0.228) - this node is a cross-community bridge._
- **Should `Sketchup` be split into smaller, more focused modules?**
  _Cohesion score 0.06666666666666667 - nodes in this community are weakly interconnected._
- **Why does `VGD::Diagram::Dialog` connect `VGD::Diagram::Dialog` to `VGD`?**
  _High betweenness centrality (0.212) - this node is a cross-community bridge._
- **Should `UI::HtmlDialog` be split into smaller, more focused modules?**
  _Cohesion score 0.06896551724137931 - nodes in this community are weakly interconnected._
- **Why does `UI` connect `UI::HtmlDialog` to `UI::HtmlDialog`?**
  _High betweenness centrality (0.058) - this node is a cross-community bridge._
- **Should `VGD::Diagram::Tree` be split into smaller, more focused modules?**
  _Cohesion score 0.14 - nodes in this community are weakly interconnected._
- **Should `VGD::Diagram::Dialog` be split into smaller, more focused modules?**
  _Cohesion score 0.13178294573643412 - nodes in this community are weakly interconnected._