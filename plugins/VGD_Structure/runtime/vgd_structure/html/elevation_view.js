// Tab Mặt đứng: xem mặt đứng 2D dựng từ HÌNH THẬT trong SketchUp (Ruby: SuSection.elevation, ElevationGeometry). Không cắt. Che khuất theo TỪNG ĐIỂM ẢNH
// (z-buffer: mỗi mặt có mặt phẳng độ sâu `plane` do Ruby tính), nên mặt chồng nhau một phần vẫn đúng; nét vẽ từ ranh giới giữa các mặt nhìn thấy:
// viền ngoài (giáp nền) đậm, ranh giới hai đối tượng vừa, nếp giữa các mặt của cùng đối tượng mảnh. Cốt tầng, kích thước, trục lưới vẽ đè (VGDMarks). Bấm một mặt thì chọn đúng đối tượng đó trong SketchUp (cùng cách với mặt cắt),
// và chọn trong SketchUp thì mặt sáng lên. Không lưu dữ liệu: mỗi lần chọn hướng Ruby đọc lại model hiện tại.
(function () {
  'use strict';
  var host = null, S = null, canvas = null, ctx = null, size = {w: 800, h: 500, dpr: 1};
  var dir = null;                 // 'south' | 'north' | 'west' | 'east'
  var result = null;              // kết quả Ruby: {dir, polys: [{pts, holes, depth, src}] (xa đến gần), bounds, truncated}
  var view = {cx: 0, cy: 0, s: 0.1}, drag = null, selected = {}, tagNames = {};
  var raster = null;              // z-buffer đã tính: {key, W, H, id: Int32Array (chỉ số mặt, -1 = nền)}
  // Lúc đang kéo / cuộn: chỉ dời, co giãn ảnh đã vẽ (lastImg) cho mượt; dừng tay thì tính lại z-buffer (model lớn mất vài trăm ms mỗi lần).
  var quick = false, quickTimer = null, lastImg = null;
  function settle(ms) { quick = true; clearTimeout(quickTimer); quickTimer = setTimeout(function () { quick = false; draw(); }, ms); }
  // Hướng nhìn: nhãn, và cách đổi tọa độ trục lưới sang ngang s (s = dấu * tọa độ trục). Giả định hướng Bắc của model là +Y (mặc định SketchUp).
  var DIRS = {south: {label: 'Nam', axis: 'x', sign: 1}, north: {label: 'Bắc', axis: 'x', sign: -1}, west: {label: 'Tây', axis: 'y', sign: -1}, east: {label: 'Đông', axis: 'y', sign: 1}};
  var COLORS = {column: '#66DD00', beam: '#00AABA', wall: '#FF9966', slab: '#BA3300', ceiling: '#9900FF', door: '#FF7766', window: '#CCBAED', opening: '#FF7766', suobj: '#8A93A0', geom: '#666666', footing: '#999999', roof: '#FF6600', stair: '#FFBA00'};
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
    var f = VGDMarks.fit(bounds(), size); view.s = f.s; view.cx = f.cx; view.cy = f.cy; // chừa lề cho kích thước, ký hiệu cốt và trục
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
  function draw() {
    if (!ctx) return;
    ctx.setTransform(size.dpr, 0, 0, size.dpr, 0, 0);
    var bg = css('--vgd-surface', '#fff'), ink = css('--vgd-text', '#222'), muted = css('--vgd-muted', '#777'), accent = css('--vgd-accent', '#B48963');
    ctx.fillStyle = bg; ctx.fillRect(0, 0, size.w, size.h);
    if (!result) { ctx.fillStyle = muted; ctx.font = '13px sans-serif'; ctx.textAlign = 'center'; ctx.fillText(dir ? 'Đang chờ kết quả từ SketchUp...' : 'Chọn hướng nhìn: Nam, Bắc, Đông hoặc Tây.', size.w / 2, size.h / 2); return; }
    var left = toWorld(0, 0)[0], right = toWorld(size.w, 0)[0];
    var lv = {levels: S.levels, toScreen: toScreen, left: left, right: right, width: size.w, ink: ink, muted: muted};
    VGDMarks.levels(ctx, Object.assign({part: 'lines'}, lv));
    if (quick && lastImg && lastImg.result === result) { // ảnh cũ dời / co giãn theo khung nhìn mới (tạm thời, sẽ vẽ lại đúng khi dừng tay)
      var f = view.s / lastImg.s, tx = size.w / 2 * (1 - f) + (lastImg.cx - view.cx) * view.s, ty = size.h / 2 * (1 - f) - (lastImg.cy - view.cy) * view.s;
      ctx.setTransform(size.dpr * f, 0, 0, size.dpr * f, size.dpr * tx, size.dpr * ty); ctx.drawImage(lastImg.off, 0, 0, size.w, size.h);
    } else {
      var off = compose(bg, ink, accent); lastImg = {off: off, cx: view.cx, cy: view.cy, s: view.s, result: result};
      ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.drawImage(off, 0, 0); // chép 1:1 theo điểm ảnh thiết bị (không co giãn làm nhòe nét)
    }
    ctx.setTransform(size.dpr, 0, 0, size.dpr, 0, 0);
    // trục lưới (đặt sau các mặt để đọc được)
    var axes = gridAxes();
    axes.forEach(function (a) {
      var top = toScreen(a.s, bounds()[3] + 800), bot = toScreen(a.s, bounds()[1] - 300); top[1] = Math.max(top[1], 24); // vòng tên trục luôn trong khung nhìn
      ctx.strokeStyle = '#BA00CC'; ctx.globalAlpha = 0.5; ctx.setLineDash([10, 3, 2, 3]); ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(top[0], top[1]); ctx.lineTo(bot[0], bot[1]); ctx.stroke(); ctx.setLineDash([]); ctx.globalAlpha = 1;
      ctx.beginPath(); ctx.arc(top[0], top[1] - 11, 10, 0, Math.PI * 2); ctx.fillStyle = bg; ctx.fill(); ctx.strokeStyle = '#BA00CC'; ctx.stroke(); ctx.fillStyle = ink; ctx.font = '11px sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(a.name, top[0], top[1] - 11); ctx.textBaseline = 'alphabetic';
    });
    if (result.bounds) VGDMarks.dimensions(ctx, {levels: S.levels, bounds: [result.bounds.s0, result.bounds.z0, result.bounds.s1, result.bounds.z1], axes: axes, toScreen: toScreen, color: muted});
    VGDMarks.levels(ctx, Object.assign({part: 'labels'}, lv));
    ctx.fillStyle = muted; ctx.font = '11px sans-serif'; ctx.textAlign = 'right'; ctx.fillText('Mặt đứng ' + DIRS[dir].label + ' · 1 px = ' + (1 / view.s).toFixed(1) + ' mm', size.w - 8, size.h - 6);
  }

  // z-buffer theo điểm ảnh thiết bị: tô từng mặt theo đường quét (chẵn - lẻ trên mọi vòng nên lỗ để trống), độ sâu d = a s + b z + c của mặt;
  // điểm gần hơn (d nhỏ hơn) thắng, gần bằng nhau (0,5 mm) thì mặt sau trong danh sách (gần hơn theo trung bình) thắng. Chỉ tính lại khi khung nhìn đổi.
  function rasterKey() { return [Math.max(1, Math.round(size.w * size.dpr)), Math.max(1, Math.round(size.h * size.dpr)), view.cx, view.cy, view.s].join('|'); }
  function rasterize() {
    var W = Math.max(1, Math.round(size.w * size.dpr)), H = Math.max(1, Math.round(size.h * size.dpr)), key = rasterKey();
    if (raster && raster.key === key && raster.result === result) return raster;
    var id = new Int32Array(W * H).fill(-1), dep = new Float32Array(W * H).fill(Infinity), k = view.s * size.dpr;
    var dx = function (s) { return ((s - view.cx) * view.s + size.w / 2) * size.dpr; }, dy = function (z) { return (size.h / 2 - (z - view.cy) * view.s) * size.dpr; };
    result.polys.forEach(function (poly, pi) {
      var rings = [poly.pts].concat(poly.holes || []).map(function (r) { return r.map(function (p) { return [dx(p[0]), dy(p[1])]; }); });
      var ymin = Infinity, ymax = -Infinity; rings.forEach(function (r) { r.forEach(function (p) { if (p[1] < ymin) ymin = p[1]; if (p[1] > ymax) ymax = p[1]; }); });
      var y0 = Math.max(0, Math.ceil(ymin - 0.5)), y1 = Math.min(H - 1, Math.floor(ymax - 0.5)), pl = poly.plane || [0, 0, poly.depth];
      for (var y = y0; y <= y1; y++) {
        var yc = y + 0.5, xs = [];
        rings.forEach(function (r) { for (var i = 0; i < r.length; i++) { var a = r[i], b = r[(i + 1) % r.length]; if ((a[1] > yc) !== (b[1] > yc)) xs.push(a[0] + (yc - a[1]) * (b[0] - a[0]) / (b[1] - a[1])); } });
        xs.sort(function (a, b) { return a - b; });
        var z = view.cy + (size.h / 2 - yc / size.dpr) / view.s, dz = pl[1] * z + pl[2];
        for (var j = 0; j + 1 < xs.length; j += 2) {
          var xa = Math.max(0, Math.ceil(xs[j] - 0.5)), xb = Math.min(W - 1, Math.floor(xs[j + 1] - 0.5));
          for (var x = xa; x <= xb; x++) {
            var d = pl[0] * (view.cx + ((x + 0.5) - size.w / 2 * size.dpr) / k) + dz, o = y * W + x;
            if (d <= dep[o] + 0.5) { dep[o] = d; id[o] = pi; }
          }
        }
      }
    });
    raster = {key: key, result: result, W: W, H: H, id: id};
    return raster;
  }
  function rgb(hex) { var n = parseInt(String(hex).replace('#', ''), 16); return /^#?[0-9a-f]{6}$/i.test(String(hex)) ? [(n >> 16) & 255, (n >> 8) & 255, n & 255] : [128, 128, 128]; }
  // Ảnh mặt đứng (nền trong suốt): màu mặt theo loại, nét theo ranh giới điểm ảnh giữa các mặt nhìn thấy (đậm: giáp nền; vừa: khác đối tượng; mảnh: cùng đối tượng).
  function compose(bg, ink, accent) {
    var r = rasterize(), W = r.W, H = r.H, id = r.id, polys = result.polys;
    var fills = polys.map(function (p) { return rgb(mix(colorOf(p.src), bg, selected[keyOf(p.src)] ? 0.75 : 0.45)); }), keys = polys.map(function (p) { return keyOf(p.src); });
    var edge = new Uint8Array(W * H), INK = rgb(ink), ACC = rgb(accent), thick = Math.max(1, Math.round(size.dpr));
    var mark = function (o, v) { if (edge[o] < v) edge[o] = v; };
    for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) {
      var o = y * W + x, a = id[o];
      [[x + 1 < W, o + 1], [y + 1 < H, o + W]].forEach(function (n) {
        if (!n[0]) return; var b = id[n[1]]; if (a === b) return;
        var v = a < 0 || b < 0 ? 3 : keys[a] !== keys[b] ? 2 : 1;
        mark(o, v); if (v === 3) { mark(n[1], 3); for (var t = 1; t < thick; t++) { if (x + t < W) mark(o + t, 3); if (y + t < H) mark(o + t * W, 3); } }
      });
    }
    var off = document.createElement('canvas'); off.width = W; off.height = H;
    var g = off.getContext('2d'), img = g.createImageData(W, H), px = img.data;
    for (var i = 0; i < W * H; i++) {
      var p = id[i], e = edge[i], q = i * 4;
      if (p < 0 && !e) continue; // nền trong suốt: thấy cốt tầng phía sau
      var c = p >= 0 ? fills[p] : INK, on = p >= 0 && selected[keys[p]];
      if (e >= 2 || (e === 1 && on)) c = on ? ACC : INK;
      else if (e === 1) c = [Math.round(c[0] * 0.55 + INK[0] * 0.45), Math.round(c[1] * 0.55 + INK[1] * 0.45), Math.round(c[2] * 0.55 + INK[2] * 0.45)];
      px[q] = c[0]; px[q + 1] = c[1]; px[q + 2] = c[2]; px[q + 3] = 255;
    }
    g.putImageData(img, 0, 0);
    return off;
  }
  function pickAt(px, py) { // mặt nhìn thấy tại điểm bấm (theo z-buffer); chưa có z-buffer thì mặt gần nhất chứa điểm (chẵn - lẻ)
    if (!result) return null;
    if (raster && raster.result === result && raster.key === rasterKey()) { var ix = Math.floor(px * size.dpr), iy = Math.floor(py * size.dpr); if (ix >= 0 && iy >= 0 && ix < raster.W && iy < raster.H) { var hit = raster.id[iy * raster.W + ix]; return hit >= 0 ? result.polys[hit] : null; } }
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
    if (!src || src.kind === 'geom' || src.kind === 'roof' || !host.callSU) return; // hình rời và mái: chưa chọn được trong SketchUp (Ruby chỉ nhận loại trong SELECT_KINDS)
    host.callSU('plan_select', {level: src.level || S.level, items: [{kind: src.kind, ref: String(src.ref)}]});
  }
  function bind() {
    canvas.addEventListener('wheel', function (e) { e.preventDefault(); var r = canvas.getBoundingClientRect(), w0 = toWorld(e.clientX - r.left, e.clientY - r.top), f = e.deltaY < 0 ? 1.15 : 1 / 1.15; view.s = Math.min(5, Math.max(0.001, view.s * f)); var w1 = toWorld(e.clientX - r.left, e.clientY - r.top); view.cx += w0[0] - w1[0]; view.cy += w0[1] - w1[1]; settle(160); draw(); }, {passive: false});
    canvas.addEventListener('pointerdown', function (e) { var r = canvas.getBoundingClientRect(); drag = {x: e.clientX, y: e.clientY, cx: view.cx, cy: view.cy, moved: false, px: e.clientX - r.left, py: e.clientY - r.top}; canvas.setPointerCapture(e.pointerId); });
    canvas.addEventListener('pointermove', function (e) { if (!drag) return; var dx = e.clientX - drag.x, dy = e.clientY - drag.y; if (Math.abs(dx) + Math.abs(dy) > 4) drag.moved = true; if (drag.moved) { view.cx = drag.cx - dx / view.s; view.cy = drag.cy + dy / view.s; quick = true; draw(); } });
    canvas.addEventListener('pointerup', function () { if (drag && !drag.moved) { var p = pickAt(drag.px, drag.py); selectSrc(p ? p.src : null); } else if (drag) { quick = false; draw(); } drag = null; });
  }

  window.VGDElevation = {
    init: function (h) {
      host = h; S = h.state; canvas = $('elv-canvas'); ctx = canvas.getContext('2d'); bind();
      document.querySelectorAll('#elv-dirs button').forEach(function (b) { b.onclick = function () { setDir(b.getAttribute('data-dir')); }; });
      $('elv-refresh').onclick = request; $('elv-fit').onclick = function () { fit(); draw(); };
      window.addEventListener('resize', resize);
    },
    receive: receive, resize: resize,
    open: function (d) { if (DIRS[d]) setDir(d); }, // mở hướng nhìn (ký hiệu mặt đứng trên mặt bằng, cây dự án)
    show: function () { resize(); if (dir && !result) request(); },
    setTagNames: function (n) { tagNames = n || {}; draw(); },
    modelSelection: function (data) { // chọn trong SketchUp: sáng mặt cùng đối tượng
      selected = {}; ((data && data.items) || []).forEach(function (i) { selected[i.kind + '|' + (i.level || '') + '|' + i.ref] = true; if (i.kind === 'suobj') selected[i.kind + '||' + i.ref] = true; });
      if (result) result.polys.forEach(function (p) { if (p.src.kind === 'suobj' && selected['suobj||' + p.src.ref]) selected[keyOf(p.src)] = true; }); draw();
    },
    debug: function () { return {dir: dir, polys: result ? result.polys.length : 0, selected: Object.keys(selected), view: {cx: view.cx, cy: view.cy, s: view.s}, size: size, status: $('elv-status').textContent, axes: gridAxes().map(function (a) { return a.name; }), toScreen: toScreen}; }
  };
})();
