# Graph Report - VGD_Package  (2026-11-26)

## Corpus Check
- 16 files · ~4,192 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 6 file(s) not represented in the graph (top: .css 3, .woff2 2, (none) 1)

## Summary
- 132 nodes · 179 edges · 14 communities (10 shown, 4 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 3 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6808f66b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- .show
- VGD::Pack::Compatibility
- VGD::Pack::Scanner
- VGD::Pack::Asset
- VGD::Pack::Research::EnscapeInspector
- VGD Package
- UI::HtmlDialog
- vgd-theme.js
- VGD Package 0.1.7 — Bản nghiên cứu
- Phase 0 — Enscape data findings
- menu
- VGD

## God Nodes (most connected - your core abstractions)
1. `VGD::Pack::Research::EnscapeInspector` - 11 edges
2. `VGD::Pack::Compatibility` - 10 edges
3. `UI::HtmlDialog` - 9 edges
4. `VGD::Pack::Asset` - 8 edges
5. `VGD::Pack::UI` - 7 edges
6. `VGD Package` - 7 edges
7. `Sketchup` - 6 edges
8. `start()` - 6 edges
9. `VGD Package 0.1.7 — Bản nghiên cứu` - 6 edges
10. `UI` - 5 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (14 total, 4 thin omitted)

### Community 0 - ".show"
Cohesion: 0.14
Nodes (5): UI, UI::Menu, VGD, VGD::Pack, VGD::Pack::UI

### Community 1 - "VGD::Pack::Compatibility"
Cohesion: 0.20
Nodes (6): Sketchup, Sketchup::Material, Sketchup::Texture, VGD, VGD::Pack, VGD::Pack::Compatibility

### Community 2 - "VGD::Pack::Scanner"
Cohesion: 0.15
Nodes (7): VGD, VGD::Pack, VGD::Pack::Adapters, VGD::Pack::Adapters::SketchUpPBR, VGD, VGD::Pack, VGD::Pack::Scanner

### Community 3 - "VGD::Pack::Asset"
Cohesion: 0.16
Nodes (7): VGD, VGD::Pack, VGD::Pack::Adapters, VGD::Pack::Adapters::SketchUpTexture, VGD, VGD::Pack, VGD::Pack::Asset

### Community 4 - "VGD::Pack::Research::EnscapeInspector"
Cohesion: 0.23
Nodes (4): VGD, VGD::Pack, VGD::Pack::Research, VGD::Pack::Research::EnscapeInspector

### Community 5 - "VGD Package"
Cohesion: 0.25
Nodes (7): Cấu trúc, Kiểm thử, Quy tắc riêng, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD Package, Đóng gói

### Community 7 - "vgd-theme.js"
Cohesion: 0.54
Nodes (7): apply(), current(), readSaved(), root(), start(), systemIsDark(), writeSaved()

### Community 8 - "VGD Package 0.1.7 — Bản nghiên cứu"
Cohesion: 0.29
Nodes (6): Chức năng hiện tại, Cài đặt, Kiểm thử, Tương thích API, Tải lại code, VGD Package 0.1.7 — Bản nghiên cứu

### Community 9 - "Phase 0 — Enscape data findings"
Cohesion: 0.33
Nodes (5): Embedded image evidence, Inspector correction, Observed storage, Phase 0 — Enscape data findings, Safety conclusion

### Community 10 - "menu"
Cohesion: 0.40
Nodes (3): menu(), VGD, VGD::Pack

## Knowledge Gaps
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `VGD::Pack::Scanner` connect `VGD::Pack::Scanner` to `.show`?**
  _High betweenness centrality (0.123) - this node is a cross-community bridge._
- **Should `.show` be split into smaller, more focused modules?**
  _Cohesion score 0.14210526315789473 - nodes in this community are weakly interconnected._
- **Why does `VGD::Pack::Compatibility` connect `VGD::Pack::Compatibility` to `VGD::Pack::Scanner`?**
  _High betweenness centrality (0.088) - this node is a cross-community bridge._
- **Why does `VGD::Pack::Asset` connect `VGD::Pack::Asset` to `VGD::Pack::Scanner`?**
  _High betweenness centrality (0.086) - this node is a cross-community bridge._