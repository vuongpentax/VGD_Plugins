// Giao diện cửa sổ Lưới trục. Chỉ gom dữ liệu và hiển thị; Ruby kiểm tra lại và tính xem trước (Grid, AxisSymbol).
(function () {
  'use strict';
  var LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ'.split(''); // bỏ I và O, giống Grid::LETTERS ở Ruby
  var state = {origin: [0, 0], x: {first: 0, axes: []}, y: {first: 0, axes: []}, scale: 100, both: false, drawn: false, previewOk: false,
               types: [], beamTypes: [], wallTypes: [], levels: [], level: null, selected: null, drawnLevels: [], drawnBeamLevels: [], selectedBeam: null, drawnWallLevels: [], selectedWall: null, drawnSlabLevels: [], drawnCeilingLevels: [], preview: null, tab: 'grid'};
  var MODE_P = [['auto', 'Theo quy ước'], ['center', 'Tâm trên trục'], ['min', 'Cạnh nhỏ (nam / tây) tại trục'], ['max', 'Cạnh lớn (bắc / đông) tại trục']];
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
            types: state.types.map(function (t) { return {id: t.id, name: t.name, w: t.w, d: t.d}; }),
            beam_types: state.beamTypes.map(function (t) { return {id: t.id, name: t.name, w: t.w, h: t.h}; }),
            wall_types: state.wallTypes.map(function (t) { return {id: t.id, name: t.name, t: t.t}; }), levels: state.levels.map(toRubyLevel), level: state.level};
  }
  function toRubyLevel(l) {
    return {id: l.id, name: l.name, elevation: l.elevation, slab_thickness: l.slab, column_type: l.columnType || null, beam_type: l.beamType || null, wall_type: l.wallType || null, ceiling_height: l.ceilingHeight, ceiling_thickness: l.ceilingThickness,
            picks: {columns: clonePicks(l.picks), beams: clonePicks(l.beamPicks), walls: clonePicks(l.wallPicks), slabs: clonePicks(l.slabPicks), ceilings: clonePicks(l.ceilingPicks)}};
  }
  function clonePicks(picks) { var out = {}; Object.keys(picks).forEach(function (k) { out[k] = Object.assign({}, picks[k]); }); return out; }
  function fromRubyLevel(l) {
    return {id: l.id, name: l.name, elevation: l.elevation, slab: l.slab_thickness, columnType: l.column_type, beamType: l.beam_type || null, wallType: l.wall_type || null, ceilingHeight: l.ceiling_height, ceilingThickness: l.ceiling_thickness,
            picks: clonePicks((l.picks && l.picks.columns) || {}), beamPicks: clonePicks((l.picks && l.picks.beams) || {}), wallPicks: clonePicks((l.picks && l.picks.walls) || {}),
            slabPicks: clonePicks((l.picks && l.picks.slabs) || {}), ceilingPicks: clonePicks((l.picks && l.picks.ceilings) || {})};
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
    $('levels-table').querySelectorAll('select').forEach(function (sel, k) {
      var i = Math.floor(k / 3), kind = k % 3, list = [state.types, state.beamTypes, state.wallTypes][kind];
      var keep = (state.levels[i] && [state.levels[i].columnType, state.levels[i].beamType, state.levels[i].wallType][kind]) || '';
      sel.replaceChildren(); sel.append(new Option('Loại đầu danh sách', ''));
      list.forEach(function (t) { sel.append(new Option(t.name, t.id)); });
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
    heads(table, ['Tên tầng', 'Cao độ sàn (mm)', 'Dày sàn (mm)', 'Cao trần (mm)', 'Dày trần (mm)', 'Loại cột mặc định', 'Loại dầm mặc định', 'Loại tường mặc định', 'Ghi chú', '']);
    state.levels.forEach(function (l, i) {
      var row = table.insertRow(), sel = document.createElement('select'), del = document.createElement('button');
      row.insertCell().appendChild(textCell(l.name, function (v) { l.name = v; renderLevelSelects(); }, 'Tên tầng ' + (i + 1)));
      row.insertCell().appendChild(numCell(l.elevation, function (v) { l.elevation = v; refreshLevelNotes(); }, 'Cao độ ' + l.name));
      row.insertCell().appendChild(numCell(l.slab, function (v) { l.slab = v; refreshLevelNotes(); }, 'Dày sàn ' + l.name));
      row.insertCell().appendChild(numCell(l.ceilingHeight, function (v) { l.ceilingHeight = v; }, 'Cao trần ' + l.name));
      row.insertCell().appendChild(numCell(l.ceilingThickness, function (v) { l.ceilingThickness = v; }, 'Dày trần ' + l.name));
      sel.setAttribute('aria-label', 'Loại cột mặc định ' + l.name);
      sel.append(new Option('Loại đầu danh sách', ''));
      state.types.forEach(function (t) { sel.append(new Option(t.name, t.id)); });
      sel.value = l.columnType || '';
      sel.onchange = function () { l.columnType = sel.value || null; changed(); };
      row.insertCell().appendChild(sel);
      var bsel = document.createElement('select');
      bsel.setAttribute('aria-label', 'Loại dầm mặc định ' + l.name); bsel.className = 'beam-default';
      bsel.append(new Option('Loại đầu danh sách', ''));
      state.beamTypes.forEach(function (t) { bsel.append(new Option(t.name, t.id)); });
      bsel.value = l.beamType || '';
      bsel.onchange = function () { l.beamType = bsel.value || null; changed(); };
      row.insertCell().appendChild(bsel);
      var wsel = document.createElement('select');
      wsel.setAttribute('aria-label', 'Loại tường mặc định ' + l.name); wsel.className = 'wall-default';
      wsel.append(new Option('Loại đầu danh sách', ''));
      state.wallTypes.forEach(function (t) { wsel.append(new Option(t.name, t.id)); });
      wsel.value = l.wallType || '';
      wsel.onchange = function () { l.wallType = wsel.value || null; changed(); };
      row.insertCell().appendChild(wsel);
      var note = row.insertCell(); note.className = 'note'; note.textContent = levelNote(i);
      del.type = 'button'; del.className = 'del'; del.textContent = '×'; del.title = 'Xóa tầng này'; del.disabled = state.levels.length <= 1;
      del.onclick = function () { removeLevel(l.id); };
      row.insertCell().appendChild(del);
    });
    renderTypes(); renderBeamTypes(); renderWallTypes();
  }
  function refreshLevelNotes() {
    $('levels-table').querySelectorAll('td.note').forEach(function (cell, i) { cell.textContent = levelNote(i); });
  }
  function removeLevel(id) {
    state.levels = state.levels.filter(function (l) { return l.id !== id; });
    if (state.level === id) state.level = state.levels[0].id;
    state.selected = null; state.selectedBeam = null; state.selectedWall = null; renderLevels(); renderColumnsTab(); renderBeamsTab(); renderWallsTab(); CELL_TABS.forEach(function (c) { renderCellTab(c); }); changed();
  }
  function addLevel() {
    var last = state.levels[state.levels.length - 1], n = state.levels.length + 1, name = 'Tầng ' + n, taken = state.levels.map(function (l) { return l.name.toLowerCase(); });
    while (taken.indexOf(name.toLowerCase()) >= 0) name += '*';
    state.levels.push({id: rid('sl_'), name: name, elevation: Number.isFinite(last.elevation) ? last.elevation + 3600 : 0, slab: 120, columnType: null, beamType: null, wallType: null, ceilingHeight: 2800, ceilingThickness: 9, picks: {}, beamPicks: {}, wallPicks: {}, slabPicks: {}, ceilingPicks: {}});
    renderLevels(); renderColumnsTab(); renderBeamsTab(); renderWallsTab(); CELL_TABS.forEach(function (c) { renderCellTab(c); }); changed();
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

  // ---- Loại dầm ----
  function renderBeamTypes() {
    var table = $('beam-types-table'); table.replaceChildren();
    heads(table, ['Tên', 'Rộng (mm)', 'Cao (mm)', '']);
    state.beamTypes.forEach(function (t, i) {
      var row = table.insertRow(), del = document.createElement('button');
      row.insertCell().appendChild(textCell(t.name, function (v) { t.name = v; refreshTypeSelects(); }, 'Tên loại dầm ' + (i + 1)));
      row.insertCell().appendChild(numCell(t.w, function (v) { t.w = v; }, 'Rộng loại dầm ' + t.name));
      row.insertCell().appendChild(numCell(t.h, function (v) { t.h = v; }, 'Cao loại dầm ' + t.name));
      del.type = 'button'; del.className = 'del'; del.textContent = '×'; del.title = 'Xóa loại dầm này'; del.disabled = state.beamTypes.length <= 1;
      del.onclick = function () { removeBeamType(t.id); };
      row.insertCell().appendChild(del);
    });
  }
  function removeBeamType(id) {
    state.beamTypes = state.beamTypes.filter(function (t) { return t.id !== id; });
    state.levels.forEach(function (l) {
      if (l.beamType === id) l.beamType = null;
      Object.keys(l.beamPicks).forEach(function (ref) { if (l.beamPicks[ref].type === id) delete l.beamPicks[ref].type; });
    });
    renderLevels(); renderBeamsTab(); changed();
  }
  function addBeamType() {
    var base = state.beamTypes[state.beamTypes.length - 1], n = state.beamTypes.length + 1, name = 'Dầm ' + n, taken = state.beamTypes.map(function (t) { return t.name.toLowerCase(); });
    while (taken.indexOf(name.toLowerCase()) >= 0) name += '*';
    state.beamTypes.push({id: rid('bt_'), name: name, w: base ? base.w : 200, h: base ? base.h : 400});
    renderLevels(); changed();
  }

  // ---- Tab Dầm ----
  // Các nhịp (đoạn trục giữa hai giao điểm) theo cùng quy ước mã với Ruby: 'x:<trục ngang>:<trục đứng a>-<trục đứng b>' chạy theo X, 'y:<trục đứng>:<a>-<b>' chạy theo Y.
  function allSpans() {
    var gx = toAxes('x'), gy = toAxes('y'), ox = state.origin[0], oy = state.origin[1], out = [];
    gy.forEach(function (ay, yi) {
      for (var i = 0; i + 1 < gx.length; i++) out.push({ref: 'x:' + ay.name + ':' + gx[i].name + '-' + gx[i + 1].name, dir: 'x', a: ox + gx[i].offset, b: ox + gx[i + 1].offset, axis: oy + ay.offset, edge: yi === 0 || yi === gy.length - 1});
    });
    gx.forEach(function (ax, xi) {
      for (var i = 0; i + 1 < gy.length; i++) out.push({ref: 'y:' + ax.name + ':' + gy[i].name + '-' + gy[i + 1].name, dir: 'y', a: oy + gy[i].offset, b: oy + gy[i + 1].offset, axis: ox + ax.offset, edge: xi === 0 || xi === gx.length - 1});
    });
    return out;
  }
  function renderBeamsTab() { renderBeamLevelSelects(); renderBeamHeaderOnly(); renderBeamEditor(); renderBeamsButtons(); renderBeamsPlan(); }
  function renderBeamLevelSelects() {
    var sel = $('beam-level-select'), from = $('beam-copy-from');
    sel.replaceChildren(); from.replaceChildren();
    state.levels.forEach(function (l) { sel.append(new Option(l.name, l.id)); if (l.id !== state.level) from.append(new Option(l.name, l.id)); });
    sel.value = state.level;
  }
  function renderBeamHeaderOnly() {
    var i = state.levels.indexOf(currentLevel());
    if (i < 0) return;
    var l = state.levels[i], above = state.levels[i + 1];
    $('beam-level-note').textContent = above ? 'Đỉnh dầm tại đáy sàn tầng trên: cao độ ' + Math.round((above.elevation - above.slab) * 10) / 10 + ' mm' : 'Tầng trên cùng: chỉ có sàn';
  }
  function renderBeamsButtons() {
    var l = currentLevel(), top = state.levels.indexOf(l) === state.levels.length - 1;
    $('build-beams').disabled = top || !state.previewOk || !Object.keys(l.beamPicks).length;
    $('build-all-beams').disabled = !state.previewOk;
    $('remove-beams').disabled = state.drawnBeamLevels.indexOf(l.id) < 0;
    $('beam-pick-all').disabled = $('beam-pick-edge').disabled = $('beam-pick-none').disabled = top;
    $('beam-copy-picks').disabled = top || !$('beam-copy-from').options.length;
  }
  function renderBeamEditor() {
    var l = currentLevel(), pick = state.selectedBeam && l.beamPicks[state.selectedBeam];
    $('beam-editor').hidden = !pick;
    if (!pick) return;
    $('beam-ref').textContent = state.selectedBeam;
    var t = $('beam-type'); t.replaceChildren(); t.append(new Option('Theo loại mặc định của tầng', ''));
    state.beamTypes.forEach(function (ty) { t.append(new Option(ty.name + ' (' + ty.w + '×' + ty.h + ')', ty.id)); });
    t.value = pick.type || '';
    modeSelect('beam-p', MODE_P, pick.p);
  }
  function renderBeamsPlan() {
    var svg = $('plan3'), ns = 'http://www.w3.org/2000/svg', data = state.preview;
    svg.replaceChildren();
    if (!data || !data.ok) return;
    var xs = [], ys = [];
    data.axes.forEach(function (a) { a.line.forEach(function (p) { xs.push(p[0]); ys.push(p[1]); }); });
    var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs), y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys), pad = Math.max(x1 - x0, y1 - y0) * 0.05;
    svg.setAttribute('viewBox', [x0 - pad, -(y1 + pad), x1 - x0 + 2 * pad, y1 - y0 + 2 * pad].join(' '));
    function el(tag, attrs, text) { var e = document.createElementNS(ns, tag); Object.keys(attrs).forEach(function (k) { e.setAttribute(k, attrs[k]); }); if (text !== undefined) e.textContent = text; svg.appendChild(e); return e; }
    data.axes.forEach(function (a) { el('line', {class: 'axis', x1: a.line[0][0], y1: -a.line[0][1], x2: a.line[1][0], y2: -a.line[1][1]}); });
    data.axes.forEach(function (a) { var b = a.bubbles[0]; el('text', {x: b.center[0], y: -b.center[1], 'font-size': Math.max(x1 - x0, y1 - y0) * 0.022}, a.name); });
    ((data.columns && data.columns.items) || []).forEach(function (c) { el('rect', {class: 'colref', x: c.center[0] - c.w / 2, y: -(c.center[1] + c.d / 2), width: c.w, height: c.d}); });
    var l = currentLevel(), top = state.levels.indexOf(l) === state.levels.length - 1, beams = (data.beams && data.beams.items) || [], byRef = {};
    beams.forEach(function (b) { byRef[b.ref] = b; });
    var def = state.beamTypes.filter(function (t) { return t.id === l.beamType; })[0] || state.beamTypes[0] || {w: 200}, ghost = Math.max(def.w, (x1 - x0) * 0.012);
    if (!top) allSpans().forEach(function (sp) {
      var b = byRef[sp.ref];
      if (b) {
        var r = el('rect', {class: 'beam' + (state.selectedBeam === sp.ref ? ' sel' : ''), x: b.min[0], y: -b.max[1], width: b.max[0] - b.min[0], height: b.max[1] - b.min[1], 'data-ref': sp.ref});
        r.onclick = function () { state.selectedBeam = sp.ref; renderBeamEditor(); renderBeamsPlan(); };
        var tip = document.createElementNS(ns, 'title'); tip.textContent = sp.ref + ' · ' + b.type_name + ' · dài ' + b.length + ' mm'; r.appendChild(tip);
      } else {
        var rect = sp.dir === 'x' ? {x: sp.a, y: -(sp.axis + ghost / 2), width: sp.b - sp.a, height: ghost} : {x: sp.axis - ghost / 2, y: -sp.b, width: ghost, height: sp.b - sp.a};
        var g = el('rect', Object.assign({class: 'span', 'data-ref': sp.ref}, rect));
        g.onclick = function () { pickBeam(sp.ref); };
      }
    });
    var summary = $('beam-summary'), issues = $('beam-issues'); issues.replaceChildren();
    if (data.levels_ok === false) { summary.className = 'summary error'; summary.textContent = data.levels_error; return; }
    if (data.beams_error) { summary.className = 'summary'; summary.textContent = data.beams_error; return; }
    if (data.beams) {
      summary.className = 'summary';
      summary.textContent = data.beams.level_name + ': ' + data.beams.count + ' dầm, đỉnh dầm tại cao độ ' + data.beams.z_top + ' mm (đáy sàn tầng trên).' + (data.removed ? ' Đã bỏ ' + data.removed + ' lựa chọn không còn trên lưới.' : '');
      data.beams.issues.forEach(function (m) { var li = document.createElement('li'); li.textContent = m; issues.appendChild(li); });
    } else { summary.textContent = ''; }
  }
  function pickBeam(ref) { var l = currentLevel(); if (!l.beamPicks[ref]) l.beamPicks[ref] = {}; state.selectedBeam = ref; renderBeamEditor(); changed(); }

  // ---- Loại tường ----
  function renderWallTypes() {
    var table = $('wall-types-table'); table.replaceChildren();
    heads(table, ['Tên', 'Dày (mm)', '']);
    state.wallTypes.forEach(function (t, i) {
      var row = table.insertRow(), del = document.createElement('button');
      row.insertCell().appendChild(textCell(t.name, function (v) { t.name = v; refreshTypeSelects(); }, 'Tên loại tường ' + (i + 1)));
      row.insertCell().appendChild(numCell(t.t, function (v) { t.t = v; }, 'Dày loại tường ' + t.name));
      del.type = 'button'; del.className = 'del'; del.textContent = '×'; del.title = 'Xóa loại tường này'; del.disabled = state.wallTypes.length <= 1;
      del.onclick = function () { removeWallType(t.id); };
      row.insertCell().appendChild(del);
    });
  }
  function removeWallType(id) {
    state.wallTypes = state.wallTypes.filter(function (t) { return t.id !== id; });
    state.levels.forEach(function (l) {
      if (l.wallType === id) l.wallType = null;
      Object.keys(l.wallPicks).forEach(function (ref) { if (l.wallPicks[ref].type === id) delete l.wallPicks[ref].type; });
    });
    renderLevels(); renderWallsTab(); changed();
  }
  function addWallType() {
    var base = state.wallTypes[state.wallTypes.length - 1], n = state.wallTypes.length + 1, name = 'Tường dày ' + n, taken = state.wallTypes.map(function (t) { return t.name.toLowerCase(); });
    while (taken.indexOf(name.toLowerCase()) >= 0) name += '*';
    state.wallTypes.push({id: rid('wt_'), name: name, t: base ? base.t : 200});
    renderLevels(); changed();
  }

  // ---- Tab Tường ----
  function renderWallsTab() { renderWallLevelSelects(); renderWallHeaderOnly(); renderWallEditor(); renderWallsButtons(); renderWallsPlan(); }
  function renderWallLevelSelects() {
    var sel = $('wall-level-select'), from = $('wall-copy-from');
    sel.replaceChildren(); from.replaceChildren();
    state.levels.forEach(function (l) { sel.append(new Option(l.name, l.id)); if (l.id !== state.level) from.append(new Option(l.name, l.id)); });
    sel.value = state.level;
  }
  function renderWallHeaderOnly() {
    var i = state.levels.indexOf(currentLevel());
    if (i < 0) return;
    var l = state.levels[i], above = state.levels[i + 1];
    $('wall-level-note').textContent = above ? 'Chân tường tại mặt sàn: cao độ ' + l.elevation + ' mm; đỉnh tại đáy dầm hoặc đáy sàn tầng trên (' + Math.round((above.elevation - above.slab) * 10) / 10 + ' mm)' : 'Tầng trên cùng: chỉ có sàn';
  }
  function renderWallsButtons() {
    var l = currentLevel(), top = state.levels.indexOf(l) === state.levels.length - 1;
    $('build-walls').disabled = top || !state.previewOk || !Object.keys(l.wallPicks).length;
    $('build-all-walls').disabled = !state.previewOk;
    $('remove-walls').disabled = state.drawnWallLevels.indexOf(l.id) < 0;
    $('wall-pick-all').disabled = $('wall-pick-edge').disabled = $('wall-pick-none').disabled = top;
    $('wall-copy-picks').disabled = top || !$('wall-copy-from').options.length;
  }
  function renderWallEditor() {
    var l = currentLevel(), pick = state.selectedWall && l.wallPicks[state.selectedWall];
    $('wall-editor').hidden = !pick;
    if (!pick) return;
    $('wall-ref').textContent = state.selectedWall;
    var t = $('wall-type'); t.replaceChildren(); t.append(new Option('Theo loại mặc định của tầng', ''));
    state.wallTypes.forEach(function (ty) { t.append(new Option(ty.name + ' (dày ' + ty.t + ')', ty.id)); });
    t.value = pick.type || '';
    modeSelect('wall-p', MODE_P, pick.p);
  }
  function renderWallsPlan() {
    var svg = $('plan4'), ns = 'http://www.w3.org/2000/svg', data = state.preview;
    svg.replaceChildren();
    if (!data || !data.ok) return;
    var xs = [], ys = [];
    data.axes.forEach(function (a) { a.line.forEach(function (p) { xs.push(p[0]); ys.push(p[1]); }); });
    var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs), y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys), pad = Math.max(x1 - x0, y1 - y0) * 0.05;
    svg.setAttribute('viewBox', [x0 - pad, -(y1 + pad), x1 - x0 + 2 * pad, y1 - y0 + 2 * pad].join(' '));
    function el(tag, attrs, text) { var e = document.createElementNS(ns, tag); Object.keys(attrs).forEach(function (k) { e.setAttribute(k, attrs[k]); }); if (text !== undefined) e.textContent = text; svg.appendChild(e); return e; }
    data.axes.forEach(function (a) { el('line', {class: 'axis', x1: a.line[0][0], y1: -a.line[0][1], x2: a.line[1][0], y2: -a.line[1][1]}); });
    data.axes.forEach(function (a) { var b = a.bubbles[0]; el('text', {x: b.center[0], y: -b.center[1], 'font-size': Math.max(x1 - x0, y1 - y0) * 0.022}, a.name); });
    ((data.columns && data.columns.items) || []).forEach(function (c) { el('rect', {class: 'colref', x: c.center[0] - c.w / 2, y: -(c.center[1] + c.d / 2), width: c.w, height: c.d}); });
    var l = currentLevel(), top = state.levels.indexOf(l) === state.levels.length - 1, walls = (data.walls && data.walls.items) || [], byRef = {};
    walls.forEach(function (b) { byRef[b.ref] = b; });
    var def = state.wallTypes.filter(function (t) { return t.id === l.wallType; })[0] || state.wallTypes[0] || {t: 200}, ghost = Math.max(def.t, (x1 - x0) * 0.012);
    if (!top) allSpans().forEach(function (sp) {
      var b = byRef[sp.ref];
      if (b) {
        var r = el('rect', {class: 'wall' + (state.selectedWall === sp.ref ? ' sel' : ''), x: b.min[0], y: -b.max[1], width: b.max[0] - b.min[0], height: b.max[1] - b.min[1], 'data-ref': sp.ref});
        r.onclick = function () { state.selectedWall = sp.ref; renderWallEditor(); renderWallsPlan(); };
        var tip = document.createElementNS(ns, 'title'); tip.textContent = sp.ref + ' · ' + b.type_name + ' · dài ' + b.length + ' mm · cao ' + b.height + ' mm'; r.appendChild(tip);
      } else {
        var rect = sp.dir === 'x' ? {x: sp.a, y: -(sp.axis + ghost / 2), width: sp.b - sp.a, height: ghost} : {x: sp.axis - ghost / 2, y: -sp.b, width: ghost, height: sp.b - sp.a};
        var g = el('rect', Object.assign({class: 'span', 'data-ref': sp.ref}, rect));
        g.onclick = function () { pickWall(sp.ref); };
      }
    });
    var summary = $('wall-summary'), issues = $('wall-issues'); issues.replaceChildren();
    if (data.levels_ok === false) { summary.className = 'summary error'; summary.textContent = data.levels_error; return; }
    if (data.walls_error) { summary.className = 'summary'; summary.textContent = data.walls_error; return; }
    if (data.walls) {
      summary.className = 'summary';
      summary.textContent = data.walls.level_name + ': ' + data.walls.count + ' tường, từ cao độ ' + data.walls.z0 + ' mm lên đáy dầm hoặc đáy sàn tầng trên (' + data.walls.z_slab + ' mm).' + (data.removed ? ' Đã bỏ ' + data.removed + ' lựa chọn không còn trên lưới.' : '');
      data.walls.issues.forEach(function (m) { var li = document.createElement('li'); li.textContent = m; issues.appendChild(li); });
    } else { summary.textContent = ''; }
  }
  function pickWall(ref) { var l = currentLevel(); if (!l.wallPicks[ref]) l.wallPicks[ref] = {}; state.selectedWall = ref; renderWallEditor(); changed(); }



  // ---- Tab Sàn và Trần (chọn theo ô) ----
  var CELL_TABS = [
    {kind: 'slabs', picks: 'slabPicks', drawn: 'drawnSlabLevels', prefix: 'slab', plan: 'plan5', label: 'sàn', top: true},
    {kind: 'ceilings', picks: 'ceilingPicks', drawn: 'drawnCeilingLevels', prefix: 'ceiling', plan: 'plan6', label: 'trần', top: false}
  ];
  function allCells() {
    var gx = toAxes('x'), gy = toAxes('y'), ox = state.origin[0], oy = state.origin[1], out = [];
    for (var i = 0; i + 1 < gx.length; i++) for (var j = 0; j + 1 < gy.length; j++) {
      out.push({ref: gx[i].name + '-' + gx[i + 1].name + '/' + gy[j].name + '-' + gy[j + 1].name, x0: ox + gx[i].offset, x1: ox + gx[i + 1].offset, y0: oy + gy[j].offset, y1: oy + gy[j + 1].offset});
    }
    return out;
  }
  function isTop(l) { return state.levels.indexOf(l) === state.levels.length - 1; }
  function renderCellTab(c) {
    var sel = $(c.prefix + '-level-select'), from = $(c.prefix + '-copy-from');
    sel.replaceChildren(); from.replaceChildren();
    state.levels.forEach(function (l) { sel.append(new Option(l.name, l.id)); if (l.id !== state.level) from.append(new Option(l.name, l.id)); });
    sel.value = state.level;
    var l = currentLevel(), i = state.levels.indexOf(l), above = state.levels[i + 1];
    $(c.prefix + '-level-note').textContent = c.kind === 'slabs'
      ? 'Mặt trên sàn tại cao độ ' + l.elevation + ' mm, dày ' + l.slab + ' mm xuống dưới' + (isTop(l) ? ' (tầng trên cùng: sàn mái)' : '')
      : (above ? 'Mặt dưới trần tại cao độ ' + (l.elevation + l.ceilingHeight) + ' mm, dày ' + l.ceilingThickness + ' mm' : 'Tầng trên cùng: chỉ có sàn, không có trần');
    renderCellButtons(c); renderCellPlan(c);
  }
  function renderCellButtons(c) {
    var l = currentLevel(), blocked = !c.top && isTop(l);
    $('build-' + c.prefix + 's').disabled = blocked || !state.previewOk || !Object.keys(l[c.picks]).length;
    $('build-all-' + c.prefix + 's').disabled = !state.previewOk;
    $('remove-' + c.prefix + 's').disabled = state[c.drawn].indexOf(l.id) < 0;
    $(c.prefix + '-pick-all').disabled = $(c.prefix + '-pick-none').disabled = blocked;
    $(c.prefix + '-copy-picks').disabled = blocked || !$(c.prefix + '-copy-from').options.length;
  }
  function renderCellPlan(c) {
    var svg = $(c.plan), ns = 'http://www.w3.org/2000/svg', data = state.preview;
    svg.replaceChildren();
    if (!data || !data.ok) return;
    var xs = [], ys = [];
    data.axes.forEach(function (a) { a.line.forEach(function (p) { xs.push(p[0]); ys.push(p[1]); }); });
    var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs), y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys), pad = Math.max(x1 - x0, y1 - y0) * 0.05;
    svg.setAttribute('viewBox', [x0 - pad, -(y1 + pad), x1 - x0 + 2 * pad, y1 - y0 + 2 * pad].join(' '));
    function el(tag, attrs, text) { var e = document.createElementNS(ns, tag); Object.keys(attrs).forEach(function (k) { e.setAttribute(k, attrs[k]); }); if (text !== undefined) e.textContent = text; svg.appendChild(e); return e; }
    data.axes.forEach(function (a) { el('line', {class: 'axis', x1: a.line[0][0], y1: -a.line[0][1], x2: a.line[1][0], y2: -a.line[1][1]}); });
    data.axes.forEach(function (a) { var b = a.bubbles[0]; el('text', {x: b.center[0], y: -b.center[1], 'font-size': Math.max(x1 - x0, y1 - y0) * 0.022}, a.name); });
    var l = currentLevel(), blocked = !c.top && isTop(l), part = data[c.kind], byRef = {}, inset = Math.max(x1 - x0, y1 - y0) * 0.006;
    ((part && part.items) || []).forEach(function (it) { byRef[it.ref] = it; });
    if (!blocked) allCells().forEach(function (cell) {
      var it = byRef[cell.ref], node;
      if (it) {
        var pts = (it.polygon || [[it.min[0], it.min[1]], [it.max[0], it.min[1]], [it.max[0], it.max[1]], [it.min[0], it.max[1]]]).map(function (p) { return p[0] + ',' + (-p[1]); }).join(' ');
        node = el('polygon', {class: 'cell ' + c.prefix, points: pts, 'data-ref': cell.ref});
        var tip = document.createElementNS(ns, 'title'); tip.textContent = cell.ref + ' · ' + c.label + (it.area ? ' · ' + it.area + ' m²' : ''); node.appendChild(tip);
        node.onclick = function () { delete l[c.picks][cell.ref]; changed(); renderCellButtons(c); };
      } else {
        node = el('rect', {class: 'cellghost', x: cell.x0 + inset, y: -(cell.y1 - inset), width: cell.x1 - cell.x0 - 2 * inset, height: cell.y1 - cell.y0 - 2 * inset, 'data-ref': cell.ref});
        node.onclick = function () { l[c.picks][cell.ref] = {}; changed(); renderCellButtons(c); };
      }
    });
    var summary = $(c.prefix + '-summary'), issues = $(c.prefix + '-issues'); issues.replaceChildren();
    if (data.levels_ok === false) { summary.className = 'summary error'; summary.textContent = data.levels_error; return; }
    var err = data[c.kind + '_error'];
    if (err) { summary.className = 'summary'; summary.textContent = err; return; }
    if (part) {
      summary.className = 'summary';
      var area = 0; part.items.forEach(function (it) { area += it.area || 0; });
      summary.textContent = part.level_name + ': ' + part.count + ' ' + c.label + ' (tổng ' + Math.round(area * 100) / 100 + ' m²)' + (c.kind === 'slabs' ? ', mặt trên tại ' + part.z_top + ' mm, dày ' + part.thickness + ' mm.' : ', mặt dưới tại ' + part.z_bottom + ' mm, mặt trên ' + part.z_top + ' mm.') + (data.removed ? ' Đã bỏ ' + data.removed + ' lựa chọn không còn trên lưới.' : '');
      part.issues.forEach(function (m) { var li = document.createElement('li'); li.textContent = m; issues.appendChild(li); });
    } else { summary.textContent = ''; }
  }

  function switchTab(tab) {
    state.tab = tab;
    document.querySelectorAll('.tabs button').forEach(function (b) { b.setAttribute('aria-selected', String(b.getAttribute('data-tab') === tab)); });
    ['grid', 'levels', 'columns', 'beams', 'walls', 'slabs', 'ceilings'].forEach(function (t) { $('tab-' + t).hidden = t !== tab; });
    if (tab === 'columns') renderColumnsTab();
    if (tab === 'beams') renderBeamsTab();
    if (tab === 'walls') renderWallsTab();
    CELL_TABS.forEach(function (c) { if (tab === c.kind) renderCellTab(c); });
  }

  function receive(event, data) {
    if (event === 'state') {
      state.origin = data.grid.origin.slice();
      var x = fromAxes(data.grid.x_axes), y = fromAxes(data.grid.y_axes);
      state.x = x; state.y = y; state.scale = data.symbol.scale; state.both = data.symbol.both_ends; state.drawn = data.drawn;
      state.types = data.types.map(function (t) { return {id: t.id, name: t.name, w: t.w, d: t.d}; });
      state.beamTypes = (data.beam_types || []).map(function (t) { return {id: t.id, name: t.name, w: t.w, h: t.h}; });
      state.wallTypes = (data.wall_types || []).map(function (t) { return {id: t.id, name: t.name, t: t.t}; });
      state.levels = data.levels.map(fromRubyLevel); state.level = state.levels[0].id; state.selected = null; state.selectedBeam = null; state.selectedWall = null;
      state.drawnLevels = data.drawn_levels || []; state.drawnBeamLevels = data.drawn_beam_levels || []; state.drawnWallLevels = data.drawn_wall_levels || []; state.drawnSlabLevels = data.drawn_slab_levels || []; state.drawnCeilingLevels = data.drawn_ceiling_levels || [];
      $('version').textContent = 'v' + data.version;
      renderAll(); renderLevels(); renderColumnsTab(); renderBeamsTab(); renderWallsTab(); CELL_TABS.forEach(function (c) { renderCellTab(c); });
      message(data.saved ? 'Đã nạp lưới trục lưu trong model.' : 'Lưới mặc định: sửa các số rồi bấm Vẽ lưới trục.');
    } else if (event === 'preview') {
      state.previewOk = !!data.ok;
      var s = $('summary');
      if (data.ok) {
        var m = data.summary;
        s.className = 'summary';
        s.textContent = m.x_axes + ' trục đứng × ' + m.y_axes + ' trục ngang: ' + m.intersections + ' giao điểm, ' + m.spans + ' nhịp, ' + m.cells + ' ô. Khung lưới ' + m.width + ' × ' + m.depth + ' mm.';
      } else { s.className = 'summary error'; s.textContent = data.error; }
      state.preview = data; drawPlan(data); renderButtons(); renderColumnsButtons(); renderColumnsPlan(); renderBeamsButtons(); renderBeamsPlan(); renderWallsButtons(); renderWallsPlan(); CELL_TABS.forEach(function (c) { renderCellButtons(c); renderCellPlan(c); });
    } else if (event === 'axes') {
      var set = fromAxes(data.axes); state[data.dir] = set; renderAxes(data.dir); changed();
    } else if (event === 'levels') {
      state.levels = data.levels.map(fromRubyLevel); renderLevels(); renderColumnsTab(); renderBeamsTab(); renderWallsTab(); CELL_TABS.forEach(function (c) { renderCellTab(c); }); changed(); message(data.message);
    } else if (event === 'columns_built') {
      state.drawnLevels = data.drawn_levels || []; renderColumnsButtons(); message(data.message, data.error);
    } else if (event === 'beams_built') {
      state.drawnBeamLevels = data.drawn_beam_levels || []; renderBeamsButtons(); message(data.message, data.error);
    } else if (event === 'plates_built') {
      var cfg = CELL_TABS.filter(function (c) { return c.kind === data.kind; })[0];
      if (cfg) { state[cfg.drawn] = data.drawn_levels || []; renderCellButtons(cfg); }
      message(data.message, data.error);
    } else if (event === 'walls_built') {
      state.drawnWallLevels = data.drawn_wall_levels || []; state.drawnSlabLevels = data.drawn_slab_levels || []; state.drawnCeilingLevels = data.drawn_ceiling_levels || []; renderWallsButtons(); message(data.message, data.error);
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
  $('add-beam-type').onclick = addBeamType;
  $('beam-level-select').onchange = function () { state.level = $('beam-level-select').value; state.selectedBeam = null; state.selectedWall = null; state.selected = null; renderBeamsTab(); renderColumnsTab(); renderWallsTab(); CELL_TABS.forEach(function (x) { renderCellTab(x); }); changed(); };
  $('wall-level-select').onchange = function () { state.level = $('wall-level-select').value; state.selectedBeam = null; state.selectedWall = null; state.selected = null; renderBeamsTab(); renderColumnsTab(); renderWallsTab(); CELL_TABS.forEach(function (x) { renderCellTab(x); }); changed(); };
  $('level-select').onchange = function () { state.level = $('level-select').value; state.selected = null; state.selectedBeam = null; state.selectedWall = null; renderColumnsTab(); renderBeamsTab(); renderWallsTab(); CELL_TABS.forEach(function (x) { renderCellTab(x); }); changed(); };
  $('beam-pick-all').onclick = function () { var l = currentLevel(); allSpans().forEach(function (sp) { if (!l.beamPicks[sp.ref]) l.beamPicks[sp.ref] = {}; }); changed(); renderBeamsButtons(); };
  $('beam-pick-edge').onclick = function () { var l = currentLevel(); allSpans().forEach(function (sp) { if (sp.edge && !l.beamPicks[sp.ref]) l.beamPicks[sp.ref] = {}; }); changed(); renderBeamsButtons(); };
  $('beam-pick-none').onclick = function () { currentLevel().beamPicks = {}; state.selectedBeam = null; renderBeamEditor(); changed(); renderBeamsButtons(); };
  $('beam-remove').onclick = function () { delete currentLevel().beamPicks[state.selectedBeam]; state.selectedBeam = null; renderBeamEditor(); changed(); renderBeamsButtons(); };
  $('beam-type').onchange = function () { var p = currentLevel().beamPicks[state.selectedBeam]; if ($('beam-type').value) p.type = $('beam-type').value; else delete p.type; changed(); };
  $('beam-p').onchange = function () { var p = currentLevel().beamPicks[state.selectedBeam]; if ($('beam-p').value === 'auto') delete p.p; else p.p = $('beam-p').value; changed(); };
  $('beam-copy-picks').onclick = function () { var p = payload(); p.from = $('beam-copy-from').value; p.to = state.level; p.kind = 'beams'; call('picks_copy', p); };
  $('build-beams').onclick = function () { call('beams_build', {state: payload(), levels: [state.level]}); };
  $('build-all-beams').onclick = function () {
    var ids = state.levels.slice(0, -1).filter(function (l) { return Object.keys(l.beamPicks).length; }).map(function (l) { return l.id; });
    call('beams_build', {state: payload(), levels: ids});
  };
  $('remove-beams').onclick = function () { call('beams_remove', {level: state.level}); };
  $('add-wall-type').onclick = addWallType;
  $('wall-pick-all').onclick = function () { var l = currentLevel(); allSpans().forEach(function (sp) { if (!l.wallPicks[sp.ref]) l.wallPicks[sp.ref] = {}; }); changed(); renderWallsButtons(); };
  $('wall-pick-edge').onclick = function () { var l = currentLevel(); allSpans().forEach(function (sp) { if (sp.edge && !l.wallPicks[sp.ref]) l.wallPicks[sp.ref] = {}; }); changed(); renderWallsButtons(); };
  $('wall-pick-none').onclick = function () { currentLevel().wallPicks = {}; state.selectedWall = null; renderWallEditor(); changed(); renderWallsButtons(); };
  $('wall-remove').onclick = function () { delete currentLevel().wallPicks[state.selectedWall]; state.selectedWall = null; renderWallEditor(); changed(); renderWallsButtons(); };
  $('wall-type').onchange = function () { var p = currentLevel().wallPicks[state.selectedWall]; if ($('wall-type').value) p.type = $('wall-type').value; else delete p.type; changed(); };
  $('wall-p').onchange = function () { var p = currentLevel().wallPicks[state.selectedWall]; if ($('wall-p').value === 'auto') delete p.p; else p.p = $('wall-p').value; changed(); };
  $('wall-copy-picks').onclick = function () { var p = payload(); p.from = $('wall-copy-from').value; p.to = state.level; p.kind = 'walls'; call('picks_copy', p); };
  $('build-walls').onclick = function () { call('walls_build', {state: payload(), levels: [state.level]}); };
  $('build-all-walls').onclick = function () {
    var ids = state.levels.slice(0, -1).filter(function (l) { return Object.keys(l.wallPicks).length; }).map(function (l) { return l.id; });
    call('walls_build', {state: payload(), levels: ids});
  };
  $('remove-walls').onclick = function () { call('walls_remove', {level: state.level}); };

  CELL_TABS.forEach(function (c) {
    var p = c.prefix;
    $(p + '-level-select').onchange = function () { state.level = $(p + '-level-select').value; state.selected = null; state.selectedBeam = null; state.selectedWall = null; renderColumnsTab(); renderBeamsTab(); renderWallsTab(); CELL_TABS.forEach(function (x) { renderCellTab(x); }); changed(); };
    $(p + '-pick-all').onclick = function () { var l = currentLevel(); allCells().forEach(function (cell) { l[c.picks][cell.ref] = {}; }); changed(); renderCellButtons(c); };
    $(p + '-pick-none').onclick = function () { currentLevel()[c.picks] = {}; changed(); renderCellButtons(c); };
    $(p + '-copy-picks').onclick = function () { var q = payload(); q.from = $(p + '-copy-from').value; q.to = state.level; q.kind = c.kind; call('picks_copy', q); };
    $('build-' + p + 's').onclick = function () { call('plates_build', {kind: c.kind, state: payload(), levels: [state.level]}); };
    $('build-all-' + p + 's').onclick = function () {
      var ids = state.levels.filter(function (l) { return (c.top || !isTop(l)) && Object.keys(l[c.picks]).length; }).map(function (l) { return l.id; });
      call('plates_build', {kind: c.kind, state: payload(), levels: ids});
    };
    $('remove-' + p + 's').onclick = function () { call('plates_remove', {kind: c.kind, level: state.level}); };
  });
  $('build').onclick = function () { call('grid_build', payload()); };
  $('remove').onclick = function () { call('grid_remove'); };
  $('reset').onclick = function () { call('grid_reset'); };
  if (window.VGDTheme) window.VGDTheme.start({key: 'vgd.structure.theme', button: $('theme')});
  window.addEventListener('load', function () { call('ready'); });
})();
