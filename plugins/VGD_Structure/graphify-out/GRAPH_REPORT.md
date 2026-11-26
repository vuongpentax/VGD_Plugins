# Graph Report - VGD_Structure  (2026-11-26)

## Corpus Check
- 141 files · ~248,102 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 6 file(s) not represented in the graph (top: .css 3, .woff2 2, (none) 1)

## Summary
- 2265 nodes · 4633 edges · 156 communities (96 shown, 60 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 210 edges (avg confidence: 0.88)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6808f66b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- plan_edit.js
- plan_modify.js
- VGD::Structure::Panel
- plan_notes.js
- VGD::Structure::PickTool
- VGD::Structure::ModelEdit
- receive
- .normalize!
- VGD::Structure::SuSection
- test_bridge.rb
- changed
- test_door_hand.rb
- UI::HtmlDialog
- plan_section.js
- test_finish_layers.rb
- test_su_edit.rb
- test_su_section.rb
- test_wall_layers.rb
- .find
- Geom::Point3d
- test_schedule.rb
- test_sketchup_import.rb
- UI::HtmlDialog
- app.js
- plan_view.js
- Sketchup::Model
- UI::HtmlDialog
- VGD::Structure::RoofPlan
- elevation_view.js
- ed
- .ensure
- make_draw_icons.py
- UI::HtmlDialog
- draw
- VGD::Structure::PlateBuilder
- VGD::Structure::BeamBuilder
- plan_browser.js
- section_view.js
- VGD::Structure::WallBuilder
- .plan
- Sketchup
- .plan
- VGD::Structure::Geometry
- toScreen
- VGD::Structure::OpeningBuilder
- UI::HtmlDialog
- VGD::Structure::StairBuilder
- test_roof.rb
- .plan
- VGD::Structure::ColumnBuilder
- VGD::Structure::FootingBuilder
- Quy tắc riêng
- .plan_for
- VGD::Structure::WallJoins
- VGD::Structure::GlassWallBuilder
- .build
- Sketchup::FakeEntities
- .bounds
- renderLevelRooms
- buildTop
- .plan
- test_model_edit.rb
- VGD::Structure::StairPlan
- buildShapes
- onUp
- Sketchup::Instance
- test_footing_strip.rb
- .plan
- renderLayerEditor
- selectBox
- Sketchup::Selection
- test_joins.rb
- test_notes.rb
- test_polygon.rb
- test_structure_levels.rb
- test_ui.cjs
- .prepare
- .fingerprint
- Sketchup::Group
- test_glass_wall.rb
- test_opening_builder.rb
- test_plate_builder.rb
- test_slab_holes.rb
- test_stair_builder.rb
- .plan
- VGD::Structure::Grid
- VGD::Structure
- Sketchup::Materials
- test_beam_builder.rb
- test_column_builder.rb
- test_free.rb
- test_oblique.rb
- test_wall_builder.rb
- VGD::Bridge
- marks2d.js
- VGD Structure
- Sketchup::Face
- test_footing.rb
- test_free_footing.rb
- test_grid_builder.rb
- test_rooms.rb
- VGD::Structure::GridTag
- .harvest
- .write
- Sketchup::Entity
- test_elevation_geometry.rb
- test_proposal.rb
- .by_cell
- test_stair_hole.rb
- opening_plan.rb
- renderColumnsPlan
- test_section_geometry.rb
- test_stair_plan.rb
- VGD Structure 0.30.0-beta.10
- axis_symbol.rb
- beam_plan.rb
- beam_types.rb
- ceiling_plan.rb
- column_plan.rb
- column_types.rb
- footing_plan.rb
- grid.rb
- levels.rb
- opening_types.rb
- stair_types.rb
- wall_plan.rb
- wall_types.rb
- VGD
- VGD
- VGD
- RELEASE_NOTES_v0.1.0.md
- RELEASE_NOTES_v0.28.0.md
- RELEASE_NOTES_v0.29.0.md
- RELEASE_NOTES_v0.2.0.md
- RELEASE_NOTES_v0.30.0.md
- RELEASE_NOTES_v0.3.0.md
- RELEASE_NOTES_v0.4.0.md
- RELEASE_NOTES_v0.5.0.md
- RELEASE_NOTES_v0.6.0.md
- RELEASE_NOTES_v0.7.0.md
- RELEASE_NOTES_v0.8.0.md
- RELEASE_NOTES_v0.9.0.md

## God Nodes (most connected - your core abstractions)
1. `VGD::Structure::Panel` - 68 edges
2. `Quy tắc riêng` - 68 edges
3. `draw()` - 49 edges
4. `changed()` - 41 edges
5. `renderLevels()` - 39 edges
6. `receive()` - 35 edges
7. `currentLevel()` - 29 edges
8. `VGD::Structure::Levels` - 28 edges
9. `Geom::Point3d` - 27 edges
10. `Sketchup` - 24 edges

## Surprising Connections (you probably didn't know these)
- `Quy tắc riêng` --references--> `ring()`  [INFERRED]
  CLAUDE.md → runtime/vgd_structure/html/plan_view.js
- `Quy tắc riêng` --references--> `toRubyLevel()`  [INFERRED]
  CLAUDE.md → runtime/vgd_structure/html/app.js
- `Quy tắc riêng` --references--> `fromRubyLevel()`  [INFERRED]
  CLAUDE.md → runtime/vgd_structure/html/app.js
- `Quy tắc riêng` --references--> `plateProbe()`  [INFERRED]
  CLAUDE.md → runtime/vgd_structure/html/app.js
- `Quy tắc riêng` --references--> `changed()`  [INFERRED]
  CLAUDE.md → runtime/vgd_structure/html/app.js

## Import Cycles
- None detected.

## Communities (156 total, 60 thin omitted)

### Community 0 - "plan_edit.js"
Cohesion: 0.06
Nodes (90): addFreeColumn(), addFreeLinear(), addPicks(), addStair(), alignName(), alignOf(), alignOption(), blocked() (+82 more)

### Community 1 - "plan_modify.js"
Cohesion: 0.07
Nodes (76): activate(), alignClick(), applyMap(), applyOffset(), applyPlan(), box(), busy(), cancel() (+68 more)

### Community 3 - "plan_notes.js"
Cohesion: 0.09
Nodes (44): activate(), arcPoint(), arcSweep(), box(), circlePoly(), click(), constrained(), create() (+36 more)

### Community 4 - "VGD::Structure::PickTool"
Cohesion: 0.05
Nodes (10): Sketchup::Color, Sketchup::InputPoint, VGD, VGD::Structure, VGD::Structure::SuScan, VGD, VGD::Structure, VGD::Structure::ModelWatcher (+2 more)

### Community 5 - "VGD::Structure::ModelEdit"
Cohesion: 0.08
Nodes (11): VGD, VGD::Structure, VGD::Structure::ModelEdit, VGD::Structure::ModelEdit::Error, VGD, VGD::Structure, VGD::Structure::SketchupImport, VGD (+3 more)

### Community 6 - "receive"
Cohesion: 0.10
Nodes (43): addOpening(), currentLevel(), drawnList(), freeCenter(), isTop(), modeSelect(), openSectionView(), pickBeam() (+35 more)

### Community 7 - ".normalize!"
Cohesion: 0.10
Nodes (11): VGD::Structure::BeamTypes, VGD::Structure::ColumnTypes, VGD::Structure::OpeningTypes, VGD, VGD::Structure, VGD::Structure::Proposal, VGD::Structure::StairTypes, VGD (+3 more)

### Community 8 - "VGD::Structure::SuSection"
Cohesion: 0.09
Nodes (10): VGD, VGD::Structure, VGD::Structure::ElevationGeometry, VGD, VGD::Structure, VGD::Structure::SectionGeometry, VGD::Structure::SectionGeometry::Plane, VGD (+2 more)

### Community 9 - "test_bridge.rb"
Cohesion: 0.06
Nodes (9): Sketchup, SketchupExtension, UI, UI::Command, UI::HtmlDialog, UI::MenuNode, UI::Toolbar, VGD (+1 more)

### Community 10 - "changed"
Cohesion: 0.15
Nodes (36): addBeamType(), addLevel(), addOpeningType(), addType(), addWallType(), changed(), footingLabel(), footingProblems() (+28 more)

### Community 11 - "test_door_hand.rb"
Cohesion: 0.08
Nodes (9): built(), call(), count_ev(), evs(), last_ev(), UI, UI::HtmlDialog, VGD (+1 more)

### Community 12 - "UI::HtmlDialog"
Cohesion: 0.07
Nodes (7): Sketchup, SketchupExtension, UI, UI::Command, UI::HtmlDialog, UI::MenuNode, UI::Toolbar

### Community 13 - "plan_section.js"
Cohesion: 0.12
Nodes (20): activate(), box(), click(), dist(), draw(), field(), ghost(), handles() (+12 more)

### Community 14 - "test_finish_layers.rb"
Cohesion: 0.09
Nodes (10): call(), count_ev(), deep(), evs(), last_ev(), lv_state(), UI, UI::HtmlDialog (+2 more)

### Community 15 - "test_su_edit.rb"
Cohesion: 0.08
Nodes (8): call(), count_ev(), evs(), last_ev(), UI, UI::HtmlDialog, VGD, VGD::Structure

### Community 16 - "test_su_section.rb"
Cohesion: 0.09
Nodes (10): add_box(), call(), count_ev(), evs(), last_ev(), pt(), UI, UI::HtmlDialog (+2 more)

### Community 17 - "test_wall_layers.rb"
Cohesion: 0.09
Nodes (11): call(), count_ev(), deep(), evs(), last_ev(), layered_state(), UI, UI::HtmlDialog (+3 more)

### Community 19 - "Geom::Point3d"
Cohesion: 0.11
Nodes (6): Geom, Geom::Point3d, Geom::Transformation, Geom::Vector3d, Numeric, Sketchup::FakeBounds

### Community 20 - "test_schedule.rb"
Cohesion: 0.09
Nodes (8): call(), count_ev(), evs(), last_ev(), UI, UI::HtmlDialog, VGD, VGD::Structure

### Community 21 - "test_sketchup_import.rb"
Cohesion: 0.09
Nodes (8): call(), count_ev(), evs(), last_ev(), UI, UI::HtmlDialog, VGD, VGD::Structure

### Community 22 - "UI::HtmlDialog"
Cohesion: 0.09
Nodes (8): call(), count_ev(), evs(), last_ev(), UI, UI::HtmlDialog, VGD, VGD::Structure

### Community 23 - "app.js"
Cohesion: 0.14
Nodes (24): addAxis(), allCells(), allSpans(), cleanLayer(), clonePicks(), copySchedule(), defaultName(), drawPlan() (+16 more)

### Community 24 - "plan_view.js"
Cohesion: 0.13
Nodes (23): applyKeys(), buildKeys(), currentScaleN(), defaultKeymap(), fitView(), ghostStrip(), ghostZ(), keyOf() (+15 more)

### Community 26 - "UI::HtmlDialog"
Cohesion: 0.10
Nodes (8): call(), count_ev(), evs(), last_ev(), UI, UI::HtmlDialog, VGD, VGD::Structure

### Community 27 - "VGD::Structure::RoofPlan"
Cohesion: 0.15
Nodes (4): VGD, VGD::Structure, VGD::Structure::RoofPlan, VGD::Structure::RoofPlan::Error

### Community 28 - "elevation_view.js"
Cohesion: 0.19
Nodes (24): bind(), bounds(), colorOf(), compose(), css(), draw(), fit(), gridAxes() (+16 more)

### Community 29 - "ed"
Cohesion: 0.11
Nodes (24): addGuide(), axisLines(), constrain(), ed(), guideClick(), injectClick(), injectMove(), levelGuides() (+16 more)

### Community 30 - ".ensure"
Cohesion: 0.15
Nodes (7): VGD, VGD::Structure, VGD::Structure::RoofBuilder, VGD::Structure::RoofBuilder::Result, VGD, VGD::Structure, VGD::Structure::TagStore

### Community 31 - "make_draw_icons.py"
Cohesion: 0.12
Nodes (10): box(), fit(), front_rect(), icon(), main(), path_of(), proj(), svg_of() (+2 more)

### Community 32 - "UI::HtmlDialog"
Cohesion: 0.10
Nodes (7): add_box(), call(), pt(), UI, UI::HtmlDialog, VGD, VGD::Structure

### Community 33 - "draw"
Cohesion: 0.24
Nodes (23): adoptSu(), commandForKey(), deleteSelection(), draw(), drawDims(), hideSelection(), isolateSelection(), notifySelection() (+15 more)

### Community 34 - "VGD::Structure::PlateBuilder"
Cohesion: 0.18
Nodes (4): VGD, VGD::Structure, VGD::Structure::PlateBuilder, VGD::Structure::PlateBuilder::Result

### Community 35 - "VGD::Structure::BeamBuilder"
Cohesion: 0.15
Nodes (7): VGD, VGD::Structure, VGD::Structure::BeamBuilder, VGD::Structure::BeamBuilder::Result, VGD, VGD::Structure, VGD::Structure::Placement

### Community 36 - "plan_browser.js"
Cohesion: 0.20
Nodes (20): closeMenu(), effectiveType(), el(), elementLabel(), isOpen(), matches(), node(), norm() (+12 more)

### Community 37 - "section_view.js"
Cohesion: 0.21
Nodes (21): allSections(), axesCrossing(), bind(), bounds(), colorOf(), css(), draw(), fillSelect() (+13 more)

### Community 38 - "VGD::Structure::WallBuilder"
Cohesion: 0.17
Nodes (4): VGD, VGD::Structure, VGD::Structure::WallBuilder, VGD::Structure::WallBuilder::Result

### Community 39 - ".plan"
Cohesion: 0.15
Nodes (7): VGD::Structure::CeilingPlan, VGD, VGD::Structure, VGD::Structure::LayerList, VGD, VGD::Structure, VGD::Structure::Plates

### Community 40 - "Sketchup"
Cohesion: 0.13
Nodes (7): Sketchup, Sketchup::Definitions, Sketchup::Folder, Sketchup::Layer, Sketchup::Layers, Sketchup::LineStyle, Sketchup::SelectionObserver

### Community 42 - "VGD::Structure::Geometry"
Cohesion: 0.21
Nodes (3): VGD, VGD::Structure, VGD::Structure::Geometry

### Community 43 - "toScreen"
Cohesion: 0.16
Nodes (18): badgeCounts(), css(), drawBadges(), drawElevationMarks(), drawGrid(), drawOpening(), line(), drawOverlay() (+10 more)

### Community 44 - "VGD::Structure::OpeningBuilder"
Cohesion: 0.20
Nodes (4): VGD, VGD::Structure, VGD::Structure::OpeningBuilder, VGD::Structure::OpeningBuilder::Result

### Community 45 - "UI::HtmlDialog"
Cohesion: 0.12
Nodes (7): call(), events(), last_event(), UI, UI::HtmlDialog, VGD, VGD::Structure

### Community 46 - "VGD::Structure::StairBuilder"
Cohesion: 0.21
Nodes (4): VGD, VGD::Structure, VGD::Structure::StairBuilder, VGD::Structure::StairBuilder::Result

### Community 47 - "test_roof.rb"
Cohesion: 0.17
Nodes (8): kept_points(), norm(), outline(), outline_plan(), plan_of(), roof_state(), VGD, VGD::Structure

### Community 49 - "VGD::Structure::ColumnBuilder"
Cohesion: 0.23
Nodes (4): VGD, VGD::Structure, VGD::Structure::ColumnBuilder, VGD::Structure::ColumnBuilder::Result

### Community 50 - "VGD::Structure::FootingBuilder"
Cohesion: 0.23
Nodes (4): VGD, VGD::Structure, VGD::Structure::FootingBuilder, VGD::Structure::FootingBuilder::Result

### Community 51 - "Quy tắc riêng"
Cohesion: 0.30
Nodes (15): Quy tắc riêng, applySuEdit(), applySuImport(), historyChanged(), kindsToBuild(), levelSig(), message(), mutate() (+7 more)

### Community 52 - ".plan_for"
Cohesion: 0.19
Nodes (6): VGD, VGD::Structure, VGD::Structure::Checker, VGD, VGD::Structure, VGD::Structure::Schedule

### Community 53 - "VGD::Structure::WallJoins"
Cohesion: 0.27
Nodes (3): VGD, VGD::Structure, VGD::Structure::WallJoins

### Community 54 - "VGD::Structure::GlassWallBuilder"
Cohesion: 0.25
Nodes (4): VGD, VGD::Structure, VGD::Structure::GlassWallBuilder, VGD::Structure::GlassWallBuilder::Result

### Community 55 - ".build"
Cohesion: 0.22
Nodes (4): VGD, VGD::Structure, VGD::Structure::GridBuilder, VGD::Structure::GridBuilder::Result

### Community 57 - ".bounds"
Cohesion: 0.22
Nodes (4): VGD::Structure::AxisSymbol, VGD, VGD::Structure, VGD::Structure::Preview

### Community 58 - "renderLevelRooms"
Cohesion: 0.21
Nodes (13): frameCorners(), gridCells(), gridPoints(), holeProblem(), outlineProblem(), renderLevelRoof(), renderLevelRooms(), roofLabel() (+5 more)

### Community 59 - "buildTop"
Cohesion: 0.23
Nodes (14): buildRibbon(), buildSide(), buildTop(), toggle(), buildViewBar(), sel(), el(), fillTagKinds() (+6 more)

### Community 60 - ".plan"
Cohesion: 0.24
Nodes (4): VGD, VGD::Structure, VGD::Structure::SlabPlan, VGD::Structure::SlabPlan::Error

### Community 62 - "VGD::Structure::StairPlan"
Cohesion: 0.27
Nodes (4): VGD, VGD::Structure, VGD::Structure::StairPlan, VGD::Structure::StairPlan::Error

### Community 63 - "buildShapes"
Cohesion: 0.18
Nodes (11): addNoteShapes(), buildShapes(), ring(), drawTags(), drawWallLayers(), hid(), mid2(), mm() (+3 more)

### Community 64 - "onUp"
Cohesion: 0.23
Nodes (12): closeDimInput(), elevationMarkAt(), onUp(), onWheel(), openDimInput(), openPrompt(), end(), point() (+4 more)

### Community 66 - "test_footing_strip.rb"
Cohesion: 0.25
Nodes (8): clash?(), clashes(), footing_of(), norm(), plan_of(), state_with(), VGD, VGD::Structure

### Community 67 - ".plan"
Cohesion: 0.25
Nodes (4): VGD, VGD::Structure, VGD::Structure::StairPlace, VGD::Structure::StairPlace::Error

### Community 68 - "renderLayerEditor"
Cohesion: 0.29
Nodes (11): call(), fnColor(), layersTotal(), payload(), plateProbe(), renderLayerEditor(), renderWallTypes(), requestSchedule() (+3 more)

### Community 69 - "selectBox"
Cohesion: 0.22
Nodes (10): applySel(), bboxOf(), crossesRect(), inside(), inWindow(), pickAll(), pickAt(), segsCross() (+2 more)

### Community 71 - "test_joins.rb"
Cohesion: 0.22
Nodes (4): state_with(), VGD, VGD::Structure, wplan()

### Community 73 - "test_polygon.rb"
Cohesion: 0.22
Nodes (4): poly_state(), state_with(), VGD, VGD::Structure

### Community 75 - "test_ui.cjs"
Cohesion: 0.20
Nodes (5): {chromium}, {execFileSync}, F, path, {pathToFileURL}

### Community 76 - ".prepare"
Cohesion: 0.27
Nodes (4): VGD, VGD::Structure, VGD::Structure::AllBuilder, VGD::Structure::AllBuilder::Error

### Community 77 - ".fingerprint"
Cohesion: 0.33
Nodes (3): VGD, VGD::Structure, VGD::Structure::ModelSync

### Community 79 - "test_glass_wall.rb"
Cohesion: 0.25
Nodes (4): bad(), state(), VGD, VGD::Structure

### Community 82 - "test_slab_holes.rb"
Cohesion: 0.25
Nodes (4): bad(), state(), VGD, VGD::Structure

### Community 84 - ".plan"
Cohesion: 0.25
Nodes (4): VGD, VGD::Structure, VGD::Structure::GlassWallPlan, VGD::Structure::GlassWallPlan::Error

### Community 86 - "VGD::Structure"
Cohesion: 0.28
Nodes (3): menu(), VGD, VGD::Structure

### Community 94 - "marks2d.js"
Cohesion: 0.39
Nodes (5): dim(), dimensions(), levels(), levelText(), line()

### Community 95 - "VGD Structure"
Cohesion: 0.29
Nodes (6): Cấu trúc, Kiểm thử, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD Structure, Đóng gói

### Community 99 - "test_grid_builder.rb"
Cohesion: 0.29
Nodes (3): fresh(), VGD, VGD::Structure

### Community 100 - "test_rooms.rb"
Cohesion: 0.33
Nodes (4): bad(), state(), VGD, VGD::Structure

### Community 101 - "VGD::Structure::GridTag"
Cohesion: 0.38
Nodes (3): VGD, VGD::Structure, VGD::Structure::GridTag

### Community 102 - ".harvest"
Cohesion: 0.33
Nodes (3): VGD, VGD::Structure, VGD::Structure::IdKeeper

### Community 103 - ".write"
Cohesion: 0.38
Nodes (3): VGD, VGD::Structure, VGD::Structure::ModelStore

### Community 107 - ".by_cell"
Cohesion: 0.33
Nodes (4): room(), VGD, VGD::Structure, VGD::Structure::RoomPlan

### Community 110 - "opening_plan.rb"
Cohesion: 0.33
Nodes (4): VGD, VGD::Structure, VGD::Structure::OpeningPlan, VGD::Structure::OpeningPlan::Error

### Community 111 - "renderColumnsPlan"
Cohesion: 0.40
Nodes (5): allRefs(), pickRef(), renderColumnsPlan(), renderEditor(), typeById()

### Community 117 - "VGD Structure 0.30.0-beta.10"
Cohesion: 0.40
Nodes (4): Cài đặt, Kiểm thử, Trạng thái, VGD Structure 0.30.0-beta.10

### Community 118 - "axis_symbol.rb"
Cohesion: 0.40
Nodes (3): VGD, VGD::Structure, VGD::Structure::AxisSymbol::Error

### Community 119 - "beam_plan.rb"
Cohesion: 0.40
Nodes (3): VGD, VGD::Structure, VGD::Structure::BeamPlan::Error

### Community 120 - "beam_types.rb"
Cohesion: 0.40
Nodes (3): VGD, VGD::Structure, VGD::Structure::BeamTypes::Error

### Community 121 - "ceiling_plan.rb"
Cohesion: 0.40
Nodes (3): VGD, VGD::Structure, VGD::Structure::CeilingPlan::Error

### Community 122 - "column_plan.rb"
Cohesion: 0.40
Nodes (3): VGD, VGD::Structure, VGD::Structure::ColumnPlan::Error

### Community 123 - "column_types.rb"
Cohesion: 0.40
Nodes (3): VGD, VGD::Structure, VGD::Structure::ColumnTypes::Error

### Community 124 - "footing_plan.rb"
Cohesion: 0.40
Nodes (3): VGD, VGD::Structure, VGD::Structure::FootingPlan::Error

### Community 125 - "grid.rb"
Cohesion: 0.40
Nodes (3): VGD, VGD::Structure, VGD::Structure::Grid::Error

### Community 126 - "levels.rb"
Cohesion: 0.40
Nodes (3): VGD, VGD::Structure, VGD::Structure::Levels::Error

### Community 127 - "opening_types.rb"
Cohesion: 0.40
Nodes (3): VGD, VGD::Structure, VGD::Structure::OpeningTypes::Error

### Community 128 - "stair_types.rb"
Cohesion: 0.40
Nodes (3): VGD, VGD::Structure, VGD::Structure::StairTypes::Error

### Community 129 - "wall_plan.rb"
Cohesion: 0.40
Nodes (3): VGD, VGD::Structure, VGD::Structure::WallPlan::Error

### Community 130 - "wall_types.rb"
Cohesion: 0.40
Nodes (3): VGD, VGD::Structure, VGD::Structure::WallTypes::Error

### Community 133 - "VGD"
Cohesion: 0.50
Nodes (3): VGD, VGD::Structure, VGD::Structure::Schema

## Knowledge Gaps
- **60 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Sketchup` connect `Sketchup` to `Sketchup::Face`, `Sketchup::Instance`, `VGD::Structure::PickTool`, `Sketchup::Selection`, `Sketchup::Entity`, `Sketchup::Group`, `Geom::Point3d`, `Sketchup::Materials`, `Sketchup::FakeEntities`, `Sketchup::Model`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Are the 67 inferred relationships involving `Quy tắc riêng` (e.g. with `allCells()` and `allRefs()`) actually correct?**
  _`Quy tắc riêng` has 67 INFERRED edges - model-reasoned connections that need verification._
- **Should `plan_edit.js` be split into smaller, more focused modules?**
  _Cohesion score 0.06400343642611683 - nodes in this community are weakly interconnected._
- **Why does `Quy tắc riêng` connect `Quy tắc riêng` to `plan_edit.js`, `plan_modify.js`, `onUp`, `draw`, `renderLayerEditor`, `plan_browser.js`, `changed`, `toScreen`, `plan_section.js`, `renderColumnsPlan`, `app.js`, `plan_view.js`, `renderLevelRooms`, `buildTop`, `elevation_view.js`, `ed`, `VGD Structure`, `buildShapes`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Should `plan_modify.js` be split into smaller, more focused modules?**
  _Cohesion score 0.07376543209876543 - nodes in this community are weakly interconnected._
- **Why does `Geom::Point3d` connect `Geom::Point3d` to `UI::HtmlDialog`, `VGD::Structure::PlateBuilder`, `VGD::Structure::BeamBuilder`, `VGD::Structure::PickTool`, `VGD::Structure::WallBuilder`, `VGD::Structure::SuSection`, `VGD::Structure::OpeningBuilder`, `VGD::Structure::StairBuilder`, `test_su_section.rb`, `VGD::Structure::ColumnBuilder`, `VGD::Structure::GlassWallBuilder`, `.build`, `.ensure`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Should `VGD::Structure::Panel` be split into smaller, more focused modules?**
  _Cohesion score 0.0893707033315706 - nodes in this community are weakly interconnected._