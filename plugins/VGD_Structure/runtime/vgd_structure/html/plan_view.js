// Tab Mặt bằng: vẽ mặt bằng tầng đang chọn lên canvas (kéo / cuộn để xem). Chỉ hiển thị kết quả xem trước do Ruby tính, chưa sửa dữ liệu
// (cột mốc P1; vẽ và sửa ở các cột mốc sau). Tọa độ thế giới là mm, Y hướng lên; màn hình lật trục Y.
(function () {
  'use strict';
  // Màu theo bộ tag mẫu của VGD BIM.
  var COLORS = {column: '#66DD00', beam: '#00AABA', wall: '#FF9966', slab: '#BA3300', ceiling: '#9900FF', door: '#FF7766', window: '#CCBAED', grid: '#BA00CC'};
  var LAYERS = [['grid', 'Lưới trục'], ['slab', 'Sàn'], ['ceiling', 'Trần'], ['beam', 'Dầm'], ['wall', 'Tường'], ['opening', 'Cửa'], ['column', 'Cột']];
  var TOOLS = [
    ['Chọn & xem', [['select', 'Chọn', 'Space', 'Chọn / xem thông tin (Space)'], ['pan', 'Kéo', 'H', 'Kéo mặt bằng (H). Chuột giữa luôn kéo được']]],
    ['Vẽ kết cấu', [['', 'Lưới', 'G'], ['', 'Cột', 'C'], ['', 'Dầm', 'B'], ['', 'Tường', 'W'], ['', 'Sàn', ''], ['', 'Cửa', 'D']]],
    ['Sửa', [['', 'Move', 'M'], ['', 'Rotate', 'Q'], ['', 'Mirror', ''], ['', 'Offset', 'O'], ['', 'Trim', 'T'], ['', 'Xóa', 'E']]]
  ];
  var MIN_SCALE = 0.001, MAX_SCALE = 5; // px trên mm
  var opts, root, canvas, ctx, status = {}, levelSelect;
  var view = {cx: 0, cy: 0, s: 0.05}, data = null, boundsKey = '', fitted = false, tool = 'select', shapes = [], hover = null, cursor = null, drag = null;
  var visible = {grid: true, slab: true, ceiling: false, beam: true, wall: true, opening: true, column: true};
  var size = {w: 300, h: 200, dpr: 1};

  function $(id) { return document.getElementById(id); }
  function css(name, fallback) { var v = getComputedStyle(root).getPropertyValue(name).trim(); return v || fallback; }
  function toScreen(x, y) { return [(x - view.cx) * view.s + size.w / 2, size.h / 2 - (y - view.cy) * view.s]; }
  function toWorld(px, py) { return [(px - size.w / 2) / view.s + view.cx, (size.h / 2 - py) / view.s + view.cy]; }

  // ---- Khung giao diện ----
  function el(tag, props, parent) {
    var e = document.createElement(tag); Object.keys(props || {}).forEach(function (k) { if (k === 'text') e.textContent = props[k]; else e.setAttribute(k, props[k]); });
    if (parent) parent.appendChild(e); return e;
  }
  function buildBar(bar) {
    var lv = el('label', {class: 'pv-level'}, bar); el('span', {text: 'Tầng'}, lv);
    levelSelect = el('select', {'aria-label': 'Tầng đang xem'}, lv);
    levelSelect.onchange = function () { opts.onLevel(levelSelect.value); };
    TOOLS.forEach(function (group) {
      el('span', {class: 'pv-sep'}, bar);
      var g = el('span', {class: 'pv-group', role: 'group', 'aria-label': group[0]}, bar); el('i', {text: group[0]}, g);
      group[1].forEach(function (t) {
        var live = !!t[0], b = el('button', {type: 'button', class: 'pv-tool', title: live ? t[3] : t[1] + ' — có ở cột mốc sau (chưa dùng được)', 'data-tool': t[0] || ''}, g);
        b.textContent = t[1]; if (t[2]) el('kbd', {text: t[2]}, b);
        if (live) b.onclick = function () { setTool(t[0]); }; else b.disabled = true;
      });
    });
    el('span', {class: 'pv-grow'}, bar);
    var layers = el('span', {class: 'pv-group pv-layers', role: 'group', 'aria-label': 'Lớp hiển thị'}, bar); el('i', {text: 'Hiện'}, layers);
    LAYERS.forEach(function (l) {
      var lab = el('label', {class: 'pv-layer'}, layers), box = el('input', {type: 'checkbox', 'data-layer': l[0]}, lab);
      box.checked = visible[l[0]]; el('span', {text: l[1]}, lab);
      box.onchange = function () { visible[l[0]] = box.checked; hover = null; draw(); };
    });
    var fit = el('button', {type: 'button', class: 'pv-tool', id: 'pv-fit', title: 'Vừa khung (F)'}, bar); fit.textContent = 'Vừa khung'; el('kbd', {text: 'F'}, fit);
    fit.onclick = fitView;
  }
  function setTool(t) {
    tool = t; root.querySelectorAll('.pv-tool[data-tool]').forEach(function (b) { b.setAttribute('aria-pressed', String(b.getAttribute('data-tool') === t && !!t)); });
    canvas.style.cursor = t === 'pan' ? 'grab' : 'default';
  }

  // ---- Dữ liệu ----
  function worldBounds(d) {
    var xs = [], ys = [];
    ((d && d.axes) || []).forEach(function (a) {
      a.line.forEach(function (p) { xs.push(p[0]); ys.push(p[1]); });
      a.bubbles.forEach(function (b) { xs.push(b.center[0] - b.radius, b.center[0] + b.radius); ys.push(b.center[1] - b.radius, b.center[1] + b.radius); });
    });
    return xs.length ? [Math.min.apply(null, xs), Math.min.apply(null, ys), Math.max.apply(null, xs), Math.max.apply(null, ys)] : null;
  }
  function section(key) { return (data && data[key] && data[key].items) || []; }
  function rectPoly(min, max) { return [[min[0], min[1]], [max[0], min[1]], [max[0], max[1]], [min[0], max[1]]]; }
  function buildShapes() {
    shapes = [];
    section('slabs').forEach(function (i) { shapes.push({layer: 'slab', poly: rectPoly(i.min, i.max), text: 'Sàn ' + i.ref + ' · dày ' + i.thickness + ' mm · ' + i.area + ' m²'}); });
    section('ceilings').forEach(function (i) { shapes.push({layer: 'ceiling', poly: i.polygon, text: 'Trần ' + i.ref + ' · ' + i.area + ' m²'}); });
    section('beams').forEach(function (i) { shapes.push({layer: 'beam', poly: rectPoly(i.min, i.max), text: 'Dầm ' + i.ref + ' · ' + i.type_name + ' · dài ' + i.length + ' mm'}); });
    section('walls').forEach(function (i) { shapes.push({layer: 'wall', poly: rectPoly(i.min, i.max), text: 'Tường ' + i.ref + ' · ' + i.type_name + ' · dày ' + i.t + ' · dài ' + i.length + ' · cao ' + i.height + ' mm'}); });
    section('openings').forEach(function (i) { shapes.push({layer: 'opening', poly: rectPoly(i.min, i.max), text: (i.kind === 'door' ? 'Cửa đi ' : 'Cửa sổ ') + i.type_name + ' · ' + i.w + ' × ' + i.h + ' mm · ngưỡng ' + i.sill}); });
    section('columns').forEach(function (i) { shapes.push({layer: 'column', poly: rectPoly([i.center[0] - i.w / 2, i.center[1] - i.d / 2], [i.center[0] + i.w / 2, i.center[1] + i.d / 2]), text: 'Cột ' + i.ref + ' · ' + i.type_name + ' · ' + i.w + ' × ' + i.d + ' mm'}); });
  }
  function inside(poly, x, y) {
    var c = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      var a = poly[i], b = poly[j];
      if ((a[1] > y) !== (b[1] > y) && x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]) c = !c;
    }
    return c;
  }
  function pick(x, y) {
    for (var i = shapes.length - 1; i >= 0; i--) { var s = shapes[i]; if (visible[s.layer] && inside(s.poly, x, y)) return s; }
    return null;
  }

  // ---- Xem ----
  function fitView() {
    var b = worldBounds(data); if (!b) return;
    var w = Math.max(b[2] - b[0], 1), h = Math.max(b[3] - b[1], 1), pad = 40;
    view.s = Math.min(MAX_SCALE, Math.max(MIN_SCALE, Math.min((size.w - 2 * pad) / w, (size.h - 2 * pad) / h)));
    view.cx = (b[0] + b[2]) / 2; view.cy = (b[1] + b[3]) / 2; fitted = true; draw();
  }
  function zoomAt(px, py, factor) {
    var before = toWorld(px, py);
    view.s = Math.min(MAX_SCALE, Math.max(MIN_SCALE, view.s * factor));
    view.cx = before[0] - (px - size.w / 2) / view.s; view.cy = before[1] + (py - size.h / 2) / view.s; // giữ điểm dưới con trỏ đứng yên
    draw();
  }
  function resize() {
    var r = canvas.parentNode.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
    size = {w: Math.max(50, Math.floor(r.width)), h: Math.max(50, Math.floor(r.height)), dpr: dpr};
    canvas.width = Math.round(size.w * dpr); canvas.height = Math.round(size.h * dpr);
    canvas.style.width = size.w + 'px'; canvas.style.height = size.h + 'px';
    if (!fitted && data) fitView(); else draw();
  }

  // ---- Vẽ ----
  function path(poly) { ctx.beginPath(); poly.forEach(function (p, i) { var q = toScreen(p[0], p[1]); if (i) ctx.lineTo(q[0], q[1]); else ctx.moveTo(q[0], q[1]); }); ctx.closePath(); }
  function fillStroke(poly, color, alpha, dash, width) {
    path(poly); ctx.globalAlpha = alpha; ctx.fillStyle = color; if (alpha > 0) ctx.fill(); ctx.globalAlpha = 1;
    ctx.setLineDash(dash || []); ctx.lineWidth = width || 1; ctx.strokeStyle = color; ctx.stroke(); ctx.setLineDash([]);
  }
  function draw() {
    if (!ctx) return;
    ctx.setTransform(size.dpr, 0, 0, size.dpr, 0, 0);
    var bg = css('--vgd-surface', '#fff'), ink = css('--vgd-text', '#222'), muted = css('--vgd-muted', '#777');
    ctx.fillStyle = bg; ctx.fillRect(0, 0, size.w, size.h);
    if (!data || !data.ok) { ctx.fillStyle = muted; ctx.font = '13px sans-serif'; ctx.textAlign = 'center'; ctx.fillText((data && data.error) || 'Chưa có lưới trục hợp lệ.', size.w / 2, size.h / 2); updateStatus(); return; }
    if (visible.slab) section('slabs').forEach(function (i) { fillStroke(rectPoly(i.min, i.max), COLORS.slab, 0.12, null, 1); });
    if (visible.ceiling) section('ceilings').forEach(function (i) { fillStroke(i.polygon, COLORS.ceiling, 0.08, [5, 4], 1); });
    if (visible.beam) section('beams').forEach(function (i) { fillStroke(rectPoly(i.min, i.max), COLORS.beam, 0.25, [6, 3], 1); });
    if (visible.wall) section('walls').forEach(function (i) { fillStroke(rectPoly(i.min, i.max), COLORS.wall, 0.8, null, 1); });
    if (visible.opening) section('openings').forEach(function (i) { drawOpening(i, bg); });
    if (visible.column) section('columns').forEach(function (i) { fillStroke(rectPoly([i.center[0] - i.w / 2, i.center[1] - i.d / 2], [i.center[0] + i.w / 2, i.center[1] + i.d / 2]), COLORS.column, 0.9, null, 1.5); });
    if (visible.grid) drawGrid(ink);
    if (hover && visible[hover.layer]) { path(hover.poly); ctx.lineWidth = 2.5; ctx.strokeStyle = css('--vgd-accent', '#1e88e5'); ctx.stroke(); }
    updateStatus();
  }
  function drawGrid(ink) {
    ctx.save(); ctx.strokeStyle = COLORS.grid; ctx.lineWidth = 1; ctx.globalAlpha = 0.7; ctx.setLineDash([14, 3, 2, 3]);
    data.axes.forEach(function (a) { var p = toScreen(a.line[0][0], a.line[0][1]), q = toScreen(a.line[1][0], a.line[1][1]); ctx.beginPath(); ctx.moveTo(p[0], p[1]); ctx.lineTo(q[0], q[1]); ctx.stroke(); });
    ctx.restore(); ctx.setLineDash([]);
    data.axes.forEach(function (a) {
      a.bubbles.forEach(function (b) {
        var c = toScreen(b.center[0], b.center[1]), r = b.radius * view.s;
        if (r < 2) return;
        ctx.beginPath(); ctx.arc(c[0], c[1], r, 0, Math.PI * 2); ctx.fillStyle = css('--vgd-surface', '#fff'); ctx.fill(); ctx.lineWidth = 1.2; ctx.strokeStyle = COLORS.grid; ctx.stroke();
        var fs = a.text_height * view.s;
        if (fs >= 6) { ctx.fillStyle = ink; ctx.font = Math.round(fs) + 'px sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(a.name, c[0], c[1]); }
      });
    });
  }
  // Cửa: khoét lỗ trên nét tường; cửa đi có cánh mở 90° và cung quay, cửa sổ có hai nét kính.
  function drawOpening(i, bg) {
    var poly = rectPoly(i.min, i.max), color = i.kind === 'door' ? COLORS.door : COLORS.window, along = i.dir === 'x' ? 0 : 1, across = 1 - along;
    path(poly); ctx.fillStyle = bg; ctx.fill(); ctx.lineWidth = 1; ctx.strokeStyle = color; ctx.stroke();
    var mid = (i.min[across] + i.max[across]) / 2, a0 = i.min[along], a1 = i.max[along];
    function pt(u, v) { var p = [0, 0]; p[along] = u; p[across] = v; return p; }
    function line(p, q, width) { var s = toScreen(p[0], p[1]), e = toScreen(q[0], q[1]); ctx.beginPath(); ctx.moveTo(s[0], s[1]); ctx.lineTo(e[0], e[1]); ctx.lineWidth = width; ctx.strokeStyle = color; ctx.stroke(); }
    if (i.kind === 'window') { line(pt(a0, mid), pt(a1, mid), 1.5); return; }
    var w = a1 - a0, dir = i.flip ? -1 : 1, hinge = pt(a0, mid), leaf = pt(a0, mid + dir * w);
    line(hinge, leaf, 2);
    ctx.beginPath();
    for (var k = 0; k <= 12; k++) { var t = k / 12 * Math.PI / 2, p = pt(a0 + w * Math.cos(t), mid + dir * w * Math.sin(t)), q = toScreen(p[0], p[1]); if (k) ctx.lineTo(q[0], q[1]); else ctx.moveTo(q[0], q[1]); }
    ctx.lineWidth = 1; ctx.strokeStyle = color; ctx.setLineDash([3, 3]); ctx.stroke(); ctx.setLineDash([]);
  }
  function updateStatus() {
    status.xy.textContent = cursor ? 'X ' + Math.round(cursor[0]) + '   Y ' + Math.round(cursor[1]) + ' mm' : '';
    status.hint.textContent = hover ? hover.text : (data && data.ok ? 'Rê chuột lên một phần tử để xem thông tin. Cuộn = thu phóng, chuột giữa hoặc H = kéo, F = vừa khung.' : '');
    status.zoom.textContent = '1 px = ' + (1 / view.s).toFixed(1) + ' mm';
  }

  // ---- Chuột và bàn phím ----
  function point(e) { var r = canvas.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; }
  function onDown(e) {
    canvas.focus();
    if (e.button === 1 || (e.button === 0 && tool === 'pan')) { drag = {x: e.clientX, y: e.clientY, cx: view.cx, cy: view.cy}; canvas.setPointerCapture(e.pointerId); canvas.style.cursor = 'grabbing'; e.preventDefault(); }
  }
  function onMove(e) {
    var p = point(e); cursor = toWorld(p[0], p[1]);
    if (drag) { view.cx = drag.cx - (e.clientX - drag.x) / view.s; view.cy = drag.cy + (e.clientY - drag.y) / view.s; draw(); return; }
    var h = pick(cursor[0], cursor[1]);
    if (h !== hover) hover = h;
    draw();
  }
  function onUp(e) { if (drag) { drag = null; try { canvas.releasePointerCapture(e.pointerId); } catch (x) { /* đã thả */ } canvas.style.cursor = tool === 'pan' ? 'grab' : 'default'; } }
  function onWheel(e) { e.preventDefault(); var p = point(e); zoomAt(p[0], p[1], Math.exp(-e.deltaY * 0.0015)); }
  function onKey(e) {
    if (root.hidden || e.ctrlKey || e.metaKey || e.altKey) return;
    var t = e.target; if (t && /^(INPUT|SELECT|TEXTAREA)$/.test(t.tagName)) return;
    var k = e.key.toLowerCase();
    if (k === 'f') { fitView(); e.preventDefault(); } else if (k === 'h') { setTool('pan'); e.preventDefault(); } else if (k === ' ' || k === 'escape') { setTool('select'); e.preventDefault(); }
  }

  var api = {
    init: function (options) {
      opts = options; root = $('tab-plan'); canvas = $('pv-canvas'); ctx = canvas.getContext('2d');
      status = {xy: $('pv-xy'), hint: $('pv-hint'), zoom: $('pv-zoom')};
      buildBar($('pv-bar')); setTool('select');
      canvas.addEventListener('pointerdown', onDown); canvas.addEventListener('pointermove', onMove); canvas.addEventListener('pointerup', onUp); canvas.addEventListener('pointercancel', onUp);
      canvas.addEventListener('pointerleave', function () { cursor = null; hover = null; draw(); });
      canvas.addEventListener('wheel', onWheel, {passive: false});
      document.addEventListener('keydown', onKey);
      window.addEventListener('resize', resize);
      if (window.ResizeObserver) new ResizeObserver(resize).observe(canvas.parentNode);
      if (window.MutationObserver) new MutationObserver(draw).observe(document.documentElement, {attributes: true, attributeFilter: ['data-theme', 'class']});
      if (window.matchMedia) window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', draw);
    },
    // Danh sách tầng và tầng đang xem (đồng bộ với các tab khác).
    setLevels: function (levels, current) {
      levelSelect.replaceChildren(); levels.forEach(function (l) { levelSelect.append(new Option(l.name, l.id)); }); levelSelect.value = current;
    },
    update: function (preview) {
      data = preview; hover = null;
      var b = worldBounds(data), key = b ? b.join(',') : '';
      buildShapes();
      if (key !== boundsKey) { boundsKey = key; fitted = false; }
      if (!fitted && !root.hidden) { resize(); } else draw();
    },
    show: function () { resize(); },
    fit: fitView,
    // Dùng cho test: trạng thái xem và số phần tử đang vẽ.
    debug: function () {
      var counts = {}; shapes.forEach(function (s) { counts[s.layer] = (counts[s.layer] || 0) + 1; });
      return {view: {cx: view.cx, cy: view.cy, s: view.s}, size: size, tool: tool, counts: counts, hover: hover && hover.text, visible: Object.assign({}, visible), axes: data && data.ok ? data.axes.length : 0};
    },
    toScreen: toScreen, toWorld: toWorld
  };
  window.VGDPlan = api;
})();
