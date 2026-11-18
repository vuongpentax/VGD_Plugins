// Công cụ sửa trên tab Mặt bằng (kiểu Revit): Move, Copy, Array, Mirror, Match (P4) và, từ P4b-1, Offset, Align, Trim, Rotate, Mở khóa lưới
// cùng kích thước tạm thời. Có hai chế độ:
//  - THEO LƯỚI (P4): bấm hai giao điểm của lưới thì phần tử theo lưới dịch theo số ô, qua một trục của lưới thì lật theo chỉ số.
//  - TỰ DO (P4b-1, xiên từ P4b-2): mọi lệnh khác tác động lên phần tử TỰ DO (cột, dầm, tường có khóa 'free': tọa độ tùy ý, dầm / tường ngang, dọc hoặc xiên, cột xoay góc bất kỳ). Cột, dầm, tường theo lưới được
//    "mở khóa" (đổi thành phần tử tự do đúng hình đang thấy) rồi mới dịch / xoay / lật / dời. Sàn, trần theo ô chỉ dịch và lật theo lưới (đa giác tự do ở P4b-2).
// Mọi thay đổi đi qua host.mutate (có hoàn tác); Ruby vẫn kiểm tra lại.
(function () {
  'use strict';
  var host = null, S = null, A = null;
  var OK = '#2F7BFF', BAD = '#E5484D', NODE_PX = 16, AXIS_PX = 10, GAP = 50, NODE_EPS = 1;
  var TOOLS = ['move', 'copy', 'array', 'mirror', 'match', 'offset', 'align', 'trim', 'rotate', 'unlock'];
  var ONE_SHOT_KEEP = ['match', 'align', 'trim']; // công cụ giữ nguyên sau mỗi lần bấm (Esc mới kết thúc)
  var PICKS = {column: 'picks', beam: 'beamPicks', wall: 'wallPicks', slab: 'slabPicks', ceiling: 'ceilingPicks'};
  var LINEAR = {beam: 'beams', wall: 'walls'}, ITEMS = {column: 'columns', beam: 'beams', wall: 'walls'}, PREFIX = {column: 'fc_', beam: 'fb_', wall: 'fw_'};
  var NAMES = {move: 'Move', copy: 'Copy', array: 'Array', mirror: 'Mirror', match: 'Match', offset: 'Offset', align: 'Align', trim: 'Trim', rotate: 'Rotate', unlock: 'Mở khóa lưới'};
  var tool = null, phase = '', input = [], base = null, axis = null, source = null, note = '', target = null, cursorW = null, trimA = null, alignRef = null;
  var opt = {keep: true, count: 2, distance: 1000, copy: true, angle: '90'};

  function lvl() { return A.level(); }
  function dist(a, b) { return Math.hypot(a[0] - b[0], a[1] - b[1]); }
  function tol(px) { return px / host.scale(); }
  function clone(o) { return JSON.parse(JSON.stringify(o)); }
  function round(v) { return Math.round(v * 10) / 10; }

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
  function describe(g, shape) { // {cls, i, j} của một phần tử THEO LƯỚI; null nếu không phải (hoặc phần tử tự do)
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
  function mapped(g, d, op) { // đối xứng qua trục CỦA LƯỚI hoặc dịch theo số ô
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
    else if (shape.kind === 'beam' || shape.kind === 'wall') { var across = d.cls === 'xspan' ? 'y' : 'x'; if (op.dir === across && p.p) p.p = swapMode(p.p); }
    return p;
  }

  // ---- Phần tử tự do: hình học, mở khóa, biến đổi ----
  function box(kind) { return lvl()[PICKS[kind]]; }
  function pickOf(shape) { return PICKS[shape.kind] ? box(shape.kind)[shape.ref] : null; }
  function isFree(pick) { return !!(pick && pick.free); }
  function previewItem(shape) { var list = (S.preview && S.preview[ITEMS[shape.kind]] && S.preview[ITEMS[shape.kind]].items) || []; return list.filter(function (i) { return i.ref === shape.ref; })[0] || null; }
  // Hình học dạng "tự do" của một phần tử (cột: {x, y, rot}; dầm / tường: {a, b}); phần tử theo lưới lấy từ hình đang tính ở xem trước. null nếu chưa có hình.
  function geomOf(shape) {
    var pick = pickOf(shape); if (!pick) return null;
    if (pick.free) return clone(pick.free);
    var it = previewItem(shape); if (!it) return null;
    if (shape.kind === 'column') return {x: round(it.center[0]), y: round(it.center[1]), rot: 0};
    return it.dir === 'x' ? {a: [round(it.start), round(it.center)], b: [round(it.finish), round(it.center)]} : {a: [round(it.center), round(it.start)], b: [round(it.center), round(it.finish)]};
  }
  function typeOfPick(shape) { // loại cần giữ khi mở khóa / sao chép: loại riêng, không thì loại thực của phần tử đang tính
    var pick = pickOf(shape); if (pick && pick.type) return pick.type;
    var it = previewItem(shape); return it ? it.type_id : undefined;
  }
  function isOrtho(f) { return f.a[0] === f.b[0] || f.a[1] === f.b[1]; }
  // Chuẩn hóa đoạn: lệch dưới 0,05 mm theo một phương thì làm thẳng (khớp Ruby); đầu a là đầu bên trái (đứng dọc thì đầu thấp).
  function normLinear(f) {
    var a = f.a.map(round), b = f.b.map(round);
    if (Math.abs(a[0] - b[0]) <= 0.05) b[0] = a[0]; else if (Math.abs(a[1] - b[1]) <= 0.05) b[1] = a[1];
    var swap = isOrtho({a: a, b: b}) ? (b[0] - a[0]) + (b[1] - a[1]) < 0 : b[0] < a[0];
    return swap ? {a: b, b: a} : {a: a, b: b};
  }
  // Góc (độ, 0 <= góc < 180) của trục "rộng" của cột sau phép biến đổi fn: ảnh của hướng cũ qua fn. Hình chữ nhật đối xứng 180 độ nên chỉ cần tới 180.
  function columnRot(free, fn) {
    var c = [free.x, free.y], r = (free.rot || 0) * Math.PI / 180, p = fn(c), q = fn([c[0] + Math.cos(r), c[1] + Math.sin(r)]);
    var deg = Math.round((((Math.atan2(q[1] - p[1], q[0] - p[0]) * 180 / Math.PI) % 180) + 180) % 180 * 100) / 100;
    return deg >= 180 ? 0 : deg;
  }
  function applyMap(kind, free, fn) { // fn: điểm -> điểm; trả về hình học mới
    if (kind === 'column') { var c = fn([free.x, free.y]); return {x: round(c[0]), y: round(c[1]), rot: columnRot(free, fn)}; }
    return normLinear({a: fn(free.a), b: fn(free.b)});
  }
  function movePoly(poly, fn) { return poly.map(function (p) { return fn(p); }); }
  function newId(kind) { return A.rid(PREFIX[kind]); }
  function wallStart(free) { return free.a[0] === free.b[0] ? free.a[1] : free.a[0]; } // tọa độ đầu tường dọc phương của nó
  function wallLength(free) { return Math.hypot(free.b[0] - free.a[0], free.b[1] - free.a[1]); }

  // Cửa theo tường khi tường bị lật / xoay (fn là phép biến đổi điểm): nếu đầu tường a bị đổi sang đầu kia thì vị trí tính từ đầu tường đổi (dài - cũ);
  // lật mặt cánh: phép LẬT giữ chiều tường thì đổi mặt, phép XOAY đổi chiều tường thì đổi mặt (bản lề luôn ở đầu tường, chưa có tùy chọn bản lề).
  function openingFixer(kind, fn) {
    return function (e, oldF, newF) {
      var m = fn(oldF.a), reversed = dist(m, newF.b) < dist(m, newF.a), L = wallLength(oldF);
      if (reversed) e.pos = round(L - e.pos);
      if (kind === 'mirror' ? !reversed : reversed) e.flip = !e.flip;
    };
  }
  // Biến đổi hình học các phần tử chọn bằng điểm-ánh-xạ fn. keep = giữ bản gốc (tạo phần tử mới), ngược lại dời tại chỗ (phần tử theo lưới thì mở khóa).
  // fix(cửa, hình cũ, hình mới) chỉnh cửa theo tường. Trả về {moved, skipped: [[tên, lý do]]}.
  function transformSelection(sel, fn, keep, fix) {
    var moved = 0, skipped = [], map = {};
    sel.forEach(function (s) {
      if (!ITEMS[s.kind]) { if (s.kind !== 'opening') skipped.push([s.title, 'sàn, trần theo ô chỉ dịch hoặc lật theo lưới']); return; }
      var pick = pickOf(s), free = pick && geomOf(s);
      if (!free) { skipped.push([s.title, 'chưa có hình trong xem trước']); return; }
      var next = applyMap(s.kind, free, fn), b = box(s.kind), to = s.ref, ty = typeOfPick(s);
      if (keep || !isFree(pick)) {
        var np = {free: next}; if (ty) np.type = ty;
        if (!keep) delete b[s.ref];
        to = newId(s.kind); b[to] = np;
      } else pick.free = next;
      map[s.ref] = {to: to, old: free, next: next, kind: s.kind};
      moved++;
    });
    var o = lvl().openingPicks;
    Object.keys(o).slice().forEach(function (id) {
      var e = o[id], m = map[e.wall]; if (!m || m.kind !== 'wall') return;
      var out = {wall: m.to, type: e.type, pos: e.pos, flip: !!e.flip};
      if (fix) fix(out, m.old, m.next);
      if (keep) o[A.rid('op_')] = out; else o[id] = out;
    });
    return {moved: moved, skipped: skipped};
  }
  function summary(verb, moved, skipped) { // skipped: [[tên, lý do]]
    var why = {}; skipped.forEach(function (s) { why[s[1]] = (why[s[1]] || 0) + 1; });
    var tail = Object.keys(why).map(function (k) { return why[k] + ' ' + k; }).join(', ');
    return moved ? 'Đã ' + verb + ' ' + moved + ' phần tử' + (tail ? ' (bỏ qua: ' + tail + ')' : '') + '. Dựng lại để cập nhật model.' : 'Không có phần tử nào ' + verb + ' được' + (tail ? ' (' + tail + ')' : '') + '.';
  }

  // ---- Chế độ THEO LƯỚI (P4) ----
  function plan(selection, op, keep) {
    var g = grid(), l = lvl(), moves = [], skipped = [], movingOut = {};
    selection.forEach(function (s) {
      var d = describe(g, s);
      if (!d) { if (s.kind === 'opening' || isFree(pickOf(s))) return; skipped.push({shape: s, why: 'không thuộc lưới'}); return; }
      var m = mapped(g, d, op);
      if (!m.ref) { skipped.push({shape: s, why: 'ra ngoài lưới'}); return; }
      if (m.ref === s.ref) { skipped.push({shape: s, why: 'trùng vị trí cũ'}); return; }
      moves.push({shape: s, from: s.ref, to: m.ref, d: d, pick: l[PICKS[s.kind]][s.ref]});
      if (!keep) movingOut[s.kind + '|' + s.ref] = true;
    });
    var seen = {};
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
    var l = lvl(), openings = l.openingPicks, moved = {};
    p.moves.forEach(function (mv) {
      var b = l[PICKS[mv.shape.kind]], pick = transformPick(mv.shape, mv.d, mv.pick, op);
      if (!keep) delete b[mv.from];
      b[mv.to] = pick;
      if (mv.shape.kind === 'wall') moved[mv.from] = mv.to;
    });
    var walls = (S.preview && S.preview.walls && S.preview.walls.items) || [], len = {}; walls.forEach(function (w) { len[w.ref] = w.length; });
    Object.keys(openings).slice().forEach(function (id) {
      var e = openings[id], to = moved[e.wall]; if (!to) return;
      var out = {wall: to, type: e.type, pos: e.pos, flip: !!e.flip};
      if (op.type === 'mirror') {
        var wallDir = e.wall.charAt(0);
        if (len[e.wall] && op.dir === wallDir) out.pos = Math.round((len[e.wall] - e.pos) * 10) / 10; // lật qua trục VUÔNG GÓC với tường: đổi chiều dọc tường
        if (op.dir !== wallDir) out.flip = !out.flip; // lật qua trục SONG SONG với tường: cánh sang mặt kia
      }
      if (keep) openings[A.rid('op_')] = out; else { delete openings[id]; openings[id] = out; }
    });
  }

  // ---- Điểm và trục ----
  function nodes() { var g = grid(), out = []; g.gx.forEach(function (ax, i) { g.gy.forEach(function (ay, j) { out.push({i: i, j: j, p: [g.ox + ax.offset, g.oy + ay.offset]}); }); }); return out; }
  function nodeAtPoint(p) { var hit = null; nodes().forEach(function (n) { if (dist(n.p, p) <= NODE_EPS) hit = n; }); return hit; }
  // Điểm bấm: giao điểm của lưới gần nhất (trong 8 px) được ưu tiên để chế độ "theo lưới" nhận ra; không thì bắt điểm (đầu mút, giao điểm, trung điểm...), không thì điểm thô.
  function pointAt(w) {
    var best = null; nodes().forEach(function (n) { var d = dist(n.p, w); if (d <= tol(8) && (!best || d < best.d)) best = {p: n.p, d: d}; });
    if (best) return best.p;
    var s = host.snapPoint ? host.snapPoint(w) : null; return s || w;
  }
  function nearestAxis(w) {
    var g = grid(), best = null;
    g.gx.forEach(function (a, i) { var d = Math.abs(g.ox + a.offset - w[0]); if (d <= tol(AXIS_PX) && (!best || d < best.d)) best = {dir: 'x', index: i, name: a.name, pos: g.ox + a.offset, d: d}; });
    g.gy.forEach(function (a, j) { var d = Math.abs(g.oy + a.offset - w[1]); if (d <= tol(AXIS_PX) && (!best || d < best.d)) best = {dir: 'y', index: j, name: a.name, pos: g.oy + a.offset, d: d}; });
    (host.guides ? host.guides() : []).forEach(function (gd) { // đường gióng ngang / dọc cũng làm trục đối xứng (không thuộc lưới)
      var vertical = Math.abs(gd.d[0]) < 1e-6, horizontal = Math.abs(gd.d[1]) < 1e-6; if (!vertical && !horizontal) return;
      var d = Math.abs(vertical ? gd.p[0] - w[0] : gd.p[1] - w[1]); if (d <= tol(AXIS_PX) && (!best || d < best.d)) best = {dir: vertical ? 'x' : 'y', index: null, name: 'đường gióng', pos: vertical ? gd.p[0] : gd.p[1], d: d};
    });
    return best;
  }
  function reflect(ax) { return function (p) { return ax.dir === 'x' ? [2 * ax.pos - p[0], p[1]] : [p[0], 2 * ax.pos - p[1]]; }; }
  function rotateAbout(c, deg) { // quay ngược chiều kim đồng hồ; bội của 90 độ tính đúng, không sai số
    if (deg % 90 === 0) { var q = ((deg % 360) + 360) % 360; return function (p) { var dx = p[0] - c[0], dy = p[1] - c[1]; if (q === 90) return [c[0] - dy, c[1] + dx]; if (q === 180) return [c[0] - dx, c[1] - dy]; if (q === 270) return [c[0] + dy, c[1] - dx]; return [p[0], p[1]]; }; }
    var r = deg * Math.PI / 180, cs = Math.cos(r), sn = Math.sin(r);
    return function (p) { var dx = p[0] - c[0], dy = p[1] - c[1]; return [c[0] + dx * cs - dy * sn, c[1] + dx * sn + dy * cs]; };
  }
  function translate(dx, dy) { return function (p) { return [p[0] + dx, p[1] + dy]; }; }

  // ---- Giao diện công cụ ----
  function handles(t) { return TOOLS.indexOf(t) >= 0; }
  function activate(t, sel) {
    tool = handles(t) ? t : null; phase = ''; input = []; base = null; axis = null; source = null; target = null; note = ''; trimA = null; alignRef = null; cursorW = null;
    if (!tool) return;
    if (tool === 'match') { phase = 'source'; return; }
    if (tool === 'align') { phase = 'ref'; return; }
    if (tool === 'trim') { phase = 'first'; return; }
    if (!sel || !sel.length) { note = NAMES[tool] + ': hãy chọn phần tử trước (bấm hoặc kéo khung), rồi gõ lại lệnh.'; tool = null; return; }
    input = sel;
    if (tool === 'unlock') { runUnlock(); return; }
    phase = tool === 'mirror' ? 'axis' : tool === 'offset' ? 'side' : tool === 'rotate' ? 'center' : 'base';
  }
  function resetPhase() { return tool === 'match' ? 'source' : tool === 'align' ? 'ref' : tool === 'trim' ? 'first' : ''; }
  function cancel() { phase = resetPhase(); if (tool && ONE_SHOT_KEEP.indexOf(tool) < 0) tool = null; base = null; axis = null; source = null; target = null; note = ''; trimA = null; alignRef = null; }
  function busy() { return !!tool && phase !== resetPhase(); }
  function active() { return tool; }

  function move(w) {
    cursorW = w; target = null; if (!tool) return;
    if (phase === 'axis') { axis = nearestAxis(w); return; }
    if (phase === 'base' || phase === 'center') { base = {p: pointAt(w)}; return; }
    if (phase === 'target') target = {p: pointAt(w)};
  }
  function click(w) {
    note = ''; if (!tool) return;
    cursorW = w;
    if (tool === 'match') return matchClick(w);
    if (tool === 'align') return alignClick(w);
    if (tool === 'trim') return trimClick(w);
    if (phase === 'axis') { var a = nearestAxis(w); if (!a) { note = 'Bấm vào một trục của lưới (hoặc một đường gióng ngang / dọc) làm trục đối xứng.'; return; } axis = a; run(); return; }
    if (phase === 'base') { base = {p: pointAt(w)}; phase = 'target'; return; }
    if (phase === 'target') {
      var t = pointAt(w); if (dist(t, base.p) < 0.5) { note = 'Điểm đích trùng điểm gốc.'; return; }
      target = {p: t}; run(); return;
    }
    if (phase === 'side') { applyOffset(opt.distance, w); return; }
    if (phase === 'center') { base = {p: pointAt(w)}; runRotate(); }
  }
  function finishRun() { phase = ''; tool = null; base = null; target = null; axis = null; input = []; if (host.finish) host.finish(); }

  function run() {
    var lone = ownSelectionNote(input), msg = '', keep = tool === 'move' ? false : tool === 'mirror' ? opt.keep : true;
    var verb = tool === 'move' ? 'di chuyển' : tool === 'mirror' ? 'lật' : tool === 'array' ? 'nhân bản' : 'sao chép';
    host.mutate(function () { msg = tool === 'mirror' ? runMirror(input, keep, verb) : runShift(input, keep, verb); });
    note = msg + lone;
    finishRun();
  }
  function runShift(sel, keep, verb) {
    var v = [target.p[0] - base.p[0], target.p[1] - base.p[1]], bn = nodeAtPoint(base.p), tn = nodeAtPoint(target.p), nodeMode = !!(bn && tn), times = tool === 'array' ? opt.count : 1;
    var moved = 0, skipped = [];
    for (var k = 1; k <= times; k++) {
      if (nodeMode) { // hai giao điểm của lưới: phần tử theo lưới dịch theo số ô; phần tử tự do dịch đúng véc-tơ
        var step = {type: 'shift', di: (tn.i - bn.i) * k, dj: (tn.j - bn.j) * k}, p = plan(sel, step, keep);
        applyPlan(p, step, keep); moved += p.moves.length; p.skipped.forEach(function (s) { skipped.push([s.shape.title, s.why]); });
        var fr = transformSelection(sel.filter(function (s) { return ITEMS[s.kind] && isFree(pickOf(s)); }), translate(v[0] * k, v[1] * k), keep);
        moved += fr.moved; skipped = skipped.concat(fr.skipped);
      } else { // điểm tự do: mọi cột, dầm, tường (theo lưới thì mở khóa) dịch đúng véc-tơ; sàn, trần theo ô không dịch tự do được
        var fr2 = transformSelection(sel.filter(function (s) { return ITEMS[s.kind]; }), translate(v[0] * k, v[1] * k), keep);
        moved += fr2.moved; skipped = skipped.concat(fr2.skipped);
        if (k === 1) sel.forEach(function (s) { if (s.kind === 'slab' || s.kind === 'ceiling') skipped.push([s.title, 'sàn, trần theo ô: bấm hai giao điểm của lưới để dịch theo ô']); });
      }
    }
    return summary(verb, moved, skipped);
  }
  function runMirror(sel, keep, verb) {
    var fix = openingFixer('mirror', reflect(axis)), moved = 0, skipped = [];
    if (axis.index !== null) { // trục của lưới: phần tử theo lưới lật theo chỉ số, phần tử tự do lật theo tọa độ
      var op = {type: 'mirror', dir: axis.dir, index: axis.index}, p = plan(sel, op, keep);
      applyPlan(p, op, keep); moved += p.moves.length; p.skipped.forEach(function (s) { skipped.push([s.shape.title, s.why]); });
      var fr = transformSelection(sel.filter(function (s) { return ITEMS[s.kind] && isFree(pickOf(s)); }), reflect(axis), keep, fix);
      moved += fr.moved; skipped = skipped.concat(fr.skipped);
    } else { // đường gióng: mọi cột, dầm, tường (theo lưới thì mở khóa) lật theo tọa độ
      var fr2 = transformSelection(sel.filter(function (s) { return ITEMS[s.kind]; }), reflect(axis), keep, fix);
      moved += fr2.moved; skipped = skipped.concat(fr2.skipped);
      sel.forEach(function (s) { if (s.kind === 'slab' || s.kind === 'ceiling') skipped.push([s.title, 'sàn, trần chỉ lật qua trục của lưới']); });
    }
    return summary(verb, moved, skipped);
  }
  function runUnlock() {
    var l = lvl(), moved = 0, skipped = [];
    host.mutate(function () {
      input.forEach(function (s) {
        if (!ITEMS[s.kind]) { if (s.kind !== 'opening') skipped.push([s.title, 'sàn, trần chưa có dạng tự do']); return; }
        var pick = pickOf(s); if (!pick) return;
        if (isFree(pick)) { skipped.push([s.title, 'đã là phần tử tự do']); return; }
        var free = geomOf(s); if (!free) { skipped.push([s.title, 'chưa có hình trong xem trước']); return; }
        var ty = typeOfPick(s), np = {free: free}; if (ty) np.type = ty;
        var id = newId(s.kind); delete l[PICKS[s.kind]][s.ref]; l[PICKS[s.kind]][id] = np;
        if (s.kind === 'wall') Object.keys(l.openingPicks).forEach(function (oid) { if (l.openingPicks[oid].wall === s.ref) l.openingPicks[oid].wall = id; });
        moved++;
      });
    });
    note = moved ? 'Đã mở khóa lưới cho ' + moved + ' phần tử: giữ nguyên hình, nay di chuyển / xoay / dời tự do được.' + (skipped.length ? ' Bỏ qua ' + skipped.length + ' phần tử (đã tự do, sàn / trần hoặc chưa có hình).' : '') : 'Không có phần tử nào mở khóa được (' + (skipped.length ? skipped[0][1] : 'chọn cột, dầm hoặc tường theo lưới') + ').';
    phase = ''; tool = null; input = [];
  }

  // ---- Offset ----
  function linearShapes(sel) { return sel.filter(function (s) { return LINEAR[s.kind]; }); }
  function offsetFn(free, w, d) { // dời vuông góc với phần tử về phía điểm w
    var len = wallLength(free), n = [-(free.b[1] - free.a[1]) / len, (free.b[0] - free.a[0]) / len];
    var side = ((w[0] - free.a[0]) * n[0] + (w[1] - free.a[1]) * n[1]) >= 0 ? 1 : -1;
    return translate(side * d * n[0], side * d * n[1]);
  }
  function applyOffset(distance, w) {
    if (!isFinite(distance) || distance <= 0 || distance > 1e5) { note = 'Khoảng cách phải là số dương (mm).'; return false; }
    var sel = linearShapes(input), keep = !!opt.copy, moved = 0, skipped = [];
    if (!sel.length) { note = 'Offset chỉ dùng cho dầm và tường (chọn dầm / tường trước).'; return false; }
    host.mutate(function () {
      sel.forEach(function (s) {
        var free = geomOf(s); if (!free) { skipped.push([s.title, 'chưa có hình trong xem trước']); return; }
        var one = transformSelection([s], offsetFn(free, w, distance), keep); moved += one.moved; skipped = skipped.concat(one.skipped);
      });
    });
    input.forEach(function (s) { if (!LINEAR[s.kind] && s.kind !== 'opening') skipped.push([s.title, 'Offset chỉ dùng cho dầm và tường']); });
    note = summary((keep ? 'sao chép dời ' : 'dời ') + distance + ' mm cho', moved, skipped).replace(/^Đã (.*) (\d+) phần tử/, 'Đã $1 $2 phần tử');
    finishRun(); return true;
  }

  // ---- Rotate ----
  function runRotate() {
    var deg = Number(opt.angle), keep = !!opt.copy, c = base.p;
    if (!isFinite(deg) || Math.abs(deg) > 360 || deg % 360 === 0) { note = 'Góc xoay phải là số độ khác 0, trong khoảng -360 đến 360.'; return; }
    var r = {moved: 0, skipped: []}, fn = rotateAbout(c, deg);
    host.mutate(function () { r = transformSelection(input, fn, keep, openingFixer('rotate', fn)); });
    note = summary('xoay ' + deg + '°' + (keep ? ' (sao chép)' : ''), r.moved, r.skipped);
    finishRun();
  }

  // ---- Align ----
  function referenceAt(w) { // đường ngang / dọc gần điểm bấm: cạnh phần tử, trục hoặc đường gióng
    var l = host.lineAt ? host.lineAt(w) : null;
    if (!l) return null;
    if (Math.abs(l.d[1]) < 1e-6) return {dir: 'y', pos: l.p[1]};
    if (Math.abs(l.d[0]) < 1e-6) return {dir: 'x', pos: l.p[0]};
    return {dir: null};
  }
  function shapeBox(poly) { var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity; poly.forEach(function (p) { x0 = Math.min(x0, p[0]); y0 = Math.min(y0, p[1]); x1 = Math.max(x1, p[0]); y1 = Math.max(y1, p[1]); }); return [x0, y0, x1, y1]; }
  function alignClick(w) {
    if (phase === 'ref') {
      var ref = referenceAt(w); if (!ref) { note = 'Align: bấm vào một cạnh, trục hoặc đường gióng làm đường chuẩn.'; return; }
      if (!ref.dir) { note = 'Đường chuẩn phải nằm ngang hoặc dọc (đường xiên làm ở bước sau).'; return; }
      alignRef = ref; phase = 'element'; return;
    }
    var hit = host.shapeAt(w); if (!hit || !ITEMS[hit.kind]) { note = 'Bấm vào một cột, dầm hoặc tường để căn.'; return; }
    var hg = geomOf(hit); if (hg && (hg.a ? !isOrtho(hg) : (hg.rot || 0) % 90 !== 0)) { note = hit.title + ': đang xiên / xoay góc bất kỳ, Align chỉ căn phần tử ngang hoặc dọc.'; return; }
    var b = shapeBox(hit.poly), faces = alignRef.dir === 'x' ? [b[0], b[2]] : [b[1], b[3]], d = faces.map(function (f) { return alignRef.pos - f; }), delta = Math.abs(d[0]) <= Math.abs(d[1]) ? d[0] : d[1];
    if (Math.abs(delta) < 0.05) { note = hit.title + ' đã nằm trên đường chuẩn.'; return; }
    var fn = alignRef.dir === 'x' ? translate(delta, 0) : translate(0, delta), r;
    host.mutate(function () { r = transformSelection([hit], fn, false); });
    note = r.moved ? 'Đã căn ' + hit.title + ' (dời ' + round(delta) + ' mm). Bấm phần tử khác để căn tiếp, Esc kết thúc.' : summary('căn', 0, r.skipped);
  }

  // ---- Trim (nối góc L) ----
  function trimClick(w) {
    var hit = host.shapeAt(w); if (!hit || !LINEAR[hit.kind]) { note = 'Trim: bấm vào dầm hoặc tường (bấm đúng phần muốn GIỮ lại).'; return; }
    var free = geomOf(hit); if (!free) { note = hit.title + ': chưa có hình trong xem trước.'; return; }
    if (phase === 'first') { trimA = {shape: hit, free: free, w: w}; phase = 'second'; return; }
    if (hit.kind === trimA.shape.kind && hit.ref === trimA.shape.ref) { note = 'Hãy bấm phần tử thứ hai (khác phần tử đầu).'; return; }
    var a = trimA, ha = a.free.a[1] === a.free.b[1], hb = free.a[1] === free.b[1];
    if (!isOrtho(a.free) || !isOrtho(free)) { note = 'Trim nối góc chỉ làm với dầm / tường ngang hoặc dọc (đầu xiên cắt vuông, chưa có nối góc xiên).'; return; }
    if (ha === hb) { note = 'Trim nối góc cần hai phần tử vuông góc nhau (một ngang, một dọc).'; return; }
    var widthOf = function (s) { var it = previewItem(s); return it ? (it.t || it.w) : 0; }, ta = widthOf(a.shape), tb = widthOf(hit);
    if (!ta || !tb) { note = 'Không đọc được bề dày của phần tử (chưa có xem trước).'; return; }
    // Phần tử 1 chạy suốt tới mặt NGOÀI của phần tử 2; phần tử 2 dừng ở mặt phần tử 1 phía nó đang giữ: hai phần tử khít góc L, không chồng nhau.
    var seg1 = trimEnd(a.free, ha, a.w, hb ? free.a[1] : free.a[0], tb, false), seg2 = trimEnd(free, hb, w, ha ? a.free.a[1] : a.free.a[0], ta, true);
    if (!seg1 || !seg2) { note = 'Không nối được: phần giữ lại không nằm một phía của giao điểm.'; return; }
    host.mutate(function () { writeTrim(a.shape, a.free, seg1, ha); writeTrim(hit, free, seg2, hb); });
    note = 'Đã nối góc ' + a.shape.title + ' và ' + hit.title + '. Dựng lại để cập nhật model. Bấm tường 1 của lần nối kế, Esc kết thúc.';
    phase = 'first'; trimA = null;
  }
  // free: hình học; horizontal: phần tử nằm ngang; click: điểm bấm; cross: tọa độ tim phần tử kia (cắt dọc phương này); otherT: bề dày phần tử kia;
  // butt: dừng ở mặt gần (true) hay chạy tới mặt xa (false). Trả về đoạn giữ lại {lo, hi} hoặc null nếu bị triệt tiêu.
  function trimEnd(free, horizontal, click, cross, otherT, butt) {
    var lo = horizontal ? Math.min(free.a[0], free.b[0]) : Math.min(free.a[1], free.b[1]), hi = horizontal ? Math.max(free.a[0], free.b[0]) : Math.max(free.a[1], free.b[1]);
    var c = horizontal ? click[0] : click[1], keepLow = c < cross;
    var end = keepLow ? (butt ? cross - otherT / 2 : cross + otherT / 2) : (butt ? cross + otherT / 2 : cross - otherT / 2), far = keepLow ? lo : hi;
    if (keepLow ? far >= end - 1 : far <= end + 1) return null;
    return keepLow ? {lo: far, hi: end} : {lo: end, hi: far};
  }
  function writeTrim(shape, oldFree, seg, horizontal) {
    var l = lvl(), b = box(shape.kind), pick = b[shape.ref], cross = horizontal ? oldFree.a[1] : oldFree.a[0];
    var nf = horizontal ? {a: [round(seg.lo), cross], b: [round(seg.hi), cross]} : {a: [cross, round(seg.lo)], b: [cross, round(seg.hi)]};
    var oldStart = wallStart(oldFree), newStart = wallStart(nf), ty = typeOfPick(shape), ref = shape.ref;
    if (!isFree(pick)) { var np = {free: nf}; if (ty) np.type = ty; delete b[shape.ref]; ref = newId(shape.kind); b[ref] = np; } else pick.free = nf;
    if (shape.kind === 'wall') Object.keys(l.openingPicks).forEach(function (id) {
      var e = l.openingPicks[id]; if (e.wall !== shape.ref) return;
      e.wall = ref; e.pos = round(e.pos + (oldStart - newStart)); // đầu tường đổi chỗ: giữ cửa đúng chỗ cũ
    });
  }

  // ---- Match ----
  function matchClick(w) {
    var hit = host.shapeAt(w); if (!hit || !(PICKS[hit.kind] || hit.kind === 'opening')) { note = 'Bấm vào một cột, dầm, tường, sàn, trần hoặc cửa.'; return; }
    var l = lvl(), b = hit.kind === 'opening' ? l.openingPicks : l[PICKS[hit.kind]], pick = b[hit.ref];
    if (!pick) return;
    if (phase === 'source') { source = {kind: hit.kind, ref: hit.ref, pick: clone(pick), title: hit.title}; phase = 'targets'; return; }
    if (hit.kind !== source.kind) { note = 'Phần tử mẫu là ' + source.title + ': chỉ nhận được phần tử cùng loại.'; return; }
    if (hit.ref === source.ref) { note = 'Đây là phần tử mẫu.'; return; }
    var src = source.pick, either = isFree(pick) || isFree(src);
    host.mutate(function () {
      if (hit.kind === 'opening') { pick.type = src.type; pick.flip = !!src.flip; return; }
      (either ? ['type'] : ['type', 'x', 'y', 'p']).forEach(function (k) { if (k in src) pick[k] = src[k]; else delete pick[k]; }); // phần tử tự do không có "vị trí theo quy ước lưới"
    });
    note = 'Đã áp dụng loại' + (either ? '' : ' và vị trí') + ' của ' + source.title + ' cho ' + hit.title + '.';
  }

  function options(t) {
    if (t === 'array') return [{id: 'count', label: 'Số bản', kind: 'number', value: opt.count, min: 1, max: 50}];
    if (t === 'mirror') return [{id: 'keep', label: 'Giữ bản gốc', kind: 'checkbox', value: opt.keep}];
    if (t === 'offset') return [{id: 'distance', label: 'Khoảng cách (mm)', kind: 'number', value: opt.distance, min: 1, max: 100000}, {id: 'copy', label: 'Sao chép', kind: 'checkbox', value: opt.copy}];
    if (t === 'rotate') return [{id: 'angle', label: 'Góc (độ, ngược chiều kim đồng hồ)', kind: 'number', value: Number(opt.angle), min: -360, max: 360}, {id: 'copy', label: 'Sao chép', kind: 'checkbox', value: opt.copy}];
    return [];
  }
  function setOption(t, id, value) {
    if (id === 'count') opt.count = Math.max(1, Math.min(50, Math.round(Number(value)) || 1));
    else if (id === 'distance') opt.distance = Math.max(1, Math.min(100000, Number(value) || 1000));
    else if (id === 'keep') opt.keep = !!value; else if (id === 'copy') opt.copy = !!value; else if (id === 'angle') opt.angle = String(value);
  }
  // Gõ số + Enter ở ô nhập: Offset = khoảng cách (dời về phía con trỏ).
  function typed(n) {
    if (tool === 'offset' && phase === 'side') { if (!cursorW) { note = 'Hãy rê chuột về phía cần dời rồi gõ khoảng cách.'; return false; } opt.distance = n; return applyOffset(n, cursorW); }
    note = tool ? NAMES[tool] + ': ô nhập số dùng cho Offset (khoảng cách).' : ''; return false;
  }

  function nodeBoth() { return base && cursorW && !!nodeAtPoint(base.p) && !!nodeAtPoint(pointAt(cursorW)); }
  function hint() {
    if (!tool) return note;
    if (note) return note;
    var nm = NAMES[tool], n = input.length;
    if (tool === 'match') return phase === 'source' ? 'Match: bấm phần tử MẪU (cột, dầm, tường, sàn, trần hoặc cửa). Esc kết thúc.' : 'Match: bấm các phần tử cùng loại với ' + source.title + ' để áp dụng loại và vị trí. Esc kết thúc.';
    if (tool === 'align') return phase === 'ref' ? 'Align: bấm một cạnh, trục hoặc đường gióng (ngang / dọc) làm đường chuẩn. Esc kết thúc.' : 'Align: bấm cột, dầm hoặc tường cần căn tới đường chuẩn (có thể bấm nhiều phần tử). Esc kết thúc.';
    if (tool === 'trim') return phase === 'first' ? 'Trim nối góc L: bấm tường / dầm 1 (chạy suốt tới mặt ngoài), đúng phần muốn GIỮ. Esc kết thúc.' : 'Trim: bấm tường / dầm 2 (dừng ở mặt phần tử 1), đúng phần muốn giữ. Esc hủy.';
    if (phase === 'axis') return nm + ' ' + n + ' phần tử: bấm một trục của lưới (hoặc đường gióng ngang / dọc) làm trục đối xứng (' + (opt.keep ? 'giữ' : 'bỏ') + ' bản gốc). Esc hủy.';
    if (phase === 'base') return nm + ' ' + n + ' phần tử: bấm điểm GỐC (bắt điểm). Esc hủy.';
    if (phase === 'target') return nm + ': bấm điểm ĐÍCH' + (nodeBoth() ? ' (hai giao điểm lưới: phần tử theo lưới dịch theo ô)' : ' (phần tử theo lưới sẽ được mở khóa rồi dịch tự do)') + (tool === 'array' ? '; nhân ' + opt.count + ' bản' : '') + '. Esc hủy.';
    if (phase === 'side') return 'Offset ' + n + ' phần tử ' + opt.distance + ' mm: bấm phía cần dời (hoặc gõ khoảng cách + Enter). ' + (opt.copy ? 'Có sao chép.' : 'Dời tại chỗ.') + ' Esc hủy.';
    if (phase === 'center') return 'Rotate ' + n + ' phần tử ' + opt.angle + '°: bấm tâm xoay (bắt điểm). Esc hủy.';
    return '';
  }

  // Hình xem trước: phần tử ở vị trí đích. Xanh = được, đỏ = bị bỏ qua.
  function geometry(g, cls, i, j) {
    var x = function (k) { return g.ox + g.gx[k].offset; }, y = function (k) { return g.oy + g.gy[k].offset; };
    if (cls === 'column') return {t: 'dot', p: [x(i), y(j)], r: 6};
    if (cls === 'xspan') return {t: 'line', a: [x(i), y(j)], b: [x(i + 1), y(j)], width: 6};
    if (cls === 'yspan') return {t: 'line', a: [x(i), y(j)], b: [x(i), y(j + 1)], width: 6};
    return {t: 'poly', poly: [[x(i), y(j)], [x(i + 1), y(j)], [x(i + 1), y(j + 1)], [x(i), y(j + 1)]], alpha: 0.18};
  }
  function ghostPolys(fn) { return input.filter(function (s) { return ITEMS[s.kind]; }).map(function (s) { return {t: 'poly', poly: movePoly(s.poly, fn), color: OK, alpha: 0.35}; }); }
  function refLine(r, bounds) { return r.dir === 'x' ? {t: 'line', a: [r.pos, bounds[1] - 500], b: [r.pos, bounds[3] + 500], color: OK, dash: [10, 5], width: 2} : {t: 'line', a: [bounds[0] - 500, r.pos], b: [bounds[2] + 500, r.pos], color: OK, dash: [10, 5], width: 2}; }
  function ghost() {
    var out = []; if (!tool) return out;
    var g = grid(), cur = cursorW ? pointAt(cursorW) : null;
    if (phase === 'axis' && axis) {
      out.push(refLine(axis, host.bounds())); out = out.concat(ghostPolys(reflect(axis)));
      if (axis.index !== null) { // ô lưới của sàn, trần: xem trước theo chỉ số
        var op = {type: 'mirror', dir: axis.dir, index: axis.index};
        plan(input.filter(function (s) { return !isFree(pickOf(s)); }), op, opt.keep).moves.forEach(function (mv) { var m = mapped(g, mv.d, op); if (m.cls === 'cell') { var geo = geometry(g, m.cls, m.i, m.j); geo.color = OK; out.push(geo); } });
      }
    }
    if (base && (phase === 'target' || phase === 'base' || phase === 'center')) out.push({t: 'dot', p: base.p, color: OK, r: 6});
    if (phase === 'target' && base && cur) {
      out.push({t: 'line', a: base.p, b: cur, color: OK, dash: [4, 3], width: 1.5});
      var v = [cur[0] - base.p[0], cur[1] - base.p[1]], bn = nodeAtPoint(base.p), tn = nodeAtPoint(cur), nm = !!(bn && tn), times = tool === 'array' ? opt.count : 1;
      for (var k = 1; k <= times; k++) {
        if (nm) {
          var step = {type: 'shift', di: (tn.i - bn.i) * k, dj: (tn.j - bn.j) * k}, pl = plan(input, step, tool !== 'move');
          pl.moves.forEach(function (mv) { var m = mapped(g, mv.d, step), geo = geometry(g, m.cls, m.i, m.j); geo.color = OK; geo.alpha = geo.alpha || 0.6; out.push(geo); });
          pl.skipped.forEach(function (s) { var d = describe(g, s.shape); if (!d) return; var m = mapped(g, d, step); if (inRange(g, m.cls, m.i, m.j)) { var geo = geometry(g, m.cls, m.i, m.j); geo.color = BAD; geo.alpha = 0.5; out.push(geo); } });
          input.filter(function (s) { return isFree(pickOf(s)); }).forEach(function (s) { out.push({t: 'poly', poly: movePoly(s.poly, translate(v[0] * k, v[1] * k)), color: OK, alpha: 0.35}); });
        } else out = out.concat(ghostPolys(translate(v[0] * k, v[1] * k)));
      }
    }
    if (phase === 'side' && cursorW) linearShapes(input).forEach(function (s) { var f = geomOf(s); if (f) out.push({t: 'poly', poly: movePoly(s.poly, offsetFn(f, cursorW, opt.distance)), color: OK, alpha: 0.35}); });
    if (phase === 'center' && base) out = out.concat(ghostPolys(rotateAbout(base.p, Number(opt.angle))));
    if (alignRef && phase === 'element') out.push(refLine(alignRef, host.bounds()));
    if (tool === 'trim' && trimA) out.push({t: 'poly', poly: trimA.shape.poly, color: OK, alpha: 0.3});
    return out;
  }

  // ---- Kích thước tạm thời (Temporary Dimensions) ----
  function items(key) { return (S.preview && S.preview[key] && S.preview[key].items) || []; }
  function dimOf(a, b, side, off, editable, extra) {
    var item = {a: [a[0] + side[0] * off, a[1] + side[1] * off], b: [b[0] + side[0] * off, b[1] + side[1] * off], from: a, to: b, value: round(Math.hypot(b[0] - a[0], b[1] - a[1])), editable: !!editable};
    return Object.assign(item, extra || {});
  }
  // Kích thước tạm thời cho MỘT phần tử đang chọn. Cửa: tới hai đầu tường, sửa được. Dầm / tường TỰ DO: chiều dài sửa được (đổi đầu b). Còn lại chỉ xem.
  function freeGeom(shape) { var pk = PICKS[shape.kind] ? pickOf(shape) : null; return pk && pk.free ? pk.free : null; }
  function tempDims(shape) {
    if (!shape) return [];
    if (shape.kind === 'opening') {
      var o = items('openings').filter(function (i) { return i.ref === shape.ref; })[0], w = o && items('walls').filter(function (i) { return i.ref === o.wall; })[0];
      if (!o || !w) return [];
      if (w.dir === 'o') { // tường xiên: kích thước đo dọc theo tường, đặt lệch về phía pháp tuyến
        var len = w.length, ux = (w.b[0] - w.a[0]) / len, uy = (w.b[1] - w.a[1]) / len, nrm = [-uy, ux], at = function (t) { return [w.a[0] + ux * t, w.a[1] + uy * t]; };
        var l0 = o.pos - o.w / 2, l1 = o.pos + o.w / 2, offO = 450 + w.t / 2;
        return [
          dimOf(at(0), at(l0), nrm, offO, true, {id: 'left', opening: o.ref, value: round(l0)}),
          dimOf(at(l1), at(len), nrm, offO, true, {id: 'right', opening: o.ref, value: round(len - l1)}),
          dimOf(at(l0), at(l1), nrm, offO + 350, false, {id: 'width', value: round(o.w)})
        ];
      }
      var h = w.dir === 'x', key = h ? 0 : 1, cross = h ? 1 : 0, side = h ? [0, 1] : [1, 0], off = 450 + w.t / 2;
      var pt = function (u) { var p = [0, 0]; p[key] = u; p[cross] = w.center; return p; };
      var a0 = o.min[key], a1 = o.max[key];
      return [
        dimOf(pt(w.start), pt(a0), side, off, true, {id: 'left', opening: o.ref, value: round(a0 - w.start)}),
        dimOf(pt(a1), pt(w.finish), side, off, true, {id: 'right', opening: o.ref, value: round(w.finish - a1)}),
        dimOf(pt(a0), pt(a1), side, off + 350, false, {id: 'width', value: round(o.w)})
      ];
    }
    var sp = freeGeom(shape);
    if (sp && sp.a && !isOrtho(sp)) { // dầm / tường xiên: chiều dài dọc theo đoạn (sửa được, đổi đầu b)
      var ln = wallLength(sp), nn = [-(sp.b[1] - sp.a[1]) / ln, (sp.b[0] - sp.a[0]) / ln];
      return [dimOf(sp.a, sp.b, nn, 350, true, {id: 'length', value: round(ln), shape: {kind: shape.kind, ref: shape.ref}})];
    }
    if (sp && sp.x !== undefined && (sp.rot || 0) % 90 !== 0) return []; // cột xoay góc bất kỳ: hộp bao không phản ánh kích thước thật, xem ở bảng Thuộc tính
    var b = shapeBox(shape.poly), w2 = b[2] - b[0], h2 = b[3] - b[1], out = [], freeLinear = !!(LINEAR[shape.kind] && isFree(pickOf(shape))), tag = freeLinear ? {kind: shape.kind, ref: shape.ref} : null;
    if (w2 >= h2 * 0.25) out.push(dimOf([b[0], b[1]], [b[2], b[1]], [0, -1], 350, freeLinear && w2 >= h2, {id: freeLinear && w2 >= h2 ? 'length' : 'w', value: round(w2), shape: tag}));
    if (h2 >= w2 * 0.25) out.push(dimOf([b[2], b[1]], [b[2], b[3]], [1, 0], 350, freeLinear && h2 > w2, {id: freeLinear && h2 > w2 ? 'length' : 'h', value: round(h2), shape: tag}));
    return out;
  }
  function commitDim(dim, text) {
    var v = Number(String(text).trim().replace(',', '.'));
    if (!isFinite(v) || v < 0) return 'Hãy gõ một số không âm (mm).';
    if (dim.id === 'length') { // dầm / tường tự do: đổi chiều dài, giữ đầu a
      if (v < 100) return 'Chiều dài tối thiểu 100 mm.';
      var pick = box(dim.shape.kind)[dim.shape.ref]; if (!pick || !pick.free) return 'Phần tử không còn.';
      var f = pick.free, cur = wallLength(f), k = v / cur;
      if (Math.abs(cur - v) < 0.05) return null;
      host.mutate(function () { pick.free = {a: f.a, b: [round(f.a[0] + (f.b[0] - f.a[0]) * k), round(f.a[1] + (f.b[1] - f.a[1]) * k)]}; });
      return null;
    }
    var o = items('openings').filter(function (i) { return i.ref === dim.opening; })[0], w = o && items('walls').filter(function (i) { return i.ref === o.wall; })[0];
    var op = lvl().openingPicks[dim.opening]; if (!o || !w || !op) return 'Cửa không còn trên tường.';
    var pos = dim.id === 'left' ? v + o.w / 2 : w.length - v - o.w / 2; pos = round(pos);
    if (pos - o.w / 2 < 0 || pos + o.w / 2 > w.length) return 'Cửa rộng ' + o.w + ' mm không nằm trọn trong tường dài ' + w.length + ' mm.';
    var clash = A.wallOpenings(w.ref).some(function (e) { return e.id !== dim.opening && !(pos + o.w / 2 + GAP <= e.x0 || pos - o.w / 2 >= e.x1 + GAP); });
    if (clash) return 'Chồng hoặc sát cửa khác (cần cách nhau ít nhất ' + GAP + ' mm).';
    host.mutate(function () { op.pos = pos; });
    return null;
  }

  window.VGDPlanModify = {
    init: function (h) { host = h; S = h.state; A = h.api; },
    handles: handles, activate: activate, cancel: cancel, busy: busy, active: active, click: click, move: move, hint: hint, ghost: ghost, options: options, setOption: setOption, typed: typed,
    tempDims: tempDims, commitDim: commitDim,
    // Dùng cho test.
    _plan: function (sel, op, keep) { var p = plan(sel, op, keep); return {moves: p.moves.map(function (m) { return [m.shape.kind, m.from, m.to]; }), skipped: p.skipped.map(function (s) { return [s.shape.ref, s.why]; })}; },
    _trimEnd: trimEnd,
    debug: function () { return {tool: tool, phase: phase, base: base && base.p, target: target && target.p, axis: axis && axis.dir + ':' + axis.name, source: source && source.ref, note: note, opt: clone(opt), alignRef: alignRef, trim: trimA && trimA.shape.ref}; }
  };
})();
