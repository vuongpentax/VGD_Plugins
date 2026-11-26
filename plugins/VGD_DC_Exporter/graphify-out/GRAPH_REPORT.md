# Graph Report - VGD_DC_Exporter  (2026-11-26)

## Corpus Check
- 9 files · ~3,839 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 111 nodes · 158 edges · 11 communities (7 shown, 4 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6808f66b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- VGD_DC_Exporter::Walker
- test_exporter.rb
- Obj
- UI
- VGD_DC_Exporter::Params
- VGD DC Exporter
- test_reload.rb
- Sketchup
- VGD DC Exporter 1.0.5
- build_release.py
- vgd_dc_exporter.rb

## God Nodes (most connected - your core abstractions)
1. `VGD_DC_Exporter::Walker` - 19 edges
2. `Obj` - 7 edges
3. `Vec` - 7 edges
4. `VGD_DC_Exporter::Params` - 7 edges
5. `VGD DC Exporter` - 7 edges
6. `Sketchup` - 6 edges
7. `Tr` - 6 edges
8. `VGD DC Exporter 1.0.5` - 6 edges
9. `Box` - 5 edges
10. `UI` - 5 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (11 total, 4 thin omitted)

### Community 1 - "test_exporter.rb"
Cohesion: 0.13
Nodes (4): Box, Pt, Tr, Vec

### Community 2 - "Obj"
Cohesion: 0.18
Nodes (3): Dict, Ents, Obj

### Community 3 - "UI"
Cohesion: 0.19
Nodes (5): UI, UI::M, menu(), VGD, VGD_DC_Exporter

### Community 5 - "VGD DC Exporter"
Cohesion: 0.25
Nodes (7): Cấu trúc, Kiểm thử, Quy tắc riêng, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD DC Exporter, Đóng gói

### Community 6 - "test_reload.rb"
Cohesion: 0.25
Nodes (3): Sketchup, Sketchup::ComponentInstance, Sketchup::Group

### Community 7 - "Sketchup"
Cohesion: 0.38
Nodes (5): Sketchup, Sketchup::ComponentInstance, Sketchup::Entity, Sketchup::Face, Sketchup::Group

### Community 8 - "VGD DC Exporter 1.0.5"
Cohesion: 0.29
Nodes (6): Cài và dùng, Giới hạn, Kiểm thử, Nội dung JSON (schema `vgd.dc_snapshot`, version 2), Tải lại code, VGD DC Exporter 1.0.5

## Knowledge Gaps
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `VGD_DC_Exporter::Walker` connect `VGD_DC_Exporter::Walker` to `UI`?**
  _High betweenness centrality (0.103) - this node is a cross-community bridge._
- **Should `test_exporter.rb` be split into smaller, more focused modules?**
  _Cohesion score 0.1286549707602339 - nodes in this community are weakly interconnected._
- **Why does `UI` connect `UI` to `test_reload.rb`?**
  _High betweenness centrality (0.080) - this node is a cross-community bridge._
- **Why does `Sketchup` connect `Sketchup` to `test_exporter.rb`?**
  _High betweenness centrality (0.034) - this node is a cross-community bridge._