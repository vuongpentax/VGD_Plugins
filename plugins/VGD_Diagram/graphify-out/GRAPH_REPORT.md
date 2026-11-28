# Graph Report - VGD_Diagram  (2026-11-28)

## Corpus Check
- 21 files · ~30,343 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 3 file(s) not represented in the graph (top: .woff2 2, (none) 1)

## Summary
- 1902 nodes · 3396 edges · 126 communities (48 shown, 78 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 319 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6fc67b52`
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
- VGD Diagram 0.2.0-beta.1
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
- ji
- Ma
- hc
- parseAsync
- .copy
- xl
- vo
- Pn
- Mo
- ho
- br
- kh
- parseObject
- ui
- .copy
- go
- s
- Bl
- .updateMatrix
- constructor
- gs
- .getHex
- .clone
- fa
- .raycast
- ac
- Oe
- _deactivateAction
- .parse
- Lh
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
- kl
- .constructor
- pl
- qh
- load
- El
- .constructor
- Hl
- ql
- uu
- .set
- Es
- isEmpty
- gi
- Wl
- .setHSL
- jh
- Le
- Ic
- cs
- ih
- Ou
- nh
- tu
- VGD
- VGD
- Bo
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
- `x()` --indirect_call--> `d()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 16 → community 24_
- `w()` --indirect_call--> `b()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 36 → community 35_
- `update()` --indirect_call--> `t()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 20 → community 63_
- `ro()` --indirect_call--> `u()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 16 → community 27_
- `F()` --indirect_call--> `u()`  [INFERRED]
  runtime/vgd_diagram/vendor/three.min.js → runtime/vgd_diagram/vendor/three.min.js  _Bridges community 16 → community 35_

## Import Cycles
- None detected.

## Communities (126 total, 78 thin omitted)

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

### Community 9 - "VGD Diagram 0.2.0-beta.1"
Cohesion: 0.25
Nodes (7): Cài đặt và tải lại, Cách dùng, Kiểm thử, Mô hình 3D (mới ở 0.2.0-beta.1), Quy tắc gom và thứ tự (giả định cần xác nhận), Trạng thái, VGD Diagram 0.2.0-beta.1

### Community 11 - "three.min.js"
Cohesion: 0.02
Nodes (11): at(), clampPoint(), closestPointToPoint(), closestPointToPointParameter(), delta(), disconnect(), distanceToPoint(), getAverageFrequency() (+3 more)

### Community 12 - "dialog.js"
Cohesion: 0.18
Nodes (23): advancePlayback(), bindOrbit(), checkOrder(), clamp(), clearParts(), createView(), highlight(), idsOf() (+15 more)

### Community 16 - "ns"
Cohesion: 0.06
Nodes (19): Ar, as(), Dr, fr, gr(), ls(), x(), no() (+11 more)

### Community 18 - "gh"
Cohesion: 0.05
Nodes (13): ah(), bh, dh, fh, gh, _lendControlInterpolant(), mh, oh() (+5 more)

### Community 20 - "Ru"
Cohesion: 0.06
Nodes (10): clone(), c(), l(), o(), g(), mo(), t(), Ru (+2 more)

### Community 21 - "je"
Cohesion: 0.06
Nodes (3): je, jr(), Rr

### Community 24 - ".setAttribute"
Cohesion: 0.08
Nodes (12): Fc, p(), Gc, Hc, Jl, l(), v(), na() (+4 more)

### Community 26 - "Lu"
Cohesion: 0.08
Nodes (5): bind(), getValue(), Lu, setValue(), subscribe_()

### Community 27 - "nn"
Cohesion: 0.10
Nodes (8): nn, S(), ro(), bt(), Ct(), Et(), Mt(), Tt()

### Community 28 - "Sketchup"
Cohesion: 0.07
Nodes (11): Geom, Geom::Point3d, Geom::Transformation, Sketchup, Sketchup::ComponentDefinition, Sketchup::ComponentInstance, Sketchup::Entity, Sketchup::Face (+3 more)

### Community 31 - "wh"
Cohesion: 0.09
Nodes (7): ch(), fo(), _h, hh(), lh(), Th(), wh

### Community 32 - "Gn"
Cohesion: 0.09
Nodes (3): Gn, Hn, Vn

### Community 35 - "so"
Cohesion: 0.15
Nodes (23): Be(), ei(), hi, Je(), so(), A(), b(), C() (+15 more)

### Community 36 - "$n"
Cohesion: 0.10
Nodes (4): fc(), jc, $n, w()

### Community 37 - ".copy"
Cohesion: 0.10
Nodes (7): Bn, ol, Qa, rh, th, wo, Zc

### Community 40 - "bt"
Cohesion: 0.10
Nodes (15): ao(), ds(), At(), bt(), Hr(), hs(), Or(), ps() (+7 more)

### Community 43 - "Ma"
Cohesion: 0.12
Nodes (10): _a(), ba(), ga, Ka(), Ma, ua(), va, wa() (+2 more)

### Community 44 - "hc"
Cohesion: 0.24
Nodes (18): Ac(), bc(), cc(), dc(), Ec(), gc(), hc(), lc() (+10 more)

### Community 45 - "parseAsync"
Cohesion: 0.16
Nodes (13): bindSkeletons(), Fe(), Jo, loadAsync(), parse(), parseAnimations(), parseAsync(), parseImages() (+5 more)

### Community 48 - "vo"
Cohesion: 0.16
Nodes (4): add(), updateMatrixWorld(), vo, wr

### Community 49 - "Pn"
Cohesion: 0.13
Nodes (4): ja(), Pn, qa(), Xa()

### Community 50 - "Mo"
Cohesion: 0.16
Nodes (3): n(), Mo, Ne()

### Community 54 - "parseObject"
Cohesion: 0.14
Nodes (5): Oh, parseObject(), Sl, Zh, Zo

### Community 56 - ".copy"
Cohesion: 0.14
Nodes (4): eh, kc, qc, setFromCenterAndSize()

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
Cohesion: 0.18
Nodes (9): Bc, constructor(), a(), o(), Hu(), _initMemoryManager(), setColors(), setLength() (+1 more)

### Community 63 - "gs"
Cohesion: 0.17
Nodes (8): fs(), gs(), ms(), setFromObject(), setTime(), $u(), update(), vi

### Community 69 - "Oe"
Cohesion: 0.20
Nodes (4): $c, Oe(), setFromCartesianCoords(), setFromVector3()

### Community 70 - "_deactivateAction"
Cohesion: 0.27
Nodes (10): _deactivateAction(), existingAction(), _removeInactiveAction(), _removeInactiveBinding(), _removeInactiveBindingsForAction(), _takeBackAction(), _takeBackBinding(), uncacheAction() (+2 more)

### Community 71 - ".parse"
Cohesion: 0.22
Nodes (3): eu, iu, parseGeometries()

### Community 77 - ".collect"
Cohesion: 0.33
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Scene

### Community 78 - "_activateAction"
Cohesion: 0.25
Nodes (8): _activateAction(), _addInactiveAction(), _addInactiveBinding(), _bindAction(), clipAction(), _isActiveAction(), _lendAction(), _lendBinding()

### Community 84 - ".constructor"
Cohesion: 0.28
Nodes (5): Nr(), C(), E(), L(), uo

### Community 96 - "Es"
Cohesion: 0.29
Nodes (7): ea(), Es(), ia(), ks(), qs(), $s(), ta()

### Community 97 - "isEmpty"
Cohesion: 0.29
Nodes (7): expandByPoint(), getCenter(), getSize(), intersect(), isEmpty(), makeEmpty(), setFromPoints()

### Community 100 - ".setHSL"
Cohesion: 0.33
Nodes (3): On(), Ue(), ze()

### Community 108 - "Ou"
Cohesion: 0.67
Nodes (4): intersectObject(), intersectObjects(), Nu(), Ou()

### Community 115 - "copy"
Cohesion: 0.67
Nodes (3): copy(), dispose(), setSize()

## Knowledge Gaps
- **78 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `fi` connect `fi` to `gi`, `.divideScalar`, `jh`, `three.min.js`, `.copy`, `ns`, `gh`, `.constructor`, `.boneTransform`, `qh`, `go`, `.copy`, `nn`, `.clone`, `gs`?**
  _High betweenness centrality (0.075) - this node is a cross-community bridge._
- **Should `Sketchup` be split into smaller, more focused modules?**
  _Cohesion score 0.07671957671957672 - nodes in this community are weakly interconnected._
- **Why does `$e` connect `$e` to `three.min.js`, `ns`, `Ke`, `We`, `.setAttribute`, `_i`, `al`, `xn`, `$n`, `Ln`, `vo`, `Pn`, `ho`, `kh`, `.copy`, `go`, `s`, `constructor`, `.fromBufferAttribute`, `.clone`, `.raycast`, `.parse`, `.constructor`, `.copy`, `.constructor`, `qh`, `.constructor`, `.set`, `jh`?**
  _High betweenness centrality (0.074) - this node is a cross-community bridge._
- **Should `UI` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._
- **Why does `We` connect `We` to `three.min.js`, `ns`, `gh`, `.setAttribute`, `al`, `Gn`, `$n`, `.copy`, `xl`, `Pn`, `.copy`, `s`, `gs`, `Oe`, `.constructor`, `mi`, `.copy`, `qh`, `El`, `Wl`, `jh`, `.divideScalar`, `ih`, `nh`, `Bo`, `.toArray`?**
  _High betweenness centrality (0.060) - this node is a cross-community bridge._
- **Should `three.min.js` be split into smaller, more focused modules?**
  _Cohesion score 0.024325046778936113 - nodes in this community are weakly interconnected._
- **Should `ns` be split into smaller, more focused modules?**
  _Cohesion score 0.060655737704918035 - nodes in this community are weakly interconnected._