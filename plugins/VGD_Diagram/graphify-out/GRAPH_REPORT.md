# Graph Report - VGD_Diagram  (2026-11-28)

## Corpus Check
- 21 files · ~34,167 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 3 file(s) not represented in the graph (top: .woff2 2, (none) 1)

## Summary
- 1938 nodes · 3487 edges · 124 communities (47 shown, 77 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 319 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c2a8b3fa`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Sketchup
- UI
- VGD::Diagram::Tree
- VGD::Diagram::Dialog
- VGD::Diagram::ModelIO
- VGD Diagram — hướng dẫn cho Claude
- menu
- test_ui.cjs
- vgd-theme.js
- VGD Diagram 0.5.0-beta.1
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
- gs
- .copy
- Ln
- qi
- bt
- So
- ji
- Ma
- hc
- parseAsync
- .copy
- xl
- $n
- Pn
- Mo
- ho
- br
- .parse
- ui
- Rr
- Bo
- go
- s
- Bl
- .updateMatrix
- constructor
- dh
- parseObject
- Dr
- fa
- fh
- Xr
- t
- _deactivateAction
- .copy
- ac
- .constructor
- Qo
- rn
- UI::HtmlDialog
- VGD::Diagram::Scene
- _activateAction
- mi
- .copy
- Ge
- gl
- updateMatrixWorld
- .constructor
- pl
- Lh
- Tr
- El
- .constructor
- .clone
- Hl
- mh
- uu
- .set
- Es
- isEmpty
- gi
- Wl
- .toJSON
- Le
- Ic
- Sl
- Ou
- load
- tu
- VGD
- VGD
- kl
- copy
- $l
- ou
- tc
- Uc
- Vc
- Zl
- Ll
- ql
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
- `r()` --indirect_call--> `t()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 100 → community 69_
- `x()` --indirect_call--> `d()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 16 → community 24_
- `w()` --indirect_call--> `b()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 48 → community 35_
- `g()` --indirect_call--> `t()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 69 → community 21_
- `update()` --indirect_call--> `t()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 69 → community 11_

## Import Cycles
- None detected.

## Communities (124 total, 77 thin omitted)

### Community 0 - "Sketchup"
Cohesion: 0.08
Nodes (7): Sketchup, Sketchup::ComponentDefinition, Sketchup::ComponentInstance, Sketchup::Entity, Sketchup::FakeModel, Sketchup::FakeSelection, Sketchup::Group

### Community 1 - "UI"
Cohesion: 0.11
Nodes (5): Sketchup, UI, UI::Command, UI::Menu, UI::Toolbar

### Community 4 - "VGD::Diagram::ModelIO"
Cohesion: 0.20
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

### Community 9 - "VGD Diagram 0.5.0-beta.1"
Cohesion: 0.25
Nodes (7): Cài đặt và tải lại, Cách dùng, Kiểm thử, Mô hình 3D, Quy tắc gom và thứ tự (giả định cần xác nhận), Trạng thái, VGD Diagram 0.5.0-beta.1

### Community 11 - "three.min.js"
Cohesion: 0.02
Nodes (16): at(), clampPoint(), closestPointToPoint(), closestPointToPointParameter(), delta(), disconnect(), distanceToPoint(), getAverageFrequency() (+8 more)

### Community 12 - "dialog.js"
Cohesion: 0.11
Nodes (41): addArrow(), advancePlayback(), applyOrder(), bindOrbit(), captureView(), checkOrder(), clamp(), clearArrows() (+33 more)

### Community 16 - "ns"
Cohesion: 0.08
Nodes (18): as(), fr, gr(), jc, ls(), x(), no(), T() (+10 more)

### Community 18 - "gh"
Cohesion: 0.18
Nodes (5): bh, gh, oh(), sh(), vh

### Community 21 - "je"
Cohesion: 0.09
Nodes (4): g(), je, mo(), xr()

### Community 24 - ".setAttribute"
Cohesion: 0.08
Nodes (12): Fc, p(), Gc, Hc, Jl, l(), v(), na() (+4 more)

### Community 26 - "Lu"
Cohesion: 0.06
Nodes (7): add(), bind(), getValue(), Lu, setValue(), subscribe_(), vo

### Community 27 - "nn"
Cohesion: 0.11
Nodes (7): nn, ro(), bt(), Ct(), Et(), Mt(), Tt()

### Community 28 - "Sketchup"
Cohesion: 0.07
Nodes (11): Geom, Geom::Point3d, Geom::Transformation, Sketchup, Sketchup::ComponentDefinition, Sketchup::ComponentInstance, Sketchup::Entity, Sketchup::Face (+3 more)

### Community 31 - "wh"
Cohesion: 0.09
Nodes (7): ch(), fo(), _h, hh(), lh(), Th(), wh

### Community 32 - "Gn"
Cohesion: 0.09
Nodes (3): Gn, Hn, Vn

### Community 33 - "zn"
Cohesion: 0.08
Nodes (5): ii(), On(), Ue(), ze(), zn

### Community 35 - "so"
Cohesion: 0.15
Nodes (23): Be(), ei(), hi, Je(), so(), A(), b(), C() (+15 more)

### Community 36 - "gs"
Cohesion: 0.40
Nodes (3): fs(), gs(), ms()

### Community 37 - ".copy"
Cohesion: 0.09
Nodes (8): Bn, ol, Qa, qc, rh, th, to, Zc

### Community 40 - "bt"
Cohesion: 0.07
Nodes (21): ao(), cs(), ds(), Ga(), At(), bt(), Hr(), hs() (+13 more)

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
Cohesion: 0.10
Nodes (5): fc(), $n, w(), sc, $u()

### Community 52 - "br"
Cohesion: 0.07
Nodes (4): br, jh, kh, oo

### Community 53 - ".parse"
Cohesion: 0.22
Nodes (4): eu, iu, n(), parseGeometries()

### Community 57 - "go"
Cohesion: 0.19
Nodes (8): go(), Ct(), Dt(), i(), Nt(), Ot(), Ut(), zt()

### Community 58 - "s"
Cohesion: 0.20
Nodes (8): Oc, s(), B(), F(), G(), k(), R(), z()

### Community 59 - "Bl"
Cohesion: 0.15
Nodes (3): Bl, Fl, Ul()

### Community 61 - "constructor"
Cohesion: 0.22
Nodes (8): Bc, constructor(), a(), o(), Hu(), _initMemoryManager(), setColors(), setLength()

### Community 64 - "parseObject"
Cohesion: 0.12
Nodes (4): _o, parseObject(), xo, Zh

### Community 69 - "t"
Cohesion: 0.31
Nodes (5): clone(), c(), l(), o(), t()

### Community 70 - "_deactivateAction"
Cohesion: 0.27
Nodes (10): _deactivateAction(), existingAction(), _removeInactiveAction(), _removeInactiveBinding(), _removeInactiveBindingsForAction(), _takeBackAction(), _takeBackBinding(), uncacheAction() (+2 more)

### Community 71 - ".copy"
Cohesion: 0.13
Nodes (4): eh, kc, nh, setFromCenterAndSize()

### Community 77 - "VGD::Diagram::Scene"
Cohesion: 0.31
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Scene

### Community 78 - "_activateAction"
Cohesion: 0.25
Nodes (8): _activateAction(), _addInactiveAction(), _addInactiveBinding(), _bindAction(), clipAction(), _isActiveAction(), _lendAction(), _lendBinding()

### Community 79 - "mi"
Cohesion: 0.17
Nodes (4): di(), mi, vi, xi

### Community 84 - ".constructor"
Cohesion: 0.28
Nodes (5): Nr(), C(), E(), L(), uo

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
- **77 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `$e` connect `$e` to `three.min.js`, `ns`, `Ke`, `.setAttribute`, `_i`, `Lu`, `al`, `xn`, `.copy`, `Ln`, `bt`, `ji`, `$n`, `ho`, `br`, `.parse`, `go`, `s`, `constructor`, `.fromBufferAttribute`, `.constructor`, `.copy`, `.constructor`, `Lh`, `.constructor`, `.clone`, `.set`, `.raycast`?**
  _High betweenness centrality (0.073) - this node is a cross-community bridge._
- **Should `Sketchup` be split into smaller, more focused modules?**
  _Cohesion score 0.07671957671957672 - nodes in this community are weakly interconnected._
- **Why does `fi` connect `fi` to `gi`, `fh`, `gs`, `three.min.js`, `.copy`, `ns`, `br`, `.constructor`, `Lh`, `go`, `nn`, `.copy`?**
  _High betweenness centrality (0.055) - this node is a cross-community bridge._
- **Should `UI` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._
- **Why does `We` connect `We` to `Oe`, `three.min.js`, `ns`, `.setAttribute`, `al`, `Gn`, `gs`, `.copy`, `Ln`, `bt`, `xl`, `$n`, `br`, `Bo`, `s`, `fh`, `.copy`, `.constructor`, `mi`, `.copy`, `Lh`, `El`, `Wl`, `.divideScalar`, `load`?**
  _High betweenness centrality (0.048) - this node is a cross-community bridge._
- **Should `three.min.js` be split into smaller, more focused modules?**
  _Cohesion score 0.023650262780697564 - nodes in this community are weakly interconnected._
- **Should `dialog.js` be split into smaller, more focused modules?**
  _Cohesion score 0.10569105691056911 - nodes in this community are weakly interconnected._