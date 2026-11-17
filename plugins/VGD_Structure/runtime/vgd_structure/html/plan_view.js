// Tab Mặt bằng: vẽ mặt bằng tầng đang chọn lên canvas (kéo / cuộn để xem). Chỉ hiển thị kết quả xem trước do Ruby tính, chưa sửa dữ liệu
// (cột mốc P1; vẽ và sửa ở các cột mốc sau). Tọa độ thế giới là mm, Y hướng lên; màn hình lật trục Y.
(function () {
  'use strict';
  // Màu theo bộ tag mẫu của VGD BIM.
  var COLORS = {column: '#66DD00', beam: '#00AABA', wall: '#FF9966', slab: '#BA3300', ceiling: '#9900FF', door: '#FF7766', window: '#CCBAED', grid: '#BA00CC'};
  var LAYERS = [['grid', 'Lưới trục'], ['slab', 'Sàn'], ['ceiling', 'Trần'], ['beam', 'Dầm'], ['wall', 'Tường'], ['opening', 'Cửa'], ['column', 'Cột']];
  // Biểu tượng tự vẽ (nét 24 × 24). Bố cục theo cửa sổ mặt bằng của VTBim: thanh trên (chọn, sửa), cột công cụ bên trái, tab theo tầng, bảng thuộc tính, thanh trạng thái.
  var ICON = {
    select: 'M5 2v17l4-5 4 7 3-2-4-6 6-1Z', pan: 'M8 12V5a1.5 1.5 0 0 1 3 0v6M11 11V3.5a1.5 1.5 0 0 1 3 0V11M14 11V5a1.5 1.5 0 0 1 3 0v8c0 5-2 8-6 8-3 0-4-2-6-5l-2-4a1.5 1.5 0 0 1 3-1l2 3V8a1.5 1.5 0 0 1 3 0',
    guide: 'M2 16h20v5H2ZM6 16v3M10 16v2M14 16v3M18 16v2M3 3l18 9', measure: 'M3 12h18M3 8v8M21 8v8M7 12v-2M11 12v-3M15 12v-2',
    move: 'M12 1v22M1 12h22M8 5l4-4 4 4M8 19l4 4 4-4M5 8l-4 4 4 4M19 8l4 4-4 4', rotate: 'M4 8a9 9 0 1 1-1 9M4 2v6h6', mirror: 'M12 2v22M9 6L3 18h6ZM15 6l6 12h-6Z',
    offset: 'M4 21V7h14M8 21V11h10', trim: 'M6 3a3 3 0 1 0 0 6 3 3 0 0 0 0-6ZM6 15a3 3 0 1 0 0 6 3 3 0 0 0 0-6ZM8.5 7.5L21 18M8.5 16.5L21 6',
    eraser: 'M3 17l9-9 7 7-5 5H6ZM8 12l7 7M3 22h18', delete: 'M4 6h16M9 6V3h6v3M6 6l1 15h10l1-15M10 10v8M14 10v8',
    grid: 'M3 8h18M3 16h18M8 3v18M16 3v18', column: 'M9 2h6v20H9Z', beam: 'M2 9h20v6H2Z', wall: 'M3 6l18-4v15L3 22Z', slab: 'M2 13l10-6 10 5-11 7Z',
    ceiling: 'M2 6h20M2 16h20M6 6v10M12 6v10M18 6v10', door: 'M7 3l11-2v21H7ZM10 12h1', window: 'M4 4l16-2v18L4 22ZM12 3v18M4 12l16-2',
    line: 'M4 20L20 4', polyline: 'M3 18l6-10 5 7 7-11', rect: 'M3 6h18v12H3Z', circle: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18Z', arc: 'M4 18a10 10 0 0 1 16 0',
    dim: 'M3 8v8M21 8v8M3 12h18M6 10l-3 2 3 2M18 10l3 2-3 2', text: 'M5 5h14M12 5v14M9 19h6', level: 'M12 3l5 8h-10ZM4 18h16M4 21h16',
    undo: 'M9 14L4 9l5-5M4 9h11a5 5 0 0 1 0 10h-3', redo: 'M15 14l5-5-5-5M20 9H9a5 5 0 0 0 0 10h3', fit: 'M3 8V3h5M16 3h5v5M21 16v5h-5M8 21H3v-5M14 14l3 3M15 11a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
    props: 'M3 4h18v16H3ZM9 4v16M12 8h6M12 12h6M12 16h4', eye: 'M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12ZM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6'
  };
  // [id, tên, phím, gợi ý, dùng được ở cột mốc này?]
  var TOP_GROUPS = [
    ['Chọn & đo', [['select', 'Chọn', '', 'Chọn / xem thông tin (Space)', 1], ['pan', 'Kéo', 'H', 'Kéo mặt bằng (H). Chuột giữa luôn kéo được', 1], ['guide', 'Đường gióng', 'G'], ['measure', 'Đo', '']]],
    ['Sửa', [['move', 'Move', 'M'], ['rotate', 'Rotate', 'Q'], ['mirror', 'Mirror', ''], ['offset', 'Offset', 'O'], ['trim', 'Trim', 'T'], ['eraser', 'Tẩy', 'E'], ['delete', 'Xóa', 'Del']]]
  ];
  var SIDE_GROUPS = [
    ['Thiết kế', [['grid', 'Lưới trục', ''], ['column', 'Cột', 'C'], ['beam', 'Dầm', 'B'], ['wall', 'Tường', 'W'], ['slab', 'Sàn', ''], ['ceiling', 'Trần', ''], ['door', 'Cửa đi', 'D'], ['window', 'Cửa sổ', 'N']]],
    ['Vẽ 2D', [['line', 'Line', 'L'], ['polyline', 'Polyline', ''], ['rect', 'Chữ nhật', 'R'], ['circle', 'Đường tròn', ''], ['arc', 'Cung', 'A']]],
    ['Ghi chú', [['dim', 'Kích thước', 'K'], ['text', 'Chữ', ''], ['level', 'Cốt cao độ', '']]]
  ];
  var MIN_SCALE = 0.001, MAX_SCALE = 5; // px trên mm
  var opts, root, canvas, ctx, status = {}, levelList = [], currentId = null, selected = null, propsOpen = true;
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
  function svg(name) { return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="' + ICON[name] + '"/></svg>'; }
  function iconButton(parent, t, extra) {
    var live = !!t[4], b = el('button', {type: 'button', class: 'pv-ic' + (extra || ''), 'data-tool': t[0], 'aria-label': t[1], title: live ? t[3] : t[1] + (t[2] ? ' (' + t[2] + ')' : '') + ' — có ở cột mốc sau, chưa dùng được'}, parent);
    b.innerHTML = svg(t[0]); if (t[2]) el('kbd', {text: t[2]}, b);
    if (live) b.onclick = function () { setTool(t[0]); }; else b.disabled = true;
    return b;
  }
  function buildTop(bar) {
    [['undo', 'Hoàn tác (Ctrl+Z) — có ở cột mốc P3'], ['redo', 'Làm lại (Ctrl+Y) — có ở cột mốc P3']].forEach(function (u) {
      var b = el('button', {type: 'button', class: 'pv-ic', 'aria-label': u[1], title: u[1]}, bar); b.innerHTML = svg(u[0]); b.disabled = true;
    });
    TOP_GROUPS.forEach(function (g) {
      el('span', {class: 'pv-sep'}, bar);
      var box = el('span', {class: 'pv-grp', role: 'group', 'aria-label': g[0], title: g[0]}, bar);
      g[1].forEach(function (t) { iconButton(box, t); });
    });
    el('span', {class: 'pv-grow'}, bar);
    var disp = el('span', {class: 'pv-drop'}, bar), eye = el('button', {type: 'button', class: 'pv-ic', id: 'pv-layers-btn', 'aria-haspopup': 'true', 'aria-expanded': 'false', title: 'Hiển thị: bật / tắt từng lớp'}, disp);
    eye.innerHTML = svg('eye') + '<b>▾</b>';
    var menu = el('div', {class: 'pv-menu', id: 'pv-layers', hidden: ''}, disp);
    LAYERS.forEach(function (l) {
      var lab = el('label', {}, menu), box = el('input', {type: 'checkbox', 'data-layer': l[0]}, lab);
      box.checked = visible[l[0]]; el('span', {text: l[1]}, lab);
      box.onchange = function () { visible[l[0]] = box.checked; hover = null; draw(); renderProps(); };
    });
    eye.onclick = function (e) { e.stopPropagation(); var open = menu.hidden; menu.hidden = !open; eye.setAttribute('aria-expanded', String(open)); };
    document.addEventListener('click', function (e) { if (!menu.hidden && !menu.contains(e.target)) { menu.hidden = true; eye.setAttribute('aria-expanded', 'false'); } });
    var fit = el('button', {type: 'button', class: 'pv-ic', id: 'pv-fit', title: 'Vừa khung (F)'}, bar); fit.innerHTML = svg('fit') + '<kbd>F</kbd>'; fit.onclick = fitView;
    var pr = el('button', {type: 'button', class: 'pv-ic on', id: 'pv-props-btn', title: 'Thuộc tính: ẩn / hiện bảng bên trái', 'aria-pressed': 'true'}, bar); pr.innerHTML = svg('props');
    pr.onclick = function () { propsOpen = !propsOpen; pr.classList.toggle('on', propsOpen); pr.setAttribute('aria-pressed', String(propsOpen)); $('pv-props').hidden = !propsOpen; resize(); };
  }
  function buildSide(side) {
    SIDE_GROUPS.forEach(function (g) {
      var box = el('div', {class: 'pv-side-grp', role: 'group', 'aria-label': g[0]}, side); el('i', {text: g[0]}, box);
      g[1].forEach(function (t) { iconButton(box, t); });
    });
  }
  function renderTabs() {
    var bar = $('pv-tabs'); bar.replaceChildren();
    levelList.forEach(function (l) {
      var b = el('button', {type: 'button', role: 'tab', class: 'pv-tab', 'aria-selected': String(l.id === currentId), 'data-level': l.id, title: l.name + ' · cao độ ' + l.elevation + ' mm'}, bar);
      b.textContent = l.name; b.onclick = function () { if (l.id !== currentId) opts.onLevel(l.id); };
    });
  }
  // Bảng thuộc tính: phần tử đang chọn, không thì phần tử đang rê chuột, không thì thông tin tầng.
  function renderProps() {
    var box = $('pv-props'); if (!box) return; box.replaceChildren();
    var shape = (selected && visible[selected.layer]) ? selected : (hover && visible[hover.layer] ? hover : null), rows, title;
    if (shape) { title = shape.title; rows = shape.rows; }
    else {
      var lv = levelList.filter(function (l) { return l.id === currentId; })[0];
      title = lv ? lv.name : 'Mặt bằng';
      rows = lv ? [['Cao độ sàn', lv.elevation + ' mm'], ['Dày sàn', lv.slab + ' mm']] : [];
      var counts = {}; shapes.forEach(function (x) { counts[x.layer] = (counts[x.layer] || 0) + 1; });
      LAYERS.forEach(function (l) { if (l[0] !== 'grid') rows.push([l[1], String(counts[l[0]] || 0)]); });
    }
    el('h3', {text: 'Thuộc tính'}, box); el('p', {class: 'pv-ptitle', text: title}, box);
    var t = el('table', {class: 'pv-ptable'}, box);
    rows.forEach(function (r) { var tr = el('tr', {}, t); el('th', {text: r[0]}, tr); el('td', {text: r[1]}, tr); });
  }
  function setTool(t) {
    tool = t; root.querySelectorAll('.pv-ic[data-tool]').forEach(function (b) { var on = b.getAttribute('data-tool') === t; b.classList.toggle('on', on); b.setAttribute('aria-pressed', String(on)); });
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
  function mm(v) { return v + ' mm'; }
  function buildShapes() {
    shapes = [];
    function add(layer, poly, title, rows, text) { shapes.push({layer: layer, poly: poly, title: title, rows: rows, text: text}); }
    section('slabs').forEach(function (i) { add('slab', rectPoly(i.min, i.max), 'Sàn ' + i.ref, [['Dày', mm(i.thickness)], ['Mặt trên', mm(i.z_top)], ['Diện tích', i.area + ' m²']], 'Sàn ' + i.ref + ' · dày ' + i.thickness + ' mm · ' + i.area + ' m²'); });
    section('ceilings').forEach(function (i) { add('ceiling', i.polygon, 'Trần ' + i.ref, [['Dày', mm(i.thickness)], ['Mặt dưới', mm(i.z_bottom)], ['Diện tích', i.area + ' m²']], 'Trần ' + i.ref + ' · ' + i.area + ' m²'); });
    section('beams').forEach(function (i) { add('beam', rectPoly(i.min, i.max), 'Dầm ' + i.ref, [['Loại', i.type_name], ['Rộng × cao', i.w + ' × ' + i.h + ' mm'], ['Dài', mm(i.length)], ['Đỉnh', mm(i.z_top)]], 'Dầm ' + i.ref + ' · ' + i.type_name + ' · dài ' + i.length + ' mm'); });
    section('walls').forEach(function (i) { add('wall', rectPoly(i.min, i.max), 'Tường ' + i.ref, [['Loại', i.type_name], ['Dày', mm(i.t)], ['Dài', mm(i.length)], ['Cao', mm(i.height)], ['Số cửa', String((i.openings || []).length)]], 'Tường ' + i.ref + ' · ' + i.type_name + ' · dày ' + i.t + ' · dài ' + i.length + ' · cao ' + i.height + ' mm'); });
    section('openings').forEach(function (i) { var k = i.kind === 'door' ? 'Cửa đi' : 'Cửa sổ'; add('opening', rectPoly(i.min, i.max), k + ' ' + i.type_name, [['Loại', k], ['Rộng × cao', i.w + ' × ' + i.h + ' mm'], ['Cao ngưỡng', mm(i.sill)], ['Tường', i.wall]], k + ' ' + i.type_name + ' · ' + i.w + ' × ' + i.h + ' mm · ngưỡng ' + i.sill); });
    section('columns').forEach(function (i) { add('column', rectPoly([i.center[0] - i.w / 2, i.center[1] - i.d / 2], [i.center[0] + i.w / 2, i.center[1] + i.d / 2]), 'Cột ' + i.ref, [['Loại', i.type_name], ['Rộng × sâu', i.w + ' × ' + i.d + ' mm'], ['Tâm', Math.round(i.center[0]) + ', ' + Math.round(i.center[1])]], 'Cột ' + i.ref + ' · ' + i.type_name + ' · ' + i.w + ' × ' + i.d + ' mm'); });
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
    if (hover && visible[hover.layer]) { path(hover.poly); ctx.lineWidth = 2; ctx.strokeStyle = css('--vgd-accent', '#1e88e5'); ctx.stroke(); }
    if (selected && visible[selected.layer]) { path(selected.poly); ctx.lineWidth = 3; ctx.setLineDash([6, 3]); ctx.strokeStyle = css('--vgd-accent', '#1e88e5'); ctx.stroke(); ctx.setLineDash([]); }
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
    status.hint.textContent = hover ? hover.text : selected && visible[selected.layer] ? selected.text : (data && data.ok ? 'Bấm một phần tử để xem thuộc tính. Cuộn = thu phóng, chuột giữa hoặc H = kéo, F = vừa khung.' : '');
    status.zoom.textContent = '1 px = ' + (1 / view.s).toFixed(1) + ' mm';
  }

  // ---- Chuột và bàn phím ----
  function point(e) { var r = canvas.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; }
  function onDown(e) {
    canvas.focus();
    if (e.button === 0 && tool === 'select') { var w = toWorld(point(e)[0], point(e)[1]); selected = pick(w[0], w[1]); draw(); renderProps(); return; }
    if (e.button === 1 || (e.button === 0 && tool === 'pan')) { drag = {x: e.clientX, y: e.clientY, cx: view.cx, cy: view.cy}; canvas.setPointerCapture(e.pointerId); canvas.style.cursor = 'grabbing'; e.preventDefault(); }
  }
  function onMove(e) {
    var p = point(e); cursor = toWorld(p[0], p[1]);
    if (drag) { view.cx = drag.cx - (e.clientX - drag.x) / view.s; view.cy = drag.cy + (e.clientY - drag.y) / view.s; draw(); return; }
    var h = pick(cursor[0], cursor[1]);
    if (h !== hover) { hover = h; renderProps(); }
    draw();
  }
  function onUp(e) { if (drag) { drag = null; try { canvas.releasePointerCapture(e.pointerId); } catch (x) { /* đã thả */ } canvas.style.cursor = tool === 'pan' ? 'grab' : 'default'; } }
  function onWheel(e) { e.preventDefault(); var p = point(e); zoomAt(p[0], p[1], Math.exp(-e.deltaY * 0.0015)); }
  function onKey(e) {
    if (root.hidden || e.ctrlKey || e.metaKey || e.altKey) return;
    var t = e.target; if (t && /^(INPUT|SELECT|TEXTAREA)$/.test(t.tagName)) return;
    var k = e.key.toLowerCase();
    if (k === 'f') { fitView(); e.preventDefault(); } else if (k === 'h') { setTool('pan'); e.preventDefault(); } else if (k === ' ') { setTool('select'); e.preventDefault(); } else if (k === 'escape') { setTool('select'); selected = null; renderProps(); draw(); }
  }

  var api = {
    init: function (options) {
      opts = options; root = $('tab-plan'); canvas = $('pv-canvas'); ctx = canvas.getContext('2d');
      status = {xy: $('pv-xy'), hint: $('pv-hint'), zoom: $('pv-zoom')};
      buildTop($('pv-top')); buildSide($('pv-side')); setTool('select'); renderProps();
      canvas.addEventListener('pointerdown', onDown); canvas.addEventListener('pointermove', onMove); canvas.addEventListener('pointerup', onUp); canvas.addEventListener('pointercancel', onUp);
      canvas.addEventListener('pointerleave', function () { cursor = null; hover = null; renderProps(); draw(); });
      canvas.addEventListener('wheel', onWheel, {passive: false});
      document.addEventListener('keydown', onKey);
      window.addEventListener('resize', resize);
      if (window.ResizeObserver) new ResizeObserver(resize).observe(canvas.parentNode);
      if (window.MutationObserver) new MutationObserver(draw).observe(document.documentElement, {attributes: true, attributeFilter: ['data-theme', 'class']});
      if (window.matchMedia) window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', draw);
    },
    // Danh sách tầng và tầng đang xem (đồng bộ với các tab khác).
    setLevels: function (levels, current) {
      levelList = levels.map(function (l) { return {id: l.id, name: l.name, elevation: l.elevation, slab: l.slab}; }); currentId = current; renderTabs(); renderProps();
    },
    update: function (preview) {
      data = preview; hover = null; selected = null;
      var b = worldBounds(data), key = b ? b.join(',') : '';
      buildShapes(); renderProps();
      if (key !== boundsKey) { boundsKey = key; fitted = false; }
      if (!fitted && !root.hidden) { resize(); } else draw();
    },
    show: function () { resize(); },
    fit: fitView,
    // Dùng cho test: trạng thái xem và số phần tử đang vẽ.
    debug: function () {
      var counts = {}; shapes.forEach(function (s) { counts[s.layer] = (counts[s.layer] || 0) + 1; });
      return {view: {cx: view.cx, cy: view.cy, s: view.s}, size: size, tool: tool, counts: counts, hover: hover && hover.text, selected: selected && selected.title, level: currentId, tabs: levelList.length, visible: Object.assign({}, visible), axes: data && data.ok ? data.axes.length : 0};
    },
    toScreen: toScreen, toWorld: toWorld
  };
  window.VGDPlan = api;
})();
