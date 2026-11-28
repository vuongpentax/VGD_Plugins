# Graph Report - VGD_Diagram  (2026-11-28)

## Corpus Check
- 24 files · ~39,555 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 3 file(s) not represented in the graph (top: .woff2 2, (none) 1)

## Summary
- 2002 nodes · 3603 edges · 130 communities (51 shown, 79 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 322 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `060dfcdf`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Sketchup
- UI::HtmlDialog
- VGD::Diagram::Tree
- VGD::Diagram::Dialog
- VGD::Diagram::ModelIO
- ol
- menu
- test_ui.cjs
- vgd-theme.js
- VGD Diagram 0.10.1-beta.1
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
- go
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
- br
- ql
- .constructor
- .finish_frames
- mr
- gs
- .set
- .copy
- vo
- s
- Bl
- constructor
- dh
- nh
- So
- fa
- fh
- Xr
- ui
- _deactivateAction
- .copy
- .raycast
- UI::HtmlDialog
- Qo
- rn
- Ge
- VGD::Diagram::Scene
- _activateAction
- mi
- gl
- parseObject
- qh
- .constructor
- Lh
- load
- El
- .constructor
- Hl
- mh
- test_formats.rb
- uu
- e
- t
- isEmpty
- .parse
- Wl
- Oc
- jh
- Le
- closestPointToPoint
- Ic
- VGD
- ja
- Ou
- .toJSON
- tu
- VGD
- Sl
- zr
- copy
- $l
- ou
- tc
- Uc
- Vc
- Zl
- Ll
- disconnect
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

## Communities (130 total, 79 thin omitted)

### Community 0 - "Sketchup"
Cohesion: 0.07
Nodes (7): Sketchup, Sketchup::ComponentDefinition, Sketchup::ComponentInstance, Sketchup::Entity, Sketchup::FakeModel, Sketchup::FakeSelection, Sketchup::Group

### Community 1 - "UI::HtmlDialog"
Cohesion: 0.07
Nodes (6): Sketchup, UI, UI::Command, UI::HtmlDialog, UI::Menu, UI::Toolbar

### Community 4 - "VGD::Diagram::ModelIO"
Cohesion: 0.20
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::ModelIO

### Community 6 - "menu"
Cohesion: 0.29
Nodes (3): menu(), VGD, VGD::Diagram

### Community 7 - "test_ui.cjs"
Cohesion: 0.25
Nodes (4): { chromium }, failed, path, sample

### Community 8 - "vgd-theme.js"
Cohesion: 0.54
Nodes (7): apply(), current(), readSaved(), root(), start(), systemIsDark(), writeSaved()

### Community 9 - "VGD Diagram 0.10.1-beta.1"
Cohesion: 0.25
Nodes (7): Cài đặt và tải lại, Cách dùng, Kiểm thử, Mô hình 3D, Quy tắc gom và thứ tự (giả định cần xác nhận), Trạng thái, VGD Diagram 0.10.1-beta.1

### Community 11 - "three.min.js"
Cohesion: 0.02
Nodes (18): clampPoint(), distanceToPoint(), ea(), Es(), getAverageFrequency(), getFrequencyData(), ia(), ks() (+10 more)

### Community 12 - "dialog.js"
Cohesion: 0.10
Nodes (49): addArrow(), advancePlayback(), applyOrder(), bindOrbit(), captureView(), checkOrder(), clamp(), clearArrows() (+41 more)

### Community 16 - "ns"
Cohesion: 0.05
Nodes (22): as(), Dr, fr, gi, gr(), ls(), x(), no() (+14 more)

### Community 18 - "gh"
Cohesion: 0.18
Nodes (5): bh, gh, oh(), sh(), vh

### Community 21 - "je"
Cohesion: 0.09
Nodes (4): g(), je, mo(), xr()

### Community 24 - ".setAttribute"
Cohesion: 0.10
Nodes (9): Fc, p(), Gc, Hc, Jl, v(), d(), Wn (+1 more)

### Community 26 - "Lu"
Cohesion: 0.08
Nodes (5): bind(), getValue(), Lu, setValue(), subscribe_()

### Community 27 - "nn"
Cohesion: 0.11
Nodes (7): nn, ro(), bt(), Ct(), Et(), Mt(), Tt()

### Community 28 - "Sketchup"
Cohesion: 0.07
Nodes (11): Geom, Geom::Point3d, Geom::Transformation, Sketchup, Sketchup::ComponentDefinition, Sketchup::ComponentInstance, Sketchup::Entity, Sketchup::Face (+3 more)

### Community 29 - "al"
Cohesion: 0.08
Nodes (4): al, ho, lo, tl

### Community 31 - "wh"
Cohesion: 0.09
Nodes (7): ch(), fo(), _h, hh(), lh(), Th(), wh

### Community 32 - "Gn"
Cohesion: 0.10
Nodes (3): Gn, Hn, Vn

### Community 33 - "zn"
Cohesion: 0.08
Nodes (5): ii(), On(), Ue(), ze(), zn

### Community 35 - "go"
Cohesion: 0.08
Nodes (32): Be(), ei(), go(), Ct(), Dt(), i(), Nt(), Ot() (+24 more)

### Community 40 - "bt"
Cohesion: 0.09
Nodes (17): ao(), cs(), ds(), Ga(), At(), bt(), Hr(), hs() (+9 more)

### Community 43 - "Ma"
Cohesion: 0.12
Nodes (10): _a(), ba(), ga, Ka(), Ma, ua(), va, wa() (+2 more)

### Community 44 - "hc"
Cohesion: 0.24
Nodes (18): Ac(), bc(), cc(), dc(), Ec(), gc(), hc(), lc() (+10 more)

### Community 45 - "parseAsync"
Cohesion: 0.15
Nodes (14): bindSkeletons(), Fe(), Jo, loadAsync(), parse(), parseAnimations(), parseAsync(), parseGeometries() (+6 more)

### Community 48 - "$n"
Cohesion: 0.12
Nodes (3): fc(), $n, sc

### Community 50 - "ql"
Cohesion: 0.05
Nodes (7): ac, kl, Mo, Ne(), Nl, ql, toShapes()

### Community 52 - ".finish_frames"
Cohesion: 0.23
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Ffmpeg

### Community 54 - "gs"
Cohesion: 0.22
Nodes (5): fs(), gs(), ms(), w(), $u()

### Community 56 - ".copy"
Cohesion: 0.18
Nodes (3): Bo, eh, setFromCenterAndSize()

### Community 57 - "vo"
Cohesion: 0.12
Nodes (4): add(), updateMatrixWorld(), vo, wr

### Community 58 - "s"
Cohesion: 0.36
Nodes (7): s(), B(), F(), G(), k(), R(), z()

### Community 59 - "Bl"
Cohesion: 0.15
Nodes (3): Bl, Fl, Ul()

### Community 61 - "constructor"
Cohesion: 0.18
Nodes (9): Bc, constructor(), a(), o(), Hu(), _initMemoryManager(), setColors(), setLength() (+1 more)

### Community 70 - "_deactivateAction"
Cohesion: 0.27
Nodes (10): _deactivateAction(), existingAction(), _removeInactiveAction(), _removeInactiveBinding(), _removeInactiveBindingsForAction(), _takeBackAction(), _takeBackBinding(), uncacheAction() (+2 more)

### Community 71 - ".copy"
Cohesion: 0.09
Nodes (7): Bn, ih, Oh, qc, th, wo, Zc

### Community 73 - "UI::HtmlDialog"
Cohesion: 0.05
Nodes (14): Cấu trúc, Kiểm thử, Quy tắc riêng, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD Diagram — hướng dẫn cho Claude, Đóng gói, Geom (+6 more)

### Community 77 - "VGD::Diagram::Scene"
Cohesion: 0.31
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Scene

### Community 78 - "_activateAction"
Cohesion: 0.25
Nodes (8): _activateAction(), _addInactiveAction(), _addInactiveBinding(), _bindAction(), clipAction(), _isActiveAction(), _lendAction(), _lendBinding()

### Community 79 - "mi"
Cohesion: 0.18
Nodes (3): di(), mi, vi

### Community 82 - "parseObject"
Cohesion: 0.12
Nodes (5): _o, parseObject(), pl, vl, Zh

### Community 84 - ".constructor"
Cohesion: 0.28
Nodes (5): oo, C(), E(), L(), uo

### Community 87 - "load"
Cohesion: 0.15
Nodes (4): Ar, load(), qr(), Tr

### Community 92 - "mh"
Cohesion: 0.22
Nodes (3): _lendControlInterpolant(), mh, yh

### Community 95 - "e"
Cohesion: 0.22
Nodes (4): jc, l(), na(), e()

### Community 96 - "t"
Cohesion: 0.43
Nodes (5): clone(), c(), l(), o(), t()

### Community 97 - "isEmpty"
Cohesion: 0.29
Nodes (7): expandByPoint(), getCenter(), getSize(), intersect(), isEmpty(), makeEmpty(), setFromPoints()

### Community 104 - "closestPointToPoint"
Cohesion: 0.50
Nodes (4): at(), closestPointToPoint(), closestPointToPointParameter(), delta()

### Community 107 - "ja"
Cohesion: 0.50
Nodes (3): ja(), qa(), Xa()

### Community 108 - "Ou"
Cohesion: 0.67
Nodes (4): intersectObject(), intersectObjects(), Nu(), Ou()

### Community 115 - "copy"
Cohesion: 0.67
Nodes (3): copy(), dispose(), setSize()

## Knowledge Gaps
- **79 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `$e` connect `$e` to `three.min.js`, `ns`, `Ke`, `.setAttribute`, `_i`, `al`, `xn`, `go`, `Ln`, `kh`, `ql`, `.constructor`, `mr`, `gs`, `.set`, `vo`, `s`, `constructor`, `.fromBufferAttribute`, `.copy`, `.raycast`, `qh`, `.constructor`, `.normalize`, `.constructor`, `e`, `.parse`, `jh`, `ja`?**
  _High betweenness centrality (0.119) - this node is a cross-community bridge._
- **Should `Sketchup` be split into smaller, more focused modules?**
  _Cohesion score 0.07407407407407407 - nodes in this community are weakly interconnected._
- **Why does `xn` connect `xn` to `nh`, `vu`, `.constructor`, `Le`, `Qo`, `three.min.js`, `.toJSON`, `.add`, `.copy`, `ns`, `Sl`, `parseObject`, `Ke`, `mr`, `.copy`, `vo`, `.updateWorldMatrix`, `al`?**
  _High betweenness centrality (0.058) - this node is a cross-community bridge._
- **Should `UI::HtmlDialog` be split into smaller, more focused modules?**
  _Cohesion score 0.06896551724137931 - nodes in this community are weakly interconnected._
- **Why does `We` connect `We` to `Oe`, `three.min.js`, `ns`, `.setAttribute`, `al`, `xl`, `.constructor`, `mr`, `gs`, `.copy`, `s`, `nh`, `fh`, `.copy`, `mi`, `qh`, `El`, `.divideScalar`, `e`, `Wl`, `jh`, `.applyMatrix3`, `ja`, `.toArray`, `.fromArray`?**
  _High betweenness centrality (0.056) - this node is a cross-community bridge._
- **Should `three.min.js` be split into smaller, more focused modules?**
  _Cohesion score 0.023793182338137726 - nodes in this community are weakly interconnected._
- **Should `dialog.js` be split into smaller, more focused modules?**
  _Cohesion score 0.10448979591836735 - nodes in this community are weakly interconnected._