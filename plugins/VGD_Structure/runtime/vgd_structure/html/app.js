// Giao diện cửa sổ Lưới trục. Chỉ gom dữ liệu và hiển thị; Ruby kiểm tra lại và tính xem trước (Grid, AxisSymbol).
(function () {
  'use strict';
  var LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ'.split(''); // bỏ I và O, giống Grid::LETTERS ở Ruby
  var state = {origin: [0, 0], x: {first: 0, axes: []}, y: {first: 0, axes: []}, scale: 100, both: false, drawn: false, previewOk: false,
               types: [], beamTypes: [], wallTypes: [], levels: [], level: null, selected: null, drawnLevels: [], drawnBeamLevels: [], selectedBeam: null, drawnWallLevels: [], selectedWall: null, drawnSlabLevels: [], drawnCeilingLevels: [], openingTypes: [], drawnOpeningLevels: [], openWall: null, preview: null, tab: 'grid'};
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
            status: !!(window.VGDPlan && window.VGDPlan.statusOn && window.VGDPlan.statusOn()),
            types: state.types.map(function (t) { return {id: t.id, name: t.name, w: t.w, d: t.d}; }),
            beam_types: state.beamTypes.map(function (t) { return {id: t.id, name: t.name, w: t.w, h: t.h}; }),
            wall_types: state.wallTypes.map(function (t) { return {id: t.id, name: t.name, t: t.t, layers: wallLayers(t).map(function (l) { var o = {fn: l.fn, t: l.t, material: l.material || ''}; if (l.color) o.color = l.color; return o; })}; }),
            opening_types: state.openingTypes.map(function (t) { return {id: t.id, name: t.name, kind: t.kind, w: t.w, h: t.h, sill: t.sill}; }), levels: state.levels.map(toRubyLevel), level: state.level};
  }
  function toRubyLevel(l) {
    return {id: l.id, name: l.name, elevation: l.elevation, screed: l.screed, slab_thickness: l.slab, column_type: l.columnType || null, beam_type: l.beamType || null, wall_type: l.wallType || null, ceiling_height: l.ceilingHeight, ceiling_thickness: l.ceilingThickness,
            floor_layers: (l.floorLayers || []).map(cleanLayer), ceiling_layers: (l.ceilingLayers || []).map(cleanLayer),
            picks: {columns: clonePicks(l.picks), beams: clonePicks(l.beamPicks), walls: clonePicks(l.wallPicks), slabs: clonePicks(l.slabPicks), ceilings: clonePicks(l.ceilingPicks), openings: clonePicks(l.openingPicks)}, notes: JSON.parse(JSON.stringify(l.notes || {}))};
  }
  function cleanLayer(l) { var o = {fn: l.fn, t: l.t, material: l.material || ''}; if (l.color) o.color = l.color; return o; }
  function clonePicks(picks) { var out = {}; Object.keys(picks).forEach(function (k) { out[k] = JSON.parse(JSON.stringify(picks[k])); }); return out; } // sao sâu: phần tử tự do có khóa 'free' lồng nhau
  function fromRubyLevel(l) {
    return {id: l.id, name: l.name, elevation: l.elevation, slab: l.slab_thickness, screed: l.screed === undefined ? 50 : l.screed, columnType: l.column_type, beamType: l.beam_type || null, wallType: l.wall_type || null, ceilingHeight: l.ceiling_height, ceilingThickness: l.ceiling_thickness,
            floorLayers: (l.floor_layers || []).map(function (x) { return {fn: x.fn, t: x.t, material: x.material || '', color: x.color || null}; }), ceilingLayers: (l.ceiling_layers || []).map(function (x) { return {fn: x.fn, t: x.t, material: x.material || '', color: x.color || null}; }),
            picks: clonePicks((l.picks && l.picks.columns) || {}), beamPicks: clonePicks((l.picks && l.picks.beams) || {}), wallPicks: clonePicks((l.picks && l.picks.walls) || {}),
            slabPicks: clonePicks((l.picks && l.picks.slabs) || {}), ceilingPicks: clonePicks((l.picks && l.picks.ceilings) || {}),
            openingPicks: clonePicks((l.picks && l.picks.openings) || {}), notes: JSON.parse(JSON.stringify(l.notes || {}))};
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

  // Hình sàn / trần thực tế của một ô chưa chọn (lùi theo dầm, cột, tường như lúc dựng) do Ruby tính; cache theo lần đổi dữ liệu để xem trước đúng hình sẽ dựng.
  var probeCache = {}, probePending = {}, stateRev = 0;
  function plateProbe(kind, levelId, ref) {
    var key = kind + '|' + levelId + '|' + ref + '|' + stateRev;
    if (key in probeCache) return probeCache[key];
    if (!probePending[key]) { probePending[key] = true; call('plate_probe', {state: payload(), level: levelId, kind: kind, ref: ref, key: key}); }
    return undefined;
  }
  function changed(positionsOnly) {
    stateRev++; probeCache = {}; probePending = {};
    if ($('check-list')) { $('check-list').replaceChildren(); $('check-summary').textContent = ''; }
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
    var h = Math.round(((above.elevation - above.screed) - (l.elevation - l.screed)) * 10) / 10; // cột từ mặt sàn kết cấu tầng này tới mặt sàn kết cấu tầng trên
    return Number.isFinite(h) ? 'Cột cao ' + h + ' mm' : '?';
  }
  function renderLevels() {
    var table = $('levels-table'); table.replaceChildren();
    heads(table, ['Tên tầng', 'Cao độ sàn hoàn thiện (mm)', 'Cán nền (mm)', 'Dày sàn (mm)', 'Cao trần (mm)', 'Dày trần (mm)', 'Loại cột mặc định', 'Loại dầm mặc định', 'Loại tường mặc định', 'Lớp sàn', 'Lớp trần', 'Ghi chú', '']);
    state.levels.forEach(function (l, i) {
      var row = table.insertRow(), sel = document.createElement('select'), del = document.createElement('button');
      row.insertCell().appendChild(textCell(l.name, function (v) { l.name = v; renderLevelSelects(); }, 'Tên tầng ' + (i + 1)));
      row.insertCell().appendChild(numCell(l.elevation, function (v) { l.elevation = v; refreshLevelNotes(); }, 'Cao độ ' + l.name));
      var scr = numCell(l.screed, function (v) { l.screed = v; refreshLevelNotes(); }, 'Cán nền ' + l.name); scr.disabled = (l.floorLayers || []).length > 0; if (scr.disabled) scr.title = 'Tổng các lớp sàn (sửa ở nút Lớp sàn)';
      row.insertCell().appendChild(scr);
      row.insertCell().appendChild(numCell(l.slab, function (v) { l.slab = v; refreshLevelNotes(); }, 'Dày sàn ' + l.name));
      row.insertCell().appendChild(numCell(l.ceilingHeight, function (v) { l.ceilingHeight = v; }, 'Cao trần ' + l.name));
      var cth = numCell(l.ceilingThickness, function (v) { l.ceilingThickness = v; }, 'Dày trần ' + l.name); cth.disabled = (l.ceilingLayers || []).length > 0; if (cth.disabled) cth.title = 'Tổng các lớp trần (sửa ở nút Lớp trần)';
      row.insertCell().appendChild(cth);
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
      ['floorLayers', 'ceilingLayers'].forEach(function (key) {
        var btn = document.createElement('button'), list = l[key] || [], total = layersSum(list);
        btn.type = 'button'; btn.className = 'layers-btn ' + (key === 'floorLayers' ? 'floor-layers' : 'ceiling-layers');
        btn.textContent = list.length ? list.length + ' lớp · ' + total + ' mm' : 'Thêm lớp';
        btn.title = key === 'floorLayers' ? 'Lớp hoàn thiện trên sàn kết cấu (gạch lát, vữa cán...): tổng = cán nền' : 'Lớp cấu tạo trần (thạch cao, cách nhiệt...): tổng = dày trần';
        btn.setAttribute('aria-expanded', String(openLayers && openLayers.id === l.id && openLayers.key === key));
        btn.onclick = function () { openLayers = openLayers && openLayers.id === l.id && openLayers.key === key ? null : {id: l.id, key: key}; renderLevels(); };
        row.insertCell().appendChild(btn);
      });
      var note = row.insertCell(); note.className = 'note'; note.textContent = levelNote(i);
      del.type = 'button'; del.className = 'del'; del.textContent = '×'; del.title = 'Xóa tầng này'; del.disabled = state.levels.length <= 1;
      del.onclick = function () { removeLevel(l.id); };
      row.insertCell().appendChild(del);
    });
    renderTypes(); renderBeamTypes(); renderWallTypes(); renderOpeningTypes(); renderLevelLayers();
  }
  // ---- Lớp hoàn thiện của sàn (trên sàn kết cấu, từ trên xuống) và của trần (từ mặt dưới lên) ----
  var openLayers = null, FINISH_FN = [['substrate', 'Lớp nền', '#d6cfc0'], ['insulation', 'Cách nhiệt', '#e6d96b'], ['finish', 'Hoàn thiện', '#f1eee6']];
  function layersSum(list) { return Math.round((list || []).reduce(function (a, l) { return a + (Number(l.t) || 0); }, 0) * 10) / 10; }
  function syncLevelLayers(l) { // tổng các lớp ĐÈ lên cán nền / dày trần (Ruby cũng làm vậy khi chuẩn hóa)
    if ((l.floorLayers || []).length) l.screed = layersSum(l.floorLayers);
    if ((l.ceilingLayers || []).length) l.ceilingThickness = layersSum(l.ceilingLayers);
  }
  function refreshLayerButtons(l) {
    var i = state.levels.indexOf(l), tb = $('levels-table'), f = tb.querySelectorAll('.floor-layers')[i], c = tb.querySelectorAll('.ceiling-layers')[i];
    if (f) f.textContent = (l.floorLayers || []).length ? l.floorLayers.length + ' lớp · ' + layersSum(l.floorLayers) + ' mm' : 'Thêm lớp';
    if (c) c.textContent = (l.ceilingLayers || []).length ? l.ceilingLayers.length + ' lớp · ' + layersSum(l.ceilingLayers) + ' mm' : 'Thêm lớp';
  }
  function renderLevelLayers() {
    var box = $('level-layers-editor'); box.replaceChildren();
    var l = openLayers && state.levels.filter(function (x) { return x.id === openLayers.id; })[0];
    box.hidden = !l; if (!l) return;
    var key = openLayers.key, isFloor = key === 'floorLayers', list = l[key] = l[key] || [], head = document.createElement('div'); head.className = 'layers-head';
    head.textContent = (isFloor ? 'Lớp hoàn thiện sàn của “' : 'Lớp cấu tạo trần của “') + l.name + (isFloor ? '” (từ trên cùng xuống sàn kết cấu; tổng = cán nền)' : '” (từ mặt dưới nhìn thấy lên trên; tổng = dày trần)'); box.appendChild(head);
    var tbl = document.createElement('table'); tbl.className = 'axes'; box.appendChild(tbl);
    heads(tbl, ['#', 'Chức năng', 'Dày (mm)', 'Vật liệu', 'Màu', '', '']);
    list.forEach(function (it, i) {
      var row = tbl.insertRow(), sel = document.createElement('select'), col = document.createElement('input'), up = document.createElement('button'), del = document.createElement('button');
      row.insertCell().textContent = String(i + 1);
      FINISH_FN.forEach(function (f) { sel.append(new Option(f[1], f[0])); }); sel.value = it.fn; sel.setAttribute('aria-label', 'Chức năng lớp ' + (i + 1));
      sel.onchange = function () { it.fn = sel.value; changed(); renderLevelLayers(); };
      row.insertCell().appendChild(sel);
      row.insertCell().appendChild(numCell(it.t, function (v) { it.t = v; syncLevelLayers(l); refreshLayerButtons(l); updateLevelLayerSummary(l, key); }, 'Dày lớp ' + (i + 1)));
      row.insertCell().appendChild(textCell(it.material || '', function (v) { it.material = v; }, 'Vật liệu lớp ' + (i + 1)));
      col.type = 'color'; col.value = it.color || (FINISH_FN.filter(function (f) { return f[0] === it.fn; })[0] || FINISH_FN[2])[2]; col.setAttribute('aria-label', 'Màu lớp ' + (i + 1)); col.oninput = function () { it.color = col.value; changed(); };
      row.insertCell().appendChild(col);
      up.type = 'button'; up.textContent = '↑'; up.title = 'Chuyển lớp lên'; up.disabled = i === 0;
      up.onclick = function () { list.splice(i - 1, 0, list.splice(i, 1)[0]); changed(); renderLevelLayers(); };
      row.insertCell().appendChild(up);
      del.type = 'button'; del.className = 'del'; del.textContent = '×'; del.title = 'Xóa lớp';
      del.onclick = function () { list.splice(i, 1); syncLevelLayers(l); if (!list.length) openLayers = null; renderLevels(); changed(); };
      row.insertCell().appendChild(del);
    });
    var add = document.createElement('button'); add.type = 'button'; add.className = 'add'; add.textContent = '+ Thêm lớp'; add.disabled = list.length >= MAX_WALL_LAYERS; add.title = 'Tối đa ' + MAX_WALL_LAYERS + ' lớp';
    add.onclick = function () { list.push({fn: 'finish', t: isFloor ? 10 : 9, material: '', color: null}); syncLevelLayers(l); renderLevels(); changed(); };
    box.appendChild(add);
    var sum = document.createElement('div'); sum.className = 'layers-sum'; sum.id = 'level-layers-sum'; box.appendChild(sum); updateLevelLayerSummary(l, key);
  }
  function updateLevelLayerSummary(l, key) {
    var sum = $('level-layers-sum'); if (!sum) return;
    var total = layersSum(l[key]), range = key === 'floorLayers' ? [0, 300] : [5, 100], bad = total < range[0] || total > range[1];
    sum.textContent = 'Tổng bề dày: ' + total + ' mm (' + (key === 'floorLayers' ? 'thành lớp cán nền' : 'thành dày trần') + ', phải từ ' + range[0] + ' đến ' + range[1] + ' mm).'; sum.className = 'layers-sum' + (bad ? ' error' : '');
    var scr = $('levels-table').querySelectorAll('tr')[state.levels.indexOf(l) + 1];
    if (scr) { var inputs = scr.querySelectorAll('input[type=number]'); if (inputs[1] && (l.floorLayers || []).length) inputs[1].value = l.screed; if (inputs[4] && (l.ceilingLayers || []).length) inputs[4].value = l.ceilingThickness; }
  }
  function refreshLevelNotes() {
    $('levels-table').querySelectorAll('td.note').forEach(function (cell, i) { cell.textContent = levelNote(i); });
  }
  function removeLevel(id) {
    state.levels = state.levels.filter(function (l) { return l.id !== id; });
    if (state.level === id) state.level = state.levels[0].id;
    state.selected = null; state.selectedBeam = null; state.selectedWall = null; renderLevels(); renderColumnsTab(); renderBeamsTab(); renderWallsTab(); renderOpeningsTab(); CELL_TABS.forEach(function (c) { renderCellTab(c); }); changed();
  }
  function addLevel() {
    var last = state.levels[state.levels.length - 1], n = state.levels.length + 1, name = 'Tầng ' + n, taken = state.levels.map(function (l) { return l.name.toLowerCase(); });
    while (taken.indexOf(name.toLowerCase()) >= 0) name += '*';
    state.levels.push({id: rid('sl_'), name: name, elevation: Number.isFinite(last.elevation) ? last.elevation + 3600 : 0, screed: 50, floorLayers: [], ceilingLayers: [], slab: 120, columnType: null, beamType: null, wallType: null, ceilingHeight: 2800, ceilingThickness: 9, picks: {}, beamPicks: {}, wallPicks: {}, slabPicks: {}, ceilingPicks: {}, notes: {}, openingPicks: {}});
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
    $('beam-level-note').textContent = above ? 'Đỉnh dầm bằng mặt sàn kết cấu tầng trên: cốt ' + Math.round((above.elevation - above.screed) * 10) / 10 + ' mm (dầm cao h là tổng chiều cao, tính từ đỉnh sàn)' : 'Tầng trên cùng: chỉ có sàn';
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

  // ---- Loại tường (nhiều lớp như Compound Structure của Revit) ----
  var WALL_FN = [['structure', 'Kết cấu', '#b8b0a2'], ['substrate', 'Lớp nền', '#d6cfc0'], ['insulation', 'Cách nhiệt', '#e6d96b'], ['finish', 'Hoàn thiện', '#f1eee6']], MAX_WALL_LAYERS = 5;
  function wallLayers(t) { if (!t.layers || !t.layers.length) t.layers = [{fn: 'structure', t: t.t, material: '', color: null}]; return t.layers; }
  function fnColor(fn) { return WALL_FN.filter(function (f) { return f[0] === fn; })[0][2]; }
  function layersTotal(t) { return Math.round(wallLayers(t).reduce(function (a, l) { return a + (Number(l.t) || 0); }, 0) * 10) / 10; }
  function syncWallT(t) { t.t = layersTotal(t); }
  var openWallType = null;
  function renderWallTypes() {
    var table = $('wall-types-table'); table.replaceChildren();
    heads(table, ['Tên', 'Lớp (tổng dày)', '']);
    state.wallTypes.forEach(function (t, i) {
      var row = table.insertRow(), del = document.createElement('button'), edit = document.createElement('button');
      row.insertCell().appendChild(textCell(t.name, function (v) { t.name = v; refreshTypeSelects(); }, 'Tên loại tường ' + (i + 1)));
      edit.type = 'button'; edit.className = 'layers-btn'; edit.textContent = wallLayers(t).length + ' lớp · ' + layersTotal(t) + ' mm'; edit.title = 'Sửa các lớp của loại tường này';
      edit.setAttribute('aria-expanded', String(openWallType === t.id));
      edit.onclick = function () { openWallType = openWallType === t.id ? null : t.id; renderWallTypes(); };
      row.insertCell().appendChild(edit);
      del.type = 'button'; del.className = 'del'; del.textContent = '×'; del.title = 'Xóa loại tường này'; del.disabled = state.wallTypes.length <= 1;
      del.onclick = function () { removeWallType(t.id); };
      row.insertCell().appendChild(del);
    });
    renderLayerEditor();
  }
  function renderLayerEditor() {
    var box = $('wall-layers-editor'); box.replaceChildren();
    var t = state.wallTypes.filter(function (x) { return x.id === openWallType; })[0];
    box.hidden = !t; if (!t) return;
    var layers = wallLayers(t), head = document.createElement('div'); head.className = 'layers-head';
    head.textContent = 'Các lớp của “' + t.name + '” (lớp 1 ở phía -Y của tường ngang, -X của tường dọc)'; box.appendChild(head);
    var tbl = document.createElement('table'); tbl.className = 'axes'; box.appendChild(tbl);
    heads(tbl, ['#', 'Chức năng', 'Dày (mm)', 'Vật liệu', 'Màu', '', '']);
    layers.forEach(function (l, i) {
      var row = tbl.insertRow(), sel = document.createElement('select'), col = document.createElement('input'), up = document.createElement('button'), del = document.createElement('button');
      row.insertCell().textContent = String(i + 1);
      WALL_FN.forEach(function (f) { sel.append(new Option(f[1], f[0])); }); sel.value = l.fn; sel.setAttribute('aria-label', 'Chức năng lớp ' + (i + 1));
      sel.onchange = function () { l.fn = sel.value; changed(); renderLayerEditor(); };
      row.insertCell().appendChild(sel);
      row.insertCell().appendChild(numCell(l.t, function (v) { l.t = v; syncWallT(t); updateLayerSummary(t); }, 'Dày lớp ' + (i + 1)));
      row.insertCell().appendChild(textCell(l.material || '', function (v) { l.material = v; }, 'Vật liệu lớp ' + (i + 1)));
      col.type = 'color'; col.value = l.color || fnColor(l.fn); col.setAttribute('aria-label', 'Màu lớp ' + (i + 1)); col.oninput = function () { l.color = col.value; changed(); };
      row.insertCell().appendChild(col);
      up.type = 'button'; up.textContent = '↑'; up.title = 'Chuyển lớp lên'; up.disabled = i === 0;
      up.onclick = function () { layers.splice(i - 1, 0, layers.splice(i, 1)[0]); changed(); renderLayerEditor(); };
      row.insertCell().appendChild(up);
      del.type = 'button'; del.className = 'del'; del.textContent = '×'; del.title = 'Xóa lớp'; del.disabled = layers.length <= 1;
      del.onclick = function () { layers.splice(i, 1); syncWallT(t); renderWallTypes(); changed(); };
      row.insertCell().appendChild(del);
    });
    var add = document.createElement('button'); add.type = 'button'; add.className = 'add'; add.textContent = '+ Thêm lớp'; add.disabled = layers.length >= MAX_WALL_LAYERS;
    add.title = 'Tối đa ' + MAX_WALL_LAYERS + ' lớp';
    add.onclick = function () { layers.push({fn: 'finish', t: 15, material: '', color: null}); syncWallT(t); renderWallTypes(); changed(); };
    box.appendChild(add);
    var sum = document.createElement('div'); sum.className = 'layers-sum'; sum.id = 'wall-layers-sum'; box.appendChild(sum); updateLayerSummary(t);
  }
  function updateLayerSummary(t) {
    var sum = $('wall-layers-sum'); if (!sum) return;
    var total = layersTotal(t), hasCore = wallLayers(t).some(function (l) { return l.fn === 'structure'; }), msg = 'Tổng bề dày: ' + total + ' mm.';
    if (!hasCore) msg += ' Cần ít nhất một lớp kết cấu.'; if (total < 50 || total > 1000) msg += ' Tổng bề dày phải từ 50 đến 1000 mm.';
    sum.textContent = msg; sum.className = 'layers-sum' + (!hasCore || total < 50 || total > 1000 ? ' error' : '');
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
    var layers = base ? wallLayers(base).map(function (l) { return {fn: l.fn, t: l.t, material: l.material, color: l.color}; }) : [{fn: 'structure', t: 200, material: '', color: null}];
    state.wallTypes.push({id: rid('wt_'), name: name, t: layers.reduce(function (a, l) { return a + l.t; }, 0), layers: layers});
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
    $('wall-level-note').textContent = above ? 'Chân tường trên sàn kết cấu: cốt ' + Math.round((l.elevation - l.screed) * 10) / 10 + ' mm; đỉnh tại đáy dầm hoặc đáy sàn tầng trên (' + Math.round((above.elevation - above.screed - above.slab) * 10) / 10 + ' mm)' : 'Tầng trên cùng: chỉ có sàn';
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
      ? 'Mặt trên sàn KẾT CẤU tại cốt ' + Math.round((l.elevation - l.screed) * 10) / 10 + ' mm (cao độ tầng ' + l.elevation + ' trừ cán nền ' + l.screed + '), dày ' + l.slab + ' mm xuống dưới; sàn lọt lòng giữa các dầm tầng dưới' + (isTop(l) ? ' (tầng trên cùng: sàn mái)' : '')
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


  // ---- Tab Tổng hợp và dựng ----
  var ALL_KINDS = [['columns', 'picks', 'Cột'], ['beams', 'beamPicks', 'Dầm'], ['walls', 'wallPicks', 'Tường'], ['openings', 'openingPicks', 'Cửa'], ['slabs', 'slabPicks', 'Sàn'], ['ceilings', 'ceilingPicks', 'Trần']];
  function renderAllTab() {
    var sel = $('all-level-select'); sel.replaceChildren();
    state.levels.forEach(function (l) { sel.append(new Option(l.name, l.id)); });
    sel.value = state.level;
    var table = $('all-table'); table.replaceChildren();
    heads(table, ['Tầng'].concat(ALL_KINDS.map(function (k) { return k[2]; })).concat(['Đã dựng']));
    state.levels.forEach(function (l) {
      var row = table.insertRow(), top = isTop(l);
      var name = row.insertCell(); name.textContent = l.name + (top ? ' (trên cùng: chỉ sàn)' : '');
      ALL_KINDS.forEach(function (k) {
        var cell = row.insertCell(); cell.className = 'num'; cell.textContent = (top && k[0] !== 'slabs') ? '—' : Object.keys(l[k[1]]).length;
      });
      var built = ALL_KINDS.filter(function (k) { return drawnList(k[0]).indexOf(l.id) >= 0; }).map(function (k) { return k[2]; });
      var d = row.insertCell(); d.className = 'note'; d.textContent = built.length ? built.join(', ') : '—';
    });
    renderAllButtons();
  }
  function drawnList(kind) { return {columns: state.drawnLevels, beams: state.drawnBeamLevels, walls: state.drawnWallLevels, openings: state.drawnOpeningLevels, slabs: state.drawnSlabLevels, ceilings: state.drawnCeilingLevels}[kind]; }
  function renderAllButtons() {
    var l = currentLevel();
    var has = function (lv) { return ALL_KINDS.some(function (k) { return Object.keys(lv[k[1]]).length; }); };
    $('build-all-level').disabled = !state.previewOk || !has(l);
    $('build-all-levels').disabled = !state.previewOk || !state.levels.some(has);
  }
  function renderCheck(data) {
    var summary = $('check-summary'), list = $('check-list'); list.replaceChildren();
    summary.className = data.errors ? 'summary error' : 'summary';
    summary.textContent = data.errors || data.warnings ? data.errors + ' lỗi, ' + data.warnings + ' cảnh báo.' : 'Không có lỗi hay cảnh báo nào.';
    data.levels.forEach(function (l) {
      l.errors.forEach(function (m) { var li = document.createElement('li'); li.textContent = l.name + ' · LỖI · ' + m; list.appendChild(li); });
      l.warnings.forEach(function (m) { var li = document.createElement('li'); li.className = 'warn'; li.textContent = l.name + ' · ' + m; list.appendChild(li); });
    });
  }


  // ---- Loại cửa và tab Cửa ----
  function renderOpeningTypes() {
    var table = $('opening-types-table'); table.replaceChildren();
    heads(table, ['Tên', 'Kiểu', 'Rộng (mm)', 'Cao (mm)', 'Cao ngưỡng (mm)', '']);
    state.openingTypes.forEach(function (t, i) {
      var row = table.insertRow(), del = document.createElement('button'), kind = document.createElement('select');
      row.insertCell().appendChild(textCell(t.name, function (v) { t.name = v; }, 'Tên loại cửa ' + (i + 1)));
      kind.setAttribute('aria-label', 'Kiểu loại cửa ' + t.name); kind.append(new Option('Cửa đi', 'door'), new Option('Cửa sổ', 'window')); kind.value = t.kind;
      kind.onchange = function () { t.kind = kind.value; changed(); renderOpeningsTab(); };
      row.insertCell().appendChild(kind);
      row.insertCell().appendChild(numCell(t.w, function (v) { t.w = v; }, 'Rộng loại cửa ' + t.name));
      row.insertCell().appendChild(numCell(t.h, function (v) { t.h = v; }, 'Cao loại cửa ' + t.name));
      row.insertCell().appendChild(numCell(t.sill, function (v) { t.sill = v; }, 'Cao ngưỡng loại cửa ' + t.name));
      del.type = 'button'; del.className = 'del'; del.textContent = '×'; del.title = 'Xóa loại cửa này'; del.disabled = state.openingTypes.length <= 1;
      del.onclick = function () { removeOpeningType(t.id); };
      row.insertCell().appendChild(del);
    });
  }
  // Xóa loại cửa: các cửa đang dùng loại đó bị gỡ khỏi tường (không còn loại để dựng).
  function removeOpeningType(id) {
    state.openingTypes = state.openingTypes.filter(function (t) { return t.id !== id; });
    state.levels.forEach(function (l) { Object.keys(l.openingPicks).forEach(function (k) { if (l.openingPicks[k].type === id) delete l.openingPicks[k]; }); });
    renderLevels(); renderOpeningsTab(); changed();
  }
  function addOpeningType() {
    var n = state.openingTypes.length + 1, name = 'Cửa ' + n, taken = state.openingTypes.map(function (t) { return t.name.toLowerCase(); });
    while (taken.indexOf(name.toLowerCase()) >= 0) name += '*';
    state.openingTypes.push({id: rid('ot_'), name: name, kind: 'door', w: 900, h: 2100, sill: 0});
    renderLevels(); changed();
  }
  function wallItems() { return (state.preview && state.preview.walls && state.preview.walls.items) || []; }
  function renderOpeningsTab() { renderOpeningLevelSelects(); renderOpeningsButtons(); renderOpeningEditor(); renderOpeningsPlan(); }
  function renderOpeningLevelSelects() {
    var sel = $('opening-level-select'), from = $('opening-copy-from');
    sel.replaceChildren(); from.replaceChildren();
    state.levels.forEach(function (l) { sel.append(new Option(l.name, l.id)); if (l.id !== state.level) from.append(new Option(l.name, l.id)); });
    sel.value = state.level;
    var l = currentLevel();
    $('opening-level-note').textContent = isTop(l) ? 'Tầng trên cùng: chỉ có sàn, không có tường nên không có cửa' : Object.keys(l.openingPicks).length + ' cửa đã đặt ở tầng này';
  }
  function renderOpeningsButtons() {
    var l = currentLevel(), top = isTop(l);
    $('build-openings').disabled = top || !state.previewOk || !Object.keys(l.openingPicks).length;
    $('build-all-openings').disabled = !state.previewOk;
    $('remove-openings').disabled = state.drawnOpeningLevels.indexOf(l.id) < 0;
    $('opening-copy-picks').disabled = top || !$('opening-copy-from').options.length;
  }
  // Vị trí tâm còn trống đầu tiên trên tường (cách đầu tường), ưu tiên giữa tường; không còn chỗ thì null.
  function freeCenter(wall, width, existing) {
    var gap = 50, tries = [0.5, 0.25, 0.75, 0.125, 0.375, 0.625, 0.875];
    for (var i = 0; i < tries.length; i++) {
      var c = Math.round(wall.length * tries[i] * 10) / 10, x0 = c - width / 2, x1 = c + width / 2;
      if (x0 < 0 || x1 > wall.length) continue;
      if (existing.every(function (e) { return x1 + gap <= e.x0 || x0 >= e.x1 + gap; })) return c;
    }
    return null;
  }
  function wallOpenings(wallRef) {
    var l = currentLevel(), t = {};
    state.openingTypes.forEach(function (x) { t[x.id] = x; });
    return Object.keys(l.openingPicks).filter(function (id) { return l.openingPicks[id].wall === wallRef; }).map(function (id) {
      var e = l.openingPicks[id], ty = t[e.type] || {w: 0};
      return {id: id, x0: e.pos - ty.w / 2, x1: e.pos + ty.w / 2};
    });
  }
  function addOpening(kind) {
    var l = currentLevel(), wall = wallItems().filter(function (w) { return w.ref === state.openWall; })[0];
    var type = state.openingTypes.filter(function (t) { return t.kind === kind; })[0];
    if (!wall) return message('Hãy chọn một tường trên mặt bằng.', true);
    if (!type) return message('Chưa có loại ' + (kind === 'door' ? 'cửa đi' : 'cửa sổ') + '. Hãy thêm ở tab Tầng và loại cột.', true);
    var pos = freeCenter(wall, type.w, wallOpenings(wall.ref));
    if (pos === null) return message('Tường này không còn chỗ trống cho cửa rộng ' + type.w + ' mm.', true);
    l.openingPicks[rid('op_')] = {wall: wall.ref, type: type.id, pos: pos, flip: false};
    renderOpeningEditor(); renderOpeningsButtons(); renderOpeningLevelSelects(); changed();
  }
  function renderOpeningEditor() {
    var l = currentLevel(), wall = state.openWall && wallItems().filter(function (w) { return w.ref === state.openWall; })[0];
    $('opening-editor').hidden = !wall;
    if (!wall) return;
    $('opening-wall-ref').textContent = wall.ref;
    $('opening-wall-note').textContent = 'Dài ' + wall.length + ' mm, cao ' + wall.height + ' mm. Vị trí là tâm cửa tính từ đầu tường (0 đến ' + wall.length + ').';
    var list = $('opening-list'); list.replaceChildren();
    Object.keys(l.openingPicks).filter(function (id) { return l.openingPicks[id].wall === wall.ref; }).forEach(function (id) {
      var e = l.openingPicks[id], row = document.createElement('div'), sel = document.createElement('select'), pos = document.createElement('input'), flip = document.createElement('label'), box = document.createElement('input'), del = document.createElement('button');
      row.className = 'oprow';
      state.openingTypes.forEach(function (t) { sel.append(new Option((t.kind === 'door' ? 'Cửa đi ' : 'Cửa sổ ') + t.name + ' (' + t.w + '×' + t.h + ')', t.id)); });
      sel.value = e.type; sel.setAttribute('aria-label', 'Loại cửa ' + id);
      sel.onchange = function () { e.type = sel.value; changed(); renderOpeningEditor(); };
      pos.type = 'number'; pos.step = 'any'; pos.value = e.pos; pos.setAttribute('aria-label', 'Vị trí tâm cửa ' + id);
      pos.oninput = function () { e.pos = pos.value === '' ? NaN : Number(pos.value); changed(); };
      box.type = 'checkbox'; box.checked = !!e.flip; box.setAttribute('aria-label', 'Đổi mặt cánh ' + id);
      box.onchange = function () { e.flip = box.checked; changed(); };
      flip.append(box, document.createTextNode(' Đổi mặt'));
      var hinge = document.createElement('label'), hbox = document.createElement('input'), isDoor = (state.openingTypes.filter(function (t) { return t.id === e.type; })[0] || {}).kind === 'door';
      hbox.type = 'checkbox'; hbox.checked = !!e.mirror; hbox.setAttribute('aria-label', 'Bản lề ở cuối cửa ' + id);
      hbox.onchange = function () { if (hbox.checked) e.mirror = true; else delete e.mirror; changed(); };
      hinge.append(hbox, document.createTextNode(' Bản lề cuối')); hinge.hidden = !isDoor;
      del.type = 'button'; del.className = 'del'; del.textContent = '×'; del.title = 'Xóa cửa này';
      del.onclick = function () { delete l.openingPicks[id]; renderOpeningEditor(); renderOpeningsButtons(); renderOpeningLevelSelects(); changed(); };
      row.append(sel, pos, flip, hinge, del); list.appendChild(row);
    });
    if (!list.children.length) { var p = document.createElement('p'); p.className = 'muted small'; p.textContent = 'Tường chưa có cửa. Bấm + Cửa đi hoặc + Cửa sổ.'; list.appendChild(p); }
  }
  function renderOpeningsPlan() {
    var svg = $('plan7'), ns = 'http://www.w3.org/2000/svg', data = state.preview;
    svg.replaceChildren();
    if (!data || !data.ok) return;
    var xs = [], ys = [];
    data.axes.forEach(function (a) { a.line.forEach(function (p) { xs.push(p[0]); ys.push(p[1]); }); });
    var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs), y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys), pad = Math.max(x1 - x0, y1 - y0) * 0.05;
    svg.setAttribute('viewBox', [x0 - pad, -(y1 + pad), x1 - x0 + 2 * pad, y1 - y0 + 2 * pad].join(' '));
    function el(tag, attrs, text) { var e = document.createElementNS(ns, tag); Object.keys(attrs).forEach(function (k) { e.setAttribute(k, attrs[k]); }); if (text !== undefined) e.textContent = text; svg.appendChild(e); return e; }
    data.axes.forEach(function (a) { el('line', {class: 'axis', x1: a.line[0][0], y1: -a.line[0][1], x2: a.line[1][0], y2: -a.line[1][1]}); });
    data.axes.forEach(function (a) { var b = a.bubbles[0]; el('text', {x: b.center[0], y: -b.center[1], 'font-size': Math.max(x1 - x0, y1 - y0) * 0.022}, a.name); });
    var l = currentLevel(), top = isTop(l), grow = Math.max(x1 - x0, y1 - y0) * 0.004;
    ((data.columns && data.columns.items) || []).forEach(function (c) { el('rect', {class: 'colref', x: c.center[0] - c.w / 2, y: -(c.center[1] + c.d / 2), width: c.w, height: c.d}); });
    if (!top) wallItems().forEach(function (w) {
      var r = el('rect', {class: 'wallbase' + (state.openWall === w.ref ? ' sel' : ''), x: w.min[0] - grow, y: -(w.max[1] + grow), width: w.max[0] - w.min[0] + 2 * grow, height: w.max[1] - w.min[1] + 2 * grow, 'data-ref': w.ref});
      var tip = document.createElementNS(ns, 'title'); tip.textContent = w.ref + ' · dài ' + w.length + ' mm · ' + w.openings.length + ' cửa'; r.appendChild(tip);
      r.onclick = function () { state.openWall = w.ref; renderOpeningEditor(); renderOpeningsPlan(); };
    });
    var open = (data.openings && data.openings.items) || [];
    open.forEach(function (o) {
      var long = o.dir === 'x';
      var r = el('rect', {class: o.kind, x: o.min[0] - (long ? 0 : grow * 1.5), y: -(o.max[1] + (long ? grow * 1.5 : 0)), width: o.max[0] - o.min[0] + (long ? 0 : 3 * grow), height: o.max[1] - o.min[1] + (long ? 3 * grow : 0), 'data-ref': o.ref});
      var tip = document.createElementNS(ns, 'title'); tip.textContent = (o.kind === 'door' ? 'Cửa đi ' : 'Cửa sổ ') + o.type_name + ' · tâm ' + o.pos + ' mm · cao ngưỡng ' + o.sill + ' mm'; r.appendChild(tip);
      r.onclick = function () { state.openWall = o.wall; renderOpeningEditor(); renderOpeningsPlan(); };
    });
    var summary = $('opening-summary'), issues = $('opening-issues'); issues.replaceChildren();
    if (data.levels_ok === false) { summary.className = 'summary error'; summary.textContent = data.levels_error; return; }
    if (data.openings_error) { summary.className = 'summary'; summary.textContent = data.openings_error; return; }
    if (data.openings) {
      summary.className = 'summary';
      summary.textContent = data.openings.level_name + ': ' + data.openings.count + ' cửa trên ' + wallItems().length + ' tường đã chọn.' + (wallItems().length ? '' : ' Hãy chọn tường ở tab Tường trước.');
      data.openings.issues.forEach(function (m) { var li = document.createElement('li'); li.textContent = m; issues.appendChild(li); });
    } else { summary.textContent = ''; }
  }

  function syncPlanLevels() { window.VGDPlan.setLevels(state.levels, state.level); }
  // Đổi tầng từ tab Mặt bằng: giống các ô chọn tầng ở tab khác.
  function setLevelFromPlan(id) {
    state.level = id; state.selected = null; state.selectedBeam = null; state.selectedWall = null; state.openWall = null;
    renderColumnsTab(); renderBeamsTab(); renderWallsTab(); renderOpeningsTab(); CELL_TABS.forEach(function (x) { renderCellTab(x); }); syncPlanLevels(); changed();
  }

  // ---- Bảng thống kê (Schedule) ----
  var schedData = null, SCHED_KINDS = [['columns', 'Cột'], ['beams', 'Dầm'], ['walls', 'Tường'], ['openings', 'Cửa'], ['slabs', 'Sàn'], ['ceilings', 'Trần']];
  function requestSchedule() { $('sched-note').textContent = 'Đang tính...'; call('schedule', payload()); }
  function renderScheduleControls() {
    var ks = $('sched-kind'), ls = $('sched-level'), kv = ks.value || 'columns', lv = ls.value || '';
    ks.replaceChildren(); SCHED_KINDS.forEach(function (k) { ks.append(new Option(k[1], k[0])); }); ks.value = kv;
    ls.replaceChildren(); ls.append(new Option('Tất cả các tầng', '')); state.levels.forEach(function (l) { ls.append(new Option(l.name, l.id)); }); ls.value = state.levels.some(function (l) { return l.id === lv; }) ? lv : '';
  }
  function schedRows() { // dòng theo loại và tầng đang lọc, kèm dòng tổng
    if (!schedData) return null;
    var sec = schedData.sections.filter(function (s) { return s.kind === $('sched-kind').value; })[0]; if (!sec) return null;
    var lv = $('sched-level').value, rows = sec.rows.filter(function (r) { return !lv || r.level === lv; });
    var head = ['Tầng', 'Loại', 'Số lượng'].concat(sec.columns.map(function (c) { return c.label + (c.unit ? ' (' + c.unit + ')' : ''); }));
    var body = rows.map(function (r) { return [r.level_name, r.type, String(r.count)].concat(sec.columns.map(function (c) { var v = r.values[c.id]; return v === undefined ? '' : String(v); })); });
    var total = ['Tổng', '', String(rows.reduce(function (a, r) { return a + r.count; }, 0))].concat(sec.columns.map(function (c) { return c.sum ? String(Math.round(rows.reduce(function (a, r) { return a + (Number(r.values[c.id]) || 0); }, 0) * 1000) / 1000) : ''; }));
    return {head: head, body: body, total: total};
  }
  function renderSchedule() {
    var t = $('sched-table'); t.replaceChildren();
    var d = schedRows(); if (!d) return;
    var hr = t.insertRow(); d.head.forEach(function (h) { var th = document.createElement('th'); th.textContent = h; hr.appendChild(th); });
    d.body.forEach(function (r) { var row = t.insertRow(); r.forEach(function (v) { row.insertCell().textContent = v; }); });
    if (d.body.length) { var tr = t.insertRow(); tr.className = 'total'; d.total.forEach(function (v) { var c = tr.insertCell(); c.textContent = v; c.style.fontWeight = '600'; }); }
    var issues = (schedData && schedData.issues) || [];
    $('sched-note').textContent = d.body.length ? d.body.length + ' dòng.' + (issues.length ? ' Lưu ý: ' + issues.join(' ') : '') : 'Chưa có ' + SCHED_KINDS.filter(function (k) { return k[0] === $('sched-kind').value; })[0][1].toLowerCase() + ' nào được chọn' + (issues.length ? '. ' + issues.join(' ') : '.');
  }
  function schedCsv() { var d = schedRows(); if (!d) return ''; return [d.head].concat(d.body, d.body.length ? [d.total] : []).map(function (r) { return r.map(function (v) { return /[\t\n"]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; }).join('\t'); }).join('\n'); }
  function copySchedule() {
    var text = schedCsv(), done = function (ok) { $('sched-note').textContent = ok ? 'Đã sao chép bảng (cột cách nhau bằng Tab): dán vào Excel.' : 'Không sao chép được: hãy chọn bảng và sao chép tay.'; };
    if (navigator.clipboard && navigator.clipboard.writeText) { navigator.clipboard.writeText(text).then(function () { done(true); }, function () { done(fallbackCopy(text)); }); } else done(fallbackCopy(text));
  }
  function fallbackCopy(text) { var ta = document.createElement('textarea'); ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0'; document.body.appendChild(ta); ta.select(); var ok = false; try { ok = document.execCommand('copy'); } catch (e) { ok = false; } ta.remove(); return ok; }
  function switchTab(tab) {
    state.tab = tab;
    document.querySelectorAll('.tabs button').forEach(function (b) { b.setAttribute('aria-selected', String(b.getAttribute('data-tab') === tab)); });
    ['grid', 'levels', 'plan', 'columns', 'beams', 'walls', 'openings', 'slabs', 'ceilings', 'schedule', 'all'].forEach(function (t) { $('tab-' + t).hidden = t !== tab; });
    if (tab === 'plan') { syncPlanLevels(); window.VGDPlan.show(); }
    if (tab === 'columns') renderColumnsTab();
    if (tab === 'beams') renderBeamsTab();
    if (tab === 'walls') renderWallsTab();
    if (tab === 'openings') renderOpeningsTab();
    CELL_TABS.forEach(function (c) { if (tab === c.kind) renderCellTab(c); });
    if (tab === 'all') renderAllTab();
    if (tab === 'schedule') { renderScheduleControls(); requestSchedule(); }
  }

  function receive(event, data) {
    if (event === 'state') {
      state.origin = data.grid.origin.slice();
      var x = fromAxes(data.grid.x_axes), y = fromAxes(data.grid.y_axes);
      state.x = x; state.y = y; state.scale = data.symbol.scale; state.both = data.symbol.both_ends; state.drawn = data.drawn;
      state.types = data.types.map(function (t) { return {id: t.id, name: t.name, w: t.w, d: t.d}; });
      state.beamTypes = (data.beam_types || []).map(function (t) { return {id: t.id, name: t.name, w: t.w, h: t.h}; });
      state.wallTypes = (data.wall_types || []).map(function (t) { return {id: t.id, name: t.name, t: t.t, layers: (t.layers || [{fn: 'structure', t: t.t, material: ''}]).map(function (l) { return {fn: l.fn, t: l.t, material: l.material || '', color: l.color || null}; })}; });
      state.openingTypes = (data.opening_types || []).map(function (t) { return {id: t.id, name: t.name, kind: t.kind, w: t.w, h: t.h, sill: t.sill}; });
      state.drawnOpeningLevels = data.drawn_opening_levels || []; state.openWall = null;
      var keepLevel = data.reload ? state.level : null; // nạp lại do Hoàn tác / Làm lại trong SketchUp: giữ tầng đang xem
      state.levels = data.levels.map(fromRubyLevel); state.level = state.levels[0].id; state.selected = null; state.selectedBeam = null; state.selectedWall = null;
      if (keepLevel && state.levels.some(function (l) { return l.id === keepLevel; })) state.level = keepLevel;
      state.drawnLevels = data.drawn_levels || []; state.drawnBeamLevels = data.drawn_beam_levels || []; state.drawnWallLevels = data.drawn_wall_levels || []; state.drawnSlabLevels = data.drawn_slab_levels || []; state.drawnCeilingLevels = data.drawn_ceiling_levels || [];
      $('version').textContent = 'v' + data.version; syncPlanLevels(); undoStack = []; redoStack = []; historyChanged();
      renderAll(); renderLevels(); renderColumnsTab(); renderBeamsTab(); renderWallsTab(); renderOpeningsTab(); CELL_TABS.forEach(function (c) { renderCellTab(c); }); renderAllTab();
      message(data.reload ? 'Đã nạp lại dữ liệu theo Hoàn tác / Làm lại trong SketchUp.' : (data.saved ? 'Đã nạp lưới trục lưu trong model.' : 'Lưới mặc định: sửa các số rồi bấm Vẽ lưới trục.'));
    } else if (event === 'preview') {
      state.previewOk = !!data.ok;
      var s = $('summary');
      if (data.ok) {
        var m = data.summary;
        s.className = 'summary';
        s.textContent = m.x_axes + ' trục đứng × ' + m.y_axes + ' trục ngang: ' + m.intersections + ' giao điểm, ' + m.spans + ' nhịp, ' + m.cells + ' ô. Khung lưới ' + m.width + ' × ' + m.depth + ' mm.';
      } else { s.className = 'summary error'; s.textContent = data.error; }
      state.preview = data; window.VGDPlan.update(data); drawPlan(data); renderButtons(); renderColumnsButtons(); renderColumnsPlan(); renderBeamsButtons(); renderBeamsPlan(); renderWallsButtons(); renderWallsPlan(); renderOpeningsButtons(); renderOpeningsPlan(); CELL_TABS.forEach(function (c) { renderCellButtons(c); renderCellPlan(c); });
    } else if (event === 'axes') {
      var set = fromAxes(data.axes); state[data.dir] = set; renderAxes(data.dir); changed();
    } else if (event === 'levels') {
      state.levels = data.levels.map(fromRubyLevel); syncPlanLevels(); renderLevels(); renderColumnsTab(); renderBeamsTab(); renderWallsTab(); renderOpeningsTab(); CELL_TABS.forEach(function (c) { renderCellTab(c); }); renderAllTab(); changed(); message(data.message);
    } else if (event === 'columns_built') {
      state.drawnLevels = data.drawn_levels || []; renderColumnsButtons(); message(data.message, data.error); changed();
    } else if (event === 'beams_built') {
      state.drawnBeamLevels = data.drawn_beam_levels || []; renderBeamsButtons(); message(data.message, data.error); changed();
    } else if (event === 'focus') {
      var tabOf = {column: 'columns', beam: 'beams', wall: 'walls', door: 'openings', window: 'openings', slab: 'slabs', ceiling: 'ceilings'}[data.kind];
      if (tabOf) {
        if (state.levels.some(function (l) { return l.id === data.level; })) state.level = data.level;
        state.selected = null; state.selectedBeam = null; state.selectedWall = null;
        var lv = currentLevel();
        if (data.kind === 'column' && lv.picks[data.ref]) state.selected = data.ref;
        if (data.kind === 'beam' && lv.beamPicks[data.ref]) state.selectedBeam = data.ref;
        if (data.kind === 'wall' && lv.wallPicks[data.ref]) state.selectedWall = data.ref;
        if ((data.kind === 'door' || data.kind === 'window') && lv.openingPicks[data.ref]) state.openWall = lv.openingPicks[data.ref].wall;
        renderLevels(); renderColumnsTab(); renderBeamsTab(); renderWallsTab(); renderOpeningsTab(); CELL_TABS.forEach(function (c) { renderCellTab(c); }); renderAllTab();
        switchTab(tabOf);
        message('Đang sửa ' + data.ref + ' ở ' + lv.name + '.');
      }
    } else if (event === 'check') {
      renderCheck(data);
    } else if (event === 'all_built') {
      state.drawnLevels = data.drawn.columns || []; state.drawnBeamLevels = data.drawn.beams || []; state.drawnWallLevels = data.drawn.walls || [];
      state.drawnSlabLevels = data.drawn.slabs || []; state.drawnCeilingLevels = data.drawn.ceilings || []; state.drawnOpeningLevels = data.drawn.openings || [];
      renderAllTab(); message(data.message); changed();
    } else if (event === 'plates_built') {
      var cfg = CELL_TABS.filter(function (c) { return c.kind === data.kind; })[0];
      if (cfg) { state[cfg.drawn] = data.drawn_levels || []; renderCellButtons(cfg); }
      message(data.message, data.error); changed();
    } else if (event === 'openings_built') {
      state.drawnOpeningLevels = data.drawn_opening_levels || []; renderOpeningsButtons(); renderAllTab(); message(data.message, data.error); changed();
    } else if (event === 'walls_built') {
      state.drawnWallLevels = data.drawn_wall_levels || []; state.drawnSlabLevels = data.drawn_slab_levels || []; state.drawnCeilingLevels = data.drawn_ceiling_levels || []; renderWallsButtons(); message(data.message, data.error); changed();
    } else if (event === 'built') {
      state.drawn = data.drawn; renderButtons(); message(data.message);
    } else if (event === 'message') {
      message(data.text, data.error);
    } else if (event === 'model_selection') { window.VGDPlan.modelSelection(data);
    } else if (event === 'model_status') { window.VGDPlan.modelStatus(data);
    } else if (event === 'select_result') { window.VGDPlan.selectResult(data);
    } else if (event === 'su_point') { window.VGDPlan.suPoint(data);
    } else if (event === 'su_move') { window.VGDPlan.suMove(data);
    } else if (event === 'su_pick_state') { window.VGDPlan.suState(data.active);
    } else if (event === 'su_key') { window.VGDPlan.suKey(data.key);
    } else if (event === 'su_text') { window.VGDPlan.suText(data.text);
    } else if (event === 'start_tool') { startDrawTool(data.tool);
    } else if (event === 'su_edit') { applySuEdit(data);
    } else if (event === 'schedule') { schedData = data; renderSchedule();
    } else if (event === 'plate_probe') { probeCache[data.key] = data.polygon || false; if (window.VGDPlan && window.VGDPlan.ghostChanged) window.VGDPlan.ghostChanged();
    }
  }
  // ---- Thao tác từ tab Mặt bằng: có hoàn tác / làm lại (chỉ các thay đổi làm trên mặt bằng) ----
  var undoStack = [], redoStack = [], HISTORY_MAX = 100;
  function snapshot() { return JSON.stringify({origin: state.origin, x: state.x, y: state.y, levels: state.levels, types: state.types, beamTypes: state.beamTypes, wallTypes: state.wallTypes, openingTypes: state.openingTypes}); }
  function restore(text) {
    var s = JSON.parse(text);
    state.origin = s.origin; state.x = s.x; state.y = s.y; state.levels = s.levels; state.types = s.types; state.beamTypes = s.beamTypes; state.wallTypes = s.wallTypes; state.openingTypes = s.openingTypes;
    if (!state.levels.some(function (l) { return l.id === state.level; })) state.level = state.levels[0].id;
    state.selected = null; state.selectedBeam = null; state.selectedWall = null; state.openWall = null;
    rerenderAll(); changed();
  }
  function rerenderAll() {
    renderAll(); renderLevels(); renderColumnsTab(); renderBeamsTab(); renderWallsTab(); renderOpeningsTab(); CELL_TABS.forEach(function (c) { renderCellTab(c); }); renderAllTab(); syncPlanLevels();
  }
  function historyChanged() { window.VGDPlan.refreshHistory(); }
  // ---- Vẽ trực tiếp trong SketchUp: mỗi lần vẽ / sửa xong thì tự dựng lại các loại phần tử đã đổi của tầng đang xem (gom các lần liên tiếp) ----
  var AUTO_BUILD_MS = 250, autoKinds = {}, autoTimer = null;
  var KIND_BOX = {columns: 'picks', beams: 'beamPicks', walls: 'wallPicks', openings: 'openingPicks', slabs: 'slabPicks', ceilings: 'ceilingPicks'};
  function levelSig() {
    var l = currentLevel(), out = {}; Object.keys(KIND_BOX).forEach(function (k) { out[k] = JSON.stringify(l[KIND_BOX[k]] || {}); }); return out;
  }
  function kindsToBuild(before, after) {
    var l = currentLevel(), changed = Object.keys(KIND_BOX).filter(function (k) { return before[k] !== after[k]; }), set = {};
    changed.forEach(function (k) { set[k] = true; });
    if (set.openings && Object.keys(l.wallPicks).length) set.walls = true;      // lỗ cửa nằm trong tường
    if (set.walls && Object.keys(l.openingPicks).length) set.openings = true;   // tường đổi chỗ thì cửa đổi theo
    return Object.keys(set);
  }
  var autoRetag = {};
  function scheduleAutoBuild(kinds, levelId, retag) {
    if (!kinds.length) return;
    kinds.forEach(function (k) { autoKinds[k + '@' + (levelId || state.level)] = levelId || state.level; });
    if (retag) Object.keys(retag).forEach(function (k) { autoRetag[k] = retag[k]; });
    clearTimeout(autoTimer);
    autoTimer = setTimeout(function () {
      var byLevel = {}; Object.keys(autoKinds).forEach(function (k) { (byLevel[autoKinds[k]] = byLevel[autoKinds[k]] || []).push(k.split('@')[0]); }); autoKinds = {}; var retag = autoRetag; autoRetag = {};
      Object.keys(byLevel).forEach(function (levelId) {
        var lv = state.levels.filter(function (x) { return x.id === levelId; })[0]; if (!lv) return;
        var build = byLevel[levelId].filter(function (k) { return Object.keys(lv[KIND_BOX[k]] || {}).length; }), gone = byLevel[levelId].filter(function (k) { return !Object.keys(lv[KIND_BOX[k]] || {}).length; });
        gone.forEach(function (k) { // đã xóa hết phần tử loại này: bỏ nhóm tương ứng trong model
          if (k === 'slabs' || k === 'ceilings') call('plates_remove', {kind: k, level: levelId}); else call(k + '_remove', {level: levelId});
        });
        if (build.length) { message('Đang dựng ' + build.join(', ') + '...'); call('build_all', {state: payload(), levels: [levelId], kinds: build, retag: retag}); }
      });
    }, AUTO_BUILD_MS);
  }
  // Bản vá dữ liệu do sửa trong SketchUp (dời, xoay, xóa phần tử đã dựng): áp vào dữ liệu rồi tự dựng lại các loại đổi, giữ VGD ID theo mã mới.
  var SU_BOX = {columns: 'picks', beams: 'beamPicks', walls: 'wallPicks', openings: 'openingPicks', slabs: 'slabPicks', ceilings: 'ceilingPicks'};
  function applySuEdit(data) {
    var patches = (data && data.patches) || [], retag = {}, byLevel = {};
    if (patches.length) {
      mutate(function () {
        patches.forEach(function (p) {
          var lv = state.levels.filter(function (x) { return x.id === p.level; })[0]; if (!lv) return;
          Object.keys(p.remove || {}).forEach(function (box) { (p.remove[box] || []).forEach(function (ref) { delete lv[SU_BOX[box]][ref]; }); });
          Object.keys(p.set || {}).forEach(function (box) { Object.keys(p.set[box]).forEach(function (ref) { lv[SU_BOX[box]][ref] = p.set[box][ref]; }); });
          Object.keys(p.retag || {}).forEach(function (old) { retag[p.level + ':' + old] = p.level + ':' + p.retag[old]; });
          (byLevel[p.level] = byLevel[p.level] || {}); (p.kinds || []).forEach(function (k) { byLevel[p.level][k] = true; });
        });
      });
      Object.keys(byLevel).forEach(function (id) {
        var lv = state.levels.filter(function (x) { return x.id === id; })[0], set = byLevel[id];
        if (set.openings && Object.keys(lv.wallPicks).length) set.walls = true;
        if (set.walls && Object.keys(lv.openingPicks).length) set.openings = true;
        scheduleAutoBuild(Object.keys(set), id, retag);
      });
      message('Đã cập nhật dữ liệu theo sửa trong SketchUp (' + patches.length + ' phần tử); đang dựng lại.');
    }
    if (data && data.skipped && data.skipped.length) message('Bỏ qua: ' + data.skipped.join('; ') + '.');
  }
  function startDrawTool(tool) {
    switchTab('plan'); window.VGDPlan.startDrawTool(tool);
  }
  function mutate(fn) {
    var drawing = window.VGDPlan && window.VGDPlan.suDrawOn && window.VGDPlan.suDrawOn(), before = drawing ? levelSig() : null;
    undoStack.push(snapshot()); if (undoStack.length > HISTORY_MAX) undoStack.shift(); redoStack = [];
    fn(); rerenderAll(); changed(); historyChanged();
    if (before) scheduleAutoBuild(kindsToBuild(before, levelSig()));
  }
  function undo() { if (!undoStack.length) return false; redoStack.push(snapshot()); restore(undoStack.pop()); historyChanged(); message('Đã hoàn tác.'); return true; }
  function redo() { if (!redoStack.length) return false; undoStack.push(snapshot()); restore(redoStack.pop()); historyChanged(); message('Đã làm lại.'); return true; }
  // Thêm trục tại vị trí tuyệt đối (mm); apply = false chỉ kiểm tra. Trả về lỗi (chuỗi) hoặc null.
  function addAxis(dir, pos, apply) {
    var list = toAxes(dir), off = Math.round((pos - state.origin[dir === 'x' ? 0 : 1]) * 10) / 10;
    if (!isFinite(off)) return 'Vị trí trục không hợp lệ.';
    if (list.length >= 60) return 'Tối đa 60 trục mỗi phương.';
    if (list.some(function (a) { return Math.abs(a.offset - off) < 100; })) return 'Trục mới phải cách các trục có sẵn ít nhất 100 mm.';
    if (apply) { list.push({name: freeName(dir, list.length), offset: off}); list.sort(function (a, b) { return a.offset - b.offset; }); state[dir] = fromAxes(list); }
    return null;
  }
  window.VGDS = {scheduleCsv: schedCsv, startTool: startDrawTool, receive: receive, _state: state, mutate: mutate, undo: undo, redo: redo, history: function () { return {undo: undoStack.length, redo: redoStack.length}; },
    api: {level: currentLevel, isTop: isTop, rid: rid, toAxes: toAxes, allSpans: allSpans, allCells: allCells, allRefs: allRefs, wallOpenings: wallOpenings, addAxis: addAxis, modes: {x: MODE_X, y: MODE_Y, p: MODE_P}}};
  window.VGDPlanEdit.init({state: state, api: window.VGDS.api, mutate: mutate, probe: plateProbe, say: function (t) { window.VGDPlan.say(t); }, scale: function () { return window.VGDPlan.scale(); }, snapPoint: function (w) { return window.VGDPlan.snapPoint(w); }, bounds: function () { return window.VGDPlan.bounds(); }});
  window.VGDPlanNotes.init({state: state, api: window.VGDS.api, mutate: mutate, say: function (t) { window.VGDPlan.say(t); }, scale: function () { return window.VGDPlan.scale(); }, snapPoint: function (w) { return window.VGDPlan.snapPoint(w); },
    promptText: function (w, initial, done) { window.VGDPlan.promptText(w, initial, done); }});
  // Công cụ vẽ kết cấu (plan_edit) và vẽ 2D / ghi chú (plan_notes) dùng chung một cổng vào cửa sổ mặt bằng: công cụ nào đang chọn thì nhận lệnh.
  var drawParts = [window.VGDPlanEdit, window.VGDPlanNotes], drawCur = null;
  var drawTools = {
    handles: function (t) { return drawParts.some(function (x) { return x.handles(t); }); },
    activate: function (t) { drawCur = null; drawParts.forEach(function (x) { x.activate(t); if (!drawCur && x.handles(t)) drawCur = x; }); },
    cancel: function () { drawParts.forEach(function (x) { x.cancel(); }); },
    busy: function () { return drawParts.some(function (x) { return x.busy(); }); },
    freeMode: function (t) { return drawParts.some(function (x) { return x.handles(t) && x.freeMode && x.freeMode(t); }); },
    options: function (t) { var x = drawParts.filter(function (y) { return y.handles(t); })[0]; return x ? x.options(t) : []; },
    setOption: function (t, id, v) { var x = drawParts.filter(function (y) { return y.handles(t); })[0]; if (x) x.setOption(t, id, v); },
    move: function (w) { if (drawCur) drawCur.move(w); }, click: function (w) { if (drawCur) return drawCur.click(w); },
    hint: function () { return drawCur ? drawCur.hint() : ''; }, ghost: function () { return drawCur ? drawCur.ghost() : []; },
    typed: function (n, cur) { return drawCur && drawCur.typed ? drawCur.typed(n, cur) : false; },
    flipDoor: function (t, ref, shift) { return window.VGDPlanEdit.flipDoor(t, ref, shift); },
    finish: function () { return drawCur && drawCur.finish ? drawCur.finish() : false; }, undoPoint: function () { return drawCur && drawCur.undoPoint ? drawCur.undoPoint() : false; },
    typeSelector: function (shape) { return shape.kind === 'note' ? null : window.VGDPlanEdit.typeSelector(shape); },
    propsFor: function (shape) { return shape.kind === 'note' ? window.VGDPlanNotes.propsFor(shape) : window.VGDPlanEdit.propsFor(shape); },
    remove: function (list) { return window.VGDPlanEdit.remove(list) + window.VGDPlanNotes.remove(list); },
    debug: function () { var d = window.VGDPlanEdit.debug(); d.notes = window.VGDPlanNotes.debug(); return d; }
  };
  window.VGDPlanModify.init({state: state, api: window.VGDS.api, mutate: mutate, scale: function () { return window.VGDPlan.scale(); }, bounds: function () { return window.VGDPlan.bounds(); }, shapeAt: function (w) { return window.VGDPlan.shapeAt(w); }, finish: function () { window.VGDPlan.finish(); },
    snapPoint: function (w) { return window.VGDPlan.snapPoint(w); }, lineAt: function (w) { return window.VGDPlan.lineAt(w); }, guides: function () { return window.VGDPlan.guides(); }});
  window.VGDPlan.init({onLevel: setLevelFromPlan, undo: undo, redo: redo, history: window.VGDS.history, edit: drawTools, notes: window.VGDPlanNotes, modify: window.VGDPlanModify, browser: window.VGDPlanBrowser,
    callSU: call, refresh: function () { changed(); },
    buildLevel: function () { message('Đang dựng tầng này vào model...'); call('build_all', {state: payload(), levels: [state.level]}); },
    allKeys: function (levelId, kind) { var box = {column: 'picks', beam: 'beamPicks', wall: 'wallPicks', opening: 'openingPicks', slab: 'slabPicks', ceiling: 'ceilingPicks', note: 'notes'}[kind], l = state.levels.filter(function (x) { return x.id === levelId; })[0]; return l && box ? Object.keys(l[box]) : []; }});
  var BROWSER_PICKS = {column: 'picks', beam: 'beamPicks', wall: 'wallPicks', opening: 'openingPicks'};
  window.VGDPlanBrowser.init({state: state, currentLevel: function () { return state.level; }, axes: toAxes,
    openLevel: function (id) { if (id !== state.level) setLevelFromPlan(id); },
    selectElement: function (levelId, kind, ref) { window.VGDPlan.selectKeys(levelId, [{kind: kind, ref: ref}]); },
    selectType: function (kind, typeId) {
      var l = currentLevel(), box = l[BROWSER_PICKS[kind]] || {};
      var keys = Object.keys(box).filter(function (ref) { return window.VGDPlanBrowser.effectiveType(kind, l, box[ref]) === typeId; }).map(function (ref) { return {kind: kind, ref: ref}; });
      window.VGDPlan.selectKeys(state.level, keys);
    }});

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
  $('beam-level-select').onchange = function () { state.level = $('beam-level-select').value; state.selectedBeam = null; state.selectedWall = null; state.selected = null; renderBeamsTab(); renderColumnsTab(); renderWallsTab(); renderOpeningsTab(); CELL_TABS.forEach(function (x) { renderCellTab(x); }); changed(); };
  $('wall-level-select').onchange = function () { state.level = $('wall-level-select').value; state.selectedBeam = null; state.selectedWall = null; state.selected = null; renderBeamsTab(); renderColumnsTab(); renderWallsTab(); renderOpeningsTab(); CELL_TABS.forEach(function (x) { renderCellTab(x); }); changed(); };
  $('level-select').onchange = function () { state.level = $('level-select').value; state.selected = null; state.selectedBeam = null; state.selectedWall = null; renderColumnsTab(); renderBeamsTab(); renderWallsTab(); renderOpeningsTab(); CELL_TABS.forEach(function (x) { renderCellTab(x); }); changed(); };
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
    $(p + '-level-select').onchange = function () { state.level = $(p + '-level-select').value; state.selected = null; state.selectedBeam = null; state.selectedWall = null; renderColumnsTab(); renderBeamsTab(); renderWallsTab(); renderOpeningsTab(); CELL_TABS.forEach(function (x) { renderCellTab(x); }); changed(); };
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
  $('all-level-select').onchange = function () { state.level = $('all-level-select').value; state.selected = null; state.selectedBeam = null; state.selectedWall = null; renderColumnsTab(); renderBeamsTab(); renderWallsTab(); CELL_TABS.forEach(function (x) { renderCellTab(x); }); changed(); renderAllButtons(); };
  $('propose-level').onclick = function () { var p = payload(); p.scope = 'level'; call('propose', p); };
  $('sched-kind').onchange = renderSchedule; $('sched-level').onchange = renderSchedule; $('sched-refresh').onclick = requestSchedule; $('sched-copy').onclick = copySchedule;
  $('propose-all').onclick = function () { var p = payload(); p.scope = 'all'; call('propose', p); };
  $('run-check').onclick = function () { call('check', payload()); };
  $('build-all-level').onclick = function () { call('build_all', {state: payload(), levels: [state.level]}); };
  $('build-all-levels').onclick = function () { call('build_all', {state: payload(), levels: state.levels.map(function (l) { return l.id; })}); };
  $('add-opening-type').onclick = addOpeningType;
  $('opening-level-select').onchange = function () { state.level = $('opening-level-select').value; state.selected = null; state.selectedBeam = null; state.selectedWall = null; state.openWall = null; renderColumnsTab(); renderBeamsTab(); renderWallsTab(); renderOpeningsTab(); CELL_TABS.forEach(function (x) { renderCellTab(x); }); changed(); };
  $('add-door').onclick = function () { addOpening('door'); };
  $('add-window').onclick = function () { addOpening('window'); };
  $('opening-copy-picks').onclick = function () { var q = payload(); q.from = $('opening-copy-from').value; q.to = state.level; q.kind = 'openings'; call('picks_copy', q); };
  $('build-openings').onclick = function () { call('openings_build', {state: payload(), levels: [state.level]}); };
  $('build-all-openings').onclick = function () {
    var ids = state.levels.filter(function (l) { return !isTop(l) && Object.keys(l.openingPicks).length; }).map(function (l) { return l.id; });
    call('openings_build', {state: payload(), levels: ids});
  };
  $('remove-openings').onclick = function () { call('openings_remove', {level: state.level}); };
  $('build').onclick = function () { call('grid_build', payload()); };
  $('remove').onclick = function () { call('grid_remove'); };
  $('reset').onclick = function () { call('grid_reset'); };
  if (window.VGDTheme) window.VGDTheme.start({key: 'vgd.structure.theme', button: $('theme')});
  window.addEventListener('load', function () { call('ready'); });
})();
