# Graph Report - VGD_Reference  (2026-11-26)

## Corpus Check
- 63 files · ~22,704 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 6 file(s) not represented in the graph (top: .css 3, .woff2 2, (none) 1)

## Summary
- 608 nodes · 1035 edges · 47 communities (30 shown, 17 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 11 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6808f66b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- VGD::Reference::Session
- compile.cjs
- VGD::Reference::InteractionTool
- VGD::Reference::ImageImport
- VGD::Reference::ReferenceOverlay
- UI::HtmlDialog
- Sketchup
- VGD::Reference::ReferenceItem
- VGD Reference 1.0.3
- VGDReferenceDiagnostics
- VGD::Reference::TextureCache
- VGD::Reference::ReferenceStore
- VGDReferenceSU2022Probe::Tool
- import.js
- VGDReferenceSpike::OverlayProbe
- Geom::BoundingBox
- VGD::Reference::AppObserver
- SketchUp verification checklist
- VGD Reference — handoff
- .read_image
- VGD Reference
- vgd-theme.js
- VGD Reference — icon và theme
- VGD::Reference::TextureCacheFixtureView
- .cursor
- VGD::Reference::Icons
- VGD::Reference::RenderFixtureView
- VGD::Reference::RedrawFixtureView
- VGD Reference 1.0.0-beta.5
- VGD Reference 1.0.0-beta.6
- VGD Reference 1.0.0-beta.7
- VGD
- app.js
- VGD
- VGD Reference 1.0.1
- VGD
- VGD
- VGD
- VGD
- menu
- VGD
- RELEASE_NOTES_v1.0.0-beta.3.md
- RELEASE_NOTES_v1.0.0-beta.4.md
- RELEASE_NOTES_v1.0.2.md
- vgd_reference.rb

## God Nodes (most connected - your core abstractions)
1. `VGD::Reference::Session` - 39 edges
2. `VGD::Reference::InteractionTool` - 30 edges
3. `VGD::Reference::ReferenceItem` - 21 edges
4. `VGD::Reference::ImageImport` - 21 edges
5. `VGD::Reference::ReferenceOverlay` - 17 edges
6. `VGD::Reference::ReferenceStore` - 15 edges
7. `VGD::Reference::Manager` - 15 edges
8. `UI::HtmlDialog` - 14 edges
9. `VGD::Reference::TextureCache` - 14 edges
10. `VGDReferenceDiagnostics` - 12 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (47 total, 17 thin omitted)

### Community 0 - "VGD::Reference::Session"
Cohesion: 0.10
Nodes (3): VGD::Reference::Session, VGD::Reference, VGD::Reference::Manager

### Community 1 - "compile.cjs"
Cohesion: 0.05
Nodes (37): colors, folder, fs, manifest, path, paths, root, fs (+29 more)

### Community 2 - "VGD::Reference::InteractionTool"
Cohesion: 0.07
Nodes (12): VGD, VGD::Reference, VGD::Reference::CropController, VGD, VGD::Reference, VGD::Reference::InteractionTool, VGD, VGD::Reference (+4 more)

### Community 3 - "VGD::Reference::ImageImport"
Cohesion: 0.08
Nodes (15): VGD, VGD::Reference, VGD::Reference::ImageFormats, VGD, VGD::Reference, VGD::Reference::ImageImport, VGD, VGD::Reference (+7 more)

### Community 4 - "VGD::Reference::ReferenceOverlay"
Cohesion: 0.09
Nodes (12): Geom, Geom::Point3d, Sketchup, Sketchup::Color, Sketchup::Overlay, UI, VGD, VGD::Reference (+4 more)

### Community 5 - "UI::HtmlDialog"
Cohesion: 0.07
Nodes (5): UI, UI::Command, UI::HtmlDialog, UI::Menu, UI::Toolbar

### Community 6 - "Sketchup"
Cohesion: 0.08
Nodes (6): FakeModel, Geom, Numeric, Sketchup, Sketchup::AppObserver, Sketchup::Overlay

### Community 7 - "VGD::Reference::ReferenceItem"
Cohesion: 0.14
Nodes (3): VGD, VGD::Reference, VGD::Reference::ReferenceItem

### Community 8 - "VGD Reference 1.0.3"
Cohesion: 0.10
Nodes (18): API đã đối chiếu, Phạm vi đã xác minh, Probe và hướng làm tiếp, Quyết định cho gói hiện tại, Vì sao không chỉ đổi minimum xuống 22, Đánh giá SketchUp 2022 cho VGD Reference beta.6, Chẩn đoán hiển thị, Cài đặt (+10 more)

### Community 10 - "VGD::Reference::TextureCache"
Cohesion: 0.24
Nodes (3): VGD, VGD::Reference, VGD::Reference::TextureCache

### Community 11 - "VGD::Reference::ReferenceStore"
Cohesion: 0.18
Nodes (3): VGD, VGD::Reference, VGD::Reference::ReferenceStore

### Community 13 - "import.js"
Cohesion: 0.31
Nodes (10): base64(), call(), collectDrop(), dataImage(), decodeImage(), init(), normalizeUrl(), processDrop() (+2 more)

### Community 15 - "Geom::BoundingBox"
Cohesion: 0.18
Nodes (4): Geom, Geom::BoundingBox, Sketchup, Sketchup::Overlay

### Community 16 - "VGD::Reference::AppObserver"
Cohesion: 0.20
Nodes (3): VGD, VGD::Reference, VGD::Reference::AppObserver

### Community 17 - "SketchUp verification checklist"
Cohesion: 0.22
Nodes (8): Beta.6 — icon and manager themes, SketchUp verification checklist, Spike 01 — overlay texture, Spike 02 — opacity, Spike 03 — edit tool, Spike 04 — RMB quick move, Spike 05 — clipboard and drop, Spike 06 — DPI

### Community 18 - "VGD Reference — handoff"
Cohesion: 0.22
Nodes (8): 1.0.1 changes, Architecture, Beta.6 — VGD icon system and theme, Beta.7 — browser image drop and formats, Current limitations, SketchUp 2022 assessment, Spike status, VGD Reference — handoff

### Community 19 - ".read_image"
Cohesion: 0.42
Nodes (4): VGD, VGD::Reference, VGD::Reference::ClipboardBridgeWin, VGD::Reference::ClipboardBridgeWin::Native

### Community 20 - "VGD Reference"
Cohesion: 0.25
Nodes (7): Cấu trúc, Kiểm thử, Quy tắc riêng, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD Reference, Đóng gói

### Community 21 - "vgd-theme.js"
Cohesion: 0.54
Nodes (7): apply(), current(), readSaved(), root(), start(), systemIsDark(), writeSaved()

### Community 22 - "VGD Reference — icon và theme"
Cohesion: 0.29
Nodes (6): File và vai trò, Hình tượng, Kiểm tra đã thực hiện, Theme trong runtime, Tạo lại và đóng gói, VGD Reference — icon và theme

### Community 23 - "VGD::Reference::TextureCacheFixtureView"
Cohesion: 0.29
Nodes (3): VGD, VGD::Reference, VGD::Reference::TextureCacheFixtureView

### Community 24 - ".cursor"
Cohesion: 0.33
Nodes (3): VGD, VGD::Reference, VGD::Reference::CursorManager

### Community 25 - "VGD::Reference::Icons"
Cohesion: 0.38
Nodes (3): VGD, VGD::Reference, VGD::Reference::Icons

### Community 26 - "VGD::Reference::RenderFixtureView"
Cohesion: 0.33
Nodes (3): VGD, VGD::Reference, VGD::Reference::RenderFixtureView

### Community 27 - "VGD::Reference::RedrawFixtureView"
Cohesion: 0.33
Nodes (3): VGD, VGD::Reference, VGD::Reference::RedrawFixtureView

### Community 28 - "VGD Reference 1.0.0-beta.5"
Cohesion: 0.33
Nodes (5): Cài đặt, Kiểm tra, Sửa cập nhật viewport, Sửa hiển thị ảnh, VGD Reference 1.0.0-beta.5

### Community 29 - "VGD Reference 1.0.0-beta.6"
Cohesion: 0.33
Nodes (5): Hiển thị ảnh, Icon VGD và giao diện, Kiểm tra, VGD Reference 1.0.0-beta.6, Đóng gói

### Community 30 - "VGD Reference 1.0.0-beta.7"
Cohesion: 0.40
Nodes (4): Bằng chứng hiện có, Giới hạn và cài đặt, Thay đổi, VGD Reference 1.0.0-beta.7

### Community 31 - "VGD"
Cohesion: 0.40
Nodes (3): VGD, VGD::Reference, VGD::Reference::Compatibility

### Community 34 - "VGD Reference 1.0.1"
Cohesion: 0.50
Nodes (3): Giới hạn đã biết, Thay đổi, VGD Reference 1.0.1

## Knowledge Gaps
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `UI` connect `UI::HtmlDialog` to `Sketchup`?**
  _High betweenness centrality (0.071) - this node is a cross-community bridge._
- **Should `VGD::Reference::Session` be split into smaller, more focused modules?**
  _Cohesion score 0.10163170163170163 - nodes in this community are weakly interconnected._
- **Why does `VGD::Reference::ReferenceOverlay` connect `VGD::Reference::ReferenceOverlay` to `VGD::Reference::Session`, `VGDReferenceDiagnostics`, `VGD::Reference::TextureCache`, `Geom::BoundingBox`?**
  _High betweenness centrality (0.064) - this node is a cross-community bridge._
- **Should `compile.cjs` be split into smaller, more focused modules?**
  _Cohesion score 0.05279034690799397 - nodes in this community are weakly interconnected._
- **Why does `Sketchup::Color` connect `VGD::Reference::ReferenceOverlay` to `VGDReferenceSU2022Probe::Tool`?**
  _High betweenness centrality (0.063) - this node is a cross-community bridge._
- **Should `VGD::Reference::InteractionTool` be split into smaller, more focused modules?**
  _Cohesion score 0.06787330316742081 - nodes in this community are weakly interconnected._
- **Should `VGD::Reference::ImageImport` be split into smaller, more focused modules?**
  _Cohesion score 0.08282828282828283 - nodes in this community are weakly interconnected._