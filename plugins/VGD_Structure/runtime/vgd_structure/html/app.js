// Giao diện cửa sổ Lưới trục. Chỉ gom dữ liệu và hiển thị; Ruby kiểm tra lại và tính xem trước (Grid, AxisSymbol).
(function () {
  'use strict';
  var LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ'.split(''); // bỏ I và O, giống Grid::LETTERS ở Ruby
  var state = {origin: [0, 0], x: {first: 0, axes: []}, y: {first: 0, axes: []}, scale: 100, both: false, drawn: false, previewOk: false};
  var timer = null;
  var $ = function (id) { return document.getElementById(id); };

  function call(name, data) { window.sketchup[name](data === undefined ? '' : JSON.stringify(data)); }
  function message(text, error) { var el = $('message'); el.textContent = text || 'Sẵn sàng.'; el.className = error ? 'error' : ''; }

  // Tên mặc định: số hoặc chữ (hết 24 chữ thì AA, AB...), giống Grid.default_names.
  function defaultName(dir, index) {
    if (dir === 'x') return String(index + 1);
    return index < LETTERS.length ? LETTERS[index] : LETTERS[Math.floor(index / LETTERS.length) - 1] + LETTERS[index % LETTERS.length];
  }
  function freeName(dir, taken) {
    var all = state.x.axes.concat(state.y.axes).map(function (a) { return a.name.toLowerCase(); });
    for (var i = taken; i < taken + 200; i++) { var n = defaultName(dir, i); if (all.indexOf(n.toLowerCase()) < 0) return n; }
    return '?';
  }

  // Mỗi trục lưu khoảng cách tới trục trước (nhịp); vị trí = gốc của trục đầu + cộng dồn.
  function fromAxes(list) {
    var first = list.length ? list[0].offset : 0;
    return {first: first, axes: list.map(function (a, i) { return {name: a.name, span: i === 0 ? 0 : Math.round((a.offset - list[i - 1].offset) * 10) / 10}; })};
  }
  function toAxes(dir) {
    var set = state[dir], offset = set.first;
    return set.axes.map(function (a, i) { if (i > 0) offset = Math.round((offset + a.span) * 10) / 10; return {name: a.name, offset: offset}; });
  }
  function payload() {
    return {grid: {origin: state.origin, x_axes: toAxes('x'), y_axes: toAxes('y')}, symbol: {scale: state.scale, both_ends: state.both}};
  }

  function renderAxes(dir) {
    var table = $('axes-' + dir), set = state[dir], positions = toAxes(dir);
    table.replaceChildren();
    var head = table.insertRow();
    ['Tên', 'Cách trục trước (mm)', 'Vị trí (mm)', ''].forEach(function (t) { var th = document.createElement('th'); th.textContent = t; head.appendChild(th); });
    set.axes.forEach(function (axis, i) {
      var row = table.insertRow(), name = document.createElement('input'), span = document.createElement('input'), del = document.createElement('button');
      name.className = 'name'; name.type = 'text'; name.maxLength = 4; name.value = axis.name; name.setAttribute('aria-label', 'Tên trục ' + (i + 1));
      name.oninput = function () { axis.name = name.value; changed(); };
      span.type = 'number'; span.step = 'any'; span.min = '0'; span.value = axis.span; span.disabled = i === 0; span.setAttribute('aria-label', 'Nhịp tới trục ' + axis.name);
      span.oninput = function () { axis.span = span.value === '' ? NaN : Number(span.value); changed(true); };
      del.type = 'button'; del.className = 'del'; del.textContent = '×'; del.title = 'Xóa trục này'; del.disabled = set.axes.length <= 2;
      del.onclick = function () { set.axes.splice(i, 1); renderAxes(dir); changed(); };
      row.insertCell().appendChild(name); row.insertCell().appendChild(span);
      var pos = row.insertCell(); pos.className = 'pos'; pos.textContent = positions[i].offset; row.insertCell().appendChild(del);
    });
  }
  function renderAll() {
    $('origin-x').value = state.origin[0]; $('origin-y').value = state.origin[1];
    renderAxes('x'); renderAxes('y');
    $('scale').value = String(state.scale); $('both').checked = state.both;
    renderButtons();
  }
  function renderButtons() {
    $('build').textContent = state.drawn ? 'Vẽ lại lưới trục' : 'Vẽ lưới trục';
    $('build').disabled = !state.previewOk;
    $('remove').disabled = !state.drawn;
  }

  function changed(positionsOnly) {
    if (positionsOnly) refreshPositions();
    clearTimeout(timer);
    timer = setTimeout(function () { call('grid_preview', payload()); }, 150);
  }
  function refreshPositions() {
    ['x', 'y'].forEach(function (dir) {
      var cells = $('axes-' + dir).querySelectorAll('td.pos'), positions = toAxes(dir);
      cells.forEach(function (cell, i) { cell.textContent = Number.isFinite(positions[i].offset) ? positions[i].offset : '?'; });
    });
  }

  // Xem trước mặt bằng bằng SVG từ kế hoạch Ruby (mm, Y hướng lên): lật trục Y, nét không đổi độ dày khi thu phóng.
  function drawPlan(data) {
    var svg = $('plan'), ns = 'http://www.w3.org/2000/svg';
    svg.replaceChildren();
    if (!data.ok) return;
    var xs = [], ys = [];
    data.axes.forEach(function (a) {
      a.line.forEach(function (p) { xs.push(p[0]); ys.push(p[1]); });
      a.bubbles.forEach(function (b) { xs.push(b.center[0] - b.radius, b.center[0] + b.radius); ys.push(b.center[1] - b.radius, b.center[1] + b.radius); });
    });
    var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs), y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys);
    var pad = Math.max(x1 - x0, y1 - y0) * 0.04;
    svg.setAttribute('viewBox', [x0 - pad, -(y1 + pad), x1 - x0 + 2 * pad, y1 - y0 + 2 * pad].join(' '));
    function el(tag, attrs, text) { var e = document.createElementNS(ns, tag); Object.keys(attrs).forEach(function (k) { e.setAttribute(k, attrs[k]); }); if (text !== undefined) e.textContent = text; svg.appendChild(e); return e; }
    data.axes.forEach(function (a) { el('line', {class: 'axis', x1: a.line[0][0], y1: -a.line[0][1], x2: a.line[1][0], y2: -a.line[1][1]}); });
    var gx = toAxes('x'), gy = toAxes('y'), r = data.axes[0].bubbles[0].radius * 0.18;
    gx.forEach(function (ax) { gy.forEach(function (ay) { el('circle', {class: 'node', cx: state.origin[0] + ax.offset, cy: -(state.origin[1] + ay.offset), r: r}); }); });
    data.axes.forEach(function (a) {
      a.bubbles.forEach(function (b) {
        el('circle', {class: 'bubble', cx: b.center[0], cy: -b.center[1], r: b.radius});
        el('text', {x: b.center[0], y: -b.center[1], 'font-size': a.text_height}, a.name);
      });
    });
  }

  function receive(event, data) {
    if (event === 'state') {
      state.origin = data.grid.origin.slice();
      var x = fromAxes(data.grid.x_axes), y = fromAxes(data.grid.y_axes);
      state.x = x; state.y = y; state.scale = data.symbol.scale; state.both = data.symbol.both_ends; state.drawn = data.drawn;
      $('version').textContent = 'v' + data.version;
      renderAll();
      message(data.saved ? 'Đã nạp lưới trục lưu trong model.' : 'Lưới mặc định: sửa các số rồi bấm Vẽ lưới trục.');
    } else if (event === 'preview') {
      state.previewOk = !!data.ok;
      var s = $('summary');
      if (data.ok) {
        var m = data.summary;
        s.className = 'summary';
        s.textContent = m.x_axes + ' trục đứng × ' + m.y_axes + ' trục ngang: ' + m.intersections + ' giao điểm, ' + m.spans + ' nhịp, ' + m.cells + ' ô. Khung lưới ' + m.width + ' × ' + m.depth + ' mm.';
      } else { s.className = 'summary error'; s.textContent = data.error; }
      drawPlan(data); renderButtons();
    } else if (event === 'axes') {
      var set = fromAxes(data.axes); state[data.dir] = set; renderAxes(data.dir); changed();
    } else if (event === 'built') {
      state.drawn = data.drawn; renderButtons(); message(data.message);
    } else if (event === 'message') {
      message(data.text, data.error);
    }
  }
  window.VGDS = {receive: receive, _state: state};

  $('origin-x').oninput = function () { state.origin[0] = Number($('origin-x').value); changed(); };
  $('origin-y').oninput = function () { state.origin[1] = Number($('origin-y').value); changed(); };
  $('scale').onchange = function () { state.scale = Number($('scale').value); changed(); };
  $('both').onchange = function () { state.both = $('both').checked; changed(); };
  document.querySelectorAll('[data-add]').forEach(function (button) {
    button.onclick = function () {
      var dir = button.getAttribute('data-add'), set = state[dir], last = set.axes[set.axes.length - 1];
      set.axes.push({name: freeName(dir, set.axes.length), span: last && last.span > 0 ? last.span : 3600});
      renderAxes(dir); changed();
    };
  });
  document.querySelectorAll('[data-quick]').forEach(function (button) {
    button.onclick = function () { var dir = button.getAttribute('data-quick'); call('grid_axes', {dir: dir, text: $('quick-' + dir).value}); };
  });
  $('build').onclick = function () { call('grid_build', payload()); };
  $('remove').onclick = function () { call('grid_remove'); };
  $('reset').onclick = function () { call('grid_reset'); };
  if (window.VGDTheme) window.VGDTheme.start({key: 'vgd.structure.theme', button: $('theme')});
  window.addEventListener('load', function () { call('ready'); });
})();
