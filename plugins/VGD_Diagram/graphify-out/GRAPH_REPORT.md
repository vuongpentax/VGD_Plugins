# Graph Report - VGD_Diagram  (2026-11-28)

## Corpus Check
- 18 files · ~7,018 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 3 file(s) not represented in the graph (top: .woff2 2, (none) 1)

## Summary
- 161 nodes · 221 edges · 16 communities (11 shown, 5 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 3 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `636033db`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Sketchup
- UI::HtmlDialog
- VGD::Diagram::Tree
- VGD::Diagram::Dialog
- VGD::Diagram::ModelIO
- VGD Diagram — hướng dẫn cho Claude
- menu
- test_ui.cjs
- vgd-theme.js
- VGD Diagram 0.1.0-beta.1
- test_reload.rb
- renderNode
- VGD
- VGD

## God Nodes (most connected - your core abstractions)
1. `VGD::Diagram::Tree` - 18 edges
2. `VGD::Diagram::Dialog` - 12 edges
3. `UI::HtmlDialog` - 10 edges
4. `VGD::Diagram::ModelIO` - 9 edges
5. `UI` - 7 edges
6. `Sketchup` - 7 edges
7. `renderNode()` - 7 edges
8. `VGD Diagram — hướng dẫn cho Claude` - 7 edges
9. `UI::Toolbar` - 6 edges
10. `Sketchup::FakeModel` - 6 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (16 total, 5 thin omitted)

### Community 0 - "Sketchup"
Cohesion: 0.08
Nodes (7): Sketchup, Sketchup::ComponentDefinition, Sketchup::ComponentInstance, Sketchup::Entity, Sketchup::FakeModel, Sketchup::FakeSelection, Sketchup::Group

### Community 1 - "UI::HtmlDialog"
Cohesion: 0.09
Nodes (5): UI, UI::Command, UI::HtmlDialog, UI::Menu, UI::Toolbar

### Community 2 - "VGD::Diagram::Tree"
Cohesion: 0.18
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Tree

### Community 3 - "VGD::Diagram::Dialog"
Cohesion: 0.25
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Dialog

### Community 4 - "VGD::Diagram::ModelIO"
Cohesion: 0.31
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::ModelIO

### Community 5 - "VGD Diagram — hướng dẫn cho Claude"
Cohesion: 0.25
Nodes (7): Cấu trúc, Kiểm thử, Quy tắc riêng, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD Diagram — hướng dẫn cho Claude, Đóng gói

### Community 6 - "menu"
Cohesion: 0.25
Nodes (3): menu(), VGD, VGD::Diagram

### Community 7 - "test_ui.cjs"
Cohesion: 0.25
Nodes (4): { chromium }, failed, path, sample

### Community 8 - "vgd-theme.js"
Cohesion: 0.54
Nodes (7): apply(), current(), readSaved(), root(), start(), systemIsDark(), writeSaved()

### Community 9 - "VGD Diagram 0.1.0-beta.1"
Cohesion: 0.29
Nodes (6): Cài đặt và tải lại, Cách dùng, Kiểm thử, Quy tắc gom và thứ tự (giả định cần xác nhận), Trạng thái, VGD Diagram 0.1.0-beta.1

### Community 12 - "renderNode"
Cohesion: 0.60
Nodes (5): checkOrder(), renderNode(), send(), setStatus(), updateSave()

## Knowledge Gaps
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `UI` connect `UI::HtmlDialog` to `VGD::Diagram::Dialog`, `test_reload.rb`, `menu`?**
  _High betweenness centrality (0.110) - this node is a cross-community bridge._
- **Should `Sketchup` be split into smaller, more focused modules?**
  _Cohesion score 0.07671957671957672 - nodes in this community are weakly interconnected._
- **Why does `VGD::Diagram::Tree` connect `VGD::Diagram::Tree` to `VGD::Diagram::Dialog`?**
  _High betweenness centrality (0.056) - this node is a cross-community bridge._
- **Should `UI::HtmlDialog` be split into smaller, more focused modules?**
  _Cohesion score 0.09090909090909091 - nodes in this community are weakly interconnected._
- **Why does `UI::HtmlDialog` connect `UI::HtmlDialog` to `VGD::Diagram::Dialog`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._