# Graph Report - VGD_Diagram  (2026-11-28)

## Corpus Check
- 23 files · ~32,266 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 3 file(s) not represented in the graph (top: .woff2 2, (none) 1)

## Summary
- 1940 nodes · 3454 edges · 123 communities (51 shown, 72 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 319 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `bcc1a2aa`
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
- VGD Diagram 0.3.0-beta.1
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
- $n
- .copy
- Ln
- qi
- bt
- So
- ui
- Ma
- hc
- Lh
- .copy
- xl
- updateMatrixWorld
- Pn
- ql
- ho
- br
- kh
- Geom::Vector3d
- Rr
- .copy
- go
- s
- Bl
- .updateWorldMatrix
- constructor
- dh
- nh
- Dr
- fa
- fh
- Xr
- Oe
- _deactivateAction
- e
- t
- .constructor
- Qo
- rn
- UI::HtmlDialog
- .collect
- _activateAction
- mi
- .copy
- Ge
- gl
- mo
- .constructor
- parseObject
- qh
- Tr
- El
- .constructor
- ol
- Hl
- mh
- uu
- .set
- Es
- isEmpty
- gi
- Wl
- .toJSON
- jh
- Le
- Ic
- Ou
- tu
- VGD
- VGD
- copy
- $l
- ou
- tc
- Uc
- Vc
- Zl
- Ll

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
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 100 → community 72_
- `x()` --indirect_call--> `u()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 24 → community 16_
- `w()` --indirect_call--> `b()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 36 → community 35_
- `g()` --indirect_call--> `t()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 72 → community 83_
- `update()` --indirect_call--> `t()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 72 → community 11_

## Import Cycles
- None detected.

## Communities (123 total, 72 thin omitted)

### Community 0 - "Sketchup"
Cohesion: 0.08
Nodes (7): Sketchup, Sketchup::ComponentDefinition, Sketchup::ComponentInstance, Sketchup::Entity, Sketchup::FakeModel, Sketchup::FakeSelection, Sketchup::Group

### Community 1 - "UI"
Cohesion: 0.11
Nodes (5): Sketchup, UI, UI::Command, UI::Menu, UI::Toolbar

### Community 4 - "VGD::Diagram::ModelIO"
Cohesion: 0.24
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

### Community 9 - "VGD Diagram 0.3.0-beta.1"
Cohesion: 0.25
Nodes (7): Cài đặt và tải lại, Cách dùng, Kiểm thử, Mô hình 3D (mới ở 0.2.0-beta.1), Quy tắc gom và thứ tự (giả định cần xác nhận), Trạng thái, VGD Diagram 0.3.0-beta.1

### Community 11 - "three.min.js"
Cohesion: 0.02
Nodes (12): bind(), clampPoint(), disconnect(), distanceToPoint(), getAverageFrequency(), getFrequencyData(), getValue(), setFromObject() (+4 more)

### Community 12 - "dialog.js"
Cohesion: 0.16
Nodes (26): advancePlayback(), bindOrbit(), checkOrder(), clamp(), clearParts(), createView(), highlight(), idsOf() (+18 more)

### Community 16 - "ns"
Cohesion: 0.08
Nodes (17): as(), fr, gr(), ls(), no(), T(), w(), ns (+9 more)

### Community 18 - "gh"
Cohesion: 0.14
Nodes (6): ah(), bh, gh, oh(), sh(), vh

### Community 24 - ".setAttribute"
Cohesion: 0.09
Nodes (10): Fc, p(), Gc, Hc, Jl, v(), x(), d() (+2 more)

### Community 26 - "Lu"
Cohesion: 0.06
Nodes (5): add(), Lu, setValue(), subscribe_(), vo

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
Cohesion: 0.10
Nodes (3): Gn, Hn, Vn

### Community 33 - "zn"
Cohesion: 0.08
Nodes (5): ii(), On(), Ue(), ze(), zn

### Community 35 - "so"
Cohesion: 0.15
Nodes (23): Be(), ei(), hi, Je(), so(), A(), b(), C() (+15 more)

### Community 36 - "$n"
Cohesion: 0.07
Nodes (9): fc(), fs(), gs(), jc, ms(), $n, w(), Oc (+1 more)

### Community 37 - ".copy"
Cohesion: 0.10
Nodes (6): Bn, $c, qc, th, wo, Zc

### Community 38 - "Ln"
Cohesion: 0.11
Nodes (3): Ln, mr(), sc

### Community 40 - "bt"
Cohesion: 0.07
Nodes (21): ao(), cs(), ds(), Ga(), At(), bt(), Hr(), hs() (+13 more)

### Community 42 - "ui"
Cohesion: 0.06
Nodes (5): di(), ji, Sl, ui, wl()

### Community 43 - "Ma"
Cohesion: 0.12
Nodes (10): _a(), ba(), ga, Ka(), Ma, ua(), va, wa() (+2 more)

### Community 44 - "hc"
Cohesion: 0.24
Nodes (18): Ac(), bc(), cc(), dc(), Ec(), gc(), hc(), lc() (+10 more)

### Community 45 - "Lh"
Cohesion: 0.05
Nodes (19): bindSkeletons(), eu, Fe(), ih, iu, Jo, Lh, load() (+11 more)

### Community 50 - "ql"
Cohesion: 0.05
Nodes (8): ac, n(), kl, Mo, Ne(), Nl, ql, toShapes()

### Community 54 - "Geom::Vector3d"
Cohesion: 0.08
Nodes (11): Geom, Geom::Point3d, Geom::Vector3d, Sketchup, Sketchup::BoundsStub, Sketchup::Camera, Sketchup::ModelStub, Sketchup::ViewStub (+3 more)

### Community 56 - ".copy"
Cohesion: 0.17
Nodes (3): Bo, eh, setFromCenterAndSize()

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

### Community 64 - "nh"
Cohesion: 0.12
Nodes (3): nh, _o, xo

### Community 69 - "Oe"
Cohesion: 0.29
Nodes (7): at(), closestPointToPoint(), closestPointToPointParameter(), delta(), Oe(), setFromCartesianCoords(), setFromVector3()

### Community 70 - "_deactivateAction"
Cohesion: 0.27
Nodes (10): _deactivateAction(), existingAction(), _removeInactiveAction(), _removeInactiveBinding(), _removeInactiveBindingsForAction(), _takeBackAction(), _takeBackBinding(), uncacheAction() (+2 more)

### Community 71 - "e"
Cohesion: 0.29
Nodes (4): kc, l(), na(), e()

### Community 72 - "t"
Cohesion: 0.43
Nodes (5): clone(), c(), l(), o(), t()

### Community 77 - ".collect"
Cohesion: 0.33
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Scene

### Community 78 - "_activateAction"
Cohesion: 0.25
Nodes (8): _activateAction(), _addInactiveAction(), _addInactiveBinding(), _bindAction(), clipAction(), _isActiveAction(), _lendAction(), _lendBinding()

### Community 79 - "mi"
Cohesion: 0.18
Nodes (4): mi, uo, vi, xi

### Community 83 - "mo"
Cohesion: 0.33
Nodes (3): g(), mo(), xr()

### Community 84 - ".constructor"
Cohesion: 0.28
Nodes (5): Nr(), oo, C(), E(), L()

### Community 85 - "parseObject"
Cohesion: 0.15
Nodes (4): parseObject(), pl, vl, Zh

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
- **72 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `fi` connect `fi` to `gi`, `fh`, `$n`, `.divideScalar`, `jh`, `ui`, `three.min.js`, `.copy`, `ns`, `.constructor`, `.boneTransform`, `qh`, `go`, `nn`, `.clone`?**
  _High betweenness centrality (0.057) - this node is a cross-community bridge._
- **Should `Sketchup` be split into smaller, more focused modules?**
  _Cohesion score 0.07671957671957672 - nodes in this community are weakly interconnected._
- **Why does `$e` connect `$e` to `three.min.js`, `ns`, `.setAttribute`, `_i`, `Lu`, `al`, `$n`, `.copy`, `Ln`, `bt`, `ui`, `Lh`, `ql`, `ho`, `kh`, `go`, `s`, `constructor`, `.fromBufferAttribute`, `.constructor`, `rn`, `.copy`, `.constructor`, `qh`, `.constructor`, `.set`, `jh`?**
  _High betweenness centrality (0.057) - this node is a cross-community bridge._
- **Should `UI` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._
- **Why does `We` connect `We` to `three.min.js`, `ns`, `.setAttribute`, `al`, `$n`, `.copy`, `Ln`, `bt`, `Lh`, `xl`, `.copy`, `s`, `nh`, `fh`, `e`, `.constructor`, `mi`, `.copy`, `qh`, `El`, `.applyMatrix3`, `Wl`, `jh`, `.divideScalar`, `.fromArray`, `.toArray`?**
  _High betweenness centrality (0.048) - this node is a cross-community bridge._
- **Should `three.min.js` be split into smaller, more focused modules?**
  _Cohesion score 0.024033437826541274 - nodes in this community are weakly interconnected._
- **Should `ns` be split into smaller, more focused modules?**
  _Cohesion score 0.08078231292517007 - nodes in this community are weakly interconnected._