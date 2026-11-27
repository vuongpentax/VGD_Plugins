# Graph Report - VGD_Center  (2026-11-26)

## Corpus Check
- 46 files · ~40,169 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 6 file(s) not represented in the graph (top: .css 3, .woff2 2, (none) 1)

## Summary
- 420 nodes · 717 edges · 43 communities (13 shown, 30 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 31 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6808f66b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- VGD::Center
- VGD::Center::Manager::Toggle
- UI::HtmlDialog
- Sketchup
- manager.js
- VGD::Center::Manager
- package.py
- UI::HtmlDialog
- test_center.rb
- UI
- UI::HtmlDialog
- VGD::Center::Manager::Linker
- vgd-theme.js
- VGD::Center::Manager
- .write
- VGD
- VGD
- VGD
- menu
- RELEASE_NOTES_v1.0.0.md
- RELEASE_NOTES_v1.0.1.md
- RELEASE_NOTES_v1.0.10.md
- RELEASE_NOTES_v1.0.11.md
- RELEASE_NOTES_v1.0.2.md
- RELEASE_NOTES_v1.0.3.md
- RELEASE_NOTES_v1.0.4.md
- RELEASE_NOTES_v1.0.5.md
- RELEASE_NOTES_v1.0.6.md
- RELEASE_NOTES_v1.0.7.md
- RELEASE_NOTES_v1.0.8.md
- RELEASE_NOTES_v1.0.9.md
- RELEASE_NOTES_v1.1.0.md
- RELEASE_NOTES_v1.2.0.md
- RELEASE_NOTES_v1.2.1.md
- RELEASE_NOTES_v1.2.2.md
- RELEASE_NOTES_v1.2.3.md
- RELEASE_NOTES_v1.2.4.md
- RELEASE_NOTES_v1.2.5.md
- RELEASE_NOTES_v1.2.6.md

## God Nodes (most connected - your core abstractions)
1. `VGD::Center` - 53 edges
2. `VGD::Center::Manager::Toggle` - 43 edges
3. `VGD::Center::Manager` - 18 edges
4. `byId()` - 18 edges
5. `init()` - 16 edges
6. `UI::HtmlDialog` - 12 edges
7. `drawToggle()` - 11 edges
8. `main()` - 10 edges
9. `UI::HtmlDialog` - 10 edges
10. `Sketchup` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Cấu trúc` --references--> `main()`  [INFERRED]
  CLAUDE.md → dev/package.py
- `Hướng dẫn cho plugin` --references--> `main()`  [INFERRED]
  README.md → dev/package.py

## Import Cycles
- None detected.

## Communities (43 total, 30 thin omitted)

### Community 2 - "UI::HtmlDialog"
Cohesion: 0.05
Nodes (6): Sketchup, UI, UI::Command, UI::HtmlDialog, UI::Menu, UI::Toolbar

### Community 3 - "Sketchup"
Cohesion: 0.06
Nodes (12): Cấu trúc, Kiểm thử, Quy tắc riêng, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD Center, Đóng gói, Sketchup (+4 more)

### Community 4 - "manager.js"
Cohesion: 0.19
Nodes (34): applyAttributes(), bind(), bulk(), bulkNames(), byId(), call(), collect(), drawToggle() (+26 more)

### Community 5 - "VGD::Center::Manager"
Cohesion: 0.11
Nodes (7): VGD, VGD::Center, VGD::Center::Manager, VGD, VGD::Center, VGD::Center::Manager, VGD::Center::Manager::Log

### Community 6 - "package.py"
Cohesion: 0.15
Nodes (13): check_catalog(), collect_files(), fail(), main(), read_version(), sync_shared_metadata(), Cài đặt, Hướng dẫn cho plugin (+5 more)

### Community 7 - "UI::HtmlDialog"
Cohesion: 0.11
Nodes (5): Sketchup, Sketchup::Http, Sketchup::Http::Request::Response, UI, UI::HtmlDialog

### Community 8 - "test_center.rb"
Cohesion: 0.16
Nodes (6): check(), FakeExtension, FakeExtensions, ids_of(), rejected(), validate()

### Community 11 - "VGD::Center::Manager::Linker"
Cohesion: 0.31
Nodes (4): VGD, VGD::Center, VGD::Center::Manager, VGD::Center::Manager::Linker

### Community 12 - "vgd-theme.js"
Cohesion: 0.54
Nodes (7): apply(), current(), readSaved(), root(), start(), systemIsDark(), writeSaved()

### Community 13 - "VGD::Center::Manager"
Cohesion: 0.29
Nodes (4): VGD, VGD::Center, VGD::Center::Manager, VGD::Center::Manager::Text

### Community 14 - ".write"
Cohesion: 0.33
Nodes (4): VGD, VGD::Center, VGD::Center::Manager, VGD::Center::Manager::ZipWriter

### Community 17 - "VGD"
Cohesion: 0.50
Nodes (3): VGD, VGD::Center, VGD::Center::Manager

### Community 18 - "VGD"
Cohesion: 0.50
Nodes (3): VGD, VGD::Center, VGD::Center::Manager

## Knowledge Gaps
- **30 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `VGD::Center` connect `VGD::Center` to `menu`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `init()` (e.g. with `manager.js` and `drawToggle()`) actually correct?**
  _`init()` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Should `VGD::Center` be split into smaller, more focused modules?**
  _Cohesion score 0.1025974025974026 - nodes in this community are weakly interconnected._
- **Why does `VGD::Center::Manager::Toggle` connect `VGD::Center::Manager::Toggle` to `VGD`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **Should `VGD::Center::Manager::Toggle` be split into smaller, more focused modules?**
  _Cohesion score 0.12050739957716702 - nodes in this community are weakly interconnected._
- **Why does `Sketchup::Http::Request` connect `VGD::Center` to `UI::HtmlDialog`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._
- **Should `UI::HtmlDialog` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._