# Graph Report - VGD_Image_Importer  (2026-11-26)

## Corpus Check
- 30 files · ~13,064 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 6 file(s) not represented in the graph (top: .css 3, .woff2 2, (none) 1)

## Summary
- 289 nodes · 385 edges · 25 communities (14 shown, 11 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 15 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6808f66b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- fixture.rb
- test_ui.cjs
- VGD_ImageImporter
- UI::HtmlDialog
- UI::HtmlDialog
- VGD_ImageImporter
- package.json
- test_reload.rb
- dialog.js
- test_drop.rb
- VGD Image Importer
- VGD Image Importer 1.1.2
- vgd-theme.js
- VGDImageImporterSmoke
- VGD Image Importer — bàn giao
- VGD_ImageImporter::FilePicker
- main.rb
- RELEASE_NOTES_v1.1.0.md
- RELEASE_NOTES_v1.1.0-beta.5.md
- RELEASE_NOTES_v1.1.1.md
- vgd_image_importer.rb

## God Nodes (most connected - your core abstractions)
1. `VGD_ImageImporter` - 18 edges
2. `UI::HtmlDialog` - 10 edges
3. `UI::HtmlDialog` - 10 edges
4. `UI` - 9 edges
5. `VGD_ImageImporter` - 9 edges
6. `Sketchup` - 7 edges
7. `Entities` - 7 edges
8. `Dir` - 7 edges
9. `VGD Image Importer` - 7 edges
10. `Sketchup::ImageRep` - 6 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (25 total, 11 thin omitted)

### Community 0 - "fixture.rb"
Cohesion: 0.06
Nodes (10): Definitions, Entities, Material, Materials, Model, Numeric, Sketchup, SketchupExtension (+2 more)

### Community 1 - "test_ui.cjs"
Cohesion: 0.09
Nodes (21): fs, path, { RubyVM }, { WASI }, fs, path, resolve(), add() (+13 more)

### Community 2 - "VGD_ImageImporter"
Cohesion: 0.19
Nodes (3): Dir, VGD_ImageImporter, VGD_ImageImporter

### Community 3 - "UI::HtmlDialog"
Cohesion: 0.08
Nodes (5): UI, UI::Command, UI::HtmlDialog, UI::Menu, UI::Toolbar

### Community 4 - "UI::HtmlDialog"
Cohesion: 0.10
Nodes (5): UI, UI::Command, UI::HtmlDialog, UI::Menu, UI::Toolbar

### Community 5 - "VGD_ImageImporter"
Cohesion: 0.15
Nodes (4): Geom, Geom::Transformation, Sketchup::ImageRep, VGD_ImageImporter

### Community 6 - "package.json"
Cohesion: 0.16
Nodes (15): devDependencies, jszip@3.10.1, playwright@1.58.2, @ruby/3.2-wasm-wasi@2.10.1, @ruby/wasm-wasi@2.10.1, name, private, scripts (+7 more)

### Community 7 - "test_reload.rb"
Cohesion: 0.13
Nodes (5): Geom, Numeric, Sketchup, Sketchup::SketchupExtension, SketchupExtension

### Community 8 - "dialog.js"
Cohesion: 0.24
Nodes (10): call(), config(), convertImage(), done(), fileUrl(), renderFiles(), sendDroppedFile(), status() (+2 more)

### Community 9 - "test_drop.rb"
Cohesion: 0.18
Nodes (6): run_drop_tests(), Sketchup, Sketchup::Http, Sketchup::Http::Request, Sketchup::Http::Request::Resp, UI

### Community 11 - "VGD Image Importer"
Cohesion: 0.25
Nodes (7): Cấu trúc, Kiểm thử, Quy tắc riêng, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD Image Importer, Đóng gói

### Community 12 - "VGD Image Importer 1.1.2"
Cohesion: 0.25
Nodes (6): Chức năng, Cài đặt, Phát triển và kiểm tra, Tải lại code, VGD Image Importer 1.1.2, VGD Image Importer 1.1.2

### Community 13 - "vgd-theme.js"
Cohesion: 0.54
Nodes (7): apply(), current(), readSaved(), root(), start(), systemIsDark(), writeSaved()

### Community 16 - "VGD Image Importer — bàn giao"
Cohesion: 0.40
Nodes (4): Cấu trúc, Giới hạn đã biết, Quy tắc tiếp tục, VGD Image Importer — bàn giao

## Knowledge Gaps
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Sketchup::ImageRep` connect `VGD_ImageImporter` to `fixture.rb`, `VGDImageImporterSmoke`?**
  _High betweenness centrality (0.109) - this node is a cross-community bridge._
- **Should `fixture.rb` be split into smaller, more focused modules?**
  _Cohesion score 0.06456456456456457 - nodes in this community are weakly interconnected._
- **Why does `Sketchup` connect `fixture.rb` to `VGD_ImageImporter`?**
  _High betweenness centrality (0.101) - this node is a cross-community bridge._
- **Should `test_ui.cjs` be split into smaller, more focused modules?**
  _Cohesion score 0.08870967741935484 - nodes in this community are weakly interconnected._
- **Should `UI::HtmlDialog` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._
- **Should `UI::HtmlDialog` be split into smaller, more focused modules?**
  _Cohesion score 0.09523809523809523 - nodes in this community are weakly interconnected._
- **Should `VGD_ImageImporter` be split into smaller, more focused modules?**
  _Cohesion score 0.14736842105263157 - nodes in this community are weakly interconnected._