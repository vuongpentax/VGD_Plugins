// Nét 2D và ghi chú trên mặt bằng (cột mốc P5b): Line, Polyline, Chữ nhật, Đường tròn, Cung, Kích thước, Chữ, Cốt cao độ.
// Dữ liệu lưu theo tầng ở `level.notes` ({mã 'an_xxxxxxxx' => ghi chú}); CHỈ là chú thích 2D trong dữ liệu plugin, KHÔNG dựng vào model SketchUp.
// Mọi thay đổi đi qua host.mutate (có hoàn tác); Ruby (Levels.notes!) kiểm tra lại khi lưu. Module có cùng giao diện công cụ với plan_edit.js
// (handles / activate / move / click / hint / ghost / options ...) nên cửa sổ mặt bằng dùng chung đường dẫn xử lý.
(function () {
  'use strict';
  var host = null, S = null, A = null;
  var TOOLS = ['line', 'polyline', 'rect', 'circle', 'arc', 'dim', 'text', 'level'];
  var GOOD = '#2F7BFF', BAD = '#E5484D', INK = '#6B7A99';
  var opt = {line: {ortho: false}, polyline: {ortho: false}, dim: {ortho: false}, text: {h: 250}, level: {z: null}};
  var tool = null, pts = [], target = null, note = '', promptToken = 0, prompting = false;
  var NAMES = {line: 'Nét', poly: 'Đa tuyến', circle: 'Đường tròn', arc: 'Cung', text: 'Chữ', dim: 'Kích thước', mark: 'Cốt cao độ'};

  function lvl() { return A.level(); }
  function box() { var l = lvl(); if (!l.notes) l.notes = {}; return l.notes; }
  function dist(a, b) { return Math.hypot(a[0] - b[0], a[1] - b[1]); }
  function r1(v) { return Math.round(v * 10) / 10; }
  function r2(v) { return Math.round(v * 100) / 100; }
  function tol(px) { return px / host.scale(); }
  function norm360(d) { return ((d % 360) + 360) % 360; }
  function deg(a, b) { return Math.atan2(b[1] - a[1], b[0] - a[0]) * 180 / Math.PI; }
  function unitOf(a, b) { var l = dist(a, b) || 1; return [(b[0] - a[0]) / l, (b[1] - a[1]) / l]; }
  function fmtZ(z) { return z === 0 ? '±0.000' : (z > 0 ? '+' : '-') + Math.abs(z / 1000).toFixed(3); }
  function say(m) { note = m; }

  // ---- Hình học của từng ghi chú (dùng chung cho vẽ, chọn, bắt điểm) ----
  function arcSweep(n) { var a1 = n.a1 <= n.a0 ? n.a1 + 360 : n.a1; return [n.a0, a1]; }
  function arcPoint(n, d) { var r = d * Math.PI / 180; return [n.c[0] + n.r * Math.cos(r), n.c[1] + n.r * Math.sin(r)]; }
  function circlePoly(c, r, steps) { var out = []; for (var i = 0; i < steps; i++) { var t = i / steps * 2 * Math.PI; out.push([c[0] + r * Math.cos(t), c[1] + r * Math.sin(t)]); } return out; }
  function textBox(n) { // hình chữ nhật bao của chữ (ước lượng: rộng ~ 0,55 x cao x số ký tự), xoay theo n.rot, góc trái-dưới tại n.p
    var w = n.text.length * n.h * 0.55, h = n.h, r = (n.rot || 0) * Math.PI / 180, cs = Math.cos(r), sn = Math.sin(r);
    return [[0, 0], [w, 0], [w, h], [0, h]].map(function (q) { return [n.p[0] + q[0] * cs - q[1] * sn, n.p[1] + q[0] * sn + q[1] * cs]; });
  }
  function dimGeom(n) { // đường kích thước song song với a-b, lệch off theo pháp tuyến
    var u = unitOf(n.a, n.b), nrm = [-u[1], u[0]], A2 = [n.a[0] + nrm[0] * n.off, n.a[1] + nrm[1] * n.off], B2 = [n.b[0] + nrm[0] * n.off, n.b[1] + nrm[1] * n.off];
    return {u: u, n: nrm, A: A2, B: B2, len: dist(n.a, n.b), sgn: n.off >= 0 ? 1 : -1};
  }
  function markBox(n) { return [[n.p[0] - 150, n.p[1]], [n.p[0] + 1100, n.p[1]], [n.p[0] + 1100, n.p[1] + 420], [n.p[0] - 150, n.p[1] + 420]]; }
  function segDist(p, a, b) {
    var dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy, t = l2 ? Math.max(0, Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2)) : 0;
    return Math.hypot(p[0] - (a[0] + dx * t), p[1] - (a[1] + dy * t));
  }
  function inPoly(poly, x, y) {
    var c = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) { var a = poly[i], b = poly[j]; if ((a[1] > y) !== (b[1] > y) && x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]) c = !c; }
    return c;
  }
  function mid(a, b) { return [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]; }

  // Một hình cho cửa sổ mặt bằng: {layer, kind, ref, poly, title, rows, text, hit(x, y, tol), snaps, edges}.
  function shapeOf(id, n) {
    var s = {layer: 'note', kind: 'note', ref: id, note: n, title: NAMES[n.t] + ' ' + id, rows: [['Loại', NAMES[n.t]]], text: NAMES[n.t], snaps: [], edges: []};
    function ends(list) { list.forEach(function (p) { s.snaps.push({p: p, rank: 0, text: 'Đầu mút'}); }); }
    function edge(a, b) { s.edges.push([a, b]); s.snaps.push({p: mid(a, b), rank: 2, text: 'Trung điểm'}); }
    if (n.t === 'line') {
      s.poly = [n.a, n.b]; ends([n.a, n.b]); edge(n.a, n.b); s.rows.push(['Dài', r1(dist(n.a, n.b)) + ' mm']);
      s.hit = function (x, y, t) { return segDist([x, y], n.a, n.b) <= t; };
    } else if (n.t === 'poly') {
      s.poly = n.pts; ends(n.pts); for (var i = 0; i + 1 < n.pts.length; i++) edge(n.pts[i], n.pts[i + 1]); if (n.closed) edge(n.pts[n.pts.length - 1], n.pts[0]);
      s.rows.push(['Số điểm', String(n.pts.length)], ['Khép kín', n.closed ? 'Có' : 'Không']);
      s.hit = function (x, y, t) { for (var k = 0; k + 1 < n.pts.length; k++) if (segDist([x, y], n.pts[k], n.pts[k + 1]) <= t) return true; return n.closed && segDist([x, y], n.pts[n.pts.length - 1], n.pts[0]) <= t; };
    } else if (n.t === 'circle') {
      s.poly = circlePoly(n.c, n.r, 36); s.snaps.push({p: n.c, rank: 2, text: 'Tâm'});
      [0, 90, 180, 270].forEach(function (d) { s.snaps.push({p: arcPoint({c: n.c, r: n.r}, d), rank: 0, text: 'Góc phần tư'}); });
      s.rows.push(['Bán kính', r1(n.r) + ' mm']);
      s.hit = function (x, y, t) { return Math.abs(dist([x, y], n.c) - n.r) <= t; };
    } else if (n.t === 'arc') {
      var sw = arcSweep(n), poly = []; for (var q = 0; q <= 24; q++) poly.push(arcPoint(n, sw[0] + (sw[1] - sw[0]) * q / 24));
      s.poly = poly; s.snaps.push({p: n.c, rank: 2, text: 'Tâm'}, {p: poly[0], rank: 0, text: 'Đầu mút'}, {p: poly[24], rank: 0, text: 'Đầu mút'}, {p: poly[12], rank: 2, text: 'Giữa cung'});
      s.rows.push(['Bán kính', r1(n.r) + ' mm'], ['Góc quét', r2(sw[1] - sw[0]) + '°']);
      s.hit = function (x, y, t) {
        if (Math.abs(dist([x, y], n.c) - n.r) > t) return false;
        var a = norm360(deg(n.c, [x, y])), from = norm360(sw[0]), span = sw[1] - sw[0], rel = norm360(a - from);
        return rel <= span;
      };
    } else if (n.t === 'text') {
      s.poly = textBox(n); s.snaps.push({p: n.p, rank: 0, text: 'Đầu mút'}); s.title = 'Chữ “' + n.text + '”'; s.text = s.title;
      s.rows.push(['Nội dung', n.text], ['Cao chữ', n.h + ' mm']);
      s.hit = function (x, y) { return inPoly(s.poly, x, y); };
    } else if (n.t === 'dim') {
      var g = dimGeom(n); s.poly = [g.A, g.B, [g.B[0] + g.n[0] * 1, g.B[1] + g.n[1] * 1], [g.A[0] + g.n[0] * 1, g.A[1] + g.n[1] * 1]];
      ends([n.a, n.b, g.A, g.B]); s.edges.push([g.A, g.B]); s.snaps.push({p: mid(g.A, g.B), rank: 2, text: 'Trung điểm'});
      s.title = 'Kích thước ' + Math.round(g.len) + ' mm'; s.text = s.title; s.rows = [['Loại', 'Kích thước'], ['Chiều dài', r1(g.len) + ' mm'], ['Độ lệch', r1(n.off) + ' mm']];
      s.hit = function (x, y, t) { var p = [x, y]; return segDist(p, g.A, g.B) <= t || segDist(p, n.a, g.A) <= t || segDist(p, n.b, g.B) <= t; };
    } else { // mark
      s.poly = markBox(n); s.snaps.push({p: n.p, rank: 0, text: 'Đầu mút'}); s.title = 'Cốt cao độ ' + fmtZ(n.z); s.text = s.title;
      s.rows.push(['Cao độ', n.z + ' mm (' + fmtZ(n.z) + ' m)']);
      s.hit = function (x, y) { return inPoly(s.poly, x, y); };
    }
    return s;
  }
  function shapes() { var b = box(); return Object.keys(b).map(function (id) { return shapeOf(id, b[id]); }); }

  // ---- Vẽ ghi chú lên canvas (g: {ctx, toScreen, scale}) ----
  function draw(g) {
    var ctx = g.ctx, ts = g.toScreen, s = g.scale, b = box();
    function line(p, q) { var a = ts(p[0], p[1]), c = ts(q[0], q[1]); ctx.moveTo(a[0], a[1]); ctx.lineTo(c[0], c[1]); }
    function label(text, wp, rotDeg, worldH, align, base) {
      var q = ts(wp[0], wp[1]), px = Math.max(9, worldH * s); ctx.save(); ctx.translate(q[0], q[1]); ctx.rotate(-rotDeg * Math.PI / 180);
      ctx.font = Math.round(px) + 'px sans-serif'; ctx.textAlign = align || 'left'; ctx.textBaseline = base || 'alphabetic'; ctx.fillStyle = INK; ctx.fillText(text, 0, 0); ctx.restore();
    }
    Object.keys(b).forEach(function (id) {
      if (g.hidden && g.hidden(id)) return;
      var n = b[id]; ctx.save(); ctx.strokeStyle = INK; ctx.fillStyle = INK; ctx.lineWidth = 1.3; ctx.beginPath();
      if (n.t === 'line') { line(n.a, n.b); ctx.stroke(); }
      else if (n.t === 'poly') { n.pts.forEach(function (p, i) { var q = ts(p[0], p[1]); if (i) ctx.lineTo(q[0], q[1]); else ctx.moveTo(q[0], q[1]); }); if (n.closed) ctx.closePath(); ctx.stroke(); }
      else if (n.t === 'circle') { var c = ts(n.c[0], n.c[1]); ctx.arc(c[0], c[1], n.r * s, 0, Math.PI * 2); ctx.stroke(); }
      else if (n.t === 'arc') { var ca = ts(n.c[0], n.c[1]), sw = arcSweep(n); ctx.arc(ca[0], ca[1], n.r * s, -sw[0] * Math.PI / 180, -sw[1] * Math.PI / 180, true); ctx.stroke(); }
      else if (n.t === 'text') { ctx.restore(); label(n.text, n.p, n.rot || 0, n.h, 'left', 'alphabetic'); return; }
      else if (n.t === 'dim') {
        var d = dimGeom(n), e = 120 * d.sgn, tick = 130;
        line([n.a[0] + d.n[0] * 80 * d.sgn, n.a[1] + d.n[1] * 80 * d.sgn], [d.A[0] + d.n[0] * e, d.A[1] + d.n[1] * e]); line([n.b[0] + d.n[0] * 80 * d.sgn, n.b[1] + d.n[1] * 80 * d.sgn], [d.B[0] + d.n[0] * e, d.B[1] + d.n[1] * e]); line(d.A, d.B);
        var t1 = [(d.u[0] + d.n[0]) * tick / 1.414, (d.u[1] + d.n[1]) * tick / 1.414];
        line([d.A[0] - t1[0], d.A[1] - t1[1]], [d.A[0] + t1[0], d.A[1] + t1[1]]); line([d.B[0] - t1[0], d.B[1] - t1[1]], [d.B[0] + t1[0], d.B[1] + t1[1]]); ctx.stroke(); ctx.restore();
        var ang = Math.atan2(d.u[1], d.u[0]) * 180 / Math.PI; if (ang > 90 || ang <= -90) ang += 180;
        label(String(Math.round(d.len)), mid(d.A, d.B), ang, 200, 'center', 'bottom'); return;
      } else { // mark: tam giác chỉ xuống, đuôi ngang và số cao độ phía trên đuôi
        var p = n.p, tip = ts(p[0], p[1]), l = ts(p[0] - 150, p[1] + 260), r = ts(p[0] + 150, p[1] + 260), tail = ts(p[0] + 1000, p[1] + 260);
        ctx.moveTo(tip[0], tip[1]); ctx.lineTo(l[0], l[1]); ctx.lineTo(r[0], r[1]); ctx.closePath(); ctx.moveTo(l[0], l[1]); ctx.lineTo(tail[0], tail[1]); ctx.stroke(); ctx.restore();
        label(fmtZ(n.z), [p[0] + 200, p[1] + 290], 0, 180, 'left', 'alphabetic'); return;
      }
      ctx.restore();
    });
  }

  // ---- Thanh tùy chọn ----
  function options(t) {
    if (t === 'line' || t === 'polyline' || t === 'dim') return [{id: 'ortho', label: 'Giữ ngang / dọc', kind: 'checkbox', value: opt[t === 'polyline' ? 'polyline' : t].ortho}];
    if (t === 'text') return [{id: 'h', label: 'Cao chữ (mm)', kind: 'number', value: opt.text.h, min: 50, max: 5000}];
    if (t === 'level') return [{id: 'z', label: 'Cao độ (mm)', kind: 'number', value: opt.level.z === null ? lvl().elevation : opt.level.z, min: -1000000, max: 1000000}];
    return [];
  }
  function setOption(t, id, value) {
    if (id === 'ortho') opt[t].ortho = !!value;
    else if (t === 'text' && id === 'h') opt.text.h = Math.max(50, Math.min(5000, Number(value) || 250));
    else if (t === 'level' && id === 'z') opt.level.z = isFinite(Number(value)) ? Number(value) : null;
  }

  // ---- Vẽ ----
  function handles(t) { return TOOLS.indexOf(t) >= 0; }
  function activate(t) { tool = handles(t) ? t : null; pts = []; target = null; note = ''; promptToken++; prompting = false; }
  function cancel() { pts = []; target = null; note = ''; promptToken++; prompting = false; }
  function busy() { return pts.length > 0 || prompting; }
  function freeMode() { return true; }
  function point(w) { var s2 = host.snapPoint(w) || w; return [r1(s2[0]), r1(s2[1])]; }
  function constrained(from, p) { // giữ ngang / dọc so với điểm trước nếu tùy chọn bật
    if (!opt[tool] || !opt[tool].ortho || !from) return p;
    return Math.abs(p[0] - from[0]) >= Math.abs(p[1] - from[1]) ? [p[0], from[1]] : [from[0], p[1]];
  }
  function create(item) {
    var id = A.rid('an_'); host.mutate(function () { box()[id] = item; });
    return id;
  }
  function move(w) {
    var p = point(w), last = pts[pts.length - 1];
    if (tool === 'line' || tool === 'polyline') p = constrained(last, p);
    if (tool === 'dim' && pts.length === 1) p = constrained(pts[0], p);
    var close = tool === 'polyline' && pts.length >= 3 && dist(w, pts[0]) <= tol(10);
    target = {p: close ? pts[0].slice() : p, close: close};
  }
  function click(w) {
    note = ''; if (!tool || prompting) return;
    move(w); var p = target.p;
    if (tool === 'line') {
      if (!pts.length) { pts = [p]; return; }
      if (dist(pts[0], p) < 1) { say('Hai đầu nét trùng nhau.'); return; }
      var len = r1(dist(pts[0], p)); create({t: 'line', a: pts[0].slice(), b: p.slice()}); pts = [p]; say('Đã thêm nét dài ' + len + ' mm. Bấm tiếp để nối chuỗi, Esc kết thúc.');
    } else if (tool === 'polyline') {
      if (target.close) { create({t: 'poly', pts: pts.map(function (q) { return q.slice(); }), closed: true}); pts = []; target = null; say('Đã thêm đường khép kín.'); return; }
      if (pts.length && dist(pts[pts.length - 1], p) < 1) return;
      pts.push(p.slice());
    } else if (tool === 'rect') {
      if (!pts.length) { pts = [p]; return; }
      var a = pts[0];
      if (Math.abs(p[0] - a[0]) < 1 || Math.abs(p[1] - a[1]) < 1) { say('Chữ nhật phải có rộng và cao khác 0.'); return; }
      create({t: 'poly', pts: [a.slice(), [p[0], a[1]], p.slice(), [a[0], p[1]]], closed: true}); pts = []; say('Đã thêm chữ nhật ' + r1(Math.abs(p[0] - a[0])) + ' × ' + r1(Math.abs(p[1] - a[1])) + ' mm.');
    } else if (tool === 'circle') {
      if (!pts.length) { pts = [p]; return; }
      var r = dist(pts[0], p); if (r < 1) { say('Bán kính quá nhỏ.'); return; }
      create({t: 'circle', c: pts[0].slice(), r: r1(r)}); pts = []; say('Đã thêm đường tròn bán kính ' + r1(r) + ' mm.');
    } else if (tool === 'arc') {
      if (pts.length < 2) { if (pts.length === 1 && dist(pts[0], p) < 1) { say('Điểm đầu trùng tâm.'); return; } pts.push(p); return; }
      var a0 = norm360(deg(pts[0], pts[1])), a1 = norm360(deg(pts[0], p));
      if (Math.abs(a1 - a0) < 0.01) { say('Điểm cuối cùng hướng với điểm đầu.'); return; }
      create({t: 'arc', c: pts[0].slice(), r: r1(dist(pts[0], pts[1])), a0: r2(a0), a1: r2(a1)}); pts = []; say('Đã thêm cung từ ' + r2(a0) + '° tới ' + r2(a1) + '° (ngược chiều kim đồng hồ).');
    } else if (tool === 'dim') {
      if (pts.length < 2) { if (pts.length === 1 && dist(pts[0], p) < 1) { say('Hai điểm trùng nhau.'); return; } pts.push(p); return; }
      var u = unitOf(pts[0], pts[1]), off = r1((p[0] - pts[0][0]) * -u[1] + (p[1] - pts[0][1]) * u[0]);
      create({t: 'dim', a: pts[0].slice(), b: pts[1].slice(), off: off}); say('Đã thêm kích thước ' + r1(dist(pts[0], pts[1])) + ' mm.'); pts = [];
    } else if (tool === 'text') {
      var token = ++promptToken, h = opt.text.h; prompting = true;
      host.promptText(p, '', function (text) {
        if (token !== promptToken) return; prompting = false;
        if (text === null) return; // Esc hoặc rời ô nhập: hủy, không báo
        text = String(text || '').replace(/[\u0000-\u001f\u007f]/g, ' ').trim();
        if (!text) { say('Chưa nhập nội dung chữ.'); return; }
        if (text.length > 200) { say('Chữ dài tối đa 200 ký tự.'); return; }
        create({t: 'text', p: p.slice(), text: text, h: h, rot: 0}); say('Đã thêm chữ.');
      });
    } else if (tool === 'level') {
      var z = opt.level.z === null ? lvl().elevation : opt.level.z;
      create({t: 'mark', p: p.slice(), z: z}); say('Đã đặt cốt cao độ ' + fmtZ(z) + ' m.');
    }
  }
  function undoPoint() { if (!pts.length) return false; pts.pop(); return true; }
  function finish() { // Enter: kết thúc đa tuyến hở
    if (tool !== 'polyline' || !pts.length) return false;
    if (pts.length < 2) { say('Đa tuyến cần ít nhất 2 điểm.'); return false; }
    create({t: 'poly', pts: pts.map(function (q) { return q.slice(); }), closed: false}); pts = []; target = null; say('Đã thêm đa tuyến.'); return true;
  }
  // Gõ số + Enter: nét / đa tuyến dài đúng n mm theo hướng con trỏ; đường tròn bán kính n.
  function typed(n, cursor) {
    if (!(n > 0)) { say('Hãy gõ một số dương (mm).'); return false; }
    var from = pts[pts.length - 1];
    if (!from || !cursor) { say('Hãy bấm điểm đầu trước rồi gõ số.'); return false; }
    var u = unitOf(from, cursor);
    if (dist(from, cursor) < 1e-6) { say('Hãy rê chuột theo hướng cần vẽ rồi gõ số.'); return false; }
    if (opt[tool] && opt[tool].ortho) u = Math.abs(u[0]) >= Math.abs(u[1]) ? [u[0] >= 0 ? 1 : -1, 0] : [0, u[1] >= 0 ? 1 : -1];
    var end = [r1(from[0] + u[0] * n), r1(from[1] + u[1] * n)];
    if (tool === 'line') { create({t: 'line', a: from.slice(), b: end}); pts = [end]; say('Đã thêm nét dài ' + n + ' mm.'); return true; }
    if (tool === 'polyline') { pts.push(end); return true; }
    if (tool === 'circle' && pts.length === 1) { create({t: 'circle', c: from.slice(), r: r1(n)}); pts = []; say('Đã thêm đường tròn bán kính ' + n + ' mm.'); return true; }
    say('Ô nhập số dùng cho Line, Polyline và Đường tròn.'); return false;
  }

  function hint() {
    if (!tool) return '';
    if (note) return note;
    var n = pts.length;
    if (tool === 'line') return n ? 'Line: bấm điểm cuối (hoặc gõ độ dài + Enter); bấm tiếp để nối chuỗi; Esc kết thúc.' : 'Line: bấm điểm đầu (bắt điểm đang bật). Esc kết thúc.';
    if (tool === 'polyline') return n ? 'Polyline: ' + n + ' điểm. Bấm điểm tiếp theo; bấm lại điểm đầu để KHÉP KÍN; Enter kết thúc (hở); Backspace bỏ điểm cuối; Esc hủy.' : 'Polyline: bấm từng điểm. Esc hủy.';
    if (tool === 'rect') return n ? 'Chữ nhật: bấm góc đối diện. Esc hủy.' : 'Chữ nhật: bấm một góc. Esc kết thúc.';
    if (tool === 'circle') return n ? 'Đường tròn: bấm một điểm trên đường tròn (hoặc gõ bán kính + Enter). Esc hủy.' : 'Đường tròn: bấm tâm. Esc kết thúc.';
    if (tool === 'arc') return n === 0 ? 'Cung: bấm tâm.' : n === 1 ? 'Cung: bấm điểm ĐẦU của cung (xác định bán kính).' : 'Cung: bấm điểm CUỐI (hướng so với tâm); cung chạy ngược chiều kim đồng hồ từ điểm đầu. Esc hủy.';
    if (tool === 'dim') return n === 0 ? 'Kích thước: bấm điểm đầu (bắt điểm đang bật).' : n === 1 ? 'Kích thước: bấm điểm cuối.' : 'Kích thước: bấm để chọn phía và độ lệch của đường kích thước. Esc hủy.';
    if (tool === 'text') return prompting ? 'Chữ: gõ nội dung rồi Enter (Esc hủy).' : 'Chữ: bấm vị trí rồi gõ nội dung. Cao chữ ở thanh tùy chọn.';
    return 'Cốt cao độ: bấm vị trí; cao độ đặt ở thanh tùy chọn (mặc định là cao độ tầng).';
  }
  function ringGhost(list, closed, color) {
    var out = []; for (var i = 0; i + 1 < list.length; i++) out.push({t: 'line', a: list[i], b: list[i + 1], color: color, width: 2});
    if (closed && list.length > 2) out.push({t: 'line', a: list[list.length - 1], b: list[0], color: color, width: 2});
    return out;
  }
  function ghost() {
    var g = [], p = target && target.p; if (!tool) return g;
    pts.forEach(function (q) { g.push({t: 'dot', p: q, color: GOOD, r: 4}); });
    if (p) g.push({t: 'dot', p: p, color: target.close ? '#2FA84F' : GOOD, r: target.close ? 7 : 5});
    if (!p || !pts.length) return g;
    var a = pts[0];
    if (tool === 'line') { g.push({t: 'line', a: pts[0], b: p, color: GOOD, width: 2}); g.push({t: 'text', p: p, text: r1(dist(pts[0], p)) + ' mm'}); }
    else if (tool === 'polyline') { g = g.concat(ringGhost(pts.concat(target.close ? [] : [p]), target.close, GOOD)); }
    else if (tool === 'rect') g.push({t: 'poly', poly: [a, [p[0], a[1]], p, [a[0], p[1]]], color: GOOD, alpha: 0.08});
    else if (tool === 'circle') { g.push({t: 'poly', poly: circlePoly(a, dist(a, p), 48), color: GOOD, alpha: 0.05}); g.push({t: 'text', p: p, text: 'R ' + r1(dist(a, p)) + ' mm'}); }
    else if (tool === 'arc') {
      if (pts.length === 1) g.push({t: 'line', a: a, b: p, color: GOOD, width: 1.5, dash: [4, 3]});
      else { var n = {c: a, r: dist(a, pts[1]), a0: norm360(deg(a, pts[1])), a1: norm360(deg(a, p))}; if (Math.abs(n.a1 - n.a0) > 0.01) { var sw = arcSweep(n), arc = []; for (var k = 0; k <= 32; k++) arc.push(arcPoint(n, sw[0] + (sw[1] - sw[0]) * k / 32)); g = g.concat(ringGhost(arc, false, GOOD)); } g.push({t: 'line', a: a, b: pts[1], color: GOOD, width: 1, dash: [4, 3]}); }
    } else if (tool === 'dim') {
      if (pts.length === 1) { g.push({t: 'line', a: pts[0], b: p, color: GOOD, width: 1.5, dash: [4, 3]}); g.push({t: 'text', p: p, text: r1(dist(pts[0], p)) + ' mm'}); }
      else if (pts.length === 2) { var u = unitOf(pts[0], pts[1]), off = (p[0] - pts[0][0]) * -u[1] + (p[1] - pts[0][1]) * u[0], d = dimGeom({a: pts[0], b: pts[1], off: off}); g.push({t: 'line', a: d.A, b: d.B, color: GOOD, width: 2}, {t: 'line', a: pts[0], b: d.A, color: GOOD, width: 1, dash: [3, 3]}, {t: 'line', a: pts[1], b: d.B, color: GOOD, width: 1, dash: [3, 3]}); }
    }
    return g;
  }

  // ---- Thuộc tính, xóa, biến đổi ----
  function field(id, label, kind, value, apply) { return {id: id, label: label, kind: kind, values: null, value: value, apply: apply}; }
  function propsFor(shape) {
    var n = box()[shape.ref]; if (!n) return [];
    function set(next) { host.mutate(function () { box()[shape.ref] = next; }); }
    function clone() { return JSON.parse(JSON.stringify(n)); }
    function num(id, label, getv, put, valid) { return field(id, label, 'number', getv, function (v) { if (!isFinite(v)) return; var next = clone(); put(next, v); if (valid && valid(next)) { host.say(valid(next)); return; } set(next); }); }
    var out = [];
    function xy(prefix, label, key) {
      out.push(num(prefix + 'x', label + ' · X (mm)', n[key][0], function (m, v) { m[key][0] = r1(v); }), num(prefix + 'y', label + ' · Y (mm)', n[key][1], function (m, v) { m[key][1] = r1(v); }));
    }
    if (n.t === 'line' || n.t === 'dim') {
      var short = function (m) { return dist(m.a, m.b) < 1 ? 'Hai điểm không được trùng nhau.' : ''; };
      out.push(num('ax', 'Điểm 1 · X (mm)', n.a[0], function (m, v) { m.a[0] = r1(v); }, short), num('ay', 'Điểm 1 · Y (mm)', n.a[1], function (m, v) { m.a[1] = r1(v); }, short),
               num('bx', 'Điểm 2 · X (mm)', n.b[0], function (m, v) { m.b[0] = r1(v); }, short), num('by', 'Điểm 2 · Y (mm)', n.b[1], function (m, v) { m.b[1] = r1(v); }, short));
      if (n.t === 'dim') out.push(num('off', 'Độ lệch (mm)', n.off, function (m, v) { m.off = r1(v); }));
    } else if (n.t === 'poly') {
      out.push(field('closed', 'Khép kín', 'checkbox', !!n.closed, function (v) { if (v && n.pts.length < 3) { host.say('Đường khép kín cần ít nhất 3 điểm.'); return; } var m = clone(); m.closed = !!v; set(m); }));
      if (n.pts.length <= 12) n.pts.forEach(function (p, i) {
        out.push(num('p' + i + 'x', 'Điểm ' + (i + 1) + ' · X (mm)', p[0], function (m, v) { m.pts[i][0] = r1(v); }), num('p' + i + 'y', 'Điểm ' + (i + 1) + ' · Y (mm)', p[1], function (m, v) { m.pts[i][1] = r1(v); }));
      });
    } else if (n.t === 'circle' || n.t === 'arc') {
      xy('c', 'Tâm', 'c');
      out.push(num('r', 'Bán kính (mm)', n.r, function (m, v) { m.r = r1(v); }, function (m) { return m.r < 1 ? 'Bán kính tối thiểu 1 mm.' : ''; }));
      if (n.t === 'arc') out.push(num('a0', 'Góc đầu (độ)', n.a0, function (m, v) { m.a0 = r2(norm360(v)); }, function (m) { return Math.abs(m.a0 - m.a1) < 0.01 ? 'Góc đầu và góc cuối không được trùng nhau.' : ''; }),
                                  num('a1', 'Góc cuối (độ)', n.a1, function (m, v) { m.a1 = r2(norm360(v)); }, function (m) { return Math.abs(m.a0 - m.a1) < 0.01 ? 'Góc đầu và góc cuối không được trùng nhau.' : ''; }));
    } else if (n.t === 'text') {
      out.push(field('text', 'Nội dung', 'text', n.text, function (v) { v = String(v).replace(/[\u0000-\u001f\u007f]/g, ' ').trim(); if (!v || v.length > 200) { host.say('Nội dung chữ từ 1 đến 200 ký tự.'); return; } var m = clone(); m.text = v; set(m); }));
      xy('p', 'Vị trí', 'p');
      out.push(num('h', 'Cao chữ (mm)', n.h, function (m, v) { m.h = r1(v); }, function (m) { return m.h < 50 || m.h > 5000 ? 'Cao chữ từ 50 đến 5000 mm.' : ''; }), num('rot', 'Xoay (độ)', n.rot || 0, function (m, v) { m.rot = r2(norm360(v)); }));
    } else {
      xy('p', 'Vị trí', 'p');
      out.push(num('z', 'Cao độ (mm)', n.z, function (m, v) { m.z = r1(v); }));
    }
    return out;
  }
  function remove(list) {
    var hits = list.filter(function (s) { return s.kind === 'note' && box()[s.ref]; });
    if (!hits.length) return 0;
    host.mutate(function () { hits.forEach(function (s) { delete box()[s.ref]; }); });
    return hits.length;
  }
  // Biến đổi một ghi chú bằng phép ánh xạ điểm fn (dời, xoay, lật). Trả về ghi chú mới.
  function transform(n, fn) {
    var m = function (p) { var q = fn(p); return [r1(q[0]), r1(q[1])]; };
    var o = fn([0, 0]), ox = fn([1, 0]), oy = fn([0, 1]), det = (ox[0] - o[0]) * (oy[1] - o[1]) - (ox[1] - o[1]) * (oy[0] - o[0]), delta = Math.atan2(ox[1] - o[1], ox[0] - o[0]) * 180 / Math.PI;
    var out = JSON.parse(JSON.stringify(n));
    if (n.t === 'line') { out.a = m(n.a); out.b = m(n.b); }
    else if (n.t === 'poly') out.pts = n.pts.map(m);
    else if (n.t === 'circle') out.c = m(n.c);
    else if (n.t === 'arc') {
      out.c = m(n.c);
      if (det > 0) { out.a0 = r2(norm360(n.a0 + delta)); out.a1 = r2(norm360(n.a1 + delta)); }
      else { out.a0 = r2(norm360(delta - n.a1)); out.a1 = r2(norm360(delta - n.a0)); } // phép lật đảo chiều quay: đầu và cuối đổi chỗ
    } else if (n.t === 'text') { out.p = m(n.p); if (det > 0) out.rot = r2(norm360((n.rot || 0) + delta)); }
    else if (n.t === 'dim') {
      var mid0 = mid(n.a, n.b), u = unitOf(n.a, n.b), probe = [mid0[0] - u[1] * n.off, mid0[1] + u[0] * n.off];
      out.a = m(n.a); out.b = m(n.b); var u2 = unitOf(out.a, out.b), mid2 = mid(out.a, out.b), pm = m(probe);
      out.off = r1((pm[0] - mid2[0]) * -u2[1] + (pm[1] - mid2[1]) * u2[0]);
    } else out.p = m(n.p);
    return out;
  }

  window.VGDPlanNotes = {
    init: function (h) { host = h; S = h.state; A = h.api; },
    handles: handles, activate: activate, cancel: cancel, busy: busy, freeMode: freeMode, options: options, setOption: setOption, move: move, click: click, hint: hint, ghost: ghost,
    typed: typed, finish: finish, undoPoint: undoPoint, propsFor: propsFor, remove: remove, shapes: shapes, draw: draw, transform: transform,
    debug: function () { return {tool: tool, points: pts.map(function (p) { return p.slice(); }), target: target && target.p, prompting: prompting, note: note, opt: JSON.parse(JSON.stringify(opt))}; }
  };
})();
