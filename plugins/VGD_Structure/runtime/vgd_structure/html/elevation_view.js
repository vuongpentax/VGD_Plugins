// Tab Mặt đứng: xem mặt đứng 2D dựng từ HÌNH THẬT trong SketchUp (Ruby: SuSection.elevation, ElevationGeometry). Không cắt: các mặt được tô từ xa đến gần,
// nên mặt phía trước che mặt phía sau (không che từng nét riêng). Bấm một mặt thì chọn đúng đối tượng đó trong SketchUp (cùng cách với mặt cắt),
// và chọn trong SketchUp thì mặt sáng lên. Không lưu dữ liệu: mỗi lần chọn hướng Ruby đọc lại model hiện tại.
(function () {
  'use strict';
  var host = null, S = null, canvas = null, ctx = null, size = {w: 800, h: 500, dpr: 1};
  var dir = null;                 // 'south' | 'north' | 'west' | 'east'
  var result = null;              // kết quả Ruby: {dir, polys: [{pts, holes, depth, src}] (xa đến gần), bounds, truncated}
  var view = {cx: 0, cy: 0, s: 0.1}, drag = null, selected = {}, tagNames = {};
  // Hướng nhìn: nhãn, và cách đổi tọa độ trục lưới sang ngang s (s = dấu * tọa độ trục). Giả định hướng Bắc của model là +Y (mặc định SketchUp).
  var DIRS = {south: {label: 'Nam', axis: 'x', sign: 1}, north: {label: 'Bắc', axis: 'x', sign: -1}, west: {label: 'Tây', axis: 'y', sign: -1}, east: {label: 'Đông', axis: 'y', sign: 1}};
  var COLORS = {column: '#66DD00', beam: '#00AABA', wall: '#FF9966', slab: '#BA3300', ceiling: '#9900FF', door: '#FF7766', window: '#CCBAED', opening: '#FF7766', suobj: '#8A93A0', geom: '#666666'};
  var TAG_KIND = function (tag) { var k = null; Object.keys(tagNames).forEach(function (kind) { if (String(tagNames[kind]).toLowerCase() === String(tag || '').toLowerCase()) k = kind; }); return k; };

  function $(id) { return document.getElementById(id); }
  function css(name, fb) { var v = getComputedStyle(document.documentElement).getPropertyValue(name).trim(); return v || fb; }
  function toScreen(s, z) { return [(s - view.cx) * view.s + size.w / 2, size.h / 2 - (z - view.cy) * view.s]; }
  function toWorld(px, py) { return [(px - size.w / 2) / view.s + view.cx, (size.h / 2 - py) / view.s + view.cy]; }
  function colorOf(src) { var k = src.kind === 'suobj' ? (TAG_KIND(src.tag) || 'suobj') : src.kind; return COLORS[k] || COLORS.geom; }
  // Màu tô đặc: pha màu loại với nền để mặt không chói (mặt phải đặc để che mặt phía sau).
  function mix(hex, bg, t) { if (!/^#[0-9a-f]{6}$/i.test(bg)) return hex; var a = parseInt(hex.slice(1), 16), b = parseInt(bg.slice(1), 16), out = '#'; [16, 8, 0].forEach(function (sh) { var x = (a >> sh) & 255, y = (b >> sh) & 255; out += ('0' + Math.round(x * t + y * (1 - t)).toString(16)).slice(-2); }); return out; }
  function keyOf(src) { return src.kind + '|' + (src.level || '') + '|' + (src.ref || ''); }

  function status(text) { $('elv-status').textContent = text; }
  function markDir() { document.querySelectorAll('#elv-dirs button').forEach(function (b) { b.setAttribute('aria-pressed', String(b.getAttribute('data-dir') === dir)); }); }
  function request() {
    if (!dir) { result = null; status('Chọn hướng nhìn: Nam, Bắc, Đông hoặc Tây.'); draw(); return; }
    status('Đang dựng mặt đứng ' + DIRS[dir].label + ' từ hình trong SketchUp...');
    host.call('elevation_build', {dir: dir});
  }
  function setDir(d) { dir = d; result = null; selected = {}; markDir(); request(); }
  function receive(data) {
    if (!dir || data.dir !== dir) return;
    result = data; selected = {};
    var n = data.polys.length;
    status('Mặt đứng ' + DIRS[dir].label + ': ' + n + ' mặt.' + (data.truncated ? ' Model quá lớn: đã bỏ bớt các mặt xa, hình có thể thiếu.' : '') + (!n ? ' Không có hình nào: kiểm tra model trong SketchUp.' : ''));
    fit(); draw();
  }
  function bounds() {
    var xs = [0, 1000], zs = [];
    S.levels.forEach(function (l) { zs.push(l.elevation - (l.screed || 0)); zs.push(l.elevation); });
    if (result && result.bounds) { xs = [result.bounds.s0, result.bounds.s1]; zs = zs.concat([result.bounds.z0, result.bounds.z1]); }
    var z0 = Math.min.apply(null, zs.length ? zs : [0]), z1 = Math.max.apply(null, zs.length ? zs : [3000]);
    return [Math.min.apply(null, xs), z0, Math.max.apply(null, xs), z1];
  }
  function fit() {
    var b = bounds(), w = Math.max(b[2] - b[0], 1), h = Math.max(b[3] - b[1], 1), pad = 50;
    view.s = Math.min(5, Math.max(0.001, Math.min((size.w - 2 * pad) / w, (size.h - 2 * pad) / h))); view.cx = (b[0] + b[2]) / 2; view.cy = (b[1] + b[3]) / 2;
  }
  function resize() {
    if (!canvas) return; var r = canvas.parentNode.getBoundingClientRect(); size.dpr = window.devicePixelRatio || 1;
    size.w = Math.max(100, r.width); size.h = Math.max(100, r.height); canvas.width = Math.round(size.w * size.dpr); canvas.height = Math.round(size.h * size.dpr); canvas.style.width = size.w + 'px'; canvas.style.height = size.h + 'px';
    draw();
  }

  function gridAxes() { // trục lưới trên mặt đứng: [{name, s}] (chỉ trục nằm trong khung)
    var out = []; if (!dir || !host.axes) return out;
    var d = DIRS[dir], b = bounds(), ax = host.axes()[d.axis === 'x' ? 'x' : 'y'];
    ax.forEach(function (a) { var s = d.sign * a.pos; if (s >= b[0] && s <= b[2]) out.push({name: a.name, s: s}); });
    return out;
  }
  function tracePoly(poly) {
    ctx.beginPath();
    [poly.pts].concat(poly.holes || []).forEach(function (ring) { ring.forEach(function (p, i) { var q = toScreen(p[0], p[1]); if (i) ctx.lineTo(q[0], q[1]); else ctx.moveTo(q[0], q[1]); }); ctx.closePath(); });
  }
  function draw() {
    if (!ctx) return;
    ctx.setTransform(size.dpr, 0, 0, size.dpr, 0, 0);
    var bg = css('--vgd-surface', '#fff'), ink = css('--vgd-text', '#222'), muted = css('--vgd-muted', '#777'), accent = css('--vgd-accent', '#B48963');
    ctx.fillStyle = bg; ctx.fillRect(0, 0, size.w, size.h);
    if (!result) { ctx.fillStyle = muted; ctx.font = '13px sans-serif'; ctx.textAlign = 'center'; ctx.fillText(dir ? 'Đang chờ kết quả từ SketchUp...' : 'Chọn hướng nhìn: Nam, Bắc, Đông hoặc Tây.', size.w / 2, size.h / 2); return; }
    var left = toWorld(0, 0)[0], right = toWorld(size.w, 0)[0];
    // cốt tầng (hoàn thiện nét liền, kết cấu nét đứt mảnh)
    S.levels.forEach(function (l) {
      [[l.elevation, [], 1, l.name + '  ' + (l.elevation >= 0 ? '+' : '') + (l.elevation / 1000).toFixed(3)], [l.elevation - (l.screed || 0), [4, 4], 0.6, '']].forEach(function (x) {
        var a = toScreen(left, x[0]), b = toScreen(right, x[0]); ctx.strokeStyle = muted; ctx.globalAlpha = 0.6; ctx.lineWidth = x[2]; ctx.setLineDash(x[1]); ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke(); ctx.setLineDash([]); ctx.globalAlpha = 1;
        if (x[3]) { ctx.fillStyle = muted; ctx.font = '11px sans-serif'; ctx.textAlign = 'left'; ctx.fillText(x[3], 6, a[1] - 3); }
      });
    });
    // các mặt, từ xa đến gần: mặt sau được mặt trước che
    result.polys.forEach(function (poly) {
      var on = selected[keyOf(poly.src)];
      tracePoly(poly); ctx.fillStyle = mix(colorOf(poly.src), bg, on ? 0.75 : 0.45); ctx.fill('evenodd');
      ctx.lineWidth = on ? 2.5 : 0.5; ctx.strokeStyle = on ? accent : ink; ctx.globalAlpha = on ? 1 : 0.7; ctx.stroke(); ctx.globalAlpha = 1;
    });
    // trục lưới (đặt sau các mặt để đọc được)
    gridAxes().forEach(function (a) {
      var top = toScreen(a.s, bounds()[3] + 800), bot = toScreen(a.s, bounds()[1] - 300);
      ctx.strokeStyle = '#BA00CC'; ctx.globalAlpha = 0.5; ctx.setLineDash([10, 3, 2, 3]); ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(top[0], top[1]); ctx.lineTo(bot[0], bot[1]); ctx.stroke(); ctx.setLineDash([]); ctx.globalAlpha = 1;
      ctx.beginPath(); ctx.arc(top[0], top[1] - 11, 10, 0, Math.PI * 2); ctx.fillStyle = bg; ctx.fill(); ctx.strokeStyle = '#BA00CC'; ctx.stroke(); ctx.fillStyle = ink; ctx.font = '11px sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(a.name, top[0], top[1] - 11); ctx.textBaseline = 'alphabetic';
    });
    ctx.fillStyle = muted; ctx.font = '11px sans-serif'; ctx.textAlign = 'right'; ctx.fillText('Mặt đứng ' + DIRS[dir].label + ' · 1 px = ' + (1 / view.s).toFixed(1) + ' mm', size.w - 8, size.h - 6);
  }

  function pickAt(px, py) { // mặt gần nhất chứa điểm bấm (lẻ-chẵn trên mọi vòng, nên lỗ không bị tính là mặt)
    if (!result) return null;
    var w = toWorld(px, py), best = null;
    result.polys.forEach(function (poly) {
      var inside = false;
      [poly.pts].concat(poly.holes || []).forEach(function (ring) { for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) { var a = ring[i], b = ring[j]; if (((a[1] > w[1]) !== (b[1] > w[1])) && (w[0] < (b[0] - a[0]) * (w[1] - a[1]) / (b[1] - a[1]) + a[0])) inside = !inside; } });
      if (inside) best = poly; // mảng xa đến gần: lần cuối trùng là gần nhất
    });
    return best;
  }
  function selectSrc(src) {
    selected = {}; if (src) selected[keyOf(src)] = true; draw();
    if (!src || src.kind === 'geom' || !host.callSU) return;
    host.callSU('plan_select', {level: src.level || S.level, items: [{kind: src.kind, ref: String(src.ref)}]});
  }
  function bind() {
    canvas.addEventListener('wheel', function (e) { e.preventDefault(); var r = canvas.getBoundingClientRect(), w0 = toWorld(e.clientX - r.left, e.clientY - r.top), f = e.deltaY < 0 ? 1.15 : 1 / 1.15; view.s = Math.min(5, Math.max(0.001, view.s * f)); var w1 = toWorld(e.clientX - r.left, e.clientY - r.top); view.cx += w0[0] - w1[0]; view.cy += w0[1] - w1[1]; draw(); }, {passive: false});
    canvas.addEventListener('pointerdown', function (e) { var r = canvas.getBoundingClientRect(); drag = {x: e.clientX, y: e.clientY, cx: view.cx, cy: view.cy, moved: false, px: e.clientX - r.left, py: e.clientY - r.top}; canvas.setPointerCapture(e.pointerId); });
    canvas.addEventListener('pointermove', function (e) { if (!drag) return; var dx = e.clientX - drag.x, dy = e.clientY - drag.y; if (Math.abs(dx) + Math.abs(dy) > 4) drag.moved = true; if (drag.moved) { view.cx = drag.cx - dx / view.s; view.cy = drag.cy + dy / view.s; draw(); } });
    canvas.addEventListener('pointerup', function () { if (drag && !drag.moved) { var p = pickAt(drag.px, drag.py); selectSrc(p ? p.src : null); } drag = null; });
  }

  window.VGDElevation = {
    init: function (h) {
      host = h; S = h.state; canvas = $('elv-canvas'); ctx = canvas.getContext('2d'); bind();
      document.querySelectorAll('#elv-dirs button').forEach(function (b) { b.onclick = function () { setDir(b.getAttribute('data-dir')); }; });
      $('elv-refresh').onclick = request; $('elv-fit').onclick = function () { fit(); draw(); };
      window.addEventListener('resize', resize);
    },
    receive: receive, resize: resize,
    show: function () { resize(); if (dir && !result) request(); },
    setTagNames: function (n) { tagNames = n || {}; draw(); },
    modelSelection: function (data) { // chọn trong SketchUp: sáng mặt cùng đối tượng
      selected = {}; ((data && data.items) || []).forEach(function (i) { selected[i.kind + '|' + (i.level || '') + '|' + i.ref] = true; if (i.kind === 'suobj') selected[i.kind + '||' + i.ref] = true; });
      if (result) result.polys.forEach(function (p) { if (p.src.kind === 'suobj' && selected['suobj||' + p.src.ref]) selected[keyOf(p.src)] = true; }); draw();
    },
    debug: function () { return {dir: dir, polys: result ? result.polys.length : 0, selected: Object.keys(selected), view: {cx: view.cx, cy: view.cy, s: view.s}, size: size, status: $('elv-status').textContent, axes: gridAxes().map(function (a) { return a.name; }), toScreen: toScreen}; }
  };
})();
