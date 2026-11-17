// Công cụ sửa trên tab Mặt bằng (cột mốc P4): Move, Copy, Array, Mirror, Match và kích thước tạm thời, theo cách làm của Revit.
// Dữ liệu gắn theo LƯỚI TRỤC nên bước dịch là số nguyên ô lưới và trục đối xứng là một trục của lưới (xem docs/vgd_structure/PLAN.md mục 12).
// Mọi thay đổi đi qua host.mutate (có hoàn tác); Ruby vẫn kiểm tra lại. Rotate, Offset, Trim, Align cần phần tử nằm tự do ngoài lưới: làm ở cột mốc riêng (P4b).
(function () {
  'use strict';
  var host = null, S = null, A = null;
  var OK = '#2F7BFF', BAD = '#E5484D', NODE_PX = 16, AXIS_PX = 10, GAP = 50;
  var TOOLS = ['move', 'copy', 'array', 'mirror', 'match'];
  var PICKS = {column: 'picks', beam: 'beamPicks', wall: 'wallPicks', slab: 'slabPicks', ceiling: 'ceilingPicks'};
  var NAMES = {move: 'Move', copy: 'Copy', array: 'Array', mirror: 'Mirror', match: 'Match'};
  var tool = null, phase = '', input = [], base = null, axis = null, source = null, note = '', target = null;
  var opt = {keep: true, count: 2};

  function lvl() { return A.level(); }
  function dist(a, b) { return Math.hypot(a[0] - b[0], a[1] - b[1]); }
  function tol(px) { return px / host.scale(); }
  function clone(o) { return JSON.parse(JSON.stringify(o)); }

  // ---- Chỉ số lưới: từ mã tham chiếu sang (i, j) và ngược lại (cùng cách đặt tên như app.js) ----
  function grid() {
    var gx = A.toAxes('x'), gy = A.toAxes('y'), o = S.origin, g = {gx: gx, gy: gy, nx: gx.length, ny: gy.length, ox: o[0], oy: o[1], ref: {}, name: {}};
    function reg(kind, key, ref, info) { g.ref[kind + '|' + ref] = info; g.name[kind + '|' + key] = ref; }
    gx.forEach(function (ax, i) { gy.forEach(function (ay, j) { reg('column', i + ',' + j, ax.name + '-' + ay.name, {i: i, j: j}); }); });
    gy.forEach(function (ay, j) { for (var i = 0; i + 1 < gx.length; i++) { reg('xspan', i + ',' + j, 'x:' + ay.name + ':' + gx[i].name + '-' + gx[i + 1].name, {i: i, j: j}); } });
    gx.forEach(function (ax, i) { for (var j = 0; j + 1 < gy.length; j++) { reg('yspan', i + ',' + j, 'y:' + ax.name + ':' + gy[j].name + '-' + gy[j + 1].name, {i: i, j: j}); } });
    for (var i = 0; i + 1 < gx.length; i++) for (var j = 0; j + 1 < gy.length; j++) reg('cell', i + ',' + j, gx[i].name + '-' + gx[i + 1].name + '/' + gy[j].name + '-' + gy[j + 1].name, {i: i, j: j});
    return g;
  }
  function describe(g, shape) { // {cls, i, j} của một phần tử có lựa chọn theo lưới; null nếu không phải
    var cls = shape.kind === 'column' ? 'column' : (shape.kind === 'slab' || shape.kind === 'ceiling') ? 'cell' : (shape.kind === 'beam' || shape.kind === 'wall') ? (shape.ref.charAt(0) === 'x' ? 'xspan' : 'yspan') : null;
    var info = cls && g.ref[cls + '|' + shape.ref]; return info ? {cls: cls, i: info.i, j: info.j} : null;
  }
  function inRange(g, cls, i, j) {
    if (cls === 'column') return i >= 0 && i < g.nx && j >= 0 && j < g.ny;
    if (cls === 'xspan') return i >= 0 && i + 1 < g.nx && j >= 0 && j < g.ny;
    if (cls === 'yspan') return i >= 0 && i < g.nx && j >= 0 && j + 1 < g.ny;
    return i >= 0 && i + 1 < g.nx && j >= 0 && j + 1 < g.ny;
  }
  function refAt(g, cls, i, j) { return inRange(g, cls, i, j) ? g.name[cls + '|' + i + ',' + j] : null; }
  // Phép biến đổi: dịch (di, dj) hoặc đối xứng qua trục đứng chỉ số a (axis = {dir: 'x', index}) / trục ngang chỉ số b.
  function mapped(g, d, op) {
    var i = d.i, j = d.j;
    if (op.type === 'shift') { i += op.di; j += op.dj; }
    else if (op.dir === 'x') i = d.cls === 'xspan' || d.cls === 'cell' ? 2 * op.index - i - 1 : 2 * op.index - i;
    else j = d.cls === 'yspan' || d.cls === 'cell' ? 2 * op.index - j - 1 : 2 * op.index - j;
    return {cls: d.cls, i: i, j: j, ref: refAt(g, d.cls, i, j)};
  }
  function swapMode(v) { return v === 'min' ? 'max' : v === 'max' ? 'min' : v; }
  function transformPick(shape, d, pick, op) {
    var p = clone(pick); if (op.type !== 'mirror') return p;
    if (shape.kind === 'column') { if (op.dir === 'x' && p.x) p.x = swapMode(p.x); if (op.dir === 'y' && p.y) p.y = swapMode(p.y); }
    else if (shape.kind === 'beam' || shape.kind === 'wall') { // p là vị trí theo phương VUÔNG GÓC với nhịp: chỉ đổi khi lật đúng phương đó
      var across = d.cls === 'xspan' ? 'y' : 'x'; if (op.dir === across && p.p) p.p = swapMode(p.p);
    }
    return p;
  }

  // ---- Thực hiện ----
  // Kế hoạch: với mỗi phần tử được chọn tính mã đích; trả về {moves: [{shape, from, to, pick}], skipped: [{shape, why}]}.
  function plan(selection, op, keep) {
    var g = grid(), l = lvl(), moves = [], skipped = [], movingOut = {};
    selection.forEach(function (s) {
      var d = describe(g, s);
      if (!d) { if (s.kind === 'opening') return; skipped.push({shape: s, why: 'không thuộc lưới'}); return; }
      var m = mapped(g, d, op);
      if (!m.ref) { skipped.push({shape: s, why: 'ra ngoài lưới'}); return; }
      if (m.ref === s.ref) { skipped.push({shape: s, why: 'trùng vị trí cũ'}); return; }
      moves.push({shape: s, from: s.ref, to: m.ref, d: d, pick: l[PICKS[s.kind]][s.ref]});
      if (!keep) movingOut[s.kind + '|' + s.ref] = true;
    });
    var seen = {}; // phần đích đã bị chiếm (có sẵn, hoặc do phần tử khác trong cùng lệnh)
    moves = moves.filter(function (mv) {
      var key = mv.shape.kind + '|' + mv.to, held = l[PICKS[mv.shape.kind]][mv.to] && !movingOut[key];
      if (held || seen[key]) { skipped.push({shape: mv.shape, why: 'đã có phần tử ở chỗ đích'}); return false; }
      seen[key] = true; return true;
    });
    return {g: g, moves: moves, skipped: skipped};
  }
  function ownSelectionNote(selection) { // cửa đi theo tường: chỉ nhắc khi có cửa được chọn mà tường của cửa không nằm trong lựa chọn
    var walls = {}; selection.forEach(function (s) { if (s.kind === 'wall') walls[s.ref] = true; });
    var picks = lvl().openingPicks, lone = selection.some(function (s) { return s.kind === 'opening' && !(picks[s.ref] && walls[picks[s.ref].wall]); });
    return lone ? ' Cửa đi theo tường: hãy chọn cả tường để cửa đi cùng.' : '';
  }
  function applyPlan(p, op, keep) {
    var l = lvl(), openings = l.openingPicks, moved = {}; // tường được chuyển / nhân bản: ref cũ -> ref mới (cho cửa đi theo)
    p.moves.forEach(function (mv) {
      var box = l[PICKS[mv.shape.kind]], pick = transformPick(mv.shape, mv.d, mv.pick, op);
      if (!keep) delete box[mv.from];
      box[mv.to] = pick;
      if (mv.shape.kind === 'wall') moved[mv.from] = mv.to;
    });
    var walls = (S.preview && S.preview.walls && S.preview.walls.items) || [], len = {}; walls.forEach(function (w) { len[w.ref] = w.length; });
    Object.keys(openings).slice().forEach(function (id) {
      var e = openings[id], to = moved[e.wall]; if (!to) return;
      var out = {wall: to, type: e.type, pos: e.pos, flip: !!e.flip};
      if (op.type === 'mirror') {
        if (len[e.wall]) out.pos = Math.round((len[e.wall] - e.pos) * 10) / 10; // lật theo chiều dài tường; bản lề vẫn ở đầu tường
        var wallDir = e.wall.charAt(0); if (op.dir === (wallDir === 'x' ? 'y' : 'x')) out.flip = !out.flip; // lật qua trục song song với tường: cánh sang mặt kia
      }
      if (keep) openings[A.rid('op_')] = out; else { delete openings[id]; openings[id] = out; }
    });
  }
  function report(verb, p) {
    var n = p.moves.length, why = {};
    p.skipped.forEach(function (s) { why[s.why] = (why[s.why] || 0) + 1; });
    var tail = Object.keys(why).map(function (k) { return why[k] + ' ' + k; }).join(', ');
    return n ? 'Đã ' + verb + ' ' + n + ' phần tử' + (tail ? ' (bỏ qua: ' + tail + ')' : '') + '. Dựng lại để cập nhật model.' : 'Không có phần tử nào ' + verb + ' được' + (tail ? ' (' + tail + ')' : '') + '.';
  }

  // ---- Giao diện công cụ ----
  function handles(t) { return TOOLS.indexOf(t) >= 0; }
  function activate(t, sel) {
    tool = handles(t) ? t : null; phase = ''; input = []; base = null; axis = null; source = null; target = null; note = '';
    if (!tool) return;
    if (tool === 'match') { phase = 'source'; return; }
    if (!sel || !sel.length) { note = NAMES[tool] + ': hãy chọn phần tử trước (bấm hoặc kéo khung), rồi gõ lại lệnh.'; tool = null; return; }
    input = sel; phase = tool === 'mirror' ? 'axis' : 'base';
    note = '';
  }
  function cancel() { phase = tool === 'match' ? 'source' : ''; if (tool && tool !== 'match') tool = null; base = null; axis = null; source = null; target = null; note = ''; }
  function busy() { return !!tool && (phase !== '' && !(tool === 'match' && phase === 'source')); }
  function active() { return tool; }
  function nearestNode(w) {
    var g = grid(), best = null;
    g.gx.forEach(function (ax, i) { g.gy.forEach(function (ay, j) { var p = [g.ox + ax.offset, g.oy + ay.offset], d = dist(p, w); if (d <= tol(NODE_PX) && (!best || d < best.d)) best = {i: i, j: j, p: p, d: d}; }); });
    return best;
  }
  function nearestAxis(w) {
    var g = grid(), best = null;
    g.gx.forEach(function (a, i) { var d = Math.abs(g.ox + a.offset - w[0]); if (d <= tol(AXIS_PX) && (!best || d < best.d)) best = {dir: 'x', index: i, name: a.name, pos: g.ox + a.offset, d: d}; });
    g.gy.forEach(function (a, j) { var d = Math.abs(g.oy + a.offset - w[1]); if (d <= tol(AXIS_PX) && (!best || d < best.d)) best = {dir: 'y', index: j, name: a.name, pos: g.oy + a.offset, d: d}; });
    return best;
  }
  function currentOp() {
    if (tool === 'mirror') return axis ? {type: 'mirror', dir: axis.dir, index: axis.index} : null;
    if (!base || !target) return null;
    return {type: 'shift', di: target.i - base.i, dj: target.j - base.j};
  }

  function move(w) {
    target = null; if (!tool) return;
    if (phase === 'axis') { axis = null; var a = nearestAxis(w); if (a) axis = a; return; }
    if (phase === 'base' || phase === 'target') { var n = nearestNode(w); if (n) { if (phase === 'target') target = n; else base = n; } else if (phase === 'base') base = null; }
  }
  function click(w) {
    note = ''; if (!tool) return;
    if (tool === 'match') return matchClick(w);
    if (phase === 'axis') { var a = nearestAxis(w); if (!a) { note = 'Bấm vào một trục của lưới làm trục đối xứng.'; return; } axis = a; run(); return; }
    if (phase === 'base') { var n = nearestNode(w); if (!n) { note = 'Bấm vào một giao điểm của lưới làm điểm gốc.'; return; } base = n; phase = 'target'; return; }
    if (phase === 'target') {
      var t = nearestNode(w); if (!t) { note = 'Bấm vào một giao điểm của lưới làm điểm đích.'; return; }
      if (t.i === base.i && t.j === base.j) { note = 'Điểm đích trùng điểm gốc.'; return; }
      target = t; run();
    }
  }
  function run() {
    var lone = ownSelectionNote(input); // tính trước khi dữ liệu đổi
    var op = currentOp(), sel = input, keep = tool === 'move' ? false : tool === 'mirror' ? opt.keep : true, verb = tool === 'move' ? 'di chuyển' : tool === 'mirror' ? 'lật' : tool === 'array' ? 'nhân bản' : 'sao chép';
    var times = tool === 'array' ? opt.count : 1, total = {moves: [], skipped: []};
    host.mutate(function () {
      for (var k = 1; k <= times; k++) {
        var step = op.type === 'shift' ? {type: 'shift', di: op.di * k, dj: op.dj * k} : op, p = plan(sel, step, keep);
        applyPlan(p, step, keep); total.moves = total.moves.concat(p.moves); total.skipped = total.skipped.concat(p.skipped);
      }
    });
    note = report(verb, total) + lone;
    phase = ''; tool = null; base = null; target = null; axis = null; input = [];
    if (host.finish) host.finish();
  }

  // Match: bấm phần tử mẫu rồi bấm các phần tử CÙNG LOẠI để chúng nhận loại và vị trí ngang của mẫu (cửa: loại và mặt cánh).
  function matchClick(w) {
    var hit = host.shapeAt(w); if (!hit || !(PICKS[hit.kind] || hit.kind === 'opening')) { note = 'Bấm vào một cột, dầm, tường, sàn, trần hoặc cửa.'; return; }
    var l = lvl(), box = hit.kind === 'opening' ? l.openingPicks : l[PICKS[hit.kind]], pick = box[hit.ref];
    if (!pick) return;
    if (phase === 'source') { source = {kind: hit.kind, ref: hit.ref, pick: clone(pick), title: hit.title}; phase = 'targets'; return; }
    if (hit.kind !== source.kind) { note = 'Phần tử mẫu là ' + source.title + ': chỉ nhận được phần tử cùng loại.'; return; }
    if (hit.ref === source.ref) { note = 'Đây là phần tử mẫu.'; return; }
    var src = source.pick;
    host.mutate(function () {
      if (hit.kind === 'opening') { pick.type = src.type; pick.flip = !!src.flip; return; }
      ['type', 'x', 'y', 'p'].forEach(function (k) { if (k in src) pick[k] = src[k]; else delete pick[k]; });
    });
    note = 'Đã áp dụng loại và vị trí của ' + source.title + ' cho ' + hit.title + '.';
  }

  function options(t) {
    if (t === 'array') return [{id: 'count', label: 'Số bản', kind: 'number', value: opt.count, min: 1, max: 50}];
    if (t === 'mirror') return [{id: 'keep', label: 'Giữ bản gốc', kind: 'checkbox', value: opt.keep}];
    return [];
  }
  function setOption(t, id, value) { if (id === 'count') opt.count = Math.max(1, Math.min(50, Math.round(Number(value)) || 1)); else if (id === 'keep') opt.keep = !!value; }

  function hint() {
    if (!tool) return note;
    if (note) return note;
    var nm = NAMES[tool], n = input.length;
    if (tool === 'match') return phase === 'source' ? 'Match: bấm phần tử MẪU (cột, dầm, tường, sàn, trần hoặc cửa). Esc kết thúc.' : 'Match: bấm các phần tử cùng loại với ' + source.title + ' để áp dụng loại và vị trí. Esc kết thúc.';
    if (phase === 'axis') return nm + ' ' + n + ' phần tử: bấm một trục của lưới làm trục đối xứng (' + (opt.keep ? 'giữ' : 'bỏ') + ' bản gốc). Esc hủy.';
    if (phase === 'base') return nm + ' ' + n + ' phần tử: bấm giao điểm GỐC. Esc hủy.';
    if (phase === 'target') return nm + ': bấm giao điểm ĐÍCH (dịch theo số ô lưới)' + (tool === 'array' ? '; nhân ' + opt.count + ' bản' : '') + '. Esc hủy.';
    return '';
  }

  // Hình xem trước: phần tử ở vị trí đích (đúng hình học của ô / nhịp / giao điểm đích), xanh = được, đỏ = bị bỏ qua.
  function geometry(g, cls, i, j) {
    var x = function (k) { return g.ox + g.gx[k].offset; }, y = function (k) { return g.oy + g.gy[k].offset; };
    if (cls === 'column') return {t: 'dot', p: [x(i), y(j)], r: 6};
    if (cls === 'xspan') return {t: 'line', a: [x(i), y(j)], b: [x(i + 1), y(j)], width: 6};
    if (cls === 'yspan') return {t: 'line', a: [x(i), y(j)], b: [x(i), y(j + 1)], width: 6};
    return {t: 'poly', poly: [[x(i), y(j)], [x(i + 1), y(j)], [x(i + 1), y(j + 1)], [x(i), y(j + 1)]], alpha: 0.18};
  }
  function ghost() {
    var out = []; if (!tool) return out;
    var g = grid();
    if (phase === 'axis' && axis) { var b = host.bounds(); out.push(axis.dir === 'x' ? {t: 'line', a: [axis.pos, b[1] - 500], b: [axis.pos, b[3] + 500], color: OK, dash: [10, 5], width: 2} : {t: 'line', a: [b[0] - 500, axis.pos], b: [b[2] + 500, axis.pos], color: OK, dash: [10, 5], width: 2}); }
    if (base) out.push({t: 'dot', p: base.p, color: OK, r: 6});
    if (phase === 'target' && base && target) out.push({t: 'line', a: base.p, b: target.p, color: OK, dash: [4, 3], width: 1.5});
    var op = currentOp();
    if (op && input.length) {
      var times = tool === 'array' && op.type === 'shift' ? Math.max(1, Math.min(50, opt.count)) : 1;
      for (var k = 1; k <= times; k++) {
        var step = op.type === 'shift' ? {type: 'shift', di: op.di * k, dj: op.dj * k} : op, p = plan(input, step, tool === 'move' ? false : tool === 'mirror' ? opt.keep : true);
        p.moves.forEach(function (mv) { var m = mapped(g, mv.d, step), geo = geometry(g, m.cls, m.i, m.j); geo.color = OK; geo.alpha = geo.alpha || 0.6; out.push(geo); });
        p.skipped.forEach(function (s) { var d = describe(g, s.shape); if (!d) return; var m = mapped(g, d, step), geo = inRange(g, m.cls, m.i, m.j) ? geometry(g, m.cls, m.i, m.j) : null; if (geo) { geo.color = BAD; geo.alpha = 0.5; out.push(geo); } });
      }
    }
    return out;
  }

  // ---- Kích thước tạm thời (Temporary Dimensions) ----
  function bbox(poly) { var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity; poly.forEach(function (p) { x0 = Math.min(x0, p[0]); y0 = Math.min(y0, p[1]); x1 = Math.max(x1, p[0]); y1 = Math.max(y1, p[1]); }); return [x0, y0, x1, y1]; }
  function items(key) { return (S.preview && S.preview[key] && S.preview[key].items) || []; }
  function round(v) { return Math.round(v * 10) / 10; }
  function dimOf(a, b, side, off, editable, extra) { // đường kích thước nối a - b, vẽ lệch `off` mm về phía `side` (vector đơn vị)
    var len = Math.hypot(b[0] - a[0], b[1] - a[1]);
    var item = {a: [a[0] + side[0] * off, a[1] + side[1] * off], b: [b[0] + side[0] * off, b[1] + side[1] * off], from: a, to: b, value: round(len), editable: !!editable};
    return Object.assign(item, extra || {});
  }
  // Danh sách kích thước tạm thời cho MỘT phần tử đang chọn. Cửa: tới hai đầu tường, sửa được; còn lại chỉ xem.
  function tempDims(shape) {
    if (!shape) return [];
    if (shape.kind === 'opening') {
      var o = items('openings').filter(function (i) { return i.ref === shape.ref; })[0], w = o && items('walls').filter(function (i) { return i.ref === o.wall; })[0];
      if (!o || !w) return [];
      var h = w.dir === 'x', key = h ? 0 : 1, cross = h ? 1 : 0, side = h ? [0, 1] : [1, 0], off = 450 + w.t / 2;
      function pt(u) { var p = [0, 0]; p[key] = u; p[cross] = w.center; return p; }
      var a0 = o.min[key], a1 = o.max[key];
      return [
        dimOf(pt(w.start), pt(a0), side, off, true, {id: 'left', opening: o.ref, value: round(a0 - w.start)}),
        dimOf(pt(a1), pt(w.finish), side, off, true, {id: 'right', opening: o.ref, value: round(w.finish - a1)}),
        dimOf(pt(a0), pt(a1), side, off + 350, false, {id: 'width', value: round(o.w)})
      ];
    }
    var b = bbox(shape.poly), w2 = b[2] - b[0], h2 = b[3] - b[1], out = [];
    if (w2 >= h2 * 0.25) out.push(dimOf([b[0], b[1]], [b[2], b[1]], [0, -1], 350 + Math.min(h2, 400) * 0, false, {id: 'w', value: round(w2)}));
    if (h2 >= w2 * 0.25) out.push(dimOf([b[2], b[1]], [b[2], b[3]], [1, 0], 350, false, {id: 'h', value: round(h2)}));
    return out;
  }
  // Gõ giá trị mới cho một kích thước sửa được. Trả về chuỗi lỗi hoặc null.
  function commitDim(dim, text) {
    var v = Number(String(text).trim().replace(',', '.'));
    if (!isFinite(v) || v < 0) return 'Hãy gõ một số không âm (mm).';
    var o = items('openings').filter(function (i) { return i.ref === dim.opening; })[0], w = o && items('walls').filter(function (i) { return i.ref === o.wall; })[0];
    var pick = lvl().openingPicks[dim.opening]; if (!o || !w || !pick) return 'Cửa không còn trên tường.';
    var pos = dim.id === 'left' ? v + o.w / 2 : w.length - v - o.w / 2; pos = round(pos);
    if (pos - o.w / 2 < 0 || pos + o.w / 2 > w.length) return 'Cửa rộng ' + o.w + ' mm không nằm trọn trong tường dài ' + w.length + ' mm.';
    var clash = A.wallOpenings(w.ref).some(function (e) { return e.id !== dim.opening && !(pos + o.w / 2 + GAP <= e.x0 || pos - o.w / 2 >= e.x1 + GAP); });
    if (clash) return 'Chồng hoặc sát cửa khác (cần cách nhau ít nhất ' + GAP + ' mm).';
    host.mutate(function () { pick.pos = pos; });
    return null;
  }

  window.VGDPlanModify = {
    init: function (h) { host = h; S = h.state; A = h.api; },
    handles: handles, activate: activate, cancel: cancel, busy: busy, active: active, click: click, move: move, hint: hint, ghost: ghost, options: options, setOption: setOption,
    tempDims: tempDims, commitDim: commitDim,
    // Dùng cho test.
    _plan: function (sel, op, keep) { var p = plan(sel, op, keep); return {moves: p.moves.map(function (m) { return [m.shape.kind, m.from, m.to]; }), skipped: p.skipped.map(function (s) { return [s.shape.ref, s.why]; })}; },
    debug: function () { return {tool: tool, phase: phase, base: base && [base.i, base.j], target: target && [target.i, target.j], axis: axis && axis.dir + ':' + axis.name, source: source && source.ref, note: note, opt: clone(opt)}; }
  };
})();
