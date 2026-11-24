// Tab Mặt cắt: xem mặt cắt 2D dựng từ HÌNH THẬT trong SketchUp (Ruby: SuSection / SectionGeometry). Cửa sổ chỉ vẽ kết quả: các đường viền phần bị cắt (tô nhạt theo loại,
// hatch theo vật liệu: bê tông, gạch, hoàn thiện; viền cắt nét đậm), cốt tầng có ký hiệu, kích thước chiều cao tầng / tổng và khoảng trục (VGDMarks),
// cạnh phía sau mặt cắt (nét mảnh), đường cốt tầng và trục lưới cắt qua. Bấm một đường viền thì chọn đúng đối tượng đó trong SketchUp (cùng cách với mặt bằng),
// và chọn trong SketchUp thì đường viền sáng lên. Không sửa dữ liệu.
(function () {
  'use strict';
  var host = null, S = null, canvas = null, ctx = null, size = {w: 800, h: 500, dpr: 1};
  var cur = null;                 // {levelId, id}: mặt cắt đang xem
  var result = null;              // kết quả Ruby: {length, cut, beyond, truncated, name}
  var view = {cx: 0, cy: 0, s: 0.1}, drag = null, selected = {}, tagNames = {};
  var COLORS = {column: '#66DD00', beam: '#00AABA', wall: '#FF9966', slab: '#BA3300', ceiling: '#9900FF', door: '#FF7766', window: '#CCBAED', opening: '#FF7766', suobj: '#8A93A0', geom: '#666666', footing: '#999999', roof: '#FF6600', stair: '#FFBA00'};
  var TAG_KIND = function (tag) { var k = null; Object.keys(tagNames).forEach(function (kind) { if (String(tagNames[kind]).toLowerCase() === String(tag || '').toLowerCase()) k = kind; }); return k; };

  function $(id) { return document.getElementById(id); }
  function css(name, fb) { var v = getComputedStyle(document.documentElement).getPropertyValue(name).trim(); return v || fb; }
  function toScreen(s, z) { return [(s - view.cx) * view.s + size.w / 2, size.h / 2 - (z - view.cy) * view.s]; }
  function toWorld(px, py) { return [(px - size.w / 2) / view.s + view.cx, (size.h / 2 - py) / view.s + view.cy]; }
  function kindOf(src) { return src.kind === 'suobj' ? (TAG_KIND(src.tag) || 'suobj') : src.kind; }
  function colorOf(src) { return COLORS[kindOf(src)] || COLORS.geom; }
  function keyOf(src) { return src.kind + '|' + (src.level || '') + '|' + (src.ref || ''); }

  function sectionDef() { var l = S.levels.filter(function (x) { return x.id === (cur && cur.levelId); })[0]; return l && l.sections && l.sections[cur.id]; }
  function allSections() { var out = []; S.levels.forEach(function (l) { Object.keys(l.sections || {}).forEach(function (id) { out.push({levelId: l.id, id: id, label: l.name + ' · ' + l.sections[id].name}); }); }); return out; }
  function fillSelect() {
    var sel = $('sec-select'), list = allSections(), keep = cur ? cur.levelId + '|' + cur.id : '';
    sel.replaceChildren(); sel.append(new Option(list.length ? 'Chọn mặt cắt...' : 'Chưa có mặt cắt: dùng công cụ Mặt cắt trên mặt bằng', ''));
    list.forEach(function (x) { sel.append(new Option(x.label, x.levelId + '|' + x.id)); });
    sel.value = list.some(function (x) { return x.levelId + '|' + x.id === keep; }) ? keep : '';
  }
  function request() {
    var def = sectionDef();
    if (!def) { result = null; status(cur ? 'Mặt cắt này không còn.' : 'Chọn một mặt cắt.'); draw(); return; }
    status('Đang dựng mặt cắt từ hình trong SketchUp...');
    host.call('section_build', {id: cur.id, section: {name: def.name, a: def.a, b: def.b, dir: def.dir, depth: def.depth}});
  }
  function open(levelId, id) { cur = {levelId: levelId, id: id}; result = null; selected = {}; fillSelect(); request(); }
  function status(text) { $('sec-status').textContent = text; }

  function receive(data) {
    if (!cur || data.id !== cur.id) return;
    result = data; selected = {};
    status(data.name + ': ' + data.cut.length + ' đường viền, ' + data.beyond.length + ' cạnh phía sau.' + (data.truncated ? ' Model quá lớn: đã cắt bớt, mặt cắt có thể thiếu chi tiết.' : '') + (!data.cut.length ? ' Không có đối tượng nào bị cắt: kiểm tra vị trí đường cắt.' : ''));
    fit(); draw();
  }
  function bounds() {
    var xs = [0, result ? result.length : 1000], zs = [];
    S.levels.forEach(function (l) { zs.push(l.elevation - (l.screed || 0)); zs.push(l.elevation); });
    if (result) { result.cut.forEach(function (l) { l.pts.forEach(function (p) { xs.push(p[0]); zs.push(p[1]); }); }); result.beyond.forEach(function (e) { e.forEach(function (p) { xs.push(p[0]); zs.push(p[1]); }); }); }
    var z0 = Math.min.apply(null, zs.length ? zs : [0]), z1 = Math.max.apply(null, zs.length ? zs : [3000]);
    return [Math.min.apply(null, xs), z0, Math.max.apply(null, xs), z1];
  }
  function fit() {
    var f = VGDMarks.fit(bounds(), size); view.s = f.s; view.cx = f.cx; view.cy = f.cy; // chừa lề cho kích thước, ký hiệu cốt và trục
  }
  function resize() {
    if (!canvas) return; var r = canvas.parentNode.getBoundingClientRect(); size.dpr = window.devicePixelRatio || 1;
    size.w = Math.max(100, r.width); size.h = Math.max(100, r.height); canvas.width = Math.round(size.w * size.dpr); canvas.height = Math.round(size.h * size.dpr); canvas.style.width = size.w + 'px'; canvas.style.height = size.h + 'px';
    draw();
  }

  function axesCrossing() { // trục lưới cắt qua đường cắt: [{name, s}]
    var def = sectionDef(), out = []; if (!def || !host.axes) return out;
    var ax = host.axes(), ux = def.b[0] - def.a[0], uy = def.b[1] - def.a[1], L = Math.hypot(ux, uy); ux /= L; uy /= L;
    ax.x.forEach(function (a) { if (Math.abs(ux) > 1e-6) { var s = (a.pos - def.a[0]) / ux; if (s >= 0 && s <= L) out.push({name: a.name, s: s}); } });
    ax.y.forEach(function (a) { if (Math.abs(uy) > 1e-6) { var s = (a.pos - def.a[1]) / uy; if (s >= 0 && s <= L) out.push({name: a.name, s: s}); } });
    return out;
  }
  function draw() {
    if (!ctx) return;
    ctx.setTransform(size.dpr, 0, 0, size.dpr, 0, 0);
    var bg = css('--vgd-surface', '#fff'), ink = css('--vgd-text', '#222'), muted = css('--vgd-muted', '#777'), accent = css('--vgd-accent', '#B48963');
    ctx.fillStyle = bg; ctx.fillRect(0, 0, size.w, size.h);
    if (!result) { ctx.fillStyle = muted; ctx.font = '13px sans-serif'; ctx.textAlign = 'center'; ctx.fillText(cur ? 'Đang chờ kết quả từ SketchUp...' : 'Chọn hoặc đặt một mặt cắt trên mặt bằng.', size.w / 2, size.h / 2); return; }
    var left = toWorld(0, 0)[0], right = toWorld(size.w, 0)[0];
    var lv = {levels: S.levels, toScreen: toScreen, left: left, right: right, width: size.w, ink: ink, muted: muted};
    VGDMarks.levels(ctx, Object.assign({part: 'lines'}, lv));
    // trục lưới
    axesCrossing().forEach(function (a) {
      var top = toScreen(a.s, bounds()[3] + 800), bot = toScreen(a.s, bounds()[1] - 300); top[1] = Math.max(top[1], 24); // vòng tên trục luôn trong khung nhìn
      ctx.strokeStyle = '#BA00CC'; ctx.globalAlpha = 0.5; ctx.setLineDash([10, 3, 2, 3]); ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(top[0], top[1]); ctx.lineTo(bot[0], bot[1]); ctx.stroke(); ctx.setLineDash([]); ctx.globalAlpha = 1;
      ctx.beginPath(); ctx.arc(top[0], top[1] - 11, 10, 0, Math.PI * 2); ctx.fillStyle = bg; ctx.fill(); ctx.strokeStyle = '#BA00CC'; ctx.stroke(); ctx.fillStyle = ink; ctx.font = '11px sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(a.name, top[0], top[1] - 11); ctx.textBaseline = 'alphabetic';
    });
    // cạnh phía sau
    ctx.strokeStyle = muted; ctx.globalAlpha = 0.55; ctx.lineWidth = 0.6; ctx.beginPath();
    result.beyond.forEach(function (e) { var a = toScreen(e[0][0], e[0][1]), b = toScreen(e[1][0], e[1][1]); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); });
    ctx.stroke(); ctx.globalAlpha = 1;
    // phần bị cắt
    result.cut.forEach(function (l) {
      var col = colorOf(l.src), on = selected[keyOf(l.src)];
      ctx.beginPath(); l.pts.forEach(function (p, i) { var q = toScreen(p[0], p[1]); if (i) ctx.lineTo(q[0], q[1]); else ctx.moveTo(q[0], q[1]); }); if (l.closed) ctx.closePath();
      if (l.closed) {
        ctx.globalAlpha = on ? 0.7 : 0.35; ctx.fillStyle = col; ctx.fill(); ctx.globalAlpha = 1;
        var pat = VGDMarks.hatch(ctx, kindOf(l.src), ink); if (pat) { ctx.fillStyle = pat; ctx.fill(); }
      }
      ctx.lineWidth = on ? 3 : 2; ctx.strokeStyle = on ? accent : ink; ctx.stroke(); // nét cắt đậm, cạnh phía sau mảnh
    });
    if (result.cut.length || result.beyond.length) { var bb = bounds(); VGDMarks.dimensions(ctx, {levels: S.levels, bounds: bb, axes: axesCrossing(), toScreen: toScreen, color: muted}); }
    VGDMarks.levels(ctx, Object.assign({part: 'labels'}, lv));
    ctx.fillStyle = muted; ctx.font = '11px sans-serif'; ctx.textAlign = 'right'; ctx.fillText('1 px = ' + (1 / view.s).toFixed(1) + ' mm', size.w - 8, size.h - 6);
  }

  function pickAt(px, py) {
    if (!result) return null;
    var w = toWorld(px, py), tol = 6 / view.s, best = null;
    result.cut.forEach(function (l) {
      var hit = false;
      if (l.closed) { var inside = false; for (var i = 0, j = l.pts.length - 1; i < l.pts.length; j = i++) { var a = l.pts[i], b = l.pts[j]; if (((a[1] > w[1]) !== (b[1] > w[1])) && (w[0] < (b[0] - a[0]) * (w[1] - a[1]) / (b[1] - a[1]) + a[0])) inside = !inside; } hit = inside; }
      if (!hit) for (var k = 0; k + 1 < l.pts.length; k++) { var p = l.pts[k], q = l.pts[k + 1], dx = q[0] - p[0], dz = q[1] - p[1], l2 = dx * dx + dz * dz, t = l2 ? Math.max(0, Math.min(1, ((w[0] - p[0]) * dx + (w[1] - p[1]) * dz) / l2)) : 0; if (Math.hypot(w[0] - (p[0] + t * dx), w[1] - (p[1] + t * dz)) <= tol) { hit = true; break; } }
      if (hit) best = l;
    });
    return best;
  }
  function selectSrc(src) {
    selected = {}; if (src) selected[keyOf(src)] = true; draw();
    if (!src || src.kind === 'geom' || src.kind === 'roof' || !host.callSU) return; // hình rời và mái: chưa chọn được trong SketchUp (Ruby chỉ nhận loại trong SELECT_KINDS)
    host.callSU('plan_select', {level: src.level || S.level, items: [{kind: src.kind, ref: String(src.ref)}]});
  }
  function bind() {
    canvas.addEventListener('wheel', function (e) { e.preventDefault(); var r = canvas.getBoundingClientRect(), w0 = toWorld(e.clientX - r.left, e.clientY - r.top), f = e.deltaY < 0 ? 1.15 : 1 / 1.15; view.s = Math.min(5, Math.max(0.001, view.s * f)); var w1 = toWorld(e.clientX - r.left, e.clientY - r.top); view.cx += w0[0] - w1[0]; view.cy += w0[1] - w1[1]; draw(); }, {passive: false});
    canvas.addEventListener('pointerdown', function (e) { var r = canvas.getBoundingClientRect(); drag = {x: e.clientX, y: e.clientY, cx: view.cx, cy: view.cy, moved: false, px: e.clientX - r.left, py: e.clientY - r.top}; canvas.setPointerCapture(e.pointerId); });
    canvas.addEventListener('pointermove', function (e) { if (!drag) return; var dx = e.clientX - drag.x, dy = e.clientY - drag.y; if (Math.abs(dx) + Math.abs(dy) > 4) drag.moved = true; if (drag.moved) { view.cx = drag.cx - dx / view.s; view.cy = drag.cy + dy / view.s; draw(); } });
    canvas.addEventListener('pointerup', function () { if (drag && !drag.moved) { var l = pickAt(drag.px, drag.py); selectSrc(l ? l.src : null); } drag = null; });
  }

  window.VGDSection = {
    init: function (h) {
      host = h; S = h.state; canvas = $('sec-canvas'); ctx = canvas.getContext('2d'); bind();
      $('sec-select').onchange = function () { var v = $('sec-select').value; if (!v) { cur = null; result = null; status('Chọn một mặt cắt.'); draw(); return; } var p = v.split('|'); open(p[0], p[1]); };
      $('sec-refresh').onclick = request; $('sec-fit').onclick = function () { fit(); draw(); };
      window.addEventListener('resize', resize);
    },
    open: open, receive: receive, resize: resize, refreshList: fillSelect,
    show: function () { fillSelect(); resize(); },
    setTagNames: function (n) { tagNames = n || {}; draw(); },
    modelSelection: function (data) { // chọn trong SketchUp: sáng đường viền cùng đối tượng
      selected = {}; ((data && data.items) || []).forEach(function (i) { selected[i.kind + '|' + (i.level || '') + '|' + i.ref] = true; if (i.kind === 'suobj') selected[i.kind + '||' + i.ref] = true; });
      if (result) result.cut.forEach(function (l) { if (l.src.kind === 'suobj' && selected['suobj||' + l.src.ref]) selected[keyOf(l.src)] = true; }); draw();
    },
    debug: function () { return {materials: result ? result.cut.filter(function (l) { return l.closed; }).map(function (l) { return VGDMarks.material(kindOf(l.src)); }) : [], cur: cur, cut: result ? result.cut.length : 0, beyond: result ? result.beyond.length : 0, selected: Object.keys(selected), view: {cx: view.cx, cy: view.cy, s: view.s}, size: size, status: $('sec-status').textContent, axes: axesCrossing().map(function (a) { return a.name; }), toScreen: toScreen}; }
  };
})();
