// Công cụ vẽ kết cấu trên tab Mặt bằng (cột mốc P3): bấm điểm trên lưới thì ghi vào lựa chọn của tầng (cùng dữ liệu với các tab Cột, Dầm, Tường, Cửa, Sàn, Trần).
// Mọi thay đổi đi qua host.mutate (có hoàn tác); Ruby vẫn kiểm tra lại và tính xem trước. Chỉ gom dữ liệu, không tự dựng hình trong SketchUp.
(function () {
  'use strict';
  var host = null, S = null, A = null;
  var GOOD = '#2F7BFF', BAD = '#E5484D', TOL_NODE = 14, TOL_COLUMN = 28, TOL_SPAN = 12, OPENING_GAP = 50;
  var DESIGN = ['grid', 'column', 'beam', 'wall', 'slab', 'ceiling', 'door', 'window'];
  var PICKS = {column: 'picks', beam: 'beamPicks', wall: 'wallPicks', slab: 'slabPicks', ceiling: 'ceilingPicks', opening: 'openingPicks'};
  var opt = {column: {type: '', x: 'auto', y: 'auto', mode: 'grid', rot: '0'}, beam: {type: '', p: 'auto', mode: 'grid'}, wall: {type: '', p: 'auto', mode: 'grid'}, door: {type: '', flip: '0'}, window: {type: '', flip: '0'}, grid: {dir: 'x'}};
  var tool = null, chain = null, target = null, note = '';

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
    if (!opt[tool]) return ''; // sàn, trần không có loại
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
  function freeMode(t) { return !!(opt[t] && opt[t].mode === 'free' && (t === 'column' || t === 'beam' || t === 'wall')); }
  function r1(v) { return Math.round(v * 10) / 10; }
  function options(t) {
    if (freeMode(t)) {
      var head = [{id: 'mode', label: 'Vị trí', values: MODE_VALUES, value: 'free'}, {id: 'type', label: 'Loại', values: typeValues(t), value: currentType(t)}];
      return t === 'column' ? head.concat([{id: 'rot', label: 'Xoay', values: [['0', '0°'], ['90', '90° (đổi rộng và sâu)']], value: opt.column.rot}]) : head;
    }
    if (t === 'column' || t === 'beam' || t === 'wall') { var m = {id: 'mode', label: 'Vị trí', values: MODE_VALUES, value: 'grid'}, rest = optionsGrid(t); return [m].concat(rest); }
    return optionsGrid(t);
  }
  function optionsGrid(t) {
    if (t === 'column') return [{id: 'type', label: 'Loại', values: typeValues(t), value: currentType(t)}, {id: 'x', label: 'Vị trí X', values: modeList('x'), value: opt.column.x}, {id: 'y', label: 'Vị trí Y', values: modeList('y'), value: opt.column.y}];
    if (t === 'beam' || t === 'wall') return [{id: 'type', label: 'Loại', values: typeValues(t), value: currentType(t)}, {id: 'p', label: 'Vị trí ngang', values: modeList('p'), value: opt[t].p}];
    if (t === 'door' || t === 'window') return [{id: 'type', label: 'Loại', values: typeValues(t), value: currentType(t)}, {id: 'flip', label: 'Cánh', values: [['0', 'Mặc định'], ['1', 'Đổi mặt']], value: opt[t].flip}];
    if (t === 'grid') return [{id: 'dir', label: 'Loại trục', values: [['x', 'Trục đứng (đánh số)'], ['y', 'Trục ngang (đánh chữ)']], value: opt.grid.dir}];
    return [];
  }
  function setOption(t, id, value) { if (opt[t]) opt[t][id] = value; }

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
    if (top()) return t === 'ceiling' ? 'Tầng trên cùng chỉ có sàn, không có trần.' : 'Tầng trên cùng chỉ có sàn (không có cột, dầm, tường, cửa).';
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
    ((S.preview && S.preview.walls && S.preview.walls.items) || []).forEach(function (it) { if (w[0] >= it.min[0] - e && w[0] <= it.max[0] + e && w[1] >= it.min[1] - e && w[1] <= it.max[1] + e) best = it; });
    return best;
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
  function openingPos(wall, w) { var along = (wall.dir === 'x' ? w[0] : w[1]) - wall.start; return Math.round(along / 10) * 10; }

  // ---- Vẽ TỰ DO (P4b-1): cột đặt tại điểm bất kỳ; dầm, tường chỉ ngang / dọc, đầu mút đúng điểm bấm ----
  function freePoint(w) { var s2 = host.snapPoint(w) || w; return [r1(s2[0]), r1(s2[1])]; }
  function orthoEnd(from, w) { // điểm cuối cùng hàng hoặc cùng cột với điểm đầu (theo phương con trỏ lệch nhiều hơn)
    var p = freePoint(w), horizontal = Math.abs(p[0] - from[0]) >= Math.abs(p[1] - from[1]);
    return horizontal ? [p[0], from[1]] : [from[0], p[1]];
  }
  function lengthOf(a, b) { return Math.abs(b[0] - a[0]) + Math.abs(b[1] - a[1]); }
  function addFreeColumn(p) {
    var id = A.rid('fc_'), type = currentType('column'), pick = {free: {x: p[0], y: p[1], rot: Number(opt.column.rot) || 0}};
    if (type) pick.type = type;
    host.mutate(function () { lvl().picks[id] = pick; });
    return id;
  }
  function addFreeLinear(t, a, b) {
    if ((b[0] - a[0]) + (b[1] - a[1]) < 0) { var sw = a; a = b; b = sw; } // đầu a luôn là đầu có tọa độ nhỏ hơn (cùng quy ước với Ruby)
    var id = A.rid(t === 'beam' ? 'fb_' : 'fw_'), type = currentType(t), pick = {free: {a: a.slice(), b: b.slice()}};
    if (type) pick.type = type;
    host.mutate(function () { lvl()[PICKS[t]][id] = pick; });
    return id;
  }
  function freeMove(w) {
    if (tool === 'column') { target = {free: freePoint(w)}; return; }
    if (!chain) { target = {free: freePoint(w), start: true}; return; }
    var end = orthoEnd(chain.p, w); target = lengthOf(chain.p, end) >= 100 ? {free: end, end: true} : {free: end, tooShort: true};
  }
  function freeClick(w) {
    freeMove(w); if (!target) return;
    if (tool === 'column') { var id = addFreeColumn(target.free); note = 'Đã đặt cột tự do tại ' + target.free[0] + ', ' + target.free[1] + ' mm.'; return id; }
    if (!chain) { chain = {free: true, p: target.free, ref: 'tự do'}; return; }
    if (target.tooShort) { note = 'Đoạn quá ngắn (tối thiểu 100 mm).'; return; }
    var a = chain.p, b = target.free, label = tool === 'beam' ? 'dầm' : 'tường';
    addFreeLinear(tool, a, b); note = 'Đã thêm ' + label + ' tự do dài ' + lengthOf(a, b) + ' mm.'; chain = {free: true, p: b, ref: 'tự do'};
  }
  // Gõ số + Enter khi đang kéo dầm / tường tự do: đoạn dài đúng n mm theo hướng con trỏ.
  function typed(n, cursor) {
    if (!freeMode(tool) || tool === 'column') { note = 'Ô nhập số dùng khi vẽ dầm / tường TỰ DO (sau khi bấm điểm đầu).'; return false; }
    if (!chain) { note = 'Hãy bấm điểm đầu trước rồi gõ độ dài.'; return false; }
    if (n < 100) { note = 'Độ dài tối thiểu 100 mm.'; return false; }
    var c = cursor || chain.p, horizontal = Math.abs(c[0] - chain.p[0]) >= Math.abs(c[1] - chain.p[1]), sign = (horizontal ? c[0] - chain.p[0] : c[1] - chain.p[1]) >= 0 ? 1 : -1;
    var b = horizontal ? [r1(chain.p[0] + sign * n), chain.p[1]] : [chain.p[0], r1(chain.p[1] + sign * n)];
    addFreeLinear(tool, chain.p, b); note = 'Đã thêm ' + (tool === 'beam' ? 'dầm' : 'tường') + ' tự do dài ' + n + ' mm.'; chain = {free: true, p: b, ref: 'tự do'};
    return true;
  }
  function activate(t) { tool = DESIGN.indexOf(t) >= 0 ? t : null; chain = null; target = null; note = ''; }
  function cancel() { chain = null; target = null; note = ''; }
  function busy() { return !!chain; }
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
      if (wall) { var pos = openingPos(wall, w); target = {wall: wall, type: type, pos: pos, error: openingCheck(wall, type, pos)}; }
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
      host.mutate(function () { lvl().openingPicks[id] = {wall: target.wall.ref, type: target.type.id, pos: target.pos, flip: opt[tool].flip === '1'}; });
      note = 'Đã đặt ' + (tool === 'door' ? 'cửa đi' : 'cửa sổ') + ' ' + target.type.name + ' trên tường ' + target.wall.ref + ', tâm cách đầu tường ' + target.pos + ' mm.';
    }
  }

  function hint() {
    if (!tool) return '';
    if (note) return note;
    var why = blocked(tool); if (why) return why;
    if (freeMode(tool)) {
      if (tool === 'column') return target && target.free ? 'Bấm để đặt cột tự do tại ' + target.free[0] + ', ' + target.free[1] + ' mm (bắt điểm đang bật). Esc kết thúc.' : 'Cột tự do: bấm một điểm bất kỳ. Esc kết thúc.';
      var nm = tool === 'beam' ? 'Dầm' : 'Tường';
      if (!chain) return nm + ' tự do: bấm điểm đầu (bắt điểm). Esc kết thúc.';
      return nm + ' tự do: bấm điểm cuối (tự giữ ngang / dọc)' + (target && target.end ? ', dài ' + lengthOf(chain.p, target.free) + ' mm' : '') + ' hoặc gõ độ dài + Enter; bấm tiếp để nối chuỗi. Esc kết thúc.';
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
  function ghost() {
    var g = [];
    if (tool && freeMode(tool) && !blocked(tool)) {
      if (tool === 'column') {
        if (target && target.free) { var ty = typeById('column', currentType('column')) || S.types[0], sw = Number(opt.column.rot) === 90 ? [ty.d, ty.w] : [ty.w, ty.d], c = target.free;
          g.push({t: 'poly', poly: [[c[0] - sw[0] / 2, c[1] - sw[1] / 2], [c[0] + sw[0] / 2, c[1] - sw[1] / 2], [c[0] + sw[0] / 2, c[1] + sw[1] / 2], [c[0] - sw[0] / 2, c[1] + sw[1] / 2]], color: GOOD, alpha: 0.3}); g.push({t: 'dot', p: c, color: GOOD, r: 5}); }
        return g;
      }
      if (chain) { g.push({t: 'dot', p: chain.p, color: GOOD, r: 5}); }
      if (target && target.free) {
        if (chain) { g.push({t: 'line', a: chain.p, b: target.free, color: target.tooShort ? BAD : GOOD, width: 5, alpha: 0.5}); if (target.end) g.push({t: 'text', p: target.free, text: lengthOf(chain.p, target.free) + ' mm'}); }
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
      if (target.end) { g.push({t: 'line', a: [chain.x, chain.y], b: [target.end.x, target.end.y], color: GOOD, width: 5, alpha: 0.5}); g.push({t: 'dot', p: [target.end.x, target.end.y], color: GOOD, r: 5}); g.push({t: 'text', p: [target.end.x, target.end.y], text: target.refs.length + ' nhịp'}); }
      else if (target.node) g.push({t: 'dot', p: [target.node.x, target.node.y], color: GOOD, r: 6});
      else if (target.span) { var sp = target.span; g.push({t: 'line', a: sp.dir === 'x' ? [sp.a, sp.axis] : [sp.axis, sp.a], b: sp.dir === 'x' ? [sp.b, sp.axis] : [sp.axis, sp.b], color: target.exists ? BAD : GOOD, width: 5, alpha: 0.5}); }
    } else if (tool === 'slab' || tool === 'ceiling') {
      var c = target.cell; g.push({t: 'poly', poly: [[c.x0, c.y0], [c.x1, c.y0], [c.x1, c.y1], [c.x0, c.y1]], color: target.exists ? BAD : GOOD, alpha: 0.2});
    } else if (target.wall && target.type) {
      var wl = target.wall, along = wl.start + target.pos - target.type.w / 2, h = wl.dir === 'x';
      var min = h ? [along, wl.min[1]] : [wl.min[0], along], max = h ? [along + target.type.w, wl.max[1]] : [wl.max[0], along + target.type.w];
      g.push({t: 'poly', poly: [[min[0], min[1]], [max[0], min[1]], [max[0], max[1]], [min[0], max[1]]], color: target.error ? BAD : GOOD, alpha: 0.35});
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
  function freeProps(shape, pick, setType) {
    var f = pick.free, kind = shape.kind;
    var out = [field('type', 'Loại', 'select', typeValues(kind), pick.type || '', setType)];
    function setFree(next) { edit(function () { pick.free = next; }); }
    if (kind === 'column') {
      return out.concat([field('x', 'X tâm (mm)', 'number', null, f.x, function (v) { if (isFinite(v)) setFree({x: r1(v), y: f.y, rot: f.rot}); }),
                         field('y', 'Y tâm (mm)', 'number', null, f.y, function (v) { if (isFinite(v)) setFree({x: f.x, y: r1(v), rot: f.rot}); }),
                         field('rot', 'Xoay', 'select', [['0', '0°'], ['90', '90° (đổi rộng và sâu)']], String(f.rot || 0), function (v) { setFree({x: f.x, y: f.y, rot: Number(v)}); })]);
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
  function propsFor(shape) {
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
               field('flip', 'Đổi mặt cánh', 'checkbox', null, !!pick.flip, function (v) { edit(function () { pick.flip = !!v; }); }));
    }
    return out;
  }

  window.VGDPlanEdit = {
    init: function (h) { host = h; S = h.state; A = h.api; },
    handles: handles, activate: activate, cancel: cancel, busy: busy, options: options, setOption: setOption, freeMode: freeMode, typed: typed,
    move: move, click: click, hint: hint, ghost: ghost, remove: remove, propsFor: propsFor,
    debug: function () { return {tool: tool, chain: chain && chain.ref, chainPoint: chain && chain.p, freeTarget: target && target.free, target: target && {ref: target.node && target.node.ref, end: target.end && target.end.ref, refs: target.refs, span: target.span && target.span.ref, cell: target.cell && target.cell.ref, exists: target.exists, error: target.error, pos: target.pos}, note: note, opt: JSON.parse(JSON.stringify(opt))}; }
  };
})();
