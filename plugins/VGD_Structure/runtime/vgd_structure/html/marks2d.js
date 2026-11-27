// Phần vẽ dùng chung cho mặt đứng và mặt cắt 2D: cốt cao độ tầng (đường + ký hiệu tam giác + số ±0.000), chuỗi kích thước chiều cao tầng và kích thước tổng,
// và mẫu hatch theo vật liệu của phần bị cắt. Chỉ vẽ, không giữ trạng thái; mỗi view truyền ctx, hàm đổi tọa độ (s, z) -> màn hình và màu.
(function () {
  'use strict';
  // Vật liệu theo loại phần tử: bê tông (kết cấu), gạch (tường), hoàn thiện (trần), không hatch (cửa, đối tượng lạ).
  var MATERIAL = {column: 'concrete', beam: 'concrete', slab: 'concrete', footing: 'concrete', stair: 'concrete', roof: 'concrete', wall: 'masonry', ceiling: 'finish'};
  var patterns = {};

  function line(ctx, a, b) { ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke(); }
  function levelText(e) { return (e >= 0 ? '+' : '-') + (Math.abs(e) / 1000).toFixed(3); }

  // Cốt tầng: đường hoàn thiện nét liền, đường kết cấu nét đứt mảnh; ký hiệu cốt (tam giác) ở mép phải khung nhìn kèm tên tầng và số cao độ.
  // o.part: 'lines' (vẽ trước hình, nằm dưới) hoặc 'labels' (vẽ sau cùng để không bị hình che); không có thì vẽ cả hai.
  function levels(ctx, o) {
    o.levels.forEach(function (l) {
      [[l.elevation, [], 1], [l.elevation - (l.screed || 0), [4, 4], 0.6]].forEach(function (x, i) {
        var a = o.toScreen(o.left, x[0]), b = o.toScreen(o.right, x[0]);
        if (o.part !== 'labels') { ctx.strokeStyle = o.muted; ctx.globalAlpha = 0.6; ctx.lineWidth = x[2]; ctx.setLineDash(x[1]); line(ctx, a, b); ctx.setLineDash([]); ctx.globalAlpha = 1; }
        if (i || o.part === 'lines') return;
        var px = o.width - 96, py = a[1];
        ctx.fillStyle = o.ink; ctx.beginPath(); ctx.moveTo(px, py); ctx.lineTo(px - 6, py - 8); ctx.lineTo(px + 6, py - 8); ctx.closePath(); ctx.fill();
        ctx.font = '11px sans-serif'; ctx.textAlign = 'left'; ctx.fillText(levelText(l.elevation), px + 10, py - 2);
        ctx.fillStyle = o.muted; ctx.fillText(l.name, px + 10, py + 11);
      });
    });
  }

  // Một kích thước: đường kích thước, hai vạch chéo ở đầu, đường gióng ngắn và số mm ở giữa. vertical: chiều đứng (số xoay 90 độ).
  function dim(ctx, a, b, text, vertical, color) {
    ctx.strokeStyle = color; ctx.fillStyle = color; ctx.lineWidth = 0.8; line(ctx, a, b);
    [a, b].forEach(function (p) { ctx.beginPath(); ctx.moveTo(p[0] - 4, p[1] + 4); ctx.lineTo(p[0] + 4, p[1] - 4); ctx.stroke(); });
    ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
    var mx = (a[0] + b[0]) / 2, my = (a[1] + b[1]) / 2;
    if (vertical) { ctx.save(); ctx.translate(mx - 4, my); ctx.rotate(-Math.PI / 2); ctx.fillText(text, 0, 0); ctx.restore(); } else ctx.fillText(text, mx, my - 4);
  }

  // Kích thước: chuỗi chiều cao tầng (giữa các cốt hoàn thiện) và tổng chiều cao hình ở bên trái; tổng chiều dài và chuỗi khoảng trục ở dưới.
  // o: {levels, bounds: [s0, z0, s1, z1], axes: [{s}], toScreen, color}. Chỉ vẽ khi đủ chỗ (đoạn ngắn hơn 14 px thì bỏ số).
  function dimensions(ctx, o) {
    var b = o.bounds, col = o.color, gap = 18;
    var leftX = o.toScreen(b[0], 0)[0] - 46, botY = o.toScreen(0, b[1])[1] + 34;
    var zs = o.levels.map(function (l) { return l.elevation; }).filter(function (z) { return z >= b[1] - 1 && z <= b[3] + 1; }).sort(function (x, y) { return x - y; });
    for (var i = 0; i + 1 < zs.length; i++) {
      var p = [leftX, o.toScreen(0, zs[i])[1]], q = [leftX, o.toScreen(0, zs[i + 1])[1]];
      if (Math.abs(p[1] - q[1]) >= 14) dim(ctx, p, q, String(Math.round(zs[i + 1] - zs[i])), true, col);
    }
    var t0 = [leftX - gap, o.toScreen(0, b[1])[1]], t1 = [leftX - gap, o.toScreen(0, b[3])[1]];
    if (Math.abs(t0[1] - t1[1]) >= 14) dim(ctx, t0, t1, String(Math.round(b[3] - b[1])), true, col);
    var ss = (o.axes || []).map(function (a) { return a.s; }).sort(function (x, y) { return x - y; });
    for (var k = 0; k + 1 < ss.length; k++) {
      var u = [o.toScreen(ss[k], 0)[0], botY], v = [o.toScreen(ss[k + 1], 0)[0], botY];
      if (Math.abs(u[0] - v[0]) >= 14) dim(ctx, u, v, String(Math.round(ss[k + 1] - ss[k])), false, col);
    }
    var l0 = [o.toScreen(b[0], 0)[0], botY + gap], l1 = [o.toScreen(b[2], 0)[0], botY + gap];
    if (Math.abs(l0[0] - l1[0]) >= 14) dim(ctx, l0, l1, String(Math.round(b[2] - b[0])), false, col);
  }

  // Mẫu hatch (ô 12 px lặp lại) cho phần bị cắt theo vật liệu; null nếu loại không hatch.
  function hatch(ctx, kind, ink) {
    var mat = MATERIAL[kind];
    if (!mat) return null;
    var key = mat + '|' + ink;
    if (patterns[key]) return patterns[key];
    var c = document.createElement('canvas'); c.width = 12; c.height = 12;
    var g = c.getContext('2d'); g.strokeStyle = ink; g.fillStyle = ink; g.lineWidth = 0.7; g.globalAlpha = 0.55;
    if (mat === 'concrete') { g.beginPath(); g.moveTo(0, 12); g.lineTo(12, 0); g.stroke(); g.fillRect(3, 3, 1, 1); g.fillRect(8, 9, 1, 1); g.fillRect(9, 4, 1, 1); }
    else if (mat === 'masonry') { g.beginPath(); g.moveTo(0, 12); g.lineTo(12, 0); g.moveTo(-6, 12); g.lineTo(6, 0); g.moveTo(6, 12); g.lineTo(18, 0); g.stroke(); }
    else { g.beginPath(); g.moveTo(0, 6); g.lineTo(12, 6); g.stroke(); }
    patterns[key] = ctx.createPattern(c, 'repeat');
    return patterns[key];
  }

  // Vừa khung có chừa lề: trái cho chuỗi kích thước đứng, phải cho ký hiệu cốt, dưới cho kích thước ngang, trên cho ký hiệu trục.
  // b = [s0, z0, s1, z1] (mm), size = {w, h}. Trả về {cx, cy, s} cho phép đổi toScreen(s, z) = [(s - cx) k + w / 2, h / 2 - (z - cy) k].
  var PAD = {l: 84, r: 112, t: 44, b: 74};
  function fit(b, size) {
    var w = Math.max(b[2] - b[0], 1), h = Math.max(b[3] - b[1], 1);
    var k = Math.min(5, Math.max(0.001, Math.min((size.w - PAD.l - PAD.r) / w, (size.h - PAD.t - PAD.b) / h)));
    return {s: k, cx: b[0] + (size.w / 2 - PAD.l) / k, cy: b[3] - (size.h / 2 - PAD.t) / k};
  }

  window.VGDMarks = {fit: fit, levels: levels, dimensions: dimensions, hatch: hatch, material: function (kind) { return MATERIAL[kind] || null; }, levelText: levelText};
})();
