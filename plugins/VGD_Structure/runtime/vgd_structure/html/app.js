// Giao diện cửa sổ Lưới trục. Chỉ gom dữ liệu và hiển thị; Ruby kiểm tra lại và tính xem trước (Grid, AxisSymbol).
(function () {
  'use strict';
  var LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ'.split(''); // bỏ I và O, giống Grid::LETTERS ở Ruby
  var state = {origin: [0, 0], x: {first: 0, axes: []}, y: {first: 0, axes: []}, scale: 100, both: false, drawn: false, previewOk: false,
               types: [], levels: [], level: null, selected: null, drawnLevels: [], preview: null, tab: 'grid'};
  var MODE_X = [['auto', 'Theo quy ước'], ['center', 'Tâm trên trục'], ['min', 'Cạnh tây tại trục (cột lùi sang đông)'], ['max', 'Cạnh đông tại trục (cột lùi sang tây)']];
  var MODE_Y = [['auto', 'Theo quy ước'], ['center', 'Tâm trên trục'], ['min', 'Cạnh nam tại trục (cột lùi lên bắc)'], ['max', 'Cạnh bắc tại trục (cột lùi xuống nam)']];
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
    return {grid: {origin: state.origin, x_axes: toAxes('x'), y_axes: toAxes('y')}, symbol: {scale: state.scale, both_ends: state.both},
            types: state.types.map(function (t) { return {id: t.id, name: t.name, w: t.w, d: t.d}; }), levels: state.levels.map(toRubyLevel), level: state.level};
  }
  function toRubyLevel(l) {
    return {id: l.id, name: l.name, elevation: l.elevation, slab_thickness: l.slab, column_type: l.columnType || null, picks: {columns: clonePicks(l.picks)}};
  }
  function clonePicks(picks) { var out = {}; Object.keys(picks).forEach(function (k) { out[k] = Object.assign({}, picks[k]); }); return out; }
  function fromRubyLevel(l) {
    return {id: l.id, name: l.name, elevation: l.elevation, slab: l.slab_thickness, columnType: l.column_type, picks: clonePicks((l.picks && l.picks.columns) || {})};
  }
  function rid(prefix) {
    var a = new Uint8Array(4); (window.crypto || {getRandomValues: function (x) { for (var i = 0; i < x.length; i++) x[i] = Math.floor(Math.random() * 256); }}).getRandomValues(a);
    return prefix + Array.prototype.map.call(a, function (b) { return ('0' + b.toString(16)).slice(-2); }).join('');
  }
  function currentLevel() { return state.levels.filter(function (l) { return l.id === state.level; })[0] || state.levels[0]; }
  function typeById(id) { return state.types.filter(function (t) { return t.id === id; })[0]; }

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


  // ---- Tab Tầng và loại cột ----
  function numCell(value, onInput, label) {
    var input = document.createElement('input'); input.type = 'number'; input.step = 'any'; input.value = value; input.setAttribute('aria-label', label);
    input.oninput = function () { onInput(input.value === '' ? NaN : Number(input.value)); changed(); renderColumnsHeaderOnly(); };
    return input;
  }
  function textCell(value, onInput, label, cls) {
    var input = document.createElement('input'); input.type = 'text'; input.value = value; input.maxLength = 30; input.setAttribute('aria-label', label);
    if (cls) input.className = cls;
    input.oninput = function () { onInput(input.value); changed(); renderColumnsHeaderOnly(); };
    return input;
  }
  function heads(table, list) {
    var row = table.insertRow();
    list.forEach(function (t) { var th = document.createElement('th'); th.textContent = t; row.appendChild(th); });
  }
  function renderTypes() {
    var table = $('types-table'); table.replaceChildren();
    heads(table, ['Tên', 'Rộng X (mm)', 'Sâu Y (mm)', '']);
    state.types.forEach(function (t, i) {
      var row = table.insertRow(), del = document.createElement('button');
      row.insertCell().appendChild(textCell(t.name, function (v) { t.name = v; refreshTypeSelects(); }, 'Tên loại cột ' + (i + 1)));
      row.insertCell().appendChild(numCell(t.w, function (v) { t.w = v; }, 'Rộng loại ' + t.name));
      row.insertCell().appendChild(numCell(t.d, function (v) { t.d = v; }, 'Sâu loại ' + t.name));
      del.type = 'button'; del.className = 'del'; del.textContent = '×'; del.title = 'Xóa loại cột này'; del.disabled = state.types.length <= 1;
      del.onclick = function () { removeType(t.id); };
      row.insertCell().appendChild(del);
    });
  }
  // Xóa loại cột: tầng và cột đang dùng loại đó chuyển về loại mặc định (loại đầu danh sách).
  function removeType(id) {
    state.types = state.types.filter(function (t) { return t.id !== id; });
    state.levels.forEach(function (l) {
      if (l.columnType === id) l.columnType = null;
      Object.keys(l.picks).forEach(function (ref) { if (l.picks[ref].type === id) delete l.picks[ref].type; });
    });
    renderLevels(); renderColumnsTab(); changed();
  }
  // Cập nhật danh sách loại cột trong ô chọn loại mặc định của từng tầng (khi đổi tên loại), giữ giá trị đang chọn.
  function refreshTypeSelects() {
    $('levels-table').querySelectorAll('select').forEach(function (sel, i) {
      var keep = state.levels[i] && state.levels[i].columnType || '';
      sel.replaceChildren(); sel.append(new Option('Loại đầu danh sách', ''));
      state.types.forEach(function (t) { sel.append(new Option(t.name, t.id)); });
      sel.value = keep;
    });
  }
  function levelNote(i) {
    var l = state.levels[i], above = state.levels[i + 1];
    if (!above) return 'Tầng trên cùng: chỉ có sàn';
    var h = Math.round((above.elevation - above.slab - l.elevation) * 10) / 10;
    return Number.isFinite(h) ? 'Cột cao ' + h + ' mm' : '?';
  }
  function renderLevels() {
    var table = $('levels-table'); table.replaceChildren();
    heads(table, ['Tên tầng', 'Cao độ sàn (mm)', 'Dày sàn (mm)', 'Loại cột mặc định', 'Ghi chú', '']);
    state.levels.forEach(function (l, i) {
      var row = table.insertRow(), sel = document.createElement('select'), del = document.createElement('button');
      row.insertCell().appendChild(textCell(l.name, function (v) { l.name = v; renderLevelSelects(); }, 'Tên tầng ' + (i + 1)));
      row.insertCell().appendChild(numCell(l.elevation, function (v) { l.elevation = v; refreshLevelNotes(); }, 'Cao độ ' + l.name));
      row.insertCell().appendChild(numCell(l.slab, function (v) { l.slab = v; refreshLevelNotes(); }, 'Dày sàn ' + l.name));
      sel.setAttribute('aria-label', 'Loại cột mặc định ' + l.name);
      sel.append(new Option('Loại đầu danh sách', ''));
      state.types.forEach(function (t) { sel.append(new Option(t.name, t.id)); });
      sel.value = l.columnType || '';
      sel.onchange = function () { l.columnType = sel.value || null; changed(); };
      row.insertCell().appendChild(sel);
      var note = row.insertCell(); note.className = 'note'; note.textContent = levelNote(i);
      del.type = 'button'; del.className = 'del'; del.textContent = '×'; del.title = 'Xóa tầng này'; del.disabled = state.levels.length <= 1;
      del.onclick = function () { removeLevel(l.id); };
      row.insertCell().appendChild(del);
    });
    renderTypes();
  }
  function refreshLevelNotes() {
    $('levels-table').querySelectorAll('td.note').forEach(function (cell, i) { cell.textContent = levelNote(i); });
  }
  function removeLevel(id) {
    state.levels = state.levels.filter(function (l) { return l.id !== id; });
    if (state.level === id) state.level = state.levels[0].id;
    state.selected = null; renderLevels(); renderColumnsTab(); changed();
  }
  function addLevel() {
    var last = state.levels[state.levels.length - 1], n = state.levels.length + 1, name = 'Tầng ' + n, taken = state.levels.map(function (l) { return l.name.toLowerCase(); });
    while (taken.indexOf(name.toLowerCase()) >= 0) name += '*';
    state.levels.push({id: rid('sl_'), name: name, elevation: Number.isFinite(last.elevation) ? last.elevation + 3600 : 0, slab: 120, columnType: null, picks: {}});
    renderLevels(); renderColumnsTab(); changed();
  }
  function addType() {
    var base = state.types[state.types.length - 1], n = state.types.length + 1, name = 'Loại ' + n, taken = state.types.map(function (t) { return t.name.toLowerCase(); });
    while (taken.indexOf(name.toLowerCase()) >= 0) name += '*';
    state.types.push({id: rid('ct_'), name: name, w: base ? base.w : 300, d: base ? base.d : 300});
    renderLevels(); changed();
  }

  // ---- Tab Cột ----
  function renderLevelSelects() {
    var sel = $('level-select'), from = $('copy-from');
    sel.replaceChildren(); from.replaceChildren();
    state.levels.forEach(function (l, i) {
      sel.append(new Option(l.name, l.id));
      if (l.id !== state.level) from.append(new Option(l.name, l.id));
    });
    sel.value = state.level;
  }
  function renderColumnsTab() { renderLevelSelects(); renderColumnsHeaderOnly(); renderEditor(); renderColumnsButtons(); renderColumnsPlan(); }
  function renderColumnsHeaderOnly() {
    var i = state.levels.indexOf(currentLevel());
    if (i < 0) return;
    $('level-note').textContent = levelNote(i);
  }
  function renderColumnsButtons() {
    var l = currentLevel(), top = state.levels.indexOf(l) === state.levels.length - 1;
    $('build-cols').disabled = top || !state.previewOk || !Object.keys(l.picks).length;
    $('build-all-cols').disabled = !state.previewOk;
    $('remove-cols').disabled = state.drawnLevels.indexOf(l.id) < 0;
    $('pick-all').disabled = $('pick-none').disabled = top;
    $('copy-picks').disabled = top || !$('copy-from').options.length;
  }
  function allRefs() {
    var gx = toAxes('x'), gy = toAxes('y'), out = [];
    gx.forEach(function (ax) { gy.forEach(function (ay) { out.push({ref: ax.name + '-' + ay.name, x: state.origin[0] + ax.offset, y: state.origin[1] + ay.offset}); }); });
    return out;
  }
  function pickRef(ref) { var l = currentLevel(); if (!l.picks[ref]) l.picks[ref] = {}; state.selected = ref; renderEditor(); changed(); }
  function modeSelect(id, options, value) {
    var sel = $(id); sel.replaceChildren();
    options.forEach(function (o) { sel.append(new Option(o[1], o[0])); });
    sel.value = value || 'auto';
  }
  function renderEditor() {
    var l = currentLevel(), pick = state.selected && l.picks[state.selected];
    $('col-editor').hidden = !pick;
    if (!pick) return;
    $('col-ref').textContent = state.selected;
    var t = $('col-type'); t.replaceChildren(); t.append(new Option('Theo loại mặc định của tầng', ''));
    state.types.forEach(function (ty) { t.append(new Option(ty.name + ' (' + ty.w + '×' + ty.d + ')', ty.id)); });
    t.value = pick.type || '';
    modeSelect('col-x', MODE_X, pick.x); modeSelect('col-y', MODE_Y, pick.y);
  }
  function renderColumnsPlan() {
    var svg = $('plan2'), ns = 'http://www.w3.org/2000/svg', data = state.preview;
    svg.replaceChildren();
    if (!data || !data.ok) return;
    var xs = [], ys = [];
    data.axes.forEach(function (a) { a.line.forEach(function (p) { xs.push(p[0]); ys.push(p[1]); }); });
    var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs), y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys), pad = Math.max(x1 - x0, y1 - y0) * 0.05;
    svg.setAttribute('viewBox', [x0 - pad, -(y1 + pad), x1 - x0 + 2 * pad, y1 - y0 + 2 * pad].join(' '));
    function el(tag, attrs, text) { var e = document.createElementNS(ns, tag); Object.keys(attrs).forEach(function (k) { e.setAttribute(k, attrs[k]); }); if (text !== undefined) e.textContent = text; svg.appendChild(e); return e; }
    data.axes.forEach(function (a) { el('line', {class: 'axis', x1: a.line[0][0], y1: -a.line[0][1], x2: a.line[1][0], y2: -a.line[1][1]}); });
    data.axes.forEach(function (a) { var b = a.bubbles[0]; el('text', {x: b.center[0], y: -b.center[1], 'font-size': Math.max(x1 - x0, y1 - y0) * 0.022}, a.name); });
    var l = currentLevel(), top = state.levels.indexOf(l) === state.levels.length - 1, cols = (data.columns && data.columns.items) || [], byRef = {};
    cols.forEach(function (c) { byRef[c.ref] = c; });
    var def = typeById(l.columnType) || state.types[0] || {w: 300, d: 300}, ghost = Math.max(def.w, def.d, (x1 - x0) * 0.012);
    if (!top) allRefs().forEach(function (pt) {
      var c = byRef[pt.ref];
      if (c) {
        var r = el('rect', {class: 'col' + (state.selected === pt.ref ? ' sel' : ''), x: c.center[0] - c.w / 2, y: -(c.center[1] + c.d / 2), width: c.w, height: c.d, 'data-ref': pt.ref});
        r.onclick = function () { state.selected = pt.ref; renderEditor(); renderColumnsPlan(); };
        var tip = document.createElementNS(ns, 'title'); tip.textContent = pt.ref + ' · ' + c.type_name + ' · ' + c.w + '×' + c.d; r.appendChild(tip);
      } else {
        var g = el('rect', {class: 'ghost', x: pt.x - ghost / 2, y: -(pt.y + ghost / 2), width: ghost, height: ghost, 'data-ref': pt.ref});
        g.onclick = function () { pickRef(pt.ref); };
      }
    });
    var summary = $('col-summary'), issues = $('col-issues'); issues.replaceChildren();
    if (data.levels_ok === false) { summary.className = 'summary error'; summary.textContent = data.levels_error; return; }
    if (data.columns_error) { summary.className = 'summary'; summary.textContent = data.columns_error; return; }
    if (data.columns) {
      summary.className = 'summary';
      summary.textContent = data.columns.level_name + ': ' + data.columns.count + ' cột, cao ' + data.columns.height + ' mm (từ cao độ ' + data.columns.z0 + ' đến ' + data.columns.z1 + ').' + (data.removed ? ' Đã bỏ ' + data.removed + ' lựa chọn không còn trên lưới.' : '');
      data.columns.issues.forEach(function (m) { var li = document.createElement('li'); li.textContent = m; issues.appendChild(li); });
    } else { summary.textContent = ''; }
  }
  function switchTab(tab) {
    state.tab = tab;
    document.querySelectorAll('.tabs button').forEach(function (b) { b.setAttribute('aria-selected', String(b.getAttribute('data-tab') === tab)); });
    ['grid', 'levels', 'columns'].forEach(function (t) { $('tab-' + t).hidden = t !== tab; });
    if (tab === 'columns') renderColumnsTab();
  }

  function receive(event, data) {
    if (event === 'state') {
      state.origin = data.grid.origin.slice();
      var x = fromAxes(data.grid.x_axes), y = fromAxes(data.grid.y_axes);
      state.x = x; state.y = y; state.scale = data.symbol.scale; state.both = data.symbol.both_ends; state.drawn = data.drawn;
      state.types = data.types.map(function (t) { return {id: t.id, name: t.name, w: t.w, d: t.d}; });
      state.levels = data.levels.map(fromRubyLevel); state.level = state.levels[0].id; state.selected = null; state.drawnLevels = data.drawn_levels || [];
      $('version').textContent = 'v' + data.version;
      renderAll(); renderLevels(); renderColumnsTab();
      message(data.saved ? 'Đã nạp lưới trục lưu trong model.' : 'Lưới mặc định: sửa các số rồi bấm Vẽ lưới trục.');
    } else if (event === 'preview') {
      state.previewOk = !!data.ok;
      var s = $('summary');
      if (data.ok) {
        var m = data.summary;
        s.className = 'summary';
        s.textContent = m.x_axes + ' trục đứng × ' + m.y_axes + ' trục ngang: ' + m.intersections + ' giao điểm, ' + m.spans + ' nhịp, ' + m.cells + ' ô. Khung lưới ' + m.width + ' × ' + m.depth + ' mm.';
      } else { s.className = 'summary error'; s.textContent = data.error; }
      state.preview = data; drawPlan(data); renderButtons(); renderColumnsButtons(); renderColumnsPlan();
    } else if (event === 'axes') {
      var set = fromAxes(data.axes); state[data.dir] = set; renderAxes(data.dir); changed();
    } else if (event === 'levels') {
      state.levels = data.levels.map(fromRubyLevel); renderLevels(); renderColumnsTab(); changed(); message(data.message);
    } else if (event === 'columns_built') {
      state.drawnLevels = data.drawn_levels || []; renderColumnsButtons(); message(data.message, data.error);
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

  document.querySelectorAll('.tabs button').forEach(function (b) { b.onclick = function () { switchTab(b.getAttribute('data-tab')); }; });
  $('add-type').onclick = addType; $('add-level').onclick = addLevel;
  $('level-select').onchange = function () { state.level = $('level-select').value; state.selected = null; renderColumnsTab(); changed(); };
  $('pick-all').onclick = function () { var l = currentLevel(); allRefs().forEach(function (pt) { if (!l.picks[pt.ref]) l.picks[pt.ref] = {}; }); changed(); renderColumnsButtons(); };
  $('pick-none').onclick = function () { currentLevel().picks = {}; state.selected = null; renderEditor(); changed(); renderColumnsButtons(); };
  $('col-remove').onclick = function () { delete currentLevel().picks[state.selected]; state.selected = null; renderEditor(); changed(); renderColumnsButtons(); };
  $('col-type').onchange = function () { var p = currentLevel().picks[state.selected]; if ($('col-type').value) p.type = $('col-type').value; else delete p.type; changed(); };
  $('col-x').onchange = function () { var p = currentLevel().picks[state.selected]; if ($('col-x').value === 'auto') delete p.x; else p.x = $('col-x').value; changed(); };
  $('col-y').onchange = function () { var p = currentLevel().picks[state.selected]; if ($('col-y').value === 'auto') delete p.y; else p.y = $('col-y').value; changed(); };
  $('copy-picks').onclick = function () { var p = payload(); p.from = $('copy-from').value; p.to = state.level; call('picks_copy', p); };
  $('build-cols').onclick = function () { call('columns_build', {state: payload(), levels: [state.level]}); };
  $('build-all-cols').onclick = function () {
    var ids = state.levels.slice(0, -1).filter(function (l) { return Object.keys(l.picks).length; }).map(function (l) { return l.id; });
    call('columns_build', {state: payload(), levels: ids});
  };
  $('remove-cols').onclick = function () { call('columns_remove', {level: state.level}); };
  $('build').onclick = function () { call('grid_build', payload()); };
  $('remove').onclick = function () { call('grid_remove'); };
  $('reset').onclick = function () { call('grid_reset'); };
  if (window.VGDTheme) window.VGDTheme.start({key: 'vgd.structure.theme', button: $('theme')});
  window.addEventListener('load', function () { call('ready'); });
})();
