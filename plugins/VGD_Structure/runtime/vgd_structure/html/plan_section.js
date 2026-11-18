// Mặt cắt trên mặt bằng: công cụ đặt đường cắt (bấm điểm đầu, điểm cuối, rồi bấm về phía muốn nhìn) và vẽ ký hiệu mặt cắt. Dữ liệu lưu theo tầng ở
// `level.sections` ({mã 'sc_xxxxxxxx' => {name, a, b, dir, depth}}); CHỈ là định nghĩa đường cắt (Ruby: Levels.sections!), mặt cắt thật được dựng từ HÌNH trong
// SketchUp (SuSection) và xem ở tab Mặt cắt (section_view.js). Có cùng giao diện công cụ với plan_edit.js / plan_notes.js nên dùng chung đường dẫn xử lý của mặt bằng.
(function () {
  'use strict';
  var host = null, A = null;
  var tool = null, pts = [], target = null, note = '';
  var COLOR = '#D9534F';

  function lvl() { return A.level(); }
  function box() { var l = lvl(); if (!l.sections) l.sections = {}; return l.sections; }
  function dist(a, b) { return Math.hypot(a[0] - b[0], a[1] - b[1]); }
  function r1(v) { return Math.round(v * 10) / 10; }
  function normalOf(a, b) { var l = dist(a, b) || 1; return [-(b[1] - a[1]) / l, (b[0] - a[0]) / l]; } // pháp tuyến trái của a -> b
  function nextName() {
    var taken = {}; host.allSections().forEach(function (s) { taken[s.name.toLowerCase()] = true; });
    for (var i = 1; i < 1000; i++) { var n = 'Mặt cắt ' + i; if (!taken[n.toLowerCase()]) return n; }
    return 'Mặt cắt';
  }

  function handles(t) { return t === 'section'; }
  function activate(t) { tool = handles(t) ? t : null; pts = []; target = null; note = ''; }
  function cancel() { pts = []; target = null; note = ''; }
  function busy() { return pts.length > 0; }
  function freeMode() { return true; }
  function options() { return []; }
  function setOption() {}
  function point(w) { var q = host.snapPoint(w) || w; return [r1(q[0]), r1(q[1])]; }
  function move(w) { target = {p: point(w)}; }
  function click(w) {
    note = ''; if (!tool) return;
    move(w); var p = target.p;
    if (!pts.length) { pts = [p]; return; }
    if (pts.length === 1) {
      if (dist(pts[0], p) < 100) { note = 'Đường cắt quá ngắn (ít nhất 100 mm).'; return; }
      pts.push(p); return;
    }
    var a = pts[0], b = pts[1], n = normalOf(a, b), side = ((p[0] - a[0]) * n[0] + (p[1] - a[1]) * n[1]) >= 0 ? 1 : -1, id = A.rid('sc_'), name = nextName();
    host.mutate(function () { box()[id] = {name: name, a: a.slice(), b: b.slice(), dir: side, depth: 6000}; });
    pts = []; target = null; note = 'Đã đặt ' + name + ' dài ' + r1(dist(a, b)) + ' mm. Chọn mặt cắt rồi bấm Mở mặt cắt trong bảng Thuộc tính (hoặc bấm đúp).';
    if (host.sectionAdded) host.sectionAdded(id);
  }
  function hint() {
    if (!tool) return '';
    if (note) return note;
    return pts.length === 0 ? 'Mặt cắt: bấm điểm đầu của đường cắt.' : pts.length === 1 ? 'Mặt cắt: bấm điểm cuối của đường cắt.' : 'Mặt cắt: bấm về PHÍA muốn nhìn (mũi tên chỉ hướng nhìn).';
  }
  function typed() { return false; }
  function finish() { return false; }
  function undoPoint() { if (!pts.length) return false; pts.pop(); return true; }
  function ghost() {
    var g = [];
    if (!tool) return g;
    if (pts.length === 1 && target) g.push({t: 'line', a: pts[0], b: target.p, color: '#2F7BFF', width: 3});
    if (pts.length === 2) {
      g.push({t: 'line', a: pts[0], b: pts[1], color: '#2F7BFF', width: 3});
      if (target) { var n = normalOf(pts[0], pts[1]), m = [(pts[0][0] + pts[1][0]) / 2, (pts[0][1] + pts[1][1]) / 2], side = ((target.p[0] - pts[0][0]) * n[0] + (target.p[1] - pts[0][1]) * n[1]) >= 0 ? 1 : -1; g.push({t: 'line', a: m, b: [m[0] + n[0] * 600 * side, m[1] + n[1] * 600 * side], color: '#2F7BFF', width: 3}); }
    } else if (target && pts.length === 0) g.push({t: 'dot', p: target.p, color: '#2F7BFF', r: 5});
    pts.forEach(function (p) { g.push({t: 'dot', p: p, color: '#2F7BFF', r: 5}); });
    return g;
  }

  // ---- Hình để chọn và vẽ ----
  function shapeOf(id, s) {
    var len = r1(dist(s.a, s.b));
    return {layer: 'section', kind: 'section', ref: id, section: s, poly: [s.a, s.b], holes: null, title: s.name, text: s.name, snaps: [{p: s.a, rank: 0, text: 'Đầu mút'}, {p: s.b, rank: 0, text: 'Đầu mút'}], edges: [[s.a, s.b]],
      rows: [['Tên', s.name], ['Dài', len + ' mm'], ['Phía nhìn', s.dir === 1 ? 'Bên trái đường cắt (a → b)' : 'Bên phải đường cắt (a → b)'], ['Tầm nhìn', s.depth + ' mm']],
      hit: function (x, y, t) { var dx = s.b[0] - s.a[0], dy = s.b[1] - s.a[1], l2 = dx * dx + dy * dy, k = l2 ? Math.max(0, Math.min(1, ((x - s.a[0]) * dx + (y - s.a[1]) * dy) / l2)) : 0; return Math.hypot(x - (s.a[0] + k * dx), y - (s.a[1] + k * dy)) <= t; }};
  }
  function shapes() { var b = box(); return Object.keys(b).map(function (id) { return shapeOf(id, b[id]); }); }
  function draw(g) {
    var ctx = g.ctx, ts = g.toScreen, b = box();
    Object.keys(b).forEach(function (id) {
      if (g.hidden && g.hidden(id)) return;
      var s = b[id], a = ts(s.a[0], s.a[1]), c = ts(s.b[0], s.b[1]), n = normalOf(s.a, s.b), l = Math.hypot(c[0] - a[0], c[1] - a[1]) || 1, ux = (c[0] - a[0]) / l, uy = (c[1] - a[1]) / l;
      var nx = n[0], ny = -n[1]; // pháp tuyến trong tọa độ màn hình (trục y đảo)
      var side = s.dir === 1 ? 1 : -1, ax = nx * side, ay = ny * side;
      ctx.save(); ctx.strokeStyle = COLOR; ctx.fillStyle = COLOR; ctx.lineWidth = 1.6; ctx.setLineDash([10, 4, 2, 4]);
      ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(c[0], c[1]); ctx.stroke(); ctx.setLineDash([]); ctx.lineWidth = 2.2;
      [a, c].forEach(function (p) { // đầu mặt cắt: gạch ngắn vuông góc + mũi tên chỉ hướng nhìn
        ctx.beginPath(); ctx.moveTo(p[0], p[1]); ctx.lineTo(p[0] + ax * 22, p[1] + ay * 22); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(p[0] + ax * 22, p[1] + ay * 22); ctx.lineTo(p[0] + ax * 14 - ay * 5, p[1] + ay * 14 + ax * 5); ctx.lineTo(p[0] + ax * 14 + ay * 5, p[1] + ay * 14 - ax * 5); ctx.closePath(); ctx.fill();
      });
      ctx.font = '12px sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(s.name, (a[0] + c[0]) / 2 + ax * 14, (a[1] + c[1]) / 2 + ay * 14);
      ctx.restore();
    });
  }

  // ---- Thuộc tính, xóa ----
  function field(id, label, kind, value, apply) { return {id: id, label: label, kind: kind, values: null, value: value, apply: apply}; }
  function propsFor(shape) {
    var s = box()[shape.ref]; if (!s) return [];
    function set(patch) { host.mutate(function () { Object.assign(box()[shape.ref], patch); }); }
    return [
      {kind: 'button', id: 'open_section', label: 'Mở mặt cắt', apply: function () { host.openSection(lvl().id, shape.ref); }},
      field('sname', 'Tên', 'text', s.name, function (v) {
        v = String(v).trim();
        if (!v || v.length > 30 || /[\u0000-\u001f\u007f]/.test(v)) { host.say('Tên mặt cắt từ 1 đến 30 ký tự.'); return; }
        if (host.allSections().some(function (o) { return o.id !== shape.ref && o.name.toLowerCase() === v.toLowerCase(); })) { host.say('Tên mặt cắt “' + v + '” đã có.'); return; }
        set({name: v});
      }),
      field('sdepth', 'Tầm nhìn (mm)', 'number', s.depth, function (v) { if (!isFinite(v) || v < 100 || v > 100000) { host.say('Tầm nhìn từ 100 đến 100000 mm.'); return; } set({depth: r1(v)}); }),
      field('sdir', 'Đổi phía nhìn', 'checkbox', s.dir === -1, function (v) { set({dir: v ? -1 : 1}); })
    ];
  }
  function remove(list) {
    var hits = list.filter(function (x) { return x.kind === 'section' && box()[x.ref]; });
    if (!hits.length) return 0;
    host.mutate(function () { hits.forEach(function (x) { delete box()[x.ref]; }); });
    return hits.length;
  }

  window.VGDPlanSection = {
    init: function (h) { host = h; A = h.api; },
    handles: handles, activate: activate, cancel: cancel, busy: busy, freeMode: freeMode, options: options, setOption: setOption, move: move, click: click, hint: hint, ghost: ghost,
    typed: typed, finish: finish, undoPoint: undoPoint, propsFor: propsFor, remove: remove, shapes: shapes, draw: draw,
    debug: function () { return {tool: tool, points: pts.map(function (p) { return p.slice(); }), note: note}; }
  };
})();
