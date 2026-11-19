// Công cụ vẽ kết cấu trên tab Mặt bằng (cột mốc P3): bấm điểm trên lưới thì ghi vào lựa chọn của tầng (cùng dữ liệu với các tab Cột, Dầm, Tường, Cửa, Sàn, Trần).
// Mọi thay đổi đi qua host.mutate (có hoàn tác); Ruby vẫn kiểm tra lại và tính xem trước. Chỉ gom dữ liệu, không tự dựng hình trong SketchUp.
(function () {
  'use strict';
  var host = null, S = null, A = null;
  var GOOD = '#2F7BFF', BAD = '#E5484D', TOL_NODE = 14, TOL_COLUMN = 28, TOL_SPAN = 12, OPENING_GAP = 50;
  var DESIGN = ['grid', 'column', 'beam', 'wall', 'slab', 'ceiling', 'stair', 'door', 'window'];
  var PICKS = {column: 'picks', beam: 'beamPicks', wall: 'wallPicks', slab: 'slabPicks', ceiling: 'ceilingPicks', opening: 'openingPicks', stair: 'stairPicks'};
  var opt = {column: {type: '', x: 'auto', y: 'auto', mode: 'grid', rot: '0'}, beam: {type: '', p: 'auto', mode: 'grid', angle: 'ortho'}, wall: {type: '', p: 'auto', mode: 'grid', angle: 'ortho'}, door: {type: '', hand: '0'}, window: {type: '', flip: '0'}, grid: {dir: 'x'}, slab: {mode: 'grid', edges: 'free', part: 'outer'}, ceiling: {mode: 'grid', edges: 'free', part: 'outer'}};
  var tool = null, chain = null, target = null, note = '', ring = null; // ring: đường bao / lỗ đang vẽ của sàn, trần đa giác {pts, part, host}

  function lvl() { return A.level(); }
  function top() { return A.isTop(lvl()); }
  function dist(a, b) { return Math.hypot(a[0] - b[0], a[1] - b[1]); }
  function tol(px) { return px / host.scale(); }
  function nodes() {
    var gx = A.toAxes('x'), gy = A.toAxes('y'), o = S.origin, out = [];
    gx.forEach(function (ax, i) { gy.forEach(function (ay, j) { out.push({ref: ax.name + '-' + ay.name, i: i, j: j, x: o[0] + ax.offset, y: o[1] + ay.offset}); }); });
    return out;
  }
  function nearestNode(w, px) {
    var best = null; nodes().forEach(function (n) { var d = dist([n.x, n.y], w); if (d <= tol(px) && (!best || d < best.d)) best = {node: n, d: d}; });
    return best && best.node;
  }
  function nearestSpan(w, px) {
    var best = null;
    A.allSpans().forEach(function (sp) {
      var p = sp.dir === 'x' ? [Math.max(sp.a, Math.min(sp.b, w[0])), sp.axis] : [sp.axis, Math.max(sp.a, Math.min(sp.b, w[1]))], d = dist(p, w);
      if (d <= tol(px) && (!best || d < best.d)) best = {span: sp, d: d};
    });
    return best && best.span;
  }
  function cellAt(w) { var hit = null; A.allCells().forEach(function (c) { if (w[0] >= c.x0 && w[0] <= c.x1 && w[1] >= c.y0 && w[1] <= c.y1) hit = c; }); return hit; }
  function typesFor(tool) {
    if (tool === 'column') return S.types; if (tool === 'beam') return S.beamTypes; if (tool === 'wall') return S.wallTypes;
    return S.openingTypes.filter(function (t) { return t.kind === tool; });
  }
  function typeLabel(t, tool) { return t.name + ' (' + (tool === 'column' ? t.w + '×' + t.d : tool === 'beam' ? t.w + '×' + t.h : tool === 'wall' ? 'dày ' + t.t : t.w + '×' + t.h) + ')'; }
  function currentType(tool) { // loại đang chọn ở thanh tùy chọn (cửa luôn có loại; cột, dầm, tường '' = theo loại mặc định của tầng)
    if (!opt[tool] || tool === 'slab' || tool === 'ceiling') return ''; // sàn, trần không có loại
    var id = opt[tool].type, list = typesFor(tool);
    if (id && list.some(function (t) { return t.id === id; })) return id;
    return tool === 'door' || tool === 'window' ? (list[0] ? list[0].id : '') : '';
  }
  function typeById(tool, id) { return typesFor(tool).filter(function (t) { return t.id === id; })[0]; }
  function modeList(key) { return A.modes[key]; }

  // ---- Thanh tùy chọn (Options Bar) ----
  function typeValues(tool) {
    var v = tool === 'door' || tool === 'window' ? [] : [['', 'Theo loại mặc định của tầng']];
    return v.concat(typesFor(tool).map(function (t) { return [t.id, typeLabel(t, tool)]; }));
  }
  var MODE_VALUES = [['grid', 'Theo lưới (giao điểm / nhịp)'], ['free', 'Tự do (bắt điểm bất kỳ)']];
  var ROT_VALUES = [['0', '0°'], ['15', '15°'], ['30', '30°'], ['45', '45°'], ['60', '60°'], ['75', '75°'], ['90', '90°'], ['105', '105°'], ['120', '120°'], ['135', '135°'], ['150', '150°'], ['165', '165°']];
  function isPlate(t) { return t === 'slab' || t === 'ceiling'; }
  function freeMode(t) { if (t === 'stair') return true; return !!(opt[t] && opt[t].mode === 'free' && (t === 'column' || t === 'beam' || t === 'wall' || isPlate(t))); }
  function rotRect(c, w, d, deg) { // hình chữ nhật w × d quanh tâm c, xoay deg độ ngược chiều kim đồng hồ
    var r = deg * Math.PI / 180, cs = Math.cos(r), sn = Math.sin(r);
    return [[-w / 2, -d / 2], [w / 2, -d / 2], [w / 2, d / 2], [-w / 2, d / 2]].map(function (p) { return [c[0] + p[0] * cs - p[1] * sn, c[1] + p[0] * sn + p[1] * cs]; });
  }
  function r1(v) { return Math.round(v * 10) / 10; }
  function options(t) {
    if (t === 'stair') return [];
    if (isPlate(t) && freeMode(t)) return [{id: 'mode', label: 'Vị trí', values: MODE_VALUES, value: 'free'}, {id: 'part', label: 'Vẽ', values: [['outer', 'Đường bao'], ['hole', 'Lỗ khoét (điểm đầu nằm trong một ' + (t === 'slab' ? 'sàn' : 'trần') + ' đa giác)']], value: opt[t].part}, {id: 'edges', label: 'Cạnh', values: [['free', 'Tự do'], ['ortho', 'Ngang / dọc']], value: opt[t].edges}];
    if (freeMode(t)) {
      var head = [{id: 'mode', label: 'Vị trí', values: MODE_VALUES, value: 'free'}, {id: 'type', label: 'Loại', values: typeValues(t), value: currentType(t)}];
      return t === 'column' ? head.concat([{id: 'rot', label: 'Xoay', values: ROT_VALUES, value: String(opt.column.rot)}]) : head.concat([{id: 'angle', label: 'Hướng', values: [['ortho', 'Ngang / dọc (tự giữ thẳng)'], ['free', 'Góc bất kỳ (xiên)']], value: opt[t].angle}]);
    }
    if (t === 'column' || t === 'beam' || t === 'wall' || isPlate(t)) { var m = {id: 'mode', label: 'Vị trí', values: MODE_VALUES, value: 'grid'}, rest = optionsGrid(t); return [m].concat(rest); }
    return optionsGrid(t);
  }
  function optionsGrid(t) {
    if (t === 'column') return [{id: 'type', label: 'Loại', values: typeValues(t), value: currentType(t)}, {id: 'x', label: 'Vị trí X', values: modeList('x'), value: opt.column.x}, {id: 'y', label: 'Vị trí Y', values: modeList('y'), value: opt.column.y}];
    if (t === 'beam' || t === 'wall') return [{id: 'type', label: 'Loại', values: typeValues(t), value: currentType(t)}, {id: 'p', label: 'Vị trí ngang', values: modeList('p'), value: opt[t].p}];
    if (t === 'door' || t === 'window') return [{id: 'type', label: 'Loại', values: typeValues(t), value: currentType(t)}, t === 'door' ? {id: 'hand', label: 'Bản lề (Space đổi)', values: [['0', 'Đầu tường'], ['1', 'Cuối tường']], value: opt.door.hand} : {id: 'flip', label: 'Cánh', values: [['0', 'Mặc định'], ['1', 'Đổi mặt']], value: opt[t].flip}];
    if (t === 'grid') return [{id: 'dir', label: 'Loại trục', values: [['x', 'Trục đứng (đánh số)'], ['y', 'Trục ngang (đánh chữ)']], value: opt.grid.dir}];
    return [];
  }
  function setOption(t, id, value) { if (opt[t]) { opt[t][id] = value; if (id === 'mode' || id === 'part') ring = null; } }

  // ---- Đặt phần tử ----
  function newPick(t) {
    var p = {}, type = currentType(t);
    if (type) p.type = type;
    if (t === 'column') { if (opt.column.x !== 'auto') p.x = opt.column.x; if (opt.column.y !== 'auto') p.y = opt.column.y; }
    if (t === 'beam' || t === 'wall') { if (opt[t].p !== 'auto') p.p = opt[t].p; }
    return p;
  }
  function blocked(t) {
    if (t === 'slab' || t === 'grid') return '';
    if (top()) return t === 'ceiling' ? 'Tầng trên cùng chỉ có sàn, không có trần.' : t === 'stair' ? 'Tầng trên cùng không có tầng trên để cầu thang đi lên.' : 'Tầng trên cùng chỉ có sàn (không có cột, dầm, tường, cửa).';
    return '';
  }
  function spansBetween(a, b) {
    var gx = A.toAxes('x'), gy = A.toAxes('y'), out = [], k;
    if (a.j === b.j) { for (k = Math.min(a.i, b.i); k < Math.max(a.i, b.i); k++) out.push('x:' + gy[a.j].name + ':' + gx[k].name + '-' + gx[k + 1].name); }
    else for (k = Math.min(a.j, b.j); k < Math.max(a.j, b.j); k++) out.push('y:' + gx[a.i].name + ':' + gy[k].name + '-' + gy[k + 1].name);
    return out;
  }
  // Điểm cuối của chuỗi dầm / tường: giao điểm cùng hàng hoặc cùng cột với điểm đầu, theo hướng con trỏ lệch nhiều hơn.
  function chainEnd(w) {
    var horizontal = Math.abs(w[0] - chain.x) >= Math.abs(w[1] - chain.y), best = null;
    nodes().forEach(function (n) {
      if (n === chain || (n.i === chain.i && n.j === chain.j)) return;
      if (horizontal ? n.j !== chain.j : n.i !== chain.i) return;
      var d = Math.abs(horizontal ? n.x - w[0] : n.y - w[1]);
      if (!best || d < best.d) best = {node: n, d: d};
    });
    return best && best.node;
  }
  function wallAt(w) {
    var best = null, e = tol(6);
    ((S.preview && S.preview.walls && S.preview.walls.items) || []).forEach(function (it) {
      if (it.dir === 'o') { // tường xiên: đổi điểm sang hệ (dọc, ngang) của tường
        var len = it.length, ux = (it.b[0] - it.a[0]) / len, uy = (it.b[1] - it.a[1]) / len, t = (w[0] - it.a[0]) * ux + (w[1] - it.a[1]) * uy, n = Math.abs(-(w[0] - it.a[0]) * uy + (w[1] - it.a[1]) * ux);
        if (t >= -e && t <= len + e && n <= it.t / 2 + e) best = it; return;
      }
      if (w[0] >= it.min[0] - e && w[0] <= it.max[0] + e && w[1] >= it.min[1] - e && w[1] <= it.max[1] + e) best = it;
    });
    return best;
  }
  // Phía của con trỏ so với tim tường: > 0 là phía +v (tường ngang: +Y, tường dọc: +X, tường xiên: pháp tuyến trái), < 0 là phía -v. Cửa đi mở về phía con trỏ như Revit.
  function sideOf(wall, w) {
    if (wall.dir === 'x') return w[1] - wall.center;
    if (wall.dir === 'y') return w[0] - wall.center;
    var len = wall.length, ux = (wall.b[0] - wall.a[0]) / len, uy = (wall.b[1] - wall.a[1]) / len;
    return -(w[0] - wall.a[0]) * uy + (w[1] - wall.a[1]) * ux;
  }
  // Điểm theo (u dọc tường tính từ đầu tường, v vuông góc tim tường) trong tọa độ thế giới, cùng hệ với vẽ cửa trên mặt bằng.
  function wallPoint(wall, u, v) {
    if (wall.dir === 'x') return [wall.start + u, wall.center + v];
    if (wall.dir === 'y') return [wall.center + v, wall.start + u];
    var len = wall.length, ux = (wall.b[0] - wall.a[0]) / len, uy = (wall.b[1] - wall.a[1]) / len;
    return [wall.a[0] + ux * u - uy * v, wall.a[1] + uy * u + ux * v];
  }
  // Cánh và cung quay của cửa đi (xem trước đúng hướng mở và bản lề sẽ dựng).
  function swingGhost(wall, type, pos, flip, mirror, color) {
    var w = type.w, dir = flip ? -1 : 1, hu = mirror ? pos + w / 2 : pos - w / 2, su = mirror ? -1 : 1, g = [], prev = null;
    g.push({t: 'line', a: wallPoint(wall, hu, 0), b: wallPoint(wall, hu, dir * w), color: color, width: 2.5});
    for (var k = 0; k <= 12; k++) { var a = k / 12 * Math.PI / 2, p = wallPoint(wall, hu + su * w * Math.cos(a), dir * w * Math.sin(a)); if (prev) g.push({t: 'line', a: prev, b: p, color: color, width: 1, dash: [3, 3]}); prev = p; }
    return g;
  }
  // Space: đặt cửa đi thì đổi bản lề trái / phải; đang chọn một cửa thì đổi bản lề của cửa đó (Shift: đổi hướng mở). Trả về true nếu đã xử lý.
  function flipDoor(currentTool, ref, shift) {
    if (ref && lvl().openingPicks[ref]) { edit(function () { var e = lvl().openingPicks[ref]; if (shift) e.flip = !e.flip; else if (e.mirror) delete e.mirror; else e.mirror = true; }); return true; }
    if (currentTool === 'door') { opt.door.hand = opt.door.hand === '1' ? '0' : '1'; note = 'Bản lề ở ' + (opt.door.hand === '1' ? 'cuối' : 'đầu') + ' tường.'; return true; }
    return false;
  }
  // Cửa: tâm cách đầu tường; kiểm tra như WallPlan.place_openings (trong tường, không quá cao, cách cửa khác >= 50 mm).
  function openingCheck(wall, type, pos) {
    if (!wall || !type) return 'Rê lên một tường đã chọn.';
    var x0 = pos - type.w / 2, x1 = pos + type.w / 2;
    if (x0 < 0 || x1 > wall.length) return 'Cửa rộng ' + type.w + ' mm không nằm trọn trong tường dài ' + wall.length + ' mm.';
    if (type.sill + type.h > wall.height) return 'Cửa cao ' + (type.sill + type.h) + ' mm (kể cả ngưỡng) hơn tường (' + wall.height + ' mm).';
    var clash = A.wallOpenings(wall.ref).some(function (o) { return !(x1 + OPENING_GAP <= o.x0 || x0 >= o.x1 + OPENING_GAP); });
    return clash ? 'Chồng hoặc sát cửa khác (cần cách nhau ít nhất ' + OPENING_GAP + ' mm).' : '';
  }
  function openingPos(wall, w) {
    var along = wall.dir === 'o' ? ((w[0] - wall.a[0]) * (wall.b[0] - wall.a[0]) + (w[1] - wall.a[1]) * (wall.b[1] - wall.a[1])) / wall.length : (wall.dir === 'x' ? w[0] : w[1]) - wall.start;
    return Math.round(along / 10) * 10;
  }

  // ---- Vẽ TỰ DO (P4b-1): cột đặt tại điểm bất kỳ; dầm, tường chỉ ngang / dọc, đầu mút đúng điểm bấm ----
  function freePoint(w) { var s2 = host.snapPoint(w) || w; return [r1(s2[0]), r1(s2[1])]; }
  // Điểm cuối của dầm / tường tự do: tùy chọn "Hướng": thẳng ngang / dọc, hoặc đúng điểm bắt (xiên).
  function freeEnd(from, w) { return tool === 'stair' || (opt[tool] && opt[tool].angle === 'free') ? freePoint(w) : orthoEnd(from, w); }
  function orthoEnd(from, w) { // điểm cuối cùng hàng hoặc cùng cột với điểm đầu (theo phương con trỏ lệch nhiều hơn)
    var p = freePoint(w), horizontal = Math.abs(p[0] - from[0]) >= Math.abs(p[1] - from[1]);
    return horizontal ? [p[0], from[1]] : [from[0], p[1]];
  }
  function lengthOf(a, b) { return r1(Math.hypot(b[0] - a[0], b[1] - a[1])); }
  function addFreeColumn(p) {
    var id = A.rid('fc_'), type = currentType('column'), pick = {free: {x: p[0], y: p[1], rot: Number(opt.column.rot) || 0}};
    if (type) pick.type = type;
    host.mutate(function () { lvl().picks[id] = pick; });
    return id;
  }
  function addFreeLinear(t, a, b) {
    // đầu a luôn là đầu bên trái, đứng dọc thì đầu thấp (cùng quy ước với Ruby)
    var ortho = a[0] === b[0] || a[1] === b[1];
    if (ortho ? (b[0] - a[0]) + (b[1] - a[1]) < 0 : b[0] < a[0]) { var sw = a; a = b; b = sw; }
    var id = A.rid(t === 'beam' ? 'fb_' : 'fw_'), type = currentType(t), pick = {free: {a: a.slice(), b: b.slice()}};
    if (type) pick.type = type;
    host.mutate(function () { lvl()[PICKS[t]][id] = pick; });
    return id;
  }
  // ---- Sàn, trần ĐA GIÁC (P4b-3): bấm từng đỉnh; bấm lại đỉnh đầu hoặc Enter để khép; Backspace bỏ đỉnh cuối ----
  function inRing(ringPts, p) {
    var c = false;
    for (var i = 0, j = ringPts.length - 1; i < ringPts.length; j = i++) {
      var a = ringPts[i], b = ringPts[j];
      if ((a[1] > p[1]) !== (b[1] > p[1]) && p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0]) c = !c;
    }
    return c;
  }
  function orient(a, b, c) { return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]); }
  function segTouch(a, b, c, d) { // hai đoạn chạm hoặc cắt nhau
    var d1 = orient(a, b, c), d2 = orient(a, b, d), d3 = orient(c, d, a), d4 = orient(c, d, b);
    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) return true;
    function on(p, q, r) { return Math.abs(orient(p, q, r)) < 1e-6 && r[0] >= Math.min(p[0], q[0]) - 0.05 && r[0] <= Math.max(p[0], q[0]) + 0.05 && r[1] >= Math.min(p[1], q[1]) - 0.05 && r[1] <= Math.max(p[1], q[1]) + 0.05; }
    return on(a, b, c) || on(a, b, d) || on(c, d, a) || on(c, d, b);
  }
  // Báo sớm (Ruby kiểm tra lại): vòng phải có >= 3 đỉnh, không tự cắt; lỗ phải nằm hẳn trong đường bao (hostPts), không chạm các lỗ khác.
  function ringProblem(pts, hostPts, otherHoles) {
    var n = pts.length; if (n < 3) return 'Cần ít nhất 3 đỉnh.';
    for (var i = 0; i < n; i++) for (var j = i + 1; j < n; j++) { if (j === i + 1 || (i === 0 && j === n - 1)) continue; if (segTouch(pts[i], pts[(i + 1) % n], pts[j], pts[(j + 1) % n])) return 'Đường bao tự cắt: hãy bấm lại các đỉnh để các cạnh không cắt nhau.'; }
    var area = 0; pts.forEach(function (p, i) { var q = pts[(i + 1) % n]; area += p[0] * q[1] - q[0] * p[1]; }); if (Math.abs(area) / 2 < 1) return 'Diện tích quá nhỏ.';
    if (hostPts) {
      if (!pts.every(function (p) { return inRing(hostPts, p); })) return 'Lỗ phải nằm hẳn bên trong đường bao.';
      for (var a = 0; a < n; a++) for (var b = 0; b < hostPts.length; b++) if (segTouch(pts[a], pts[(a + 1) % n], hostPts[b], hostPts[(b + 1) % hostPts.length])) return 'Lỗ không được chạm cạnh ngoài.';
      var clash = (otherHoles || []).some(function (h) { return pts.some(function (p) { return inRing(h, p); }) || h.some(function (p) { return inRing(pts, p); }) || pts.some(function (p, a2) { return h.some(function (q, b2) { return segTouch(p, pts[(a2 + 1) % n], q, h[(b2 + 1) % h.length]); }); }); });
      if (clash) return 'Lỗ chạm hoặc chồng lên lỗ khác.';
    }
    return '';
  }
  function plateAt(p) { // sàn / trần đa giác (của công cụ hiện tại) chứa điểm p, không kể trong lỗ
    var items = (S.preview && S.preview[tool === 'slab' ? 'slabs' : 'ceilings'] && S.preview[tool === 'slab' ? 'slabs' : 'ceilings'].items) || [], hit = null;
    items.forEach(function (it) { if (it.placement === 'free' && inRing(it.polygon, p) && !(it.holes || []).some(function (h) { return inRing(h, p); })) hit = it; });
    return hit;
  }
  function plateMove(w) {
    var p = freePoint(w), last = ring && ring.pts[ring.pts.length - 1];
    if (last && opt[tool].edges === 'ortho') p = orthoEnd(last, w);
    var close = !!(ring && ring.pts.length >= 3 && dist(w, ring.pts[0]) <= tol(10));
    target = {free: close ? ring.pts[0].slice() : p, close: close, plate: true};
  }
  function finishRing() {
    if (!ring || ring.pts.length < 3) { note = 'Cần ít nhất 3 đỉnh để khép vòng.'; return false; }
    var l = lvl(), box = l[PICKS[tool]], pts = ring.pts.map(function (p) { return p.slice(); }), name = tool === 'slab' ? 'sàn' : 'trần';
    if (ring.part === 'hole') {
      var h = box[ring.host]; if (!h || !h.free) { note = 'Không còn ' + name + ' đa giác chứa lỗ này.'; ring = null; return false; }
      var why = ringProblem(pts, h.free.poly, h.free.holes); if (why) { note = why; return false; }
      host.mutate(function () { h.free.holes = (h.free.holes || []).concat([pts]); });
      note = 'Đã khoét lỗ ' + pts.length + ' đỉnh trong ' + name + ' ' + ring.host + '.';
    } else {
      var why2 = ringProblem(pts); if (why2) { note = why2; return false; }
      var id = A.rid(tool === 'slab' ? 'fs_' : 'fk_');
      host.mutate(function () { box[id] = {free: {poly: pts, holes: []}}; });
      note = 'Đã thêm ' + name + ' đa giác ' + pts.length + ' đỉnh.';
    }
    ring = null; target = null; return true;
  }
  function plateClick(w) {
    plateMove(w); if (!target) return;
    if (target.close) { finishRing(); return; }
    var p = target.free;
    if (!ring) {
      ring = {pts: [], part: opt[tool].part, host: null};
      if (ring.part === 'hole') {
        var it = plateAt(p); if (!it) { note = 'Lỗ khoét: điểm đầu phải nằm trong một ' + (tool === 'slab' ? 'sàn' : 'trần') + ' đa giác (không phải sàn theo ô).'; ring = null; return; }
        ring.host = it.ref;
      }
    }
    if (ring.pts.length && dist(p, ring.pts[ring.pts.length - 1]) < 1) return;
    ring.pts.push(p.slice());
  }
  function undoPoint() { if (!ring || !ring.pts.length) return false; ring.pts.pop(); if (!ring.pts.length) ring = null; return true; }
  function finish() { return isPlate(tool) && freeMode(tool) && !!ring && finishRing(); }

  function freeMove(w) {
    if (isPlate(tool)) { plateMove(w); return; }
    if (tool === 'column') { target = {free: freePoint(w)}; return; }
    if (!chain) { target = {free: freePoint(w), start: true}; return; }
    var end = freeEnd(chain.p, w); target = lengthOf(chain.p, end) >= 100 ? {free: end, end: true} : {free: end, tooShort: true};
  }
  // Cầu thang thẳng một vế: bấm đáy vế, rồi đỉnh vế (tối thiểu 600 mm). Số bậc, va chạm do Ruby tính (StairPlace).
  function stairType() { return (S.stairTypes && S.stairTypes[0]) || null; }
  function stairClick(w) {
    freeMove(w); if (!target) return;
    if (!chain) { chain = {free: true, p: target.free, ref: 'tự do'}; return; }
    var a = chain.p, b = target.free;
    if (lengthOf(a, b) < 600) { note = 'Cầu thang tối thiểu 600 mm.'; return; }
    addStair(a, b); note = 'Đã thêm cầu thang dài ' + lengthOf(a, b) + ' mm (Ruby kiểm tra không đâm vào dầm, tường, cột).'; chain = null;
  }
  function addStair(a, b) {
    var id = A.rid('st_'), type = stairType(), pick = {free: {a: a.slice(), b: b.slice()}};
    if (type) pick.type = type.id;
    host.mutate(function () { lvl()[PICKS.stair][id] = pick; });
    return id;
  }
  // Dải bề rộng vế theo loại cầu thang đang dùng (xem trước trên mặt bằng).
  function stairFootprint(a, b) {
    var t = stairType(), width = t ? t.width : 1000, L = Math.hypot(b[0] - a[0], b[1] - a[1]);
    if (L < 1) return null;
    var ux = (b[0] - a[0]) / L, uy = (b[1] - a[1]) / L, nx = -uy * width / 2, ny = ux * width / 2;
    return [[a[0] + nx, a[1] + ny], [b[0] + nx, b[1] + ny], [b[0] - nx, b[1] - ny], [a[0] - nx, a[1] - ny]];
  }
  function freeClick(w) {
    if (tool === 'stair') { stairClick(w); return; }
    if (isPlate(tool)) { plateClick(w); return; }
    freeMove(w); if (!target) return;
    if (tool === 'column') { var id = addFreeColumn(target.free); note = 'Đã đặt cột tự do tại ' + target.free[0] + ', ' + target.free[1] + ' mm.'; return id; }
    if (!chain) { chain = {free: true, p: target.free, ref: 'tự do'}; return; }
    if (target.tooShort) { note = 'Đoạn quá ngắn (tối thiểu 100 mm).'; return; }
    var a = chain.p, b = target.free, label = tool === 'beam' ? 'dầm' : 'tường';
    addFreeLinear(tool, a, b); note = 'Đã thêm ' + label + ' tự do dài ' + lengthOf(a, b) + ' mm.'; chain = {free: true, p: b, ref: 'tự do'};
  }
  // Gõ số + Enter khi đang kéo dầm / tường tự do: đoạn dài đúng n mm theo hướng con trỏ.
  function typed(n, cursor) {
    if (!freeMode(tool) || tool === 'column' || isPlate(tool)) { note = 'Ô nhập số dùng khi vẽ dầm / tường TỰ DO (sau khi bấm điểm đầu).'; return false; }
    if (!chain) { note = 'Hãy bấm điểm đầu trước rồi gõ độ dài.'; return false; }
    if (n < 100) { note = 'Độ dài tối thiểu 100 mm.'; return false; }
    var c = cursor || chain.p, horizontal = Math.abs(c[0] - chain.p[0]) >= Math.abs(c[1] - chain.p[1]), sign = (horizontal ? c[0] - chain.p[0] : c[1] - chain.p[1]) >= 0 ? 1 : -1;
    var b = horizontal ? [r1(chain.p[0] + sign * n), chain.p[1]] : [chain.p[0], r1(chain.p[1] + sign * n)];
    if (opt[tool].angle === 'free') { var dx = c[0] - chain.p[0], dy = c[1] - chain.p[1], dl = Math.hypot(dx, dy) || 1; b = [r1(chain.p[0] + dx / dl * n), r1(chain.p[1] + dy / dl * n)]; } // xiên: đúng hướng con trỏ
    addFreeLinear(tool, chain.p, b); note = 'Đã thêm ' + (tool === 'beam' ? 'dầm' : 'tường') + ' tự do dài ' + n + ' mm.'; chain = {free: true, p: b, ref: 'tự do'};
    return true;
  }
  function activate(t) { tool = DESIGN.indexOf(t) >= 0 ? t : null; chain = null; ring = null; target = null; note = ''; }
  function cancel() { chain = null; ring = null; target = null; note = ''; }
  function busy() { return !!chain || !!(ring && ring.pts.length); }
  function handles(t) { return DESIGN.indexOf(t) >= 0; }

  function move(w) {
    target = null; if (!tool) return;
    if (blocked(tool)) return;
    if (freeMode(tool)) { freeMove(w); return; }
    if (tool === 'grid') { var s = host.snapPoint(w) || w; target = {pos: S && opt.grid.dir === 'x' ? Math.round(s[0]) : Math.round(s[1])}; return; }
    if (tool === 'column') { var n = nearestNode(w, TOL_COLUMN); if (n) target = {node: n, exists: !!lvl().picks[n.ref]}; return; }
    if (tool === 'beam' || tool === 'wall') {
      if (chain) { var e = chainEnd(w); if (e) target = {end: e, refs: spansBetween(chain, e)}; return; }
      var node = nearestNode(w, TOL_NODE); if (node) { target = {node: node}; return; }
      var sp = nearestSpan(w, TOL_SPAN); if (sp) target = {span: sp, exists: !!lvl()[PICKS[tool]][sp.ref]};
      return;
    }
    if (tool === 'slab' || tool === 'ceiling') { var c = cellAt(w); if (c) target = {cell: c, exists: !!lvl()[PICKS[tool]][c.ref]}; return; }
    if (tool === 'door' || tool === 'window') {
      var wall = wallAt(w), type = typeById(tool, currentType(tool));
      if (wall) { var pos = openingPos(wall, w); target = {wall: wall, type: type, pos: pos, flip: tool === 'door' ? sideOf(wall, w) < 0 : opt[tool].flip === '1', error: openingCheck(wall, type, pos)}; }
    }
  }

  function addPicks(container, refs, t) { // thêm các mục chưa có; trả về số mục thêm
    var l = lvl(), n = 0; refs.forEach(function (ref) { if (!l[container][ref]) { l[container][ref] = newPick(t); n++; } }); return n;
  }
  function click(w) {
    note = ''; if (!tool) return;
    var why = blocked(tool); if (why) { note = why; return; }
    if (freeMode(tool)) { freeClick(w); return; }
    move(w);
    if (tool === 'grid') {
      if (!target) return;
      var err = A.addAxis(opt.grid.dir, target.pos);
      if (err) { note = err; return; }
      host.mutate(function () { A.addAxis(opt.grid.dir, target.pos, true); }); note = 'Đã thêm trục ' + (opt.grid.dir === 'x' ? 'đứng' : 'ngang') + ' tại ' + target.pos + ' mm.';
      return;
    }
    if (!target) return;
    if (tool === 'column') {
      if (target.exists) { note = 'Cột ' + target.node.ref + ' đã có.'; return; }
      host.mutate(function () { addPicks('picks', [target.node.ref], 'column'); }); note = 'Đã thêm cột ' + target.node.ref + '.'; return;
    }
    if (tool === 'beam' || tool === 'wall') {
      var label = tool === 'beam' ? 'dầm' : 'tường', box = PICKS[tool];
      if (target.span) { if (target.exists) { note = 'Nhịp này đã có ' + label + '.'; return; } host.mutate(function () { addPicks(box, [target.span.ref], tool); }); note = 'Đã thêm ' + label + ' ' + target.span.ref + '.'; return; }
      if (target.node && !chain) { chain = target.node; return; }
      if (target.end) {
        var refs = target.refs, count = 0; host.mutate(function () { count = addPicks(box, refs, tool); });
        note = count ? 'Đã thêm ' + count + ' ' + label + (count < refs.length ? ' (' + (refs.length - count) + ' nhịp đã có)' : '') + '.' : 'Các nhịp này đã có ' + label + '.';
        chain = target.end; target = null; return;
      }
      return;
    }
    if (tool === 'slab' || tool === 'ceiling') {
      var name = tool === 'slab' ? 'sàn' : 'trần';
      if (target.exists) { note = 'Ô ' + target.cell.ref + ' đã có ' + name + '.'; return; }
      host.mutate(function () { addPicks(PICKS[tool], [target.cell.ref], tool); }); note = 'Đã thêm ' + name + ' ' + target.cell.ref + '.'; return;
    }
    if (tool === 'door' || tool === 'window') {
      if (target.error) { note = target.error; return; }
      var id = A.rid('op_');
      host.mutate(function () { lvl().openingPicks[id] = {wall: target.wall.ref, type: target.type.id, pos: target.pos + (target.wall.join_shift || 0), flip: !!target.flip}; if (tool === 'door' && opt.door.hand === '1') lvl().openingPicks[id].mirror = true; });
      note = 'Đã đặt ' + (tool === 'door' ? 'cửa đi' : 'cửa sổ') + ' ' + target.type.name + ' trên tường ' + target.wall.ref + ', tâm cách đầu tường ' + target.pos + ' mm.';
    }
  }

  function hint() {
    if (!tool) return '';
    if (note) return note;
    var why = blocked(tool); if (why) return why;
    if (freeMode(tool)) {
      if (tool === 'stair') return chain ? 'Cầu thang: bấm đỉnh vế (tối thiểu 600 mm). Esc hủy.' : 'Cầu thang: bấm đáy vế (điểm đầu).';
      if (isPlate(tool)) {
        var pn = tool === 'slab' ? 'Sàn' : 'Trần';
        if (!ring) return pn + ' đa giác: bấm từng đỉnh của ' + (opt[tool].part === 'hole' ? 'LỖ (đỉnh đầu nằm trong một ' + pn.toLowerCase() + ' đa giác)' : 'đường bao') + '; bấm lại đỉnh đầu hoặc Enter để khép; Backspace bỏ đỉnh cuối; Esc hủy.';
        return pn + ' đa giác: ' + ring.pts.length + ' đỉnh' + (target && target.close ? ' (bấm để KHÉP vòng)' : '') + '. Enter khép vòng, Backspace bỏ đỉnh cuối, Esc hủy.';
      }
      if (tool === 'column') return target && target.free ? 'Bấm để đặt cột tự do tại ' + target.free[0] + ', ' + target.free[1] + ' mm (bắt điểm đang bật). Esc kết thúc.' : 'Cột tự do: bấm một điểm bất kỳ. Esc kết thúc.';
      var nm = tool === 'beam' ? 'Dầm' : 'Tường';
      if (!chain) return nm + ' tự do: bấm điểm đầu (bắt điểm). Esc kết thúc.';
      return nm + ' tự do: bấm điểm cuối ' + (opt[tool].angle === 'free' ? '(góc bất kỳ)' : '(tự giữ ngang / dọc)') + '' + (target && target.end ? ', dài ' + lengthOf(chain.p, target.free) + ' mm' : '') + ' hoặc gõ độ dài + Enter; bấm tiếp để nối chuỗi. Esc kết thúc.';
    }
    if (tool === 'grid') return 'Trục mới: bấm vị trí (bắt được đường gióng và điểm). Chọn trục đứng / ngang ở thanh tùy chọn. Esc kết thúc.';
    if (tool === 'column') return target ? (target.exists ? 'Cột ' + target.node.ref + ' đã có.' : 'Bấm để đặt cột ' + target.node.ref + '.') : 'Cột: bấm một giao điểm của lưới. Esc kết thúc.';
    if (tool === 'beam' || tool === 'wall') {
      var label = tool === 'beam' ? 'Dầm' : 'Tường';
      if (chain) return label + ': bấm điểm cuối (cùng hàng hoặc cùng cột với ' + chain.ref + '); bấm tiếp để nối chuỗi; Esc kết thúc.';
      return label + ': bấm điểm đầu (giao điểm) rồi điểm cuối, hoặc bấm thẳng một nhịp. Esc kết thúc.';
    }
    if (tool === 'slab' || tool === 'ceiling') return 'Bấm vào một ô của lưới để đặt ' + (tool === 'slab' ? 'sàn' : 'trần') + '. Esc kết thúc.';
    if (target) return target.error || 'Bấm để đặt ' + (tool === 'door' ? 'cửa đi' : 'cửa sổ') + ' ' + (target.type ? target.type.name : '') + ', tâm cách đầu tường ' + target.pos + ' mm.';
    return (tool === 'door' ? 'Cửa đi' : 'Cửa sổ') + ': rê lên một tường đã chọn (tab Tường hoặc công cụ Tường) rồi bấm.';
  }

  // Hình xem trước theo tọa độ thế giới.
  // Kích thước loại đang vẽ (dầm, tường) kèm theo mục xem trước để cửa sổ mặt bằng dựng khối 3D trong khung nhìn SketchUp.
  function solid(g, tool) {
    if (tool !== 'beam' && tool !== 'wall') return g;
    var ty = typeById(tool, currentType(tool) || (tool === 'beam' ? lvl().beamType : lvl().wallType)) || typesFor(tool)[0];
    if (ty) { g.thick = tool === 'wall' ? ty.t : ty.w; if (tool === 'beam') g.h = ty.h; }
    return g;
  }
  function ghost() {
    var g = [];
    if (tool && freeMode(tool) && !blocked(tool)) {
      if (isPlate(tool)) {
        var pts = (ring ? ring.pts : []).slice();
        if (target && target.free && !target.close) pts.push(target.free);
        if (pts.length >= 3) g.push({t: 'poly', poly: pts, color: GOOD, alpha: 0.18, xray: tool === 'slab'});
        for (var q = 0; q + 1 < pts.length; q++) g.push({t: 'line', a: pts[q], b: pts[q + 1], color: GOOD, width: 3});
        if (target && target.close && ring) g.push({t: 'line', a: ring.pts[ring.pts.length - 1], b: ring.pts[0], color: GOOD, width: 3});
        (ring ? ring.pts : []).forEach(function (pp) { g.push({t: 'dot', p: pp, color: GOOD, r: 4}); });
        if (target && target.free) g.push({t: 'dot', p: target.free, color: target.close ? '#2FA84F' : GOOD, r: target.close ? 7 : 5});
        return g;
      }
      if (tool === 'column') {
        if (target && target.free) { var ty = typeById('column', currentType('column')) || S.types[0], c = target.free;
          g.push({t: 'poly', poly: rotRect(c, ty.w, ty.d, Number(opt.column.rot) || 0), color: GOOD, alpha: 0.3}); g.push({t: 'dot', p: c, color: GOOD, r: 5}); }
        return g;
      }
      if (tool === 'stair' && chain && target && target.free) { var fp = stairFootprint(chain.p, target.free); if (fp) g.push({t: 'poly', poly: fp, color: GOOD, alpha: 0.2}); }
      if (chain) { g.push({t: 'dot', p: chain.p, color: GOOD, r: 5}); }
      if (target && target.free) {
        if (chain) { g.push(solid({t: 'line', a: chain.p, b: target.free, color: target.tooShort ? BAD : GOOD, width: 5, alpha: 0.5}, tool)); if (target.end) g.push({t: 'text', p: target.free, text: lengthOf(chain.p, target.free) + ' mm'}); }
        g.push({t: 'dot', p: target.free, color: target.tooShort ? BAD : GOOD, r: 5});
      }
      return g;
    }
    if (!tool || !target || blocked(tool)) return g;
    if (tool === 'grid') {
      var b = host.bounds(), pos = target.pos, dirx = opt.grid.dir === 'x';
      g.push(dirx ? {t: 'line', a: [pos, b[1] - 600], b: [pos, b[3] + 600], color: GOOD, dash: [8, 4]} : {t: 'line', a: [b[0] - 600, pos], b: [b[2] + 600, pos], color: GOOD, dash: [8, 4]});
      g.push({t: 'text', p: dirx ? [pos, b[3] + 600] : [b[2] + 600, pos], text: pos + ' mm'});
    } else if (tool === 'column') {
      var ty = typeById('column', currentType('column')) || S.types[0], n = target.node;
      g.push({t: 'poly', poly: [[n.x - ty.w / 2, n.y - ty.d / 2], [n.x + ty.w / 2, n.y - ty.d / 2], [n.x + ty.w / 2, n.y + ty.d / 2], [n.x - ty.w / 2, n.y + ty.d / 2]], color: target.exists ? BAD : GOOD, alpha: 0.25});
      g.push({t: 'dot', p: [n.x, n.y], color: target.exists ? BAD : GOOD, r: 5}); g.push({t: 'text', p: [n.x, n.y], text: 'Cột ' + n.ref});
    } else if (tool === 'beam' || tool === 'wall') {
      if (chain) g.push({t: 'dot', p: [chain.x, chain.y], color: GOOD, r: 5});
      if (target.end) { g.push(solid({t: 'line', a: [chain.x, chain.y], b: [target.end.x, target.end.y], color: GOOD, width: 5, alpha: 0.5}, tool)); g.push({t: 'dot', p: [target.end.x, target.end.y], color: GOOD, r: 5}); g.push({t: 'text', p: [target.end.x, target.end.y], text: target.refs.length + ' nhịp'}); }
      else if (target.node) g.push({t: 'dot', p: [target.node.x, target.node.y], color: GOOD, r: 6});
      else if (target.span) { var sp = target.span; g.push(solid({t: 'line', a: sp.dir === 'x' ? [sp.a, sp.axis] : [sp.axis, sp.a], b: sp.dir === 'x' ? [sp.b, sp.axis] : [sp.axis, sp.b], color: target.exists ? BAD : GOOD, width: 5, alpha: 0.5}, tool)); }
    } else if (tool === 'slab' || tool === 'ceiling') {
      var c = target.cell, key = tool + 's', real, sec = S.preview && S.preview[key];
      // Hình THỰC TẾ sẽ dựng (lùi theo dầm, cột, tường): ô đã chọn lấy từ kết quả xem trước; ô chưa chọn nhờ Ruby tính (có thể chưa kịp: tạm hiện cả ô nét đứt).
      if (target.exists) { var it = sec && sec.items.filter(function (x) { return x.ref === c.ref; })[0]; real = it && it.polygon; }
      else if (host.probe) real = host.probe(key, lvl().id, c.ref);
      var full = [[c.x0, c.y0], [c.x1, c.y0], [c.x1, c.y1], [c.x0, c.y1]], unknown = !real && real !== false;
      g.push({t: 'poly', poly: real || full, color: target.exists || real === false ? BAD : GOOD, alpha: unknown ? 0.08 : 0.2, dash: unknown ? [6, 4] : undefined, xray: tool === 'slab'});
    } else if (target.wall && target.type) {
      var wl = target.wall, along = wl.start + target.pos - target.type.w / 2, h = wl.dir === 'x';
      if (wl.dir === 'o') {
        var ux = (wl.b[0] - wl.a[0]) / wl.length, uy = (wl.b[1] - wl.a[1]) / wl.length, u0 = target.pos - target.type.w / 2, u1 = target.pos + target.type.w / 2, hv = wl.t / 2;
        var at = function (u, v) { return [wl.a[0] + ux * u - uy * v, wl.a[1] + uy * u + ux * v]; };
        g.push({t: 'poly', poly: [at(u0, -hv), at(u1, -hv), at(u1, hv), at(u0, hv)], color: target.error ? BAD : GOOD, alpha: 0.35});
        if (tool === 'door') g = g.concat(swingGhost(wl, target.type, target.pos, target.flip, opt.door.hand === '1', target.error ? BAD : GOOD));
        return g;
      }
      var min = h ? [along, wl.min[1]] : [wl.min[0], along], max = h ? [along + target.type.w, wl.max[1]] : [wl.max[0], along + target.type.w];
      g.push({t: 'poly', poly: [[min[0], min[1]], [max[0], min[1]], [max[0], max[1]], [min[0], max[1]]], color: target.error ? BAD : GOOD, alpha: 0.35});
      if (tool === 'door') g = g.concat(swingGhost(wl, target.type, target.pos, target.flip, opt.door.hand === '1', target.error ? BAD : GOOD));
    }
    return g;
  }

  // ---- Xóa ----
  function remove(shapes) {
    var l = lvl(), hits = shapes.filter(function (s) { return PICKS[s.kind] && l[PICKS[s.kind]][s.ref]; });
    if (!hits.length) return 0;
    host.mutate(function () {
      hits.forEach(function (s) {
        delete l[PICKS[s.kind]][s.ref];
        if (s.kind === 'wall') Object.keys(l.openingPicks).forEach(function (id) { if (l.openingPicks[id].wall === s.ref) delete l.openingPicks[id]; }); // cửa không còn tường thì bỏ theo
      });
    });
    return hits.length;
  }

  // ---- Thuộc tính của phần tử đang chọn (sửa ngay, như bảng Properties của Revit) ----
  function field(id, label, kind, values, value, apply) { return {id: id, label: label, kind: kind, values: values, value: value, apply: apply}; }
  function edit(fn) { host.mutate(fn); }
  // Thuộc tính của phần tử TỰ DO: tọa độ nhập trực tiếp (mm). Giá trị sai (đoạn ngắn hơn 100 mm, đầu 'từ' >= đầu 'đến') thì không áp dụng và báo.
  // Sàn, trần đa giác: nhập từng đỉnh (tối đa 12 đỉnh); nhiều đỉnh hơn thì dùng Move / Rotate / Mirror hoặc vẽ lại.
  function plateProps(pick) {
    var f = pick.free, out = [];
    if (f.poly.length > 12) return out;
    f.poly.forEach(function (p, i) {
      [0, 1].forEach(function (k) {
        out.push(field('v' + i + (k ? 'y' : 'x'), 'Đỉnh ' + (i + 1) + ' · ' + (k ? 'Y' : 'X') + ' (mm)', 'number', null, p[k], function (v) {
          if (!isFinite(v)) return;
          var poly = f.poly.map(function (q) { return q.slice(); }); poly[i][k] = r1(v);
          var why = ringProblem(poly, null); if (why) { host.say(why); return; }
          if ((f.holes || []).some(function (h) { return ringProblem(h, poly, []); })) { host.say('Lỗ sẽ ra ngoài đường bao.'); return; }
          edit(function () { pick.free = {poly: poly, holes: f.holes || []}; });
        }));
      });
    });
    return out;
  }
  function freeProps(shape, pick, setType) {
    var f = pick.free, kind = shape.kind;
    if (kind === 'slab' || kind === 'ceiling') return plateProps(pick);
    var out = [field('type', 'Loại', 'select', typeValues(kind), pick.type || '', setType)];
    function setFree(next) { edit(function () { pick.free = next; }); }
    if (kind === 'column') {
      return out.concat([field('x', 'X tâm (mm)', 'number', null, f.x, function (v) { if (isFinite(v)) setFree({x: r1(v), y: f.y, rot: f.rot}); }),
                         field('y', 'Y tâm (mm)', 'number', null, f.y, function (v) { if (isFinite(v)) setFree({x: f.x, y: r1(v), rot: f.rot}); }),
                         field('rot', 'Xoay (độ)', 'number', null, f.rot || 0, function (v) { if (isFinite(v) && Math.abs(v) <= 360) setFree({x: f.x, y: f.y, rot: v}); })]);
    }
    if (f.a[0] !== f.b[0] && f.a[1] !== f.b[1]) { // dầm / tường xiên: nhập từng đầu mút
      function putEnd(which, axis, v) {
        if (!isFinite(v)) return; var a = f.a.slice(), b = f.b.slice(), t = which === 'a' ? a : b; t[axis] = r1(v);
        if (Math.hypot(b[0] - a[0], b[1] - a[1]) < 100) { host.say('Đoạn phải dài ít nhất 100 mm.'); return; }
        setFree(b[0] < a[0] ? {a: b, b: a} : {a: a, b: b}); // đầu a luôn là đầu bên trái
      }
      return out.concat([field('ax', 'Đầu 1 · X (mm)', 'number', null, f.a[0], function (v) { putEnd('a', 0, v); }), field('ay', 'Đầu 1 · Y (mm)', 'number', null, f.a[1], function (v) { putEnd('a', 1, v); }),
                         field('bx', 'Đầu 2 · X (mm)', 'number', null, f.b[0], function (v) { putEnd('b', 0, v); }), field('by', 'Đầu 2 · Y (mm)', 'number', null, f.b[1], function (v) { putEnd('b', 1, v); })]);
    }
    var h = f.a[1] === f.b[1], key = h ? 0 : 1, cross = h ? 1 : 0;
    function put(valueKey, v) { // valueKey: 'tim' | 'from' | 'to'
      if (!isFinite(v)) return; v = r1(v);
      var a = f.a.slice(), b = f.b.slice();
      if (valueKey === 'tim') { a[cross] = v; b[cross] = v; } else if (valueKey === 'from') a[key] = v; else b[key] = v;
      if (b[key] - a[key] < 100) { host.say('Đoạn phải dài ít nhất 100 mm và đầu "Đến" lớn hơn đầu "Từ".'); return; }
      setFree({a: a, b: b});
    }
    return out.concat([field('tim', h ? 'Tim Y (mm)' : 'Tim X (mm)', 'number', null, f.a[cross], function (v) { put('tim', v); }),
                       field('from', h ? 'Từ X (mm)' : 'Từ Y (mm)', 'number', null, f.a[key], function (v) { put('from', v); }),
                       field('to', h ? 'Đến X (mm)' : 'Đến Y (mm)', 'number', null, f.b[key], function (v) { put('to', v); })]);
  }
  function propsOwn(shape) {
    var l = lvl(), pick = PICKS[shape.kind] && l[PICKS[shape.kind]][shape.ref], out = [];
    if (!pick) return out;
    function setMode(key) { return function (v) { edit(function () { if (v === 'auto') delete pick[key]; else pick[key] = v; }); }; }
    function setType(v) { edit(function () { if (v) pick.type = v; else delete pick.type; }); }
    if (pick.free) return freeProps(shape, pick, setType);
    if (shape.kind === 'column') out.push(field('type', 'Loại', 'select', typeValues('column'), pick.type || '', setType), field('x', 'Vị trí X', 'select', modeList('x'), pick.x || 'auto', setMode('x')), field('y', 'Vị trí Y', 'select', modeList('y'), pick.y || 'auto', setMode('y')));
    if (shape.kind === 'beam') out.push(field('type', 'Loại', 'select', typeValues('beam'), pick.type || '', setType), field('p', 'Vị trí ngang', 'select', modeList('p'), pick.p || 'auto', setMode('p')));
    if (shape.kind === 'wall') out.push(field('type', 'Loại', 'select', typeValues('wall'), pick.type || '', setType), field('p', 'Vị trí ngang', 'select', modeList('p'), pick.p || 'auto', setMode('p')));
    if (shape.kind === 'opening') {
      var kind = (typeById('door', pick.type) ? 'door' : 'window');
      out.push(field('type', 'Loại', 'select', typeValues(kind), pick.type, function (v) { edit(function () { pick.type = v; }); }),
               field('pos', 'Tâm cách đầu tường (mm)', 'number', null, pick.pos, function (v) { if (isFinite(v)) edit(function () { pick.pos = v; }); }),
               field('flip', kind === 'door' ? 'Đổi hướng mở (sang phía kia của tường)' : 'Đổi mặt cánh', 'checkbox', null, !!pick.flip, function (v) { edit(function () { pick.flip = !!v; }); }));
      if (kind === 'door') out.push(field('mirror', 'Bản lề ở cuối cửa (trái ↔ phải)', 'checkbox', null, !!pick.mirror, function (v) { edit(function () { if (v) pick.mirror = true; else delete pick.mirror; }); }));
    }
    return out;
  }

  // ---- Thuộc tính của LOẠI (Type Properties, như Revit): sửa kích thước loại của phần tử đang chọn; đổi thì mọi phần tử cùng loại đổi theo ----
  var TYPE_SPECS = {
    column: {list: function () { return S.types; }, label: 'cột', fields: [['w', 'Rộng (mm)', 100, 3000], ['d', 'Sâu (mm)', 100, 3000]]},
    beam: {list: function () { return S.beamTypes; }, label: 'dầm', fields: [['w', 'Rộng (mm)', 100, 1500], ['h', 'Cao (mm)', 100, 2000]]},
    wall: {list: function () { return S.wallTypes; }, label: 'tường', fields: [['t', 'Bề dày (mm)', 50, 1000]]},
    opening: {list: function () { return S.openingTypes; }, label: 'cửa', fields: [['w', 'Rộng (mm)', 300, 5000], ['h', 'Cao (mm)', 300, 4000], ['sill', 'Cao ngưỡng (mm)', 0, 3000]]}
  };
  var USERS = [['column', 'picks'], ['beam', 'beamPicks'], ['wall', 'wallPicks'], ['opening', 'openingPicks']];
  function typeUsage(kind, id) { // số phần tử (mọi tầng) dùng loại này và số tầng có dùng
    var n = 0, floors = 0;
    S.levels.forEach(function (l) {
      var here = 0, box = l[USERS.filter(function (u) { return u[0] === kind; })[0][1]] || {};
      Object.keys(box).forEach(function (ref) {
        var t = kind === 'opening' ? box[ref].type : window.VGDPlanBrowser.effectiveType(kind, l, box[ref]);
        if (t === id) here++;
      });
      n += here; if (here) floors++;
    });
    return [n, floors];
  }
  // Type Selector kiểu Revit (ô chọn loại ở đầu bảng Thuộc tính): đổi loại của phần tử đang chọn, nhân đôi loại. null nếu phần tử không có loại.
  var TYPE_PREFIX = {column: 'ct_', beam: 'bt_', wall: 'wt_', opening: 'ot_'}, TYPE_MAX = 50, NAME_MAX = 20;
  function typeSelector(shape) {
    var spec = TYPE_SPECS[shape.kind], l = lvl(), box = PICKS[shape.kind] && l[PICKS[shape.kind]], pick = box && box[shape.ref];
    if (!spec || !pick) return null;
    var id = shape.kind === 'opening' ? pick.type : window.VGDPlanBrowser.effectiveType(shape.kind, l, pick), list = spec.list(), type = list.filter(function (t) { return t.id === id; })[0];
    if (!type) return null;
    var sameKind = function (t) { return shape.kind !== 'opening' || t.kind === type.kind; };
    var label = function (t) { return t.name + (shape.kind === 'column' ? ' (' + t.w + '×' + t.d + ')' : shape.kind === 'beam' ? ' (' + t.w + '×' + t.h + ')' : shape.kind === 'wall' ? ' (dày ' + t.t + ')' : ' (' + t.w + '×' + t.h + ')'); };
    return {
      value: id, values: list.filter(sameKind).map(function (t) { return [t.id, label(t)]; }),
      apply: function (v) { if (v !== id) edit(function () { pick.type = v; }); },
      canDuplicate: list.length < TYPE_MAX,
      duplicate: function () {
        if (list.length >= TYPE_MAX) { host.say('Tối đa ' + TYPE_MAX + ' loại.'); return; }
        var names = list.map(function (t) { return t.name.toLowerCase(); }), n = 2, name, base = type.name.replace(/ \(\d+\)$/, ''); // nhân đôi một bản sao thì đánh số tiếp, không chồng thêm hậu tố
        do { var suffix = ' (' + n + ')'; name = base.slice(0, NAME_MAX - suffix.length) + suffix; n++; } while (names.indexOf(name.toLowerCase()) >= 0);
        var copy = JSON.parse(JSON.stringify(type)); copy.id = A.rid(TYPE_PREFIX[shape.kind]); copy.name = name;
        edit(function () { list.push(copy); pick.type = copy.id; });
        host.say('Đã nhân đôi loại thành “' + name + '” và gán cho phần tử này; sửa kích thước ở mục Thuộc tính của loại.');
      }
    };
  }
  function typeFields(shape, pick) {
    var spec = TYPE_SPECS[shape.kind]; if (!spec || !pick) return [];
    var id = shape.kind === 'opening' ? pick.type : window.VGDPlanBrowser.effectiveType(shape.kind, lvl(), pick), type = spec.list().filter(function (t) { return t.id === id; })[0];
    if (!type) return [];
    var use = typeUsage(shape.kind, id), out = [{kind: 'heading', label: 'Thuộc tính của loại “' + type.name + '”'}];
    out.push({kind: 'info', label: 'Đổi ở đây áp dụng cho ' + use[0] + ' ' + spec.label + ' (' + use[1] + ' tầng) dùng loại này.'});
    out.push(field('type_name', 'Tên loại', 'text', null, type.name, function (v) {
      v = String(v).trim();
      if (!v || v.length > 20 || /[\u0000-\u001f\u007f]/.test(v)) { host.say('Tên loại từ 1 đến 20 ký tự.'); return; }
      if (spec.list().some(function (t) { return t.id !== type.id && t.name.toLowerCase() === v.toLowerCase(); })) { host.say('Tên loại “' + v + '” đã có.'); return; }
      edit(function () { type.name = v; });
    }));
    if (shape.kind === 'wall') { // tường: bề dày là tổng các lớp; sửa từng lớp ở đây (thêm, xóa, đổi chức năng và màu ở tab Tường)
      var layers = type.layers && type.layers.length ? type.layers : [{fn: 'structure', t: type.t, material: ''}], names = {structure: 'Kết cấu', substrate: 'Lớp nền', insulation: 'Cách nhiệt', finish: 'Hoàn thiện'};
      out.push({kind: 'info', label: 'Tổng bề dày ' + type.t + ' mm (' + layers.length + ' lớp). Thêm, xóa lớp, đổi chức năng và màu ở tab Tường.'});
      layers.forEach(function (l, i) {
        out.push(field('layer_t' + i, 'Lớp ' + (i + 1) + ' · ' + names[l.fn] + ' · dày (mm)', 'number', null, l.t, function (v) {
          var total = layers.reduce(function (a, x, k) { return a + (k === i ? v : x.t); }, 0);
          if (!isFinite(v) || v < 1 || v > 1000 || total < 50 || total > 1000) { host.say('Bề dày lớp từ 1 đến 1000 mm và tổng các lớp từ 50 đến 1000 mm.'); return; }
          edit(function () { if (!type.layers) type.layers = layers; layers[i].t = r1(v); type.t = r1(layers.reduce(function (a, x) { return a + x.t; }, 0)); });
        }));
        out.push(field('layer_m' + i, 'Lớp ' + (i + 1) + ' · vật liệu', 'text', null, l.material || '', function (v) {
          v = String(v).trim();
          if (v.length > 24 || /[\u0000-\u001f\u007f]/.test(v)) { host.say('Tên vật liệu tối đa 24 ký tự.'); return; }
          edit(function () { if (!type.layers) type.layers = layers; layers[i].material = v; });
        }));
      });
      return out;
    }
    spec.fields.forEach(function (f) {
      out.push(field('type_' + f[0], f[1], 'number', null, type[f[0]], function (v) {
        if (!isFinite(v) || v < f[2] || v > f[3]) { host.say(f[1].replace(' (mm)', '') + ' của loại phải từ ' + f[2] + ' đến ' + f[3] + ' mm.'); return; }
        edit(function () { type[f[0]] = r1(v); });
      }));
    });
    return out;
  }
  function joinField(pick) { // nối góc tự động của tường (mặc định bật; tắt thì tường giữ đúng hình nhập)
    return field('join', 'Nối góc tự động', 'checkbox', null, pick.join !== false, function (v) { edit(function () { if (v) delete pick.join; else pick.join = false; }); });
  }
  function propsFor(shape) {
    var own = propsOwn(shape), l = lvl(), box = PICKS[shape.kind] && l[PICKS[shape.kind]], pick = box && box[shape.ref];
    if (shape.kind === 'wall' && pick) own = own.concat([joinField(pick)]);
    return own.concat(typeFields(shape, pick));
  }

  window.VGDPlanEdit = {
    init: function (h) { host = h; S = h.state; A = h.api; },
    handles: handles, activate: activate, cancel: cancel, busy: busy, options: options, setOption: setOption, freeMode: freeMode, typed: typed, finish: finish, undoPoint: undoPoint,
    typeSelector: typeSelector, flipDoor: flipDoor, move: move, click: click, hint: hint, ghost: ghost, remove: remove, propsFor: propsFor,
    debug: function () { return {tool: tool, chain: chain && chain.ref, chainPoint: chain && chain.p, freeTarget: target && target.free, target: target && {ref: target.node && target.node.ref, end: target.end && target.end.ref, refs: target.refs, span: target.span && target.span.ref, cell: target.cell && target.cell.ref, exists: target.exists, error: target.error, pos: target.pos}, note: note, opt: JSON.parse(JSON.stringify(opt))}; }
  };
})();
