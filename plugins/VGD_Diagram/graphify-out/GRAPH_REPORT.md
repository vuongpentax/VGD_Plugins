# Graph Report - VGD_Diagram  (2026-11-28)

## Corpus Check
- 21 files · ~32,990 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 3 file(s) not represented in the graph (top: .woff2 2, (none) 1)

## Summary
- 1926 nodes · 3460 edges · 138 communities (52 shown, 86 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 319 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6a1f7469`
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
- ro
- Sketchup
- al
- xn
- wh
- Gn
- zn
- vu
- so
- gs
- .setValues
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
- kh
- ui
- Rr
- Bo
- go
- s
- Bl
- constructor
- dh
- nh
- Dr
- fa
- fh
- Xr
- Oe
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
- mo
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
- .raycast
- Le
- Ic
- parseObject
- tl
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
- mr
- ql
- $c
- Oc
- .constructor
- ja
- jc
- e
- zr

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
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 100 → community 86_
- `x()` --indirect_call--> `u()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 36 → community 16_
- `w()` --indirect_call--> `b()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 36 → community 35_
- `g()` --indirect_call--> `t()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 86 → community 83_
- `update()` --indirect_call--> `t()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 86 → community 11_

## Import Cycles
- None detected.

## Communities (138 total, 86 thin omitted)

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

### Community 9 - "VGD Diagram 0.3.0-beta.1"
Cohesion: 0.25
Nodes (7): Cài đặt và tải lại, Cách dùng, Kiểm thử, Mô hình 3D, Quy tắc gom và thứ tự (giả định cần xác nhận), Trạng thái, VGD Diagram 0.3.0-beta.1

### Community 11 - "three.min.js"
Cohesion: 0.02
Nodes (10): clampPoint(), disconnect(), distanceToPoint(), getAverageFrequency(), getFrequencyData(), setFromObject(), setTime(), Sh (+2 more)

### Community 12 - "dialog.js"
Cohesion: 0.15
Nodes (29): advancePlayback(), applyOrder(), bindOrbit(), checkOrder(), clamp(), clearParts(), createView(), drawTags() (+21 more)

### Community 16 - "ns"
Cohesion: 0.08
Nodes (17): as(), fr, gr(), ls(), no(), T(), w(), ns (+9 more)

### Community 18 - "gh"
Cohesion: 0.18
Nodes (5): bh, gh, oh(), sh(), vh

### Community 24 - ".setAttribute"
Cohesion: 0.10
Nodes (7): Fc, Gc, Hc, Jl, v(), Wn, Yl

### Community 26 - "Lu"
Cohesion: 0.08
Nodes (5): bind(), getValue(), Lu, setValue(), subscribe_()

### Community 27 - "ro"
Cohesion: 0.29
Nodes (6): ro(), bt(), Ct(), Et(), Mt(), Tt()

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
Cohesion: 0.09
Nodes (21): Be(), nn, S(), so(), A(), b(), C(), D() (+13 more)

### Community 36 - "gs"
Cohesion: 0.15
Nodes (8): p(), fs(), gs(), ms(), w(), x(), $u(), d()

### Community 37 - ".setValues"
Cohesion: 0.11
Nodes (6): Bn, eh, ol, Qa, rh, Zc

### Community 40 - "bt"
Cohesion: 0.08
Nodes (18): ao(), cs(), ds(), Ga(), At(), bt(), Hr(), hs() (+10 more)

### Community 43 - "Ma"
Cohesion: 0.12
Nodes (10): _a(), ba(), ga, Ka(), Ma, ua(), va, wa() (+2 more)

### Community 44 - "hc"
Cohesion: 0.24
Nodes (18): Ac(), bc(), cc(), dc(), Ec(), gc(), hc(), lc() (+10 more)

### Community 45 - "parseAsync"
Cohesion: 0.10
Nodes (15): bindSkeletons(), eu, Fe(), iu, Jo, loadAsync(), parse(), parseAnimations() (+7 more)

### Community 48 - "$n"
Cohesion: 0.12
Nodes (3): fc(), $n, sc

### Community 50 - "Mo"
Cohesion: 0.19
Nodes (3): n(), Mo, Ne()

### Community 52 - "br"
Cohesion: 0.08
Nodes (5): add(), br, jh, updateMatrixWorld(), vo

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
Cohesion: 0.18
Nodes (9): Bc, constructor(), a(), o(), Hu(), _initMemoryManager(), setColors(), setLength() (+1 more)

### Community 64 - "nh"
Cohesion: 0.12
Nodes (3): nh, _o, xo

### Community 69 - "Oe"
Cohesion: 0.29
Nodes (7): at(), closestPointToPoint(), closestPointToPointParameter(), delta(), Oe(), setFromCartesianCoords(), setFromVector3()

### Community 70 - "_deactivateAction"
Cohesion: 0.27
Nodes (10): _deactivateAction(), existingAction(), _removeInactiveAction(), _removeInactiveBinding(), _removeInactiveBindingsForAction(), _takeBackAction(), _takeBackBinding(), uncacheAction() (+2 more)

### Community 71 - ".copy"
Cohesion: 0.13
Nodes (5): kc, Oh, qc, setFromCenterAndSize(), th

### Community 72 - "ac"
Cohesion: 0.20
Nodes (3): ac, parseShapes(), toShapes()

### Community 77 - "VGD::Diagram::Scene"
Cohesion: 0.31
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Scene

### Community 78 - "_activateAction"
Cohesion: 0.25
Nodes (8): _activateAction(), _addInactiveAction(), _addInactiveBinding(), _bindAction(), clipAction(), _isActiveAction(), _lendAction(), _lendBinding()

### Community 79 - "mi"
Cohesion: 0.20
Nodes (3): di(), mi, vi

### Community 83 - "mo"
Cohesion: 0.33
Nodes (3): g(), mo(), xr()

### Community 84 - ".constructor"
Cohesion: 0.22
Nodes (6): Nr(), oo, C(), E(), L(), uo

### Community 86 - "Lh"
Cohesion: 0.07
Nodes (11): clone(), c(), l(), o(), ei(), hi, Je(), Lh (+3 more)

### Community 92 - "mh"
Cohesion: 0.20
Nodes (3): _lendControlInterpolant(), mh, yh

### Community 96 - "Es"
Cohesion: 0.29
Nodes (7): ea(), Es(), ia(), ks(), qs(), $s(), ta()

### Community 97 - "isEmpty"
Cohesion: 0.29
Nodes (7): expandByPoint(), getCenter(), getSize(), intersect(), isEmpty(), makeEmpty(), setFromPoints()

### Community 106 - "parseObject"
Cohesion: 0.22
Nodes (3): parseObject(), Sl, Zh

### Community 108 - "Ou"
Cohesion: 0.67
Nodes (4): intersectObject(), intersectObjects(), Nu(), Ou()

### Community 115 - "copy"
Cohesion: 0.67
Nodes (3): copy(), dispose(), setSize()

### Community 134 - "ja"
Cohesion: 0.50
Nodes (3): ja(), qa(), Xa()

### Community 136 - "e"
Cohesion: 0.67
Nodes (3): l(), na(), e()

## Knowledge Gaps
- **86 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `fi` connect `fi` to `gi`, `fh`, `gs`, `.divideScalar`, `three.min.js`, `.copy`, `ns`, `br`, `.boneTransform`, `.constructor`, `Lh`, `go`, `ro`, `.clone`, `.copy`?**
  _High betweenness centrality (0.065) - this node is a cross-community bridge._
- **Should `Sketchup` be split into smaller, more focused modules?**
  _Cohesion score 0.07671957671957672 - nodes in this community are weakly interconnected._
- **Why does `$e` connect `$e` to `.normalize`, `.fromArray`, `ja`, `three.min.js`, `ns`, `Ke`, `.setAttribute`, `_i`, `al`, `xn`, `gs`, `Ln`, `parseAsync`, `ho`, `br`, `kh`, `go`, `s`, `constructor`, `.fromBufferAttribute`, `.copy`, `.constructor`, `.copy`, `.constructor`, `Lh`, `.constructor`, `.clone`, `.set`, `.raycast`, `mr`?**
  _High betweenness centrality (0.060) - this node is a cross-community bridge._
- **Should `UI` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._
- **Why does `zn` connect `zn` to `nh`, `$c`, `.setValues`, `ja`, `.copy`, `e`, `.constructor`, `parseObject`, `three.min.js`, `load`, `xl`, `ns`, `Pn`, `Lh`, `constructor`, `wh`?**
  _High betweenness centrality (0.055) - this node is a cross-community bridge._
- **Should `three.min.js` be split into smaller, more focused modules?**
  _Cohesion score 0.024350205198358413 - nodes in this community are weakly interconnected._
- **Should `dialog.js` be split into smaller, more focused modules?**
  _Cohesion score 0.1471264367816092 - nodes in this community are weakly interconnected._