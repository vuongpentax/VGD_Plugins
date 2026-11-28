# Graph Report - VGD_Diagram  (2026-11-28)

## Corpus Check
- 24 files · ~42,598 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 3 file(s) not represented in the graph (top: .woff2 2, (none) 1)

## Summary
- 2016 nodes · 3647 edges · 116 communities (56 shown, 60 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 324 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `009ed4d5`
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
- VGD Diagram 0.10.4-beta.1
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
- Es
- Pn
- Ln
- qi
- bt
- kh
- ji
- fa
- hc
- parseAsync
- .copy
- xl
- mo
- ho
- .constructor
- VGD::Diagram::Ffmpeg
- .constructor
- $n
- Bo
- br
- s
- Bl
- constructor
- .fromBufferAttribute
- disconnect
- go
- toJSON
- ui
- _deactivateAction
- .copy
- .raycast
- UI::HtmlDialog
- Qo
- rn
- VGD::Diagram::Scene
- _activateAction
- mi
- parseObject
- nh
- qh
- .constructor
- Tr
- El
- .constructor
- test_formats.rb
- uu
- isEmpty
- Wl
- .copy
- kl
- ql
- Ic
- gi
- Ou
- .parse
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
- jh
- vo
- Oe
- .copy
- .toJSON

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
- `Quy tắc riêng` --references--> `explodedOffset()`  [INFERRED]
  CLAUDE.md → runtime/vgd_diagram/dialog.js
- `Quy tắc riêng` --references--> `exportFrames()`  [INFERRED]
  CLAUDE.md → runtime/vgd_diagram/dialog.js

## Import Cycles
- None detected.

## Communities (116 total, 60 thin omitted)

### Community 0 - "Sketchup"
Cohesion: 0.07
Nodes (7): Sketchup, Sketchup::ComponentDefinition, Sketchup::ComponentInstance, Sketchup::Entity, Sketchup::FakeModel, Sketchup::FakeSelection, Sketchup::Group

### Community 1 - "UI::HtmlDialog"
Cohesion: 0.07
Nodes (6): Sketchup, UI, UI::Command, UI::HtmlDialog, UI::Menu, UI::Toolbar

### Community 2 - "VGD::Diagram::Tree"
Cohesion: 0.15
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Tree

### Community 4 - "VGD::Diagram::ModelIO"
Cohesion: 0.22
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::ModelIO

### Community 5 - ".setValues"
Cohesion: 0.17
Nodes (4): ol, Qa, rh, to

### Community 6 - "menu"
Cohesion: 0.29
Nodes (3): menu(), VGD, VGD::Diagram

### Community 7 - "test_ui.cjs"
Cohesion: 0.25
Nodes (4): { chromium }, failed, path, sample

### Community 8 - "vgd-theme.js"
Cohesion: 0.54
Nodes (7): apply(), current(), readSaved(), root(), start(), systemIsDark(), writeSaved()

### Community 9 - "VGD Diagram 0.10.4-beta.1"
Cohesion: 0.25
Nodes (7): Cài đặt và tải lại, Cách dùng, Kiểm thử, Mô hình 3D, Quy tắc gom và thứ tự (giả định cần xác nhận), Trạng thái, VGD Diagram 0.10.4-beta.1

### Community 11 - "three.min.js"
Cohesion: 0.02
Nodes (11): _a(), ba(), clampPoint(), distanceToPoint(), getAverageFrequency(), getFrequencyData(), Ka(), Sh (+3 more)

### Community 12 - "dialog.js"
Cohesion: 0.07
Nodes (66): Cấu trúc, Kiểm thử, Quy tắc riêng, Thông tin plugin, Tài liệu đọc trước khi sửa, VGD Diagram — hướng dẫn cho Claude, Đóng gói, addArrow() (+58 more)

### Community 16 - "ns"
Cohesion: 0.06
Nodes (19): as(), Dr, fr, gr(), ls(), x(), no(), T() (+11 more)

### Community 18 - "gh"
Cohesion: 0.06
Nodes (12): ah(), bh, dh, fh, gh, _lendControlInterpolant(), mh, oh() (+4 more)

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

### Community 29 - "al"
Cohesion: 0.05
Nodes (10): al, clone(), c(), l(), o(), ih, Lh, load() (+2 more)

### Community 31 - "wh"
Cohesion: 0.09
Nodes (7): ch(), fo(), _h, hh(), lh(), Th(), wh

### Community 32 - "Gn"
Cohesion: 0.05
Nodes (6): Ge(), Gn, Hn, So, Ve(), Vn

### Community 33 - "zn"
Cohesion: 0.08
Nodes (5): ii(), On(), Ue(), ze(), zn

### Community 35 - "so"
Cohesion: 0.15
Nodes (23): Be(), ei(), hi, Je(), so(), A(), b(), C() (+15 more)

### Community 36 - "Es"
Cohesion: 0.29
Nodes (7): ea(), Es(), ia(), ks(), qs(), $s(), ta()

### Community 38 - "Ln"
Cohesion: 0.11
Nodes (3): Ln, mr(), sc

### Community 40 - "bt"
Cohesion: 0.11
Nodes (14): ao(), ds(), At(), bt(), Hr(), hs(), Or(), ps() (+6 more)

### Community 43 - "fa"
Cohesion: 0.11
Nodes (6): fa, ga, ka, Ma, va, ya()

### Community 44 - "hc"
Cohesion: 0.24
Nodes (18): Ac(), bc(), cc(), dc(), Ec(), gc(), hc(), lc() (+10 more)

### Community 45 - "parseAsync"
Cohesion: 0.16
Nodes (13): bindSkeletons(), Fe(), Jo, loadAsync(), parse(), parseAnimations(), parseAsync(), parseImages() (+5 more)

### Community 48 - "mo"
Cohesion: 0.33
Nodes (3): g(), mo(), xr()

### Community 52 - "VGD::Diagram::Ffmpeg"
Cohesion: 0.21
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Ffmpeg

### Community 54 - "$n"
Cohesion: 0.09
Nodes (9): fc(), fs(), gs(), jc, ms(), $n, w(), Oc (+1 more)

### Community 58 - "s"
Cohesion: 0.36
Nodes (7): s(), B(), F(), G(), k(), R(), z()

### Community 59 - "Bl"
Cohesion: 0.15
Nodes (3): Bl, Fl, Ul()

### Community 61 - "constructor"
Cohesion: 0.12
Nodes (13): Bc, constructor(), a(), o(), Hu(), _initMemoryManager(), setColors(), setFromObject() (+5 more)

### Community 64 - "go"
Cohesion: 0.19
Nodes (8): go(), Ct(), Dt(), i(), Nt(), Ot(), Ut(), zt()

### Community 70 - "_deactivateAction"
Cohesion: 0.27
Nodes (10): _deactivateAction(), existingAction(), _removeInactiveAction(), _removeInactiveBinding(), _removeInactiveBindingsForAction(), _takeBackAction(), _takeBackBinding(), uncacheAction() (+2 more)

### Community 71 - ".copy"
Cohesion: 0.11
Nodes (4): $c, eh, kc, setFromCenterAndSize()

### Community 73 - "UI::HtmlDialog"
Cohesion: 0.07
Nodes (7): Geom, Geom::Transformation, Sketchup, Sketchup::FakeModel, Sketchup::FakeSelection, UI, UI::HtmlDialog

### Community 75 - "rn"
Cohesion: 0.14
Nodes (3): cs(), Ga(), rn

### Community 77 - "VGD::Diagram::Scene"
Cohesion: 0.31
Nodes (3): VGD, VGD::Diagram, VGD::Diagram::Scene

### Community 78 - "_activateAction"
Cohesion: 0.25
Nodes (8): _activateAction(), _addInactiveAction(), _addInactiveBinding(), _bindAction(), clipAction(), _isActiveAction(), _lendAction(), _lendBinding()

### Community 79 - "mi"
Cohesion: 0.20
Nodes (3): di(), mi, uo

### Community 80 - "parseObject"
Cohesion: 0.05
Nodes (11): gl, Hl, Oh, parseObject(), pl, Sl, vl, xh (+3 more)

### Community 82 - "nh"
Cohesion: 0.12
Nodes (3): nh, _o, xo

### Community 84 - ".constructor"
Cohesion: 0.28
Nodes (5): Nr(), oo, C(), E(), L()

### Community 87 - "Tr"
Cohesion: 0.22
Nodes (3): Ar, qr(), Tr

### Community 97 - "isEmpty"
Cohesion: 0.29
Nodes (7): expandByPoint(), getCenter(), getSize(), intersect(), isEmpty(), makeEmpty(), setFromPoints()

### Community 104 - "ql"
Cohesion: 0.06
Nodes (7): ac, n(), Mo, Ne(), Nl, ql, toShapes()

### Community 106 - "gi"
Cohesion: 0.18
Nodes (4): gi, Le, po, rs()

### Community 108 - "Ou"
Cohesion: 0.67
Nodes (4): intersectObject(), intersectObjects(), Nu(), Ou()

### Community 109 - ".parse"
Cohesion: 0.22
Nodes (3): eu, iu, parseGeometries()

### Community 115 - "copy"
Cohesion: 0.67
Nodes (3): copy(), dispose(), setSize()

### Community 128 - "vo"
Cohesion: 0.13
Nodes (3): add(), updateMatrixWorld(), vo

### Community 129 - "Oe"
Cohesion: 0.29
Nodes (7): at(), closestPointToPoint(), closestPointToPointParameter(), delta(), Oe(), setFromCartesianCoords(), setFromVector3()

### Community 133 - ".copy"
Cohesion: 0.18
Nodes (5): Bn, ja(), qa(), Xa(), Zc

## Knowledge Gaps
- **60 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `$e` connect `$e` to `vo`, `.copy`, `.setValues`, `three.min.js`, `ns`, `Ke`, `.setAttribute`, `_i`, `al`, `xn`, `Ln`, `kh`, `ho`, `.constructor`, `.constructor`, `$n`, `s`, `constructor`, `.fromBufferAttribute`, `go`, `.raycast`, `qh`, `.constructor`, `.constructor`, `.copy`, `ql`, `.parse`, `jh`?**
  _High betweenness centrality (0.102) - this node is a cross-community bridge._
- **Should `Sketchup` be split into smaller, more focused modules?**
  _Cohesion score 0.07407407407407407 - nodes in this community are weakly interconnected._
- **Why does `xn` connect `xn` to `vo`, `vu`, `Ln`, `.toJSON`, `gi`, `three.min.js`, `Qo`, `.add`, `.copy`, `parseObject`, `ho`, `gh`, `nh`, `ns`, `Ke`, `Bo`, `.updateWorldMatrix`?**
  _High betweenness centrality (0.058) - this node is a cross-community bridge._
- **Should `UI::HtmlDialog` be split into smaller, more focused modules?**
  _Cohesion score 0.06896551724137931 - nodes in this community are weakly interconnected._
- **Why does `We` connect `We` to `.copy`, `three.min.js`, `ns`, `gh`, `.setAttribute`, `al`, `Gn`, `Pn`, `Ln`, `xl`, `.toArray`, `.constructor`, `.constructor`, `$n`, `.fromArray`, `Bo`, `s`, `.copy`, `mi`, `nh`, `qh`, `El`, `.divideScalar`, `Wl`, `.copy`, `jh`?**
  _High betweenness centrality (0.057) - this node is a cross-community bridge._
- **Should `VGD::Diagram::Tree` be split into smaller, more focused modules?**
  _Cohesion score 0.14855072463768115 - nodes in this community are weakly interconnected._
- **Should `three.min.js` be split into smaller, more focused modules?**
  _Cohesion score 0.02459235498529805 - nodes in this community are weakly interconnected._