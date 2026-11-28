# Graph Report - VGD_Diagram  (2026-11-28)

## Corpus Check
- 22 files · ~36,762 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 3 file(s) not represented in the graph (top: .woff2 2, (none) 1)

## Summary
- 1957 nodes · 3543 edges · 124 communities (48 shown, 76 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 321 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `446eb14e`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Sketchup
- UI::HtmlDialog
- VGD::Diagram::Tree
- VGD::Diagram::Dialog
- VGD::Diagram::ModelIO
- .setValues
- menu
- test_ui.cjs
- vgd-theme.js
- VGD Diagram 0.8.0-beta.1
- three.min.js
- dialog.js
- VGD
- VGD
- ns
- Ke
- gh
- $e
- Ru
- je
- We
- fi
- .setAttribute
- _i
- Lu
- nn
- Sketchup
- al
- xn
- wh
- Gn
- zn
- vu
- so
- Rr
- Pn
- Ln
- qi
- bt
- kh
- ji
- Ma
- hc
- parseAsync
- .copy
- xl
- $n
- So
- ql
- e
- br
- eu
- ui
- vo
- Bo
- go
- s
- Bl
- constructor
- dh
- nh
- .copy
- fa
- fh
- Xr
- ho
- _deactivateAction
- .copy
- .set
- updateMatrixWorld
- Qo
- rn
- Ge
- VGD::Diagram::Scene
- _activateAction
- mi
- parseObject
- gl
- qh
- .constructor
- pl
- Lh
- load
- El
- ja
- Hl
- mh
- test_formats.rb
- uu
- Es
- isEmpty
- gi
- Wl
- jh
- .raycast
- Le
- Vn
- Ic
- Ou
- tu
- VGD
- copy
- $l
- ou
- tc
- Uc
- Vc
- Zl
- Ll
- Oe
- .constructor

## God Nodes (most connected - your core abstractions)
1. `$e` - 112 edges
2. `We` - 86 edges
3. `fi` - 61 edges
4. `xn` - 61 edges
5. `zn` - 56 edges
6. `$n` - 54 edges
7. `qi` - 49 edges
8. `Gn` - 43 edges
9. `Ke` - 38 edges
10. `_i` - 34 edges

## Surprising Connections (you probably didn't know these)
- `Quy tắc riêng` --references--> `exportFrames()`  [INFERRED]
  CLAUDE.md → runtime/vgd_diagram/dialog.js

## Import Cycles
- None detected.

## Communities (124 total, 76 thin omitted)

### Community 0 - "Sketchup"
Cohesion: 0.08
Nodes (7): Sketchup, Sketchup::ComponentDefinition, Sketchup::ComponentInstance, Sketchup::Entity, Sketchup::FakeModel, Sketchup::FakeSelection, Sketchup::Group

### Community 1 - "UI::HtmlDialog"
Cohesion: 0.07
Nodes (6): Sketchup, UI, UI::Command, UI::HtmlDialog, UI::Menu, UI::Toolbar

### Community 2 - "VGD::Diagram::Tree"
Cohesion: 0.16
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Tree

### Community 4 - "VGD::Diagram::ModelIO"
Cohesion: 0.22
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::ModelIO

### Community 5 - ".setValues"
Cohesion: 0.15
Nodes (4): Bn, ol, rh, Zc

### Community 6 - "menu"
Cohesion: 0.29
Nodes (3): menu(), VGD, VGD::Diagram

### Community 7 - "test_ui.cjs"
Cohesion: 0.25
Nodes (4): { chromium }, failed, path, sample

### Community 8 - "vgd-theme.js"
Cohesion: 0.54
Nodes (7): apply(), current(), readSaved(), root(), start(), systemIsDark(), writeSaved()

### Community 9 - "VGD Diagram 0.8.0-beta.1"
Cohesion: 0.25
Nodes (7): Cài đặt và tải lại, Cách dùng, Kiểm thử, Mô hình 3D, Quy tắc gom và thứ tự (giả định cần xác nhận), Trạng thái, VGD Diagram 0.8.0-beta.1

### Community 11 - "three.min.js"
Cohesion: 0.02
Nodes (16): at(), clampPoint(), closestPointToPoint(), closestPointToPointParameter(), delta(), disconnect(), distanceToPoint(), getAverageFrequency() (+8 more)

### Community 12 - "dialog.js"
Cohesion: 0.08
Nodes (55): Cấu trúc, Kiểm thử, Quy tắc riêng, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD Diagram — hướng dẫn cho Claude, Đóng gói, addArrow() (+47 more)

### Community 16 - "ns"
Cohesion: 0.06
Nodes (18): as(), Dr, fr, gr(), ls(), no(), T(), w() (+10 more)

### Community 18 - "gh"
Cohesion: 0.17
Nodes (5): bh, gh, oh(), sh(), vh

### Community 20 - "Ru"
Cohesion: 0.07
Nodes (7): clone(), c(), l(), o(), t(), Ru, r()

### Community 24 - ".setAttribute"
Cohesion: 0.07
Nodes (12): Fc, p(), Gc, Hc, Jl, v(), x(), a() (+4 more)

### Community 26 - "Lu"
Cohesion: 0.08
Nodes (5): bind(), getValue(), Lu, setValue(), subscribe_()

### Community 27 - "nn"
Cohesion: 0.11
Nodes (7): nn, ro(), bt(), Ct(), Et(), Mt(), Tt()

### Community 28 - "Sketchup"
Cohesion: 0.07
Nodes (11): Geom, Geom::Point3d, Geom::Transformation, Sketchup, Sketchup::ComponentDefinition, Sketchup::ComponentInstance, Sketchup::Entity, Sketchup::Face (+3 more)

### Community 31 - "wh"
Cohesion: 0.09
Nodes (7): ch(), fo(), _h, hh(), lh(), Th(), wh

### Community 33 - "zn"
Cohesion: 0.08
Nodes (5): ii(), On(), Ue(), ze(), zn

### Community 35 - "so"
Cohesion: 0.15
Nodes (23): Be(), ei(), hi, Je(), so(), A(), b(), C() (+15 more)

### Community 40 - "bt"
Cohesion: 0.07
Nodes (21): ao(), cs(), ds(), Ga(), At(), bt(), g(), Hr() (+13 more)

### Community 43 - "Ma"
Cohesion: 0.12
Nodes (10): _a(), ba(), ga, Ka(), Ma, ua(), va, wa() (+2 more)

### Community 44 - "hc"
Cohesion: 0.24
Nodes (18): Ac(), bc(), cc(), dc(), Ec(), gc(), hc(), lc() (+10 more)

### Community 45 - "parseAsync"
Cohesion: 0.16
Nodes (13): bindSkeletons(), Fe(), Jo, loadAsync(), parse(), parseAnimations(), parseAsync(), parseImages() (+5 more)

### Community 48 - "$n"
Cohesion: 0.09
Nodes (9): fc(), fs(), gs(), jc, ms(), $n, w(), Oc (+1 more)

### Community 50 - "ql"
Cohesion: 0.05
Nodes (8): ac, n(), kl, Mo, Ne(), Nl, ql, toShapes()

### Community 51 - "e"
Cohesion: 0.22
Nodes (5): l(), mr(), na(), sc, e()

### Community 57 - "go"
Cohesion: 0.19
Nodes (8): go(), Ct(), Dt(), i(), Nt(), Ot(), Ut(), zt()

### Community 58 - "s"
Cohesion: 0.36
Nodes (7): s(), B(), F(), G(), k(), R(), z()

### Community 59 - "Bl"
Cohesion: 0.15
Nodes (3): Bl, Fl, Ul()

### Community 61 - "constructor"
Cohesion: 0.22
Nodes (8): Bc, constructor(), a(), o(), Hu(), _initMemoryManager(), setColors(), setLength()

### Community 70 - "_deactivateAction"
Cohesion: 0.27
Nodes (10): _deactivateAction(), existingAction(), _removeInactiveAction(), _removeInactiveBinding(), _removeInactiveBindingsForAction(), _takeBackAction(), _takeBackBinding(), uncacheAction() (+2 more)

### Community 71 - ".copy"
Cohesion: 0.11
Nodes (6): ih, kc, Oh, qc, setFromCenterAndSize(), th

### Community 77 - "VGD::Diagram::Scene"
Cohesion: 0.31
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Scene

### Community 78 - "_activateAction"
Cohesion: 0.25
Nodes (8): _activateAction(), _addInactiveAction(), _addInactiveBinding(), _bindAction(), clipAction(), _isActiveAction(), _lendAction(), _lendBinding()

### Community 79 - "mi"
Cohesion: 0.14
Nodes (4): di(), mi, vi, xi

### Community 80 - "parseObject"
Cohesion: 0.20
Nodes (3): parseObject(), xo, Zh

### Community 84 - ".constructor"
Cohesion: 0.28
Nodes (5): Nr(), C(), E(), L(), uo

### Community 86 - "Lh"
Cohesion: 0.13
Nodes (3): iu, Lh, parseGeometries()

### Community 87 - "load"
Cohesion: 0.18
Nodes (3): Ar, load(), Tr

### Community 90 - "ja"
Cohesion: 0.50
Nodes (3): ja(), qa(), Xa()

### Community 92 - "mh"
Cohesion: 0.25
Nodes (3): _lendControlInterpolant(), mh, yh

### Community 96 - "Es"
Cohesion: 0.29
Nodes (7): ea(), Es(), ia(), ks(), qs(), $s(), ta()

### Community 97 - "isEmpty"
Cohesion: 0.29
Nodes (7): expandByPoint(), getCenter(), getSize(), intersect(), isEmpty(), makeEmpty(), setFromPoints()

### Community 98 - "gi"
Cohesion: 0.32
Nodes (3): gi, S(), rs()

### Community 108 - "Ou"
Cohesion: 0.67
Nodes (4): intersectObject(), intersectObjects(), Nu(), Ou()

### Community 115 - "copy"
Cohesion: 0.67
Nodes (3): copy(), dispose(), setSize()

## Knowledge Gaps
- **76 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `$e` connect `$e` to `three.min.js`, `ns`, `.setAttribute`, `_i`, `al`, `xn`, `Ln`, `kh`, `ji`, `$n`, `So`, `ql`, `e`, `vo`, `go`, `s`, `constructor`, `.fromBufferAttribute`, `.copy`, `ho`, `.copy`, `.set`, `qh`, `.constructor`, `Lh`, `ja`, `jh`, `.raycast`?**
  _High betweenness centrality (0.094) - this node is a cross-community bridge._
- **Should `Sketchup` be split into smaller, more focused modules?**
  _Cohesion score 0.07671957671957672 - nodes in this community are weakly interconnected._
- **Why does `We` connect `We` to `Oe`, `three.min.js`, `ns`, `.setAttribute`, `al`, `Gn`, `Pn`, `Ln`, `xl`, `$n`, `e`, `Bo`, `s`, `nh`, `.copy`, `fh`, `.copy`, `mi`, `qh`, `El`, `.divideScalar`, `ja`, `Wl`, `jh`, `.fromArray`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._
- **Should `UI::HtmlDialog` be split into smaller, more focused modules?**
  _Cohesion score 0.06896551724137931 - nodes in this community are weakly interconnected._
- **Why does `xn` connect `xn` to `.constructor`, `three.min.js`, `ns`, `Ke`, `Ru`, `vu`, `.copy`, `e`, `vo`, `Bo`, `.updateWorldMatrix`, `nh`, `ho`, `updateMatrixWorld`, `Qo`, `parseObject`, `pl`, `.raycast`, `Le`, `.add`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Should `three.min.js` be split into smaller, more focused modules?**
  _Cohesion score 0.023650262780697564 - nodes in this community are weakly interconnected._
- **Should `dialog.js` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._