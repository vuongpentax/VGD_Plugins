// Tab Mặt bằng: vẽ mặt bằng tầng đang chọn lên canvas (kéo / cuộn để xem). Chỉ hiển thị kết quả xem trước do Ruby tính, chưa sửa dữ liệu
// (cột mốc P1; vẽ và sửa ở các cột mốc sau). Tọa độ thế giới là mm, Y hướng lên; màn hình lật trục Y.
(function () {
  'use strict';
  // Màu theo bộ tag mẫu của VGD BIM.
  var COLORS = {column: '#66DD00', beam: '#00AABA', wall: '#FF9966', slab: '#BA3300', ceiling: '#9900FF', door: '#FF7766', window: '#CCBAED', grid: '#BA00CC'};
  var LAYERS = [['grid', 'Lưới trục'], ['slab', 'Sàn'], ['ceiling', 'Trần'], ['beam', 'Dầm'], ['wall', 'Tường'], ['opening', 'Cửa'], ['column', 'Cột'], ['note', 'Ghi chú và nét 2D']];
  // Biểu tượng tự vẽ (nét 24 × 24). Bố cục theo cửa sổ mặt bằng của VTBim: thanh trên (chọn, sửa), cột công cụ bên trái, tab theo tầng, bảng thuộc tính, thanh trạng thái.
  var ICON = {
    hide: 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12ZM3 3l18 18', isolate: 'M12 2l9 5v10l-9 5-9-5V7ZM12 8v8M8 12h8',
    select: 'M5 2v17l4-5 4 7 3-2-4-6 6-1Z', pan: 'M8 12V5a1.5 1.5 0 0 1 3 0v6M11 11V3.5a1.5 1.5 0 0 1 3 0V11M14 11V5a1.5 1.5 0 0 1 3 0v8c0 5-2 8-6 8-3 0-4-2-6-5l-2-4a1.5 1.5 0 0 1 3-1l2 3V8a1.5 1.5 0 0 1 3 0',
    guide: 'M2 16h20v5H2ZM6 16v3M10 16v2M14 16v3M18 16v2M3 3l18 9', measure: 'M3 12h18M3 8v8M21 8v8M7 12v-2M11 12v-3M15 12v-2',
    move: 'M12 1v22M1 12h22M8 5l4-4 4 4M8 19l4 4 4-4M5 8l-4 4 4 4M19 8l4 4-4 4', rotate: 'M4 8a9 9 0 1 1-1 9M4 2v6h6', mirror: 'M12 2v22M9 6L3 18h6ZM15 6l6 12h-6Z',
    offset: 'M4 21V7h14M8 21V11h10', trim: 'M6 3a3 3 0 1 0 0 6 3 3 0 0 0 0-6ZM6 15a3 3 0 1 0 0 6 3 3 0 0 0 0-6ZM8.5 7.5L21 18M8.5 16.5L21 6',
    eraser: 'M3 17l9-9 7 7-5 5H6ZM8 12l7 7M3 22h18', delete: 'M4 6h16M9 6V3h6v3M6 6l1 15h10l1-15M10 10v8M14 10v8',
    grid: 'M3 8h18M3 16h18M8 3v18M16 3v18', column: 'M9 2h6v20H9Z', beam: 'M2 9h20v6H2Z', wall: 'M3 6l18-4v15L3 22Z', slab: 'M2 13l10-6 10 5-11 7Z',
    ceiling: 'M2 6h20M2 16h20M6 6v10M12 6v10M18 6v10', door: 'M7 3l11-2v21H7ZM10 12h1', window: 'M4 4l16-2v18L4 22ZM12 3v18M4 12l16-2',
    line: 'M4 20L20 4', polyline: 'M3 18l6-10 5 7 7-11', rect: 'M3 6h18v12H3Z', circle: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18Z', arc: 'M4 18a10 10 0 0 1 16 0',
    dim: 'M3 8v8M21 8v8M3 12h18M6 10l-3 2 3 2M18 10l3 2-3 2', text: 'M5 5h14M12 5v14M9 19h6', level: 'M12 3l5 8h-10ZM4 18h16M4 21h16',
    copy: 'M3 3h11v11H3ZM8 8h13v13H8', keys: 'M2 6h20v12H2ZM6 10h1M10 10h1M14 10h1M18 10h1M7 14h10',
    unlock: 'M7 11V8a5 5 0 0 1 9-3M5 11h14v10H5ZM12 15v3',
    array: 'M3 3h6v6H3ZM15 3h6v6h-6ZM3 15h6v6H3ZM15 15h6v6h-6Z', match: 'M14 4l6 6M12 6l6 6M17 3a2.8 2.8 0 0 1 4 4l-3 3M15 9L6 18l-3 1 1-3 9-9', align: 'M4 3v18M8 7h12M8 13h8M8 19h10',
    undo: 'M9 14L4 9l5-5M4 9h11a5 5 0 0 1 0 10h-3', redo: 'M15 14l5-5-5-5M20 9H9a5 5 0 0 0 0 10h3', fit: 'M3 8V3h5M16 3h5v5M21 16v5h-5M8 21H3v-5M14 14l3 3M15 11a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
    snap: 'M6 3v8a6 6 0 0 0 12 0V3M6 7h4M14 7h4', guideclr: 'M3 3l18 9M6 16l12 5M15 3l6 6M21 3l-6 6',
    tree: 'M4 4h6v4H4ZM14 10h6v4h-6ZM14 16h6v4h-6ZM7 8v10h7M7 12h7',
    link: 'M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1',
    status: 'M12 3l9 4v6c0 5-4 8-9 9-5-1-9-4-9-9V7ZM8 12l3 3 5-6',
    build: 'M3 21h18M5 21V10l7-6 7 6v11M10 21v-6h4v6',
    supick: 'M4 3v15l4-4 3 7 3-1-3-7 6-1ZM17 3v4M15 5h4', sudraw: 'M4 3v15l4-4 3 7 3-1-3-7 6-1ZM14 14l7-7 2 2-7 7-3 1Z',
    props: 'M3 4h18v16H3ZM9 4v16M12 8h6M12 12h6M12 16h4', eye: 'M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12ZM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6'
  };
  // [id, tên, phím, gợi ý, dùng được ở cột mốc này?]
  var TOP_GROUPS = [
    ['Chọn & đo', [['select', 'Chọn', '', 'Chọn (Modify): bấm = chọn một, Ctrl + bấm = thêm, Shift + bấm = bớt, kéo trái→phải = khung trong (nét liền xanh), phải→trái = khung cắt (nét đứt xanh lá), Tab = chuyển giữa các phần tử chồng nhau, Ctrl+A = chọn tất cả, Esc = hủy / bỏ chọn', 1],
      ['pan', 'Kéo', '', 'Kéo mặt bằng. Chuột giữa luôn kéo được', 1],
      ['guide', 'Đường gióng (Reference Plane)', '', 'Đường gióng: bấm một nét rồi bấm điểm = gióng song song qua điểm đó (gõ khoảng cách + Enter); bấm điểm đầu mút / giao điểm rồi điểm thứ hai = gióng qua hai điểm. Esc hủy', 1],
      ['measure', 'Đo (Measure)', '', 'Đo: bấm hai điểm, hiện khoảng cách, Δx, Δy, góc (Shift = khóa ngang / dọc; gõ số + Enter = đo theo độ dài)', 1]]],
    ['Sửa', [['move', 'Move (chọn phần tử trước, bấm điểm gốc rồi điểm đích; hai giao điểm lưới thì dịch theo ô)', ''], ['copy', 'Copy (chọn phần tử trước, bấm điểm gốc rồi điểm đích)', ''], ['array', 'Array (nhân bản liên tiếp theo bước đã bấm)', ''], ['rotate', 'Rotate (chọn phần tử trước, bấm tâm xoay; góc 90 / 180 / 270 ở thanh tùy chọn)', ''], ['mirror', 'Mirror (chọn phần tử trước, bấm một trục hoặc đường gióng làm trục đối xứng)', ''], ['offset', 'Offset (chọn dầm / tường trước, bấm phía cần dời; khoảng cách ở thanh tùy chọn hoặc gõ số + Enter)', ''], ['trim', 'Trim (nối góc L: bấm tường 1 rồi tường 2, đúng phần muốn giữ)', ''], ['align', 'Align (bấm đường chuẩn rồi các phần tử cần căn)', ''], ['match', 'Match (bấm phần tử mẫu rồi các phần tử cùng loại)', ''], ['unlock', 'Mở khóa lưới (đổi cột, dầm, tường theo lưới thành phần tử tự do)', ''], ['delete', 'Xóa', '']]]
  ];
  var SIDE_GROUPS = [
    ['Thiết kế', [['grid', 'Lưới trục', ''], ['column', 'Cột', ''], ['beam', 'Dầm', ''], ['wall', 'Tường', ''], ['slab', 'Sàn', ''], ['ceiling', 'Trần', ''], ['door', 'Cửa đi', ''], ['window', 'Cửa sổ', '']]],
    ['Vẽ 2D', [['line', 'Line', ''], ['polyline', 'Polyline', ''], ['rect', 'Chữ nhật', ''], ['circle', 'Đường tròn', ''], ['arc', 'Cung', '']]],
    ['Ghi chú', [['dim', 'Kích thước', ''], ['text', 'Chữ', ''], ['level', 'Cốt cao độ', '']]]
  ];
  // Bảng phím tắt kiểu Revit: gõ liên tiếp các chữ (không giữ phím), ví dụ WA = Tường. [id, tên lệnh, phím mặc định, nguồn]
  // Nguồn "Revit" = phím mặc định của Revit theo trí nhớ (chưa đối chiếu với bản Revit cài trên máy); "Tự đặt" = Revit không có phím mặc định cho lệnh này. Sửa được trong bảng Phím tắt.
  var COMMANDS = [
    ['fit', 'Vừa khung (Zoom to Fit)', 'ZE', 'Revit'], ['hide', 'Ẩn phần tử đang chọn (Hide Element)', 'EH', 'Revit'], ['isolate', 'Cô lập phần tử đang chọn (Isolate Element)', 'HI', 'Revit'], ['unhide', 'Bỏ ẩn / cô lập (Reset Temporary Hide/Isolate)', 'HR', 'Revit'], ['pan', 'Kéo mặt bằng', '', ''], ['guide', 'Đường gióng (Reference Plane)', 'RP', 'Revit'], ['measure', 'Đo (Measure)', 'ME', 'Revit'],
    ['snap', 'Bật / tắt bắt điểm (Snaps Off)', 'SO', 'Revit'], ['props', 'Bảng Thuộc tính', 'PP', 'Revit'], ['browser', 'Cây dự án (Project Browser)', 'PB', 'Tự đặt'], ['sudraw', 'Vẽ trong SketchUp (công cụ vẽ nhận điểm bấm trong SketchUp, tự dựng)', 'SD', 'Tự đặt'], ['sync', 'Đồng bộ chọn với SketchUp', 'SY', 'Tự đặt'], ['status', 'Hiện trạng thái so với model', 'ST', 'Tự đặt'], ['build', 'Dựng tầng này vào model', 'BD', 'Tự đặt'], ['supick', 'Chọn điểm trong SketchUp', 'PK', 'Tự đặt'], ['vis', 'Hiển thị lớp (Visibility / Graphics)', 'VG', 'Revit'], ['keys', 'Bảng phím tắt', 'KS', 'Revit'],
    ['wall', 'Tường (Wall)', 'WA', 'Revit'], ['door', 'Cửa đi (Door)', 'DR', 'Revit'], ['window', 'Cửa sổ (Window)', 'WN', 'Revit'], ['column', 'Cột (Column)', 'CL', 'Revit'], ['beam', 'Dầm (Beam)', 'BM', 'Revit'],
    ['grid', 'Lưới trục (Grid)', 'GR', 'Revit'], ['slab', 'Sàn (Floor)', 'FL', 'Tự đặt'], ['ceiling', 'Trần (Ceiling)', 'CE', 'Tự đặt'],
    ['move', 'Move', 'MV', 'Revit'], ['copy', 'Copy', 'CO', 'Revit'], ['array', 'Array (nhân bản liên tiếp)', 'AR', 'Revit'], ['match', 'Match (khớp loại)', 'MA', 'Revit'], ['align', 'Align', 'AL', 'Revit'], ['unlock', 'Mở khóa lưới (thành phần tử tự do)', 'UL', 'Tự đặt'], ['rotate', 'Rotate', 'RO', 'Revit'], ['mirror', 'Mirror (chọn trục)', 'MM', 'Revit'], ['offset', 'Offset', 'OF', 'Revit'], ['trim', 'Trim / Extend', 'TR', 'Revit'], ['delete', 'Xóa (Delete)', 'DE', 'Revit'],
    ['line', 'Line', 'LI', 'Revit'], ['polyline', 'Polyline', 'PL', 'Tự đặt'], ['rect', 'Chữ nhật', 'RC', 'Tự đặt'], ['circle', 'Đường tròn', 'CC', 'Tự đặt'], ['arc', 'Cung', 'AC', 'Tự đặt'],
    ['dim', 'Kích thước (Dimension)', 'DI', 'Revit'], ['text', 'Chữ (Text)', 'TX', 'Revit'], ['level', 'Cốt cao độ (Spot Elevation)', 'EL', 'Revit']
  ];
  var KEYS_STORE = 'vgd_structure_plan_keys', CHORD_MS = 900;
  var MIN_SCALE = 0.001, MAX_SCALE = 5; // px trên mm
  var opts, root, canvas, ctx, status = {}, levelList = [], currentId = null, selection = [], propsOpen = true;
  var badgesDrawn = 0, syncOn = true, statusOn = true, suPicking = false, lastSent = '', lastFromSU = false, modelStatus = null, pendingSelect = null, pendingDim = null, edit = null, notes = null, modify = null, lastDims = [], dimHits = [], dimInput = null, selLevel = null, opts2 = null, hoverCount = 0, keymap = {}, chord = '', chordTimer = null, tabIdx = 0, hoverSig = '', guides = {}, measure = null, draft = null, snap = null, snapOn = true, note = '', press = null, box = null, shiftKey = false;
  var SNAP_PX = 10, DRAG_PX = 4, LIVE_EDIT = ['grid', 'column', 'beam', 'wall', 'slab', 'ceiling', 'door', 'window', 'delete', 'move', 'copy', 'array', 'mirror', 'match', 'offset', 'align', 'trim', 'rotate', 'unlock', 'line', 'polyline', 'rect', 'circle', 'arc', 'dim', 'text', 'level'];
  var view = {cx: 0, cy: 0, s: 0.05}, data = null, boundsKey = '', fitted = false, tool = 'select', shapes = [], hover = null, cursor = null, drag = null;
  var visible = {grid: true, slab: true, ceiling: false, beam: true, wall: true, opening: true, column: true, note: true};
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
    var live = !!t[4] || LIVE_EDIT.indexOf(t[0]) >= 0, b = el('button', {type: 'button', class: 'pv-ic' + (extra || ''), 'data-tool': t[0], 'aria-label': t[1], title: live ? (t[3] || t[1]) : t[1] + ' — có ở cột mốc sau, chưa dùng được'}, parent);
    b.innerHTML = svg(t[0]); el('kbd', {}, b); b.setAttribute('data-title', b.title);
    if (live) b.onclick = function () { if (t[0] === 'delete') deleteSelection(); else setTool(t[0]); }; else b.disabled = true;
    return b;
  }
  function buildTop(bar) {
    [['undo', 'Hoàn tác (Ctrl+Z): chỉ các thay đổi làm trên tab Mặt bằng'], ['redo', 'Làm lại (Ctrl+Y)']].forEach(function (u) {
      var b = el('button', {type: 'button', class: 'pv-ic', id: 'pv-' + u[0], 'aria-label': u[1], title: u[1]}, bar); b.innerHTML = svg(u[0]); b.disabled = true;
      b.onclick = function () { (u[0] === 'undo' ? opts.undo : opts.redo)(); };
    });
    TOP_GROUPS.forEach(function (g) {
      el('span', {class: 'pv-sep'}, bar);
      var box = el('span', {class: 'pv-grp', role: 'group', 'aria-label': g[0], title: g[0]}, bar);
      g[1].forEach(function (t) { iconButton(box, t); });
    });
    el('span', {class: 'pv-sep'}, bar);
    var sn = el('button', {type: 'button', class: 'pv-ic on', id: 'pv-snap', title: 'Bắt điểm: đầu mút, trung điểm, giao điểm, trên cạnh (bật / tắt)', 'aria-pressed': 'true'}, bar); sn.innerHTML = svg('snap');
    sn.onclick = function () { snapOn = !snapOn; sn.classList.toggle('on', snapOn); sn.setAttribute('aria-pressed', String(snapOn)); snap = null; draw(); };
    var gc = el('button', {type: 'button', class: 'pv-ic', id: 'pv-guide-clear', title: 'Xóa mọi đường gióng của tầng này'}, bar); gc.innerHTML = svg('guideclr');
    gc.onclick = function () { guides[currentId] = []; draft = null; note = 'Đã xóa đường gióng của tầng này.'; draw(); };
    el('span', {class: 'pv-sep'}, bar);
    function toggle(id, icon, title, get, set) {
      var b = el('button', {type: 'button', class: 'pv-ic' + (get() ? ' on' : ''), id: id, title: title, 'aria-pressed': String(get())}, bar); b.innerHTML = svg(icon) + '<kbd></kbd>';
      b.onclick = function () { set(!get()); b.classList.toggle('on', get()); b.setAttribute('aria-pressed', String(get())); };
      return b;
    }
    toggle('pv-sync-btn', 'link', 'Đồng bộ chọn với SketchUp: chọn trên mặt bằng thì chọn trong SketchUp và ngược lại', function () { return syncOn; }, function (v) { syncOn = v; lastSent = ''; if (v) notifySelection(); });
    toggle('pv-status-btn', 'status', 'Hiện trạng thái so với model (chấm màu: lệch, thiếu, chưa dựng)', function () { return statusOn; }, function (v) { statusOn = v; if (v && opts.refresh) opts.refresh(); draw(); renderProps(); });
    var bd = el('button', {type: 'button', class: 'pv-ic', id: 'pv-build-btn', title: 'Dựng tầng này vào model (một bước hoàn tác)'}, bar); bd.innerHTML = svg('build') + '<kbd></kbd>'; bd.onclick = function () { if (opts.buildLevel) opts.buildLevel(); };
    var sp = el('button', {type: 'button', class: 'pv-ic', id: 'pv-supick-btn', title: 'Chọn điểm trong SketchUp: dùng điểm bắt của SketchUp cho công cụ đang chọn', 'aria-pressed': 'false'}, bar); sp.innerHTML = svg('supick') + '<kbd></kbd>'; sp.onclick = toggleSuPick;
    var sd = el('button', {type: 'button', class: 'pv-ic', id: 'pv-sudraw-btn', title: 'Vẽ trong SketchUp: công cụ vẽ nhận điểm bấm trong khung nhìn SketchUp, mỗi lần vẽ xong tự dựng vào model', 'aria-pressed': 'false'}, bar); sd.innerHTML = svg('sudraw') + '<kbd></kbd>'; sd.onclick = function () { setSuDraw(!suDraw); };
    var se = el('button', {type: 'button', class: 'pv-ic on', id: 'pv-suedit-btn', title: 'Đồng bộ sửa từ SketchUp: dời, xoay, xóa phần tử đã dựng trong SketchUp thì dữ liệu tự cập nhật theo (đang bật)', 'aria-pressed': 'true'}, bar); se.textContent = '\u21C4';
    se.onclick = function () { var on = se.getAttribute('aria-pressed') !== 'true'; se.setAttribute('aria-pressed', String(on)); se.classList.toggle('on', on); se.title = 'Đồng bộ sửa từ SketchUp: dời, xoay, xóa phần tử đã dựng trong SketchUp thì dữ liệu tự cập nhật theo (' + (on ? 'đang bật' : 'đang tắt') + ')'; if (opts.callSU) opts.callSU('su_sync_edit', on); };
    el('span', {class: 'pv-grow'}, bar);
    [['pv-hide-btn', 'hide', 'Ẩn phần tử đang chọn (tạm thời)'], ['pv-isolate-btn', 'isolate', 'Cô lập phần tử đang chọn: ẩn mọi phần tử khác (tạm thời)']].forEach(function (x) {
      var hb = el('button', {type: 'button', class: 'pv-ic', id: x[0], title: x[2]}, bar); hb.innerHTML = svg(x[1]) + '<kbd></kbd>'; hb.onclick = function () { runCommand(x[1]); };
    });
    var chip = el('span', {id: 'pv-hidden', class: 'pv-opt-note', hidden: ''}, bar); el('span', {}, chip); var un = el('button', {type: 'button', id: 'pv-unhide-btn', title: 'Bỏ ẩn / cô lập, hiện lại mọi phần tử'}, chip); un.textContent = 'Bỏ ẩn'; un.onclick = resetHidden;
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
    var fit = el('button', {type: 'button', class: 'pv-ic', id: 'pv-fit', title: 'Vừa khung'}, bar); fit.innerHTML = svg('fit') + '<kbd></kbd>'; fit.onclick = fitView;
    var kb = el('button', {type: 'button', class: 'pv-ic', id: 'pv-keys-btn', title: 'Bảng phím tắt'}, bar); kb.innerHTML = svg('keys') + '<kbd></kbd>'; kb.onclick = toggleKeys;
    var pb = el('button', {type: 'button', class: 'pv-ic on', id: 'pv-browser-btn', title: 'Cây dự án: ẩn / hiện', 'aria-pressed': 'true'}, bar); pb.innerHTML = svg('tree') + '<kbd></kbd>';
    pb.onclick = function () { var on = $('pv-browser').hidden; $('pv-browser').hidden = !on; pb.classList.toggle('on', on); pb.setAttribute('aria-pressed', String(on)); resize(); };
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
    if (opts && opts.browser) opts.browser.highlight(visibleSelection().map(function (x) { return currentId + '|' + x.kind + '|' + x.ref; }));
    var sel = visibleSelection(), shape = sel.length === 1 ? sel[0] : (!sel.length && hover && vis(hover) ? hover : null), rows, title;
    if (sel.length > 1) {
      var by = {}; sel.forEach(function (x) { by[x.layer] = (by[x.layer] || 0) + 1; });
      title = 'Đã chọn ' + sel.length + ' phần tử'; rows = LAYERS.filter(function (l) { return by[l[0]]; }).map(function (l) { return [l[1], String(by[l[0]])]; });
    } else if (shape) { title = shape.title; rows = shape.rows; }
    else {
      var lv = levelList.filter(function (l) { return l.id === currentId; })[0];
      title = lv ? lv.name : 'Mặt bằng';
      rows = lv ? [['Cao độ sàn hoàn thiện', lv.elevation + ' mm'], ['Cán nền', lv.screed + ' mm'], ['Mặt sàn kết cấu', Math.round((lv.elevation - lv.screed) * 10) / 10 + ' mm'], ['Dày sàn', lv.slab + ' mm']] : [];
      var counts = {}; shapes.forEach(function (x) { counts[x.layer] = (counts[x.layer] || 0) + 1; });
      LAYERS.forEach(function (l) { if (l[0] !== 'grid') rows.push([l[1], String(counts[l[0]] || 0)]); });
    }
    if (statusOn && modelStatus && modelStatus.level === currentId) {
      if (sel.length === 1) { var stt = statusKey(sel[0]); if (stt) rows = rows.concat([['Trạng thái model', STATUS_TEXT[stt]]]); }
      else if (!shape && !sel.length) { var cn = modelStatus.counts || {}; rows = rows.concat([['Model: khớp', String(cn.ok || 0)], ['Model: lệch', String(cn.stale || 0)], ['Model: thiếu', String(cn.missing || 0)], ['Model: chưa dựng', String(cn.unbuilt || 0)], ['Model: thừa', String(cn.extra || 0)]]); }
    }
    el('h3', {text: 'Thuộc tính'}, box); el('p', {class: 'pv-ptitle', text: title}, box);
    var t = el('table', {class: 'pv-ptable'}, box);
    rows.forEach(function (r) { var tr = el('tr', {}, t); el('th', {text: r[0]}, tr); el('td', {text: r[1]}, tr); });
    if (sel.length === 1 && edit) {
      var fields = edit.propsFor(sel[0]);
      if (fields.length) {
        el('h3', {text: 'Sửa', class: 'pv-edit-h'}, box);
        fields.forEach(function (f) {
          if (f.kind === 'heading') { el('h3', {text: f.label, class: 'pv-edit-h'}, box); return; }
          if (f.kind === 'info') { el('p', {text: f.label, class: 'pv-ptitle'}, box); return; }
          var lab = el('label', {class: 'pv-field'}, box); el('span', {text: f.label}, lab); var c;
          if (f.kind === 'select') { c = el('select', {'data-field': f.id}, lab); f.values.forEach(function (v) { c.append(new Option(v[1], v[0])); }); c.value = f.value; c.onchange = function () { f.apply(c.value); }; }
          else if (f.kind === 'text') { c = el('input', {type: 'text', maxlength: '200', 'data-field': f.id}, lab); c.value = f.value; c.onchange = function () { f.apply(c.value); }; }
          else if (f.kind === 'number') { c = el('input', {type: 'number', step: 'any', 'data-field': f.id}, lab); c.value = f.value; c.onchange = function () { if (c.value !== '') f.apply(Number(c.value)); }; }
          else { c = el('input', {type: 'checkbox', 'data-field': f.id}, lab); c.checked = !!f.value; c.onchange = function () { f.apply(c.checked); }; }
        });
      }
    }
    if (!shape) {
      var issues = []; ['columns', 'beams', 'walls', 'openings', 'slabs', 'ceilings'].forEach(function (k) { if (data && data[k] && data[k].issues) issues = issues.concat(data[k].issues); });
      if (issues.length) { el('h3', {text: 'Cảnh báo (' + issues.length + ')', class: 'pv-edit-h'}, box); var ul = el('ul', {class: 'pv-issues'}, box); issues.slice(0, 8).forEach(function (m) { el('li', {text: m}, ul); }); }
    }
  }
  // ---- Thanh tùy chọn (Options Bar): hiện khi chọn công cụ vẽ ----
  var NOTES = {grid: '', column: 'Bấm vào một giao điểm của lưới.', slab: 'Bấm vào một ô của lưới.', ceiling: 'Bấm vào một ô của lưới.', move: 'Bấm điểm gốc rồi điểm đích.', copy: 'Bấm điểm gốc rồi điểm đích.', match: 'Bấm phần tử mẫu rồi các phần tử cùng loại.', align: 'Bấm đường chuẩn rồi các phần tử cần căn.', trim: 'Bấm tường / dầm 1 rồi 2, đúng phần muốn giữ.'};
  var TOOL_NAMES = {offset: 'Offset', align: 'Align', trim: 'Trim', rotate: 'Rotate', unlock: 'Mở khóa lưới', move: 'Move', copy: 'Copy', array: 'Array', mirror: 'Mirror', match: 'Match', grid: 'Lưới trục', column: 'Cột', beam: 'Dầm', wall: 'Tường', slab: 'Sàn', ceiling: 'Trần', door: 'Cửa đi', window: 'Cửa sổ'};
  function renderOptions() {
    var bar = $('pv-options'); if (!bar) return; bar.replaceChildren();
    var h = ed(); if (!h) { bar.hidden = true; return; }
    bar.hidden = false; el('b', {text: TOOL_NAMES[tool] || tool}, bar);
    h.options(tool).forEach(function (o) {
      var lab = el('label', {}, bar); el('span', {text: o.label}, lab); var c;
      if (o.kind === 'number') { c = el('input', {type: 'number', 'data-opt': o.id, min: String(o.min), max: String(o.max), step: '1', 'aria-label': o.label}, lab); c.value = o.value; c.onchange = function () { h.setOption(tool, o.id, c.value); renderOptions(); }; }
      else if (o.kind === 'checkbox') { c = el('input', {type: 'checkbox', 'data-opt': o.id, 'aria-label': o.label}, lab); c.checked = !!o.value; c.onchange = function () { h.setOption(tool, o.id, c.checked); canvas.focus(); }; }
      else { c = el('select', {'data-opt': o.id, 'aria-label': o.label}, lab); o.values.forEach(function (v) { c.append(new Option(v[1], v[0])); }); c.value = o.value; c.onchange = function () { h.setOption(tool, o.id, c.value); renderOptions(); canvas.focus(); }; }
    });
    if (!h.options(tool).length) el('span', {class: 'pv-opt-note', text: NOTES[tool] || ''}, bar);
  }
  function deleteSelection() {
    if (!edit) return;
    var n = edit.remove(visibleSelection()); selection = []; notifySelection();
    note = n ? 'Đã xóa ' + n + ' phần tử khỏi lựa chọn của tầng (dựng lại để cập nhật model).' : 'Chưa chọn phần tử nào để xóa.';
    renderProps(); draw();
  }
  function refreshHistory() {
    var h = opts && opts.history ? opts.history() : {undo: 0, redo: 0}, u = $('pv-undo'), r = $('pv-redo');
    if (u) u.disabled = !h.undo; if (r) r.disabled = !h.redo;
  }
  // Bộ công cụ đang xử lý công cụ hiện hành: vẽ kết cấu (plan_edit), sửa (plan_modify) hoặc không có.
  function ed() { return edit && edit.handles(tool) ? edit : (modify && modify.handles(tool) ? modify : null); }
  // Chọn các hình có (kind, ref) trong danh sách; trả về số hình chọn được, báo nếu thiếu (phần tử chưa có trong xem trước, ví dụ lỗi dữ liệu).
  function applyKeys(keys) {
    var want = {}; keys.forEach(function (k) { want[k.kind + '|' + k.ref] = true; });
    selLevel = currentId; selection = shapes.filter(function (x) { return want[x.kind + '|' + x.ref] && vis(x); });
    note = selection.length === keys.length ? '' : (selection.length ? 'Chọn được ' + selection.length + '/' + keys.length + ' phần tử (số còn lại không có trong xem trước hoặc đang ẩn).' : 'Phần tử không có trong xem trước của tầng này (có thể đang ẩn lớp hoặc bị bỏ do lỗi dữ liệu).');
    return selection.length;
  }
  // ---- Liên kết với SketchUp (P6) ----
  // Gửi vùng chọn của mặt bằng cho SketchUp (chỉ khi người dùng chọn trên mặt bằng, không gửi lại khi vùng chọn do chính SketchUp đẩy sang).
  function notifySelection() {
    if (!syncOn || !opts || !opts.callSU) return;
    var items = visibleSelection().filter(function (x) { return x.kind !== 'note'; }).map(function (x) { return {kind: x.kind, ref: x.ref}; }), key = currentId + '|' + JSON.stringify(items);
    if (key === lastSent) return; lastSent = key; lastFromSU = false;
    opts.callSU('plan_select', {level: currentId, items: items});
  }
  // ---- Vẽ trực tiếp trong SketchUp: khi bật, công cụ vẽ / sửa (hoặc Đo, Đường gióng) tự nhận điểm bấm trong khung nhìn SketchUp ----
  var suDraw = false, lastGhostKey = '', ghostTimer = null, lastGhostAt = 0, GHOST_MS = 60;
  function wantsSuTool() { return !!ed() || tool === 'measure' || tool === 'guide'; }
  function syncSuTool() {
    if (!suDraw || !opts || !opts.callSU) return;
    var want = wantsSuTool();
    if (want && !suPicking) opts.callSU('su_pick_start', ''); else if (!want && suPicking) opts.callSU('su_pick_stop', '');
  }
  function setSuDraw(on) {
    suDraw = !!on; var b = $('pv-sudraw-btn'); if (b) { b.classList.toggle('on', suDraw); b.setAttribute('aria-pressed', String(suDraw)); }
    if (suDraw) { note = 'Vẽ trong SketchUp: chọn công cụ vẽ rồi bấm trong khung nhìn SketchUp; mỗi lần vẽ xong tự dựng vào model.'; syncSuTool(); }
    else { if (suPicking && opts && opts.callSU) opts.callSU('su_pick_stop', ''); sendGhost(true); }
    draw();
  }
  // Xem trước đang hiện trên mặt bằng cũng được vẽ trong khung nhìn SketchUp (đường, đa giác, chấm) ở cao độ tầng đang xem.
  function sendGhost(force) {
    if (!suPicking && !force) return;
    if (!opts || !opts.callSU) return;
    var items = [];
    if (suPicking && ed()) ed().ghost().forEach(function (g) {
      if (g.t === 'line') items.push({t: 'line', pts: [g.a, g.b]});
      else if (g.t === 'poly') items.push({t: 'poly', pts: g.poly});
      else if (g.t === 'dot') items.push({t: 'dot', pts: [g.p]});
    });
    var lv = levelList.filter(function (l) { return l.id === currentId; })[0], payloadG = {z: lv ? lv.elevation : 0, items: items}, key = JSON.stringify(payloadG);
    if (key === lastGhostKey) return; lastGhostKey = key; opts.callSU('su_ghost', payloadG);
  }
  function scheduleGhost() {
    if (!suPicking) return;
    var now = Date.now();
    if (now - lastGhostAt >= GHOST_MS) { lastGhostAt = now; sendGhost(); return; }
    if (!ghostTimer) ghostTimer = setTimeout(function () { ghostTimer = null; lastGhostAt = Date.now(); sendGhost(); }, GHOST_MS);
  }
  function toggleSuPick() {
    if (!opts || !opts.callSU) return;
    if (suPicking) { opts.callSU('su_pick_stop', ''); return; }
    if (!ed() && tool !== 'measure' && tool !== 'guide') note = 'Hãy chọn một công cụ vẽ hoặc sửa (hoặc Đo, Đường gióng) rồi bấm "Chọn điểm trong SketchUp".';
    opts.callSU('su_pick_start', '');
  }
  function statusKey(shape) { return modelStatus && modelStatus.level === currentId ? modelStatus.items[shape.kind + '|' + shape.ref] : undefined; }
  var STATUS_TEXT = {ok: 'Đã dựng, khớp dữ liệu', stale: 'Lệch dữ liệu (cần dựng lại)', missing: 'Thiếu trong model (cần dựng)', unbuilt: 'Chưa dựng'};
  function badgeCounts() { var c = {stale: 0, missing: 0, unbuilt: 0}; if (statusOn) shapes.forEach(function (x) { var k = statusKey(x); if (k && c[k] !== undefined) c[k]++; }); return c; }
  // Phần tử tương ứng của cú bấm do SketchUp gửi sang: dùng như một lần bấm / rê trên mặt bằng ở đúng tọa độ đó.
  function injectClick(w) {
    if (!suPicking) return; cursor = w; snap = null;
    if (ed()) { ed().move(w); ed().click(w); }
    else if (tool === 'measure') { if (!measure || measure.done) measure = {a: w, b: null, done: false}; else { measure.b = constrain(measure.a, w); measure.done = true; } }
    else if (tool === 'guide') guideClick(w);
    else { note = 'Hãy chọn một công cụ vẽ hoặc sửa trước khi bấm điểm trong SketchUp.'; }
    draw(); renderProps();
  }
  function injectMove(w) { if (!suPicking) return; cursor = w; if (ed()) ed().move(w); draw(); }
  // Ẩn / cô lập tạm thời (Hide / Isolate của Revit): chỉ ảnh hưởng hiển thị, chọn, bắt điểm của tầng đang xem; không đổi dữ liệu, không vào hoàn tác, đổi tầng thì bỏ.
  var hiddenKeys = {}, hiddenCount = 0, hiddenMode = '';
  function hid(kind, ref) { return !!hiddenKeys[kind + '|' + ref]; }
  function vis(sh) { return visible[sh.layer] && !hiddenKeys[sh.kind + '|' + sh.ref]; }
  function setHidden(list, mode) {
    list.forEach(function (x) { hiddenKeys[x.kind + '|' + x.ref] = true; }); hiddenCount = Object.keys(hiddenKeys).length; hiddenMode = mode;
    selection = selection.filter(vis); hover = null; refreshHiddenBar(); draw(); renderProps(); notifySelection();
  }
  function hideSelection() { var sel = visibleSelection(); if (!sel.length) { note = 'Hãy chọn phần tử cần ẩn trước.'; draw(); return; } setHidden(sel, hiddenMode || 'hide'); }
  function isolateSelection() {
    var sel = visibleSelection(); if (!sel.length) { note = 'Hãy chọn phần tử cần cô lập trước.'; draw(); return; }
    var keep = {}; sel.forEach(function (x) { keep[x.kind + '|' + x.ref] = true; });
    hiddenKeys = {}; setHidden(shapes.filter(function (x) { return !keep[x.kind + '|' + x.ref]; }), 'isolate');
  }
  function resetHidden() { hiddenKeys = {}; hiddenCount = 0; hiddenMode = ''; refreshHiddenBar(); hover = null; draw(); renderProps(); }
  function refreshHiddenBar() {
    var b = $('pv-hidden'); if (!b) return; b.hidden = !hiddenCount;
    b.querySelector('span').textContent = (hiddenMode === 'isolate' ? 'Đang cô lập: ẩn ' : 'Đang ẩn tạm thời ') + hiddenCount + ' phần tử';
  }
  function visibleSelection() { return selection.filter(function (x) { return vis(x); }); }
  function setTool(t) {
    var keepNote = '';
    if (modify && modify.handles(t) && t !== 'match') { // lệnh sửa cần chọn phần tử trước
      modify.activate(t, visibleSelection());
      if (!modify.active()) { keepNote = modify.hint(); t = 'select'; }
    } else if (modify) modify.activate(t, []);
    tool = t; draft = null; note = keepNote; if (t !== 'measure') measure = null; press = null; box = null; snap = null; closeDimInput();
    if (edit) edit.activate(t);
    if (modify && modify.handles(t)) { var sel = visibleSelection(); if (t !== 'match') modify.activate(t, sel); }
    root.querySelectorAll('.pv-ic[data-tool]').forEach(function (b) { var on = b.getAttribute('data-tool') === t; b.classList.toggle('on', on); b.setAttribute('aria-pressed', String(on)); });
    renderOptions(); draw(); syncSuTool();
    canvas.style.cursor = t === 'pan' ? 'grab' : (t === 'select' ? 'default' : 'crosshair');
  }

  // ---- Phím tắt kiểu Revit ----
  function defaultKeymap() { var m = {}; COMMANDS.forEach(function (c) { m[c[0]] = c[2]; }); return m; }
  function validKey(k) { return typeof k === 'string' && /^[A-Z]{0,3}$/.test(k); }
  function owner(key, except) { var o = null; COMMANDS.forEach(function (c) { if (key && c[0] !== except && keymap[c[0]] === key) o = c; }); return o; }
  function prefixOf(key, except) { // lệnh khác có phím trùng đầu với `key` (một phím là phần đầu của phím kia)
    var o = null; COMMANDS.forEach(function (c) { var k = keymap[c[0]]; if (key && k && c[0] !== except && k !== key && (k.indexOf(key) === 0 || key.indexOf(k) === 0)) o = c; }); return o;
  }
  function loadKeys() {
    keymap = defaultKeymap();
    try {
      var saved = JSON.parse(localStorage.getItem(KEYS_STORE) || '{}'), seen = {}, next = Object.assign({}, keymap);
      Object.keys(saved).forEach(function (id) { if (id in next && validKey(saved[id])) next[id] = saved[id]; });
      Object.keys(next).forEach(function (id) { if (next[id]) seen[next[id]] = (seen[next[id]] || 0) + 1; });
      if (Object.keys(seen).every(function (k) { return seen[k] === 1; })) keymap = next; // bảng lưu bị hỏng (trùng phím): dùng mặc định
    } catch (x) { /* không có localStorage: dùng phím mặc định */ }
  }
  function saveKeys() { try { localStorage.setItem(KEYS_STORE, JSON.stringify(keymap)); } catch (x) { /* không lưu được: chỉ giữ trong phiên này */ } }
  function keyOf(id) { return keymap[id] || ''; }
  function refreshBadges() {
    root.querySelectorAll('.pv-ic[data-tool]').forEach(function (b) {
      var k = keyOf(b.getAttribute('data-tool')), kbd = b.querySelector('kbd'); if (kbd) kbd.textContent = k; b.title = b.getAttribute('data-title') + (k ? ' (' + k + ')' : '');
    });
    [['pv-hide-btn', 'hide', 'Ẩn phần tử đang chọn (tạm thời)'], ['pv-isolate-btn', 'isolate', 'Cô lập phần tử đang chọn (tạm thời)'], ['pv-sudraw-btn', 'sudraw', 'Vẽ trong SketchUp'], ['pv-sync-btn', 'sync', 'Đồng bộ chọn với SketchUp'], ['pv-status-btn', 'status', 'Hiện trạng thái so với model'], ['pv-build-btn', 'build', 'Dựng tầng này vào model (một bước hoàn tác)'], ['pv-supick-btn', 'supick', 'Chọn điểm trong SketchUp'], ['pv-browser-btn', 'browser', 'Cây dự án: ẩn / hiện'], ['pv-fit', 'fit', 'Vừa khung'], ['pv-snap', 'snap', 'Bắt điểm (bật / tắt)'], ['pv-props-btn', 'props', 'Thuộc tính: ẩn / hiện bảng bên trái'], ['pv-layers-btn', 'vis', 'Hiển thị: bật / tắt từng lớp'], ['pv-keys-btn', 'keys', 'Bảng phím tắt']].forEach(function (x) {
      var b = $(x[0]); if (!b) return; var k = keyOf(x[1]), kbd = b.querySelector('kbd'); if (kbd) kbd.textContent = k; b.title = x[2] + (k ? ' (' + k + ')' : '');
    });
  }
  function runCommand(id) {
    var c = COMMANDS.filter(function (x) { return x[0] === id; })[0]; if (!c) return;
    if (id === 'fit') fitView(); else if (id === 'snap') $('pv-snap').click(); else if (id === 'props') $('pv-props-btn').click(); else if (id === 'sudraw') $('pv-sudraw-btn').click(); else if (id === 'sync') $('pv-sync-btn').click(); else if (id === 'status') $('pv-status-btn').click(); else if (id === 'build') $('pv-build-btn').click(); else if (id === 'supick') $('pv-supick-btn').click(); else if (id === 'browser') $('pv-browser-btn').click(); else if (id === 'keys') toggleKeys();
    else if (id === 'vis') { var m = $('pv-layers'); if (m.hidden) $('pv-layers-btn').click(); else m.hidden = true; }
    else if (id === 'hide') hideSelection(); else if (id === 'isolate') isolateSelection(); else if (id === 'unhide') resetHidden();
    else if (id === 'delete') deleteSelection();
    else {
      var b = root.querySelector('.pv-ic[data-tool="' + id + '"]');
      if (b && !b.disabled) setTool(id); else { note = c[1] + (keyOf(id) ? ' (' + keyOf(id) + ')' : '') + ': làm ở cột mốc sau, chưa dùng được.'; draw(); }
    }
  }
  function resetChord() { chord = ''; clearTimeout(chordTimer); }
  function commandForKey(k) { var o = null; COMMANDS.forEach(function (c) { if (k && keymap[c[0]] === k) o = c[0]; }); return o; }
  // Gõ liên tiếp các chữ: khớp đúng một phím và không còn phím nào dài hơn bắt đầu bằng nó thì chạy ngay; còn có thể dài hơn thì chờ thêm chữ (CHORD_MS).
  function onLetter(ch) {
    clearTimeout(chordTimer);
    var before = chord.length; chord += ch;
    var exact = commandForKey(chord), longer = COMMANDS.some(function (c) { var k = keymap[c[0]]; return k && k.length > chord.length && k.indexOf(chord) === 0; });
    if (exact && !longer) { resetChord(); note = ''; runCommand(exact); draw(); return; }
    if (longer) { note = 'Phím tắt: ' + chord + '…'; draw(); chordTimer = setTimeout(function () { var ex = commandForKey(chord); resetChord(); note = ''; if (ex) runCommand(ex); draw(); }, CHORD_MS); return; }
    resetChord(); note = '';
    if (before > 0) onLetter(ch); else draw(); // chữ đầu không thuộc phím nào: bỏ qua
  }
  function toggleKeys() {
    var d = $('pv-keys'); d.hidden = !d.hidden; resetChord();
    if (!d.hidden) { var first = d.querySelector('input'); if (first) first.focus(); } else canvas.focus();
  }
  function buildKeys() {
    var box = $('pv-keys'); if (box) box.remove();
    box = el('div', {id: 'pv-keys', class: 'pv-keys', role: 'dialog', 'aria-label': 'Phím tắt', hidden: ''}, root);
    var head = el('div', {class: 'pv-keys-head'}, box); el('h3', {text: 'Phím tắt (kiểu Revit)'}, head);
    var close = el('button', {type: 'button', 'aria-label': 'Đóng'}, head); close.textContent = '×'; close.onclick = toggleKeys;
    el('p', {class: 'pv-keys-note', text: 'Gõ liên tiếp các chữ, không giữ phím: ví dụ WA = Tường. Phím lưu theo máy này. Nguồn "Revit" là phím mặc định của Revit theo trí nhớ, chưa đối chiếu với Revit cài trên máy: nếu sai thì sửa ở đây. Chữ A–Z, tối đa 3 chữ, không trùng nhau.'}, box);
    var table = el('table', {class: 'pv-keys-table'}, box);
    COMMANDS.forEach(function (c) {
      var tr = el('tr', {}, table); el('td', {text: c[1]}, tr);
      var cell = el('td', {}, tr), inp = el('input', {type: 'text', maxlength: '3', class: 'pv-key', 'data-cmd': c[0], 'aria-label': 'Phím tắt ' + c[1], spellcheck: 'false', autocomplete: 'off'}, cell);
      inp.value = keyOf(c[0]); var msg = el('span', {class: 'pv-key-msg'}, cell);
      el('td', {text: c[3] || '—', class: 'pv-key-src'}, tr);
      inp.oninput = function () {
        var v = inp.value.toUpperCase().replace(/[^A-Z]/g, ''); inp.value = v; msg.className = 'pv-key-msg'; msg.textContent = ''; inp.classList.remove('bad');
        var dup = owner(v, c[0]);
        if (dup) { inp.classList.add('bad'); msg.className = 'pv-key-msg bad'; msg.textContent = 'Trùng với “' + dup[1] + '”, chưa áp dụng'; return; }
        keymap[c[0]] = v; saveKeys(); refreshBadges();
        var pre = prefixOf(v, c[0]); if (pre) { msg.className = 'pv-key-msg warn'; msg.textContent = 'Trùng đầu với ' + keyOf(pre[0]) + ' (' + pre[1] + '): phải chờ thêm một chút'; }
      };
      inp.onkeydown = function (e) { if (e.key === 'Escape') { toggleKeys(); e.preventDefault(); } e.stopPropagation(); };
    });
    var foot = el('div', {class: 'pv-keys-foot'}, box), reset = el('button', {type: 'button', id: 'pv-keys-reset'}, foot); reset.textContent = 'Đặt lại mặc định';
    reset.onclick = function () { keymap = defaultKeymap(); saveKeys(); refreshBadges(); box.querySelectorAll('input.pv-key').forEach(function (i) { i.value = keyOf(i.getAttribute('data-cmd')); i.classList.remove('bad'); i.nextSibling.textContent = ''; }); };
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
    var cur = null;
    function add(layer, poly, title, rows, text) { shapes.push({layer: layer, kind: layer, ref: cur.ref, poly: poly, holes: cur.holes && cur.holes.length ? cur.holes : null, title: title, rows: rows, text: text}); }
    function ring(i) { return i.placement === 'free' ? [['Số đỉnh', String(i.polygon.length)], ['Số lỗ', String((i.holes || []).length)]] : []; }
    section('slabs').forEach(function (i) { cur = i; add('slab', i.polygon || rectPoly(i.min, i.max), (i.placement === 'free' ? 'Sàn đa giác ' : 'Sàn ') + i.ref, [['Dày', mm(i.thickness)], ['Mặt trên', mm(i.z_top)], ['Diện tích', i.area + ' m²']].concat(ring(i)), 'Sàn ' + i.ref + ' · dày ' + i.thickness + ' mm · ' + i.area + ' m²'); });
    section('ceilings').forEach(function (i) { cur = i; add('ceiling', i.polygon, (i.placement === 'free' ? 'Trần đa giác ' : 'Trần ') + i.ref, [['Dày', mm(i.thickness)], ['Mặt dưới', mm(i.z_bottom)], ['Diện tích', i.area + ' m²']].concat(ring(i)), 'Trần ' + i.ref + ' · ' + i.area + ' m²'); });
    section('beams').forEach(function (i) { cur = i; add('beam', i.poly || rectPoly(i.min, i.max), (i.placement === 'free' ? 'Dầm tự do ' : 'Dầm ') + i.ref, [['Loại', i.type_name], ['Rộng × cao', i.w + ' × ' + i.h + ' mm'], ['Dài', mm(i.length)], ['Đỉnh', mm(i.z_top)]].concat(i.dir === 'o' ? [['Góc', Math.round(i.angle * 100) / 100 + '°']] : []), 'Dầm ' + i.ref + ' · ' + i.type_name + ' · dài ' + i.length + ' mm'); });
    section('walls').forEach(function (i) { cur = i; add('wall', i.poly || rectPoly(i.min, i.max), (i.placement === 'free' ? 'Tường tự do ' : 'Tường ') + i.ref, [['Loại', i.type_name], ['Dày', mm(i.t)], ['Dài', mm(i.length)], ['Cao', mm(i.height)], ['Số cửa', String((i.openings || []).length)], ['Nối góc', i.join === false ? 'Tắt' : ((i.joined || []).length ? 'Đã nối ' + i.joined.length + ' đầu' : 'Không có chỗ nối')]].concat(i.dir === 'o' ? [['Góc', Math.round(i.angle * 100) / 100 + '°']] : []), 'Tường ' + i.ref + ' · ' + i.type_name + ' · dày ' + i.t + ' · dài ' + i.length + ' · cao ' + i.height + ' mm'); });
    section('openings').forEach(function (i) { var k = i.kind === 'door' ? 'Cửa đi' : 'Cửa sổ'; cur = i; add('opening', i.poly || rectPoly(i.min, i.max), k + ' ' + i.type_name, [['Loại', k], ['Rộng × cao', i.w + ' × ' + i.h + ' mm'], ['Cao ngưỡng', mm(i.sill)], ['Tường', i.wall]], k + ' ' + i.type_name + ' · ' + i.w + ' × ' + i.h + ' mm · ngưỡng ' + i.sill); });
    section('columns').forEach(function (i) { cur = i; add('column', i.poly || rectPoly([i.center[0] - i.w / 2, i.center[1] - i.d / 2], [i.center[0] + i.w / 2, i.center[1] + i.d / 2]), (i.placement === 'free' ? 'Cột tự do ' : 'Cột ') + i.ref, [['Loại', i.type_name], ['Rộng × sâu', i.w + ' × ' + i.d + ' mm'], ['Tâm', Math.round(i.center[0]) + ', ' + Math.round(i.center[1])]].concat(i.rot ? [['Xoay', Math.round(i.rot * 100) / 100 + '°']] : []), 'Cột ' + i.ref + ' · ' + i.type_name + ' · ' + i.w + ' × ' + i.d + ' mm'); });
    addNoteShapes();
  }
  function addNoteShapes() { if (notes) shapes = shapes.concat(notes.shapes()); } // ghi chú, nét 2D của tầng đang xem (dữ liệu, không qua xem trước của Ruby)
  function inside(poly, x, y) {
    var c = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      var a = poly[i], b = poly[j];
      if ((a[1] > y) !== (b[1] > y) && x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]) c = !c;
    }
    return c;
  }
  // Mọi phần tử đang hiện chứa điểm (x, y), trên cùng trước. Tab chuyển giữa các phần tử chồng nhau (như Revit).
  function pickAll(x, y) {
    var out = [];
    for (var i = shapes.length - 1; i >= 0; i--) { var s = shapes[i]; if (vis(s) && (s.hit ? s.hit(x, y, 6 / view.s) : inside(s.poly, x, y)) && !(s.holes && s.holes.some(function (h) { return inside(h, x, y); }))) out.push(s); }
    return out;
  }
  function pickAt(x, y) {
    var list = pickAll(x, y), sig = list.map(function (v) { return v.title; }).join('|');
    if (sig !== hoverSig) { hoverSig = sig; tabIdx = 0; }
    hoverCount = list.length;
    return list.length ? list[tabIdx % list.length] : null;
  }

  function bboxOf(poly) {
    var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    poly.forEach(function (p) { x0 = Math.min(x0, p[0]); y0 = Math.min(y0, p[1]); x1 = Math.max(x1, p[0]); y1 = Math.max(y1, p[1]); });
    return [x0, y0, x1, y1];
  }
  function segsCross(a, b, c, d) {
    function o(p, q, r) { return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0]); }
    var d1 = o(a, b, c), d2 = o(a, b, d), d3 = o(c, d, a), d4 = o(c, d, b);
    return ((d1 > 0) !== (d2 > 0)) && ((d3 > 0) !== (d4 > 0));
  }
  // Khung kéo [x0, y0, x1, y1] (thế giới): "trong" = cả hình nằm trong khung; "cắt" = hình chạm khung (đỉnh trong khung, khung trong hình, hoặc cạnh cắt cạnh).
  function inWindow(poly, r) { var b = bboxOf(poly); return b[0] >= r[0] && b[1] >= r[1] && b[2] <= r[2] && b[3] <= r[3]; }
  function crossesRect(poly, r) {
    var b = bboxOf(poly); if (b[2] < r[0] || b[0] > r[2] || b[3] < r[1] || b[1] > r[3]) return false;
    var rect = rectPoly([r[0], r[1]], [r[2], r[3]]);
    if (poly.some(function (p) { return p[0] >= r[0] && p[0] <= r[2] && p[1] >= r[1] && p[1] <= r[3]; })) return true;
    if (rect.some(function (p) { return inside(poly, p[0], p[1]); })) return true;
    for (var i = 0; i < poly.length; i++) for (var j = 0; j < 4; j++) if (segsCross(poly[i], poly[(i + 1) % poly.length], rect[j], rect[(j + 1) % 4])) return true;
    return false;
  }

  // ---- Bắt điểm ----
  function levelGuides() { return guides[currentId] || (guides[currentId] = []); }
  function axisLines() { return visible.grid && data && data.ok ? data.axes.map(function (a) { var d = unit([a.line[1][0] - a.line[0][0], a.line[1][1] - a.line[0][1]]); return {p: a.line[0], d: d, kind: 'axis', name: a.name}; }) : []; }
  function unit(v) { var l = Math.hypot(v[0], v[1]) || 1; return [v[0] / l, v[1] / l]; }
  function lineHit(a, b) { // giao hai đường thẳng vô hạn {p, d}; null nếu song song
    var cr = a.d[0] * b.d[1] - a.d[1] * b.d[0]; if (Math.abs(cr) < 1e-9) return null;
    var t = ((b.p[0] - a.p[0]) * b.d[1] - (b.p[1] - a.p[1]) * b.d[0]) / cr;
    return [a.p[0] + a.d[0] * t, a.p[1] + a.d[1] * t];
  }
  function nearOnSegment(p, a, b) {
    var dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy, t = l2 ? Math.max(0, Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2)) : 0;
    return [a[0] + dx * t, a[1] + dy * t];
  }
  function nearOnLine(p, l) { var t = (p[0] - l.p[0]) * l.d[0] + (p[1] - l.p[1]) * l.d[1]; return [l.p[0] + l.d[0] * t, l.p[1] + l.d[1] * t]; }
  // Điểm bắt gần (wx, wy) trong 10 px màn hình. Thứ tự ưu tiên: đầu mút, giao điểm, trung điểm, trên cạnh / trục / đường gióng.
  function snapAt(wx, wy) {
    if (!data || !data.ok) return null;
    var tol = SNAP_PX / view.s, best = null, here = [wx, wy];
    function cand(pt, rank, text, line) {
      var d = Math.hypot(pt[0] - wx, pt[1] - wy); if (d > tol) return;
      if (!best || rank < best.rank || (rank === best.rank && d < best.d)) best = {p: pt, rank: rank, d: d, text: text, line: line || null};
    }
    shapes.forEach(function (s) {
      if (!vis(s)) return;
      if (s.snaps) { // ghi chú, nét 2D: điểm bắt và cạnh do chính hình khai báo
        s.snaps.forEach(function (q) { cand(q.p, q.rank, q.text); });
        (s.edges || []).forEach(function (e) { if (Math.hypot(e[1][0] - e[0][0], e[1][1] - e[0][1]) > 1e-6) cand(nearOnSegment(here, e[0], e[1]), 3, 'Trên cạnh', {p: e[0], d: unit([e[1][0] - e[0][0], e[1][1] - e[0][1]])}); });
        return;
      }
      var bb = bboxOf(s.poly);
      if (s.layer !== 'slab' && s.layer !== 'ceiling') cand([(bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2], 2, 'Tâm'); // tâm cột, dầm, tường, cửa (như SC của Revit)
      [s.poly].concat(s.holes || []).forEach(function (ringPts) { // đường bao và lỗ của sàn / trần đa giác
        var n = ringPts.length;
        for (var i = 0; i < n; i++) {
          var a = ringPts[i], b = ringPts[(i + 1) % n];
          cand(a, 0, 'Đầu mút');
          cand([(a[0] + b[0]) / 2, (a[1] + b[1]) / 2], 2, 'Trung điểm');
          if (Math.hypot(b[0] - a[0], b[1] - a[1]) > 1e-6) cand(nearOnSegment(here, a, b), 3, 'Trên cạnh', {p: a, d: unit([b[0] - a[0], b[1] - a[1]])});
        }
      });
    });
    var lines = axisLines().concat(levelGuides().map(function (g) { return {p: g.p, d: g.d, kind: 'guide'}; }));
    for (var i = 0; i < lines.length; i++) {
      cand(nearOnLine(here, lines[i]), 3, lines[i].kind === 'axis' ? 'Trên trục ' + lines[i].name : 'Trên đường gióng', lines[i]);
      for (var j = i + 1; j < lines.length; j++) { var h = lineHit(lines[i], lines[j]); if (h) cand(h, 1, 'Giao điểm'); }
    }
    return best;
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
  function fillStroke(poly, color, alpha, dash, width, holes) {
    path(poly); (holes || []).forEach(function (h) { h.forEach(function (p, i) { var q = toScreen(p[0], p[1]); if (i) ctx.lineTo(q[0], q[1]); else ctx.moveTo(q[0], q[1]); }); ctx.closePath(); }); // lỗ là vòng con, tô theo quy tắc chẵn lẻ
    ctx.globalAlpha = alpha; ctx.fillStyle = color; if (alpha > 0) ctx.fill('evenodd'); ctx.globalAlpha = 1;
    ctx.setLineDash(dash || []); ctx.lineWidth = width || 1; ctx.strokeStyle = color; ctx.stroke(); ctx.setLineDash([]);
  }
  function draw() {
    if (!ctx) return;
    ctx.setTransform(size.dpr, 0, 0, size.dpr, 0, 0);
    var bg = css('--vgd-surface', '#fff'), ink = css('--vgd-text', '#222'), muted = css('--vgd-muted', '#777');
    ctx.fillStyle = bg; ctx.fillRect(0, 0, size.w, size.h);
    if (!data || !data.ok) { ctx.fillStyle = muted; ctx.font = '13px sans-serif'; ctx.textAlign = 'center'; ctx.fillText((data && data.error) || 'Chưa có lưới trục hợp lệ.', size.w / 2, size.h / 2); updateStatus(); return; }
    if (visible.slab) section('slabs').forEach(function (i) { if (hid('slab', i.ref)) return; fillStroke(i.polygon || rectPoly(i.min, i.max), COLORS.slab, 0.12, null, 1, i.holes); });
    if (visible.ceiling) section('ceilings').forEach(function (i) { if (hid('ceiling', i.ref)) return; fillStroke(i.polygon, COLORS.ceiling, 0.08, [5, 4], 1, i.holes); });
    if (visible.beam) section('beams').forEach(function (i) { if (hid('beam', i.ref)) return; fillStroke(i.poly || rectPoly(i.min, i.max), COLORS.beam, 0.25, [6, 3], 1); });
    if (visible.wall) section('walls').forEach(function (i) { if (hid('wall', i.ref)) return; fillStroke(i.poly || rectPoly(i.min, i.max), COLORS.wall, 0.8, null, 1); });
    if (visible.opening) section('openings').forEach(function (i) { if (!hid('opening', i.ref)) drawOpening(i, bg); });
    if (visible.column) section('columns').forEach(function (i) { if (hid('column', i.ref)) return; fillStroke(i.poly || rectPoly([i.center[0] - i.w / 2, i.center[1] - i.d / 2], [i.center[0] + i.w / 2, i.center[1] + i.d / 2]), COLORS.column, 0.9, null, 1.5); });
    if (visible.grid) drawGrid(ink);
    if (visible.note && notes) notes.draw({ctx: ctx, toScreen: toScreen, scale: view.s, hidden: function (id) { return hid('note', id); }});
    if (hover && vis(hover)) { path(hover.poly); ctx.lineWidth = 2; ctx.strokeStyle = css('--vgd-accent', '#1e88e5'); ctx.stroke(); }
    visibleSelection().forEach(function (x) { path(x.poly); ctx.lineWidth = 3; ctx.setLineDash([6, 3]); ctx.strokeStyle = css('--vgd-accent', '#1e88e5'); ctx.stroke(); ctx.setLineDash([]); });
    drawBadges();
    drawOverlay(bg, ink);
    drawDims(bg, ink);
    updateStatus();
    scheduleGhost();
  }
  var GUIDE_COLOR = '#00A6D6', MEASURE_COLOR = '#E5484D';
  function screenLine(l) { var r = Math.hypot(size.w, size.h) / view.s * 1.5, a = toScreen(l.p[0] - l.d[0] * r, l.p[1] - l.d[1] * r), b = toScreen(l.p[0] + l.d[0] * r, l.p[1] + l.d[1] * r); return [a, b]; }
  function strokeLine(l, color, dash) { var q = screenLine(l); ctx.beginPath(); ctx.moveTo(q[0][0], q[0][1]); ctx.lineTo(q[1][0], q[1][1]); ctx.lineWidth = 1; ctx.strokeStyle = color; ctx.setLineDash(dash || []); ctx.stroke(); ctx.setLineDash([]); }
  function tag(text, x, y, bg, ink, color) {
    ctx.font = '12px sans-serif'; var w = ctx.measureText(text).width + 8;
    ctx.fillStyle = bg; ctx.globalAlpha = 0.92; ctx.fillRect(x, y - 9, w, 18); ctx.globalAlpha = 1; ctx.strokeStyle = color; ctx.lineWidth = 1; ctx.strokeRect(x + 0.5, y - 8.5, w - 1, 17);
    ctx.fillStyle = ink; ctx.textAlign = 'left'; ctx.textBaseline = 'middle'; ctx.fillText(text, x + 4, y);
  }
  function measureBox(a, b) { var dx = b[0] - a[0], dy = b[1] - a[1], ang = (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360; return {len: Math.hypot(dx, dy), dx: dx, dy: dy, angle: ang}; }
  function measureText(m) { return Math.round(m.len) + ' mm  (Δx ' + Math.round(m.dx) + ', Δy ' + Math.round(m.dy) + ', góc ' + (Math.round(m.angle * 10) / 10) + '°)'; }
  function drawOverlay(bg, ink) {
    levelGuides().forEach(function (g) { strokeLine(g, GUIDE_COLOR, [6, 4]); });
    if (ed()) ed().ghost().forEach(function (g) {
      ctx.save(); ctx.globalAlpha = g.alpha || 1; ctx.strokeStyle = g.color; ctx.fillStyle = g.color; ctx.lineWidth = g.width || 1.5; ctx.setLineDash(g.dash || []);
      if (g.t === 'poly') { path(g.poly); ctx.fill(); ctx.globalAlpha = 1; ctx.stroke(); }
      else if (g.t === 'line') { var a = toScreen(g.a[0], g.a[1]), b = toScreen(g.b[0], g.b[1]); ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke(); }
      else if (g.t === 'dot') { var c0 = toScreen(g.p[0], g.p[1]); ctx.beginPath(); ctx.arc(c0[0], c0[1], g.r || 4, 0, Math.PI * 2); ctx.fill(); }
      ctx.restore();
      if (g.t === 'text') { var q = toScreen(g.p[0], g.p[1]); tag(g.text, q[0] + 10, q[1] - 14, bg, ink, g.color || GUIDE_COLOR); }
    });
    // đường gióng đang đặt
    var cur = snap ? snap.p : cursor;
    if (draft && cur) {
      if (draft.ref) { var nrm = [-draft.ref.d[1], draft.ref.d[0]]; strokeLine({p: draft.ref.p, d: draft.ref.d}, GUIDE_COLOR, [2, 3]); strokeLine({p: cur, d: draft.ref.d}, GUIDE_COLOR, [6, 4]); }
      else if (draft.first && Math.hypot(cur[0] - draft.first[0], cur[1] - draft.first[1]) > 1e-6) strokeLine({p: draft.first, d: unit([cur[0] - draft.first[0], cur[1] - draft.first[1]])}, GUIDE_COLOR, [6, 4]);
    }
    if (measure) {
      var a = measure.a, b = measure.b || (cur ? constrain(a, cur) : null);
      var sa = toScreen(a[0], a[1]); ctx.fillStyle = MEASURE_COLOR; ctx.beginPath(); ctx.arc(sa[0], sa[1], 3.5, 0, Math.PI * 2); ctx.fill();
      if (b) {
        var sb = toScreen(b[0], b[1]); ctx.beginPath(); ctx.moveTo(sa[0], sa[1]); ctx.lineTo(sb[0], sb[1]); ctx.lineWidth = 1.5; ctx.strokeStyle = MEASURE_COLOR; ctx.stroke();
        ctx.beginPath(); ctx.arc(sb[0], sb[1], 3.5, 0, Math.PI * 2); ctx.fill();
        tag(Math.round(measureBox(a, b).len) + ' mm', (sa[0] + sb[0]) / 2 + 6, (sa[1] + sb[1]) / 2 - 12, bg, ink, MEASURE_COLOR);
      }
    }
    if (box) {
      var x = Math.min(box.x0, box.x1), y = Math.min(box.y0, box.y1), w = Math.abs(box.x1 - box.x0), h = Math.abs(box.y1 - box.y0), win = box.x1 >= box.x0, col = win ? '#2F7BFF' : '#1FA84F';
      ctx.globalAlpha = 0.12; ctx.fillStyle = col; ctx.fillRect(x, y, w, h); ctx.globalAlpha = 1; ctx.setLineDash(win ? [] : [6, 4]); ctx.lineWidth = 1; ctx.strokeStyle = col; ctx.strokeRect(x + 0.5, y + 0.5, w, h); ctx.setLineDash([]);
    }
    if (snap && snapOn && usesSnap()) {
      var c = toScreen(snap.p[0], snap.p[1]); ctx.lineWidth = 1.8; ctx.strokeStyle = snap.rank === 0 ? '#1FA84F' : snap.rank === 1 ? '#E5484D' : snap.rank === 2 ? '#F5A524' : '#2F7BFF';
      ctx.beginPath();
      if (snap.rank === 0) ctx.rect(c[0] - 5, c[1] - 5, 10, 10);
      else if (snap.rank === 1) { ctx.moveTo(c[0] - 5, c[1] - 5); ctx.lineTo(c[0] + 5, c[1] + 5); ctx.moveTo(c[0] + 5, c[1] - 5); ctx.lineTo(c[0] - 5, c[1] + 5); }
      else if (snap.rank === 2) { ctx.moveTo(c[0], c[1] - 6); ctx.lineTo(c[0] + 6, c[1] + 5); ctx.lineTo(c[0] - 6, c[1] + 5); ctx.closePath(); }
      else ctx.arc(c[0], c[1], 4, 0, Math.PI * 2);
      ctx.stroke(); tag(snap.text, c[0] + 10, c[1] + 16, bg, ink, ctx.strokeStyle);
    }
  }
  // Kích thước tạm thời (Temporary Dimensions): hiện khi chọn đúng MỘT phần tử ở công cụ Chọn; số có viền xanh bấm vào để gõ giá trị mới (chỉ cửa).
  function drawDims(bg, ink) {
    dimHits = []; lastDims = []; var sel = visibleSelection();
    if (tool !== 'select' || sel.length !== 1 || !modify) return;
    lastDims = modify.tempDims(sel[0]); lastDims.forEach(function (d) {
      var a = toScreen(d.a[0], d.a[1]), b = toScreen(d.b[0], d.b[1]), f = toScreen(d.from[0], d.from[1]), t = toScreen(d.to[0], d.to[1]), color = d.editable ? '#2F7BFF' : '#8A93A0';
      ctx.save(); ctx.strokeStyle = color; ctx.lineWidth = 1; ctx.beginPath();
      ctx.moveTo(f[0], f[1]); ctx.lineTo(a[0], a[1]); ctx.moveTo(t[0], t[1]); ctx.lineTo(b[0], b[1]); ctx.setLineDash([2, 3]); ctx.stroke(); ctx.setLineDash([]); // dây gióng
      ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke();
      [a, b].forEach(function (q) { ctx.beginPath(); ctx.moveTo(q[0] - 3, q[1] + 3); ctx.lineTo(q[0] + 3, q[1] - 3); ctx.lineWidth = 1.6; ctx.stroke(); });
      ctx.restore();
      if (Math.hypot(b[0] - a[0], b[1] - a[1]) < 14) return; // quá ngắn trên màn hình: không đủ chỗ cho số
      var text = String(d.value), mx = (a[0] + b[0]) / 2, my = (a[1] + b[1]) / 2;
      ctx.font = '12px sans-serif'; var w = ctx.measureText(text).width + 10, x = mx - w / 2, y = my - 9;
      ctx.fillStyle = bg; ctx.globalAlpha = 0.95; ctx.fillRect(x, y, w, 18); ctx.globalAlpha = 1; ctx.strokeStyle = color; ctx.lineWidth = d.editable ? 1.5 : 1; ctx.strokeRect(x + 0.5, y + 0.5, w - 1, 17);
      ctx.fillStyle = ink; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(text, mx, my);
      if (d.editable) dimHits.push({x: x, y: y, w: w, h: 18, dim: d});
    });
  }
  function closeDimInput() { if (dimInput) { dimInput.remove(); dimInput = null; } }
  // Ô nhập chữ ngay trên mặt bằng (UI::HtmlDialog không có prompt()): Enter xác nhận, Esc hoặc rời ô thì hủy (done(null)).
  function promptText(w, initial, done) { if (pointerDown) pendingPrompt = {w: w, initial: initial, done: done}; else openPrompt(w, initial, done); }
  function openPrompt(w, initial, done) {
    closeDimInput();
    var q = toScreen(w[0], w[1]), inp = document.createElement('input'), over = false;
    inp.type = 'text'; inp.className = 'pv-dim-input'; inp.value = initial || ''; inp.maxLength = 200; inp.setAttribute('aria-label', 'Nội dung chữ');
    inp.style.left = Math.max(0, q[0]) + 'px'; inp.style.top = Math.max(0, q[1] - 12) + 'px'; inp.style.width = '180px';
    function end(v) { if (over) return; over = true; closeDimInput(); canvas.focus(); done(v); draw(); renderProps(); }
    inp.onkeydown = function (e) { if (e.key === 'Enter') { end(inp.value); e.preventDefault(); } else if (e.key === 'Escape') { end(null); e.preventDefault(); } e.stopPropagation(); };
    inp.onblur = function () { setTimeout(function () { end(null); }, 0); };
    canvas.parentNode.appendChild(inp); dimInput = inp; inp.focus();
  }
  function openDimInput(hit) {
    closeDimInput();
    var box2 = canvas.parentNode, inp = document.createElement('input');
    inp.type = 'text'; inp.className = 'pv-dim-input'; inp.value = String(hit.dim.value); inp.setAttribute('aria-label', 'Giá trị kích thước (mm)');
    inp.style.left = Math.max(0, hit.x - 12) + 'px'; inp.style.top = (hit.y - 2) + 'px'; inp.style.width = Math.max(70, hit.w + 24) + 'px';
    inp.onkeydown = function (e) {
      if (e.key === 'Enter') { var err = modify.commitDim(hit.dim, inp.value); if (err) { note = err; inp.classList.add('bad'); draw(); } else { note = 'Đã đổi kích thước thành ' + inp.value + ' mm.'; closeDimInput(); canvas.focus(); renderProps(); draw(); } e.preventDefault(); }
      else if (e.key === 'Escape') { closeDimInput(); canvas.focus(); draw(); }
      e.stopPropagation();
    };
    inp.onblur = function () { setTimeout(closeDimInput, 0); };
    box2.appendChild(inp); dimInput = inp; inp.focus(); inp.select();
  }
  // Chấm trạng thái so với model: cam đặc = lệch dữ liệu, đỏ rỗng = thiếu trong model, xám rỗng = chưa dựng (phần tử "ok" không có chấm).
  function drawBadges() {
    badgesDrawn = 0;
    if (!statusOn || !modelStatus || modelStatus.level !== currentId) return;
    shapes.forEach(function (sh) {
      var st = statusKey(sh); if (!st || st === 'ok' || !vis(sh)) return;
      badgesDrawn++;
      var b = bboxOf(sh.poly), p = toScreen(b[2], b[3]), r = 4.5;
      ctx.beginPath(); ctx.arc(p[0] + 2, p[1] - 2, r, 0, Math.PI * 2);
      if (st === 'stale') { ctx.fillStyle = '#F5A524'; ctx.fill(); ctx.lineWidth = 1; ctx.strokeStyle = '#fff'; ctx.stroke(); }
      else { ctx.fillStyle = css('--vgd-surface', '#fff'); ctx.fill(); ctx.lineWidth = 1.8; ctx.strokeStyle = st === 'missing' ? '#E5484D' : '#8A93A0'; ctx.stroke(); }
    });
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
    var poly = i.poly || rectPoly(i.min, i.max), color = i.kind === 'door' ? COLORS.door : COLORS.window, oblique = i.dir === 'o', along = i.dir === 'x' ? 0 : 1, across = 1 - along;
    path(poly); ctx.fillStyle = bg; ctx.fill(); ctx.lineWidth = 1; ctx.strokeStyle = color; ctx.stroke();
    // Hệ tọa độ của cửa: (u, v) = dọc theo tường / vuông góc tường, gốc ở đầu cửa, tâm bề dày. Tường xiên: xoay theo góc tường; ngang / dọc: trục song song với trục thế giới.
    var rad = oblique ? i.angle * Math.PI / 180 : 0, cs = Math.cos(rad), sn = Math.sin(rad), a0 = oblique ? 0 : i.min[along], a1 = oblique ? i.w : i.max[along], mid = oblique ? 0 : (i.min[across] + i.max[across]) / 2;
    function pt(u, v) {
      if (oblique) return [i.origin[0] + u * cs - v * sn, i.origin[1] + u * sn + v * cs];
      var p = [0, 0]; p[along] = u; p[across] = v; return p;
    }
    function line(p, q, width) { var s = toScreen(p[0], p[1]), e = toScreen(q[0], q[1]); ctx.beginPath(); ctx.moveTo(s[0], s[1]); ctx.lineTo(e[0], e[1]); ctx.lineWidth = width; ctx.strokeStyle = color; ctx.stroke(); }
    if (i.kind === 'window') { line(pt(a0, mid), pt(a1, mid), 1.5); return; }
    var w = a1 - a0, dir = i.flip ? -1 : 1, hinge = pt(a0, mid), leaf = pt(a0, mid + dir * w);
    line(hinge, leaf, 2);
    ctx.beginPath();
    for (var k = 0; k <= 12; k++) { var t = k / 12 * Math.PI / 2, p = pt(a0 + w * Math.cos(t), mid + dir * w * Math.sin(t)), q = toScreen(p[0], p[1]); if (k) ctx.lineTo(q[0], q[1]); else ctx.moveTo(q[0], q[1]); }
    ctx.lineWidth = 1; ctx.strokeStyle = color; ctx.setLineDash([3, 3]); ctx.stroke(); ctx.setLineDash([]);
  }
  function usesSnap() { return tool === 'measure' || tool === 'guide' || tool === 'grid' || (edit && edit.handles(tool) && edit.freeMode && edit.freeMode(tool)) || (modify && modify.handles(tool) && ['move', 'copy', 'array', 'rotate'].indexOf(tool) >= 0); }
  function toolHint() {
    if (ed()) return ed().hint();
    if (tool === 'measure') {
      if (!measure || measure.done) return measure ? 'Đo: ' + measureText(measureBox(measure.a, measure.b)) + '. Bấm điểm mới để đo tiếp, Esc thoát.' : 'Đo: bấm điểm đầu (bắt điểm đang bật).';
      var cur = snap ? snap.p : cursor; return cur ? 'Đo: ' + measureText(measureBox(measure.a, constrain(measure.a, cur))) + '. Bấm điểm cuối hoặc gõ số + Enter.' : 'Đo: bấm điểm cuối.';
    }
    if (tool === 'guide') return !draft ? 'Đường gióng: bấm một nét (song song) hoặc bấm một điểm (gióng qua hai điểm).' : draft.ref ? 'Gióng song song: bấm điểm đi qua hoặc gõ khoảng cách + Enter. Esc hủy.' : 'Gióng qua hai điểm: bấm điểm thứ hai. Esc hủy.';
    return '';
  }
  function updateStatus() {
    var shown = snap && snapOn && usesSnap() ? snap.p : cursor, sel = visibleSelection();
    status.xy.textContent = shown ? 'X ' + Math.round(shown[0]) + '   Y ' + Math.round(shown[1]) + ' mm' : '';
    status.hint.textContent = (suPicking ? '[Đang nhận điểm từ SketchUp: bấm trong SketchUp, Esc để thôi] ' : '') + (note || toolHint()) || (hover ? hover.text + (hoverCount > 1 ? ' · Tab: đổi sang phần tử chồng (' + hoverCount + ')' : '') : sel.length === 1 ? sel[0].text : sel.length ? 'Đã chọn ' + sel.length + ' phần tử.' : (data && data.ok ? 'Bấm một phần tử để xem thuộc tính. Cuộn = thu phóng, chuột giữa = kéo' + (keyOf('fit') ? ', ' + keyOf('fit') + ' = vừa khung' : '') + (keyOf('keys') ? ', ' + keyOf('keys') + ' = bảng phím tắt' : '') + '.' : ''));
    status.zoom.textContent = '1 px = ' + (1 / view.s).toFixed(1) + ' mm';
  }

  // ---- Chuột và bàn phím ----
  function point(e) { var r = canvas.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; }
  function world(e) { var p = point(e); return toWorld(p[0], p[1]); }
  function pointer(e) { // điểm thế giới có bắt điểm (nếu công cụ cần và đang bật)
    var w = world(e); snap = usesSnap() && snapOn ? snapAt(w[0], w[1]) : null; return snap ? snap.p : w;
  }
  // Shift khóa hướng đo về ngang hoặc dọc.
  function constrain(a, b) { if (!shiftKey) return b; return Math.abs(b[0] - a[0]) >= Math.abs(b[1] - a[1]) ? [b[0], a[1]] : [a[0], b[1]]; }
  // Quy ước chọn của Revit: Ctrl + bấm / kéo = thêm, Shift + bấm / kéo = bớt, không phím = chọn lại.
  function selMode(e) { return e.ctrlKey || e.metaKey ? 'add' : e.shiftKey ? 'remove' : ''; }
  function applySel(hits, mode) {
    selLevel = currentId;
    if (mode === 'add') hits.forEach(function (x) { if (selection.indexOf(x) < 0) selection.push(x); });
    else if (mode === 'remove') selection = selection.filter(function (x) { return hits.indexOf(x) < 0; });
    else selection = hits.slice();
  }
  function selectAt(w, mode) {
    var hit = pickAt(w[0], w[1]);
    if (!hit) { if (!mode) selection = []; } else applySel([hit], mode);
  }
  function selectBox(b, mode) {
    var win = b.x1 >= b.x0, p0 = toWorld(Math.min(b.x0, b.x1), Math.max(b.y0, b.y1)), p1 = toWorld(Math.max(b.x0, b.x1), Math.min(b.y0, b.y1)), r = [p0[0], p0[1], p1[0], p1[1]];
    applySel(shapes.filter(function (x) { return vis(x) && (win ? inWindow(x.poly, r) : crossesRect(x.poly, r)); }), mode);
  }
  function guideClick(pt) {
    if (!draft) {
      if (snap && snap.line && snap.rank === 3) draft = {ref: {p: snap.line.p, d: snap.line.d}}; // bấm vào nét: song song với nét đó
      else draft = {first: pt};
      return;
    }
    if (draft.ref) addGuide(pt, draft.ref.d);
    else if (Math.hypot(pt[0] - draft.first[0], pt[1] - draft.first[1]) < 1e-6) { note = 'Hai điểm trùng nhau, hãy chọn điểm khác.'; return; }
    else addGuide(draft.first, unit([pt[0] - draft.first[0], pt[1] - draft.first[1]]));
  }
  function addGuide(p, d) { levelGuides().push({p: [p[0], p[1]], d: d}); draft = null; note = ''; }
  var pointerDown = false, pendingPrompt = null; // pendingPrompt: ô nhập chữ chờ nhả chuột mới mở (mở lúc nhấn thì trình duyệt lấy lại tiêu điểm)
  function onDown(e) {
    pointerDown = true; canvas.focus(); note = ''; shiftKey = e.shiftKey;
    if (e.button === 1 || (e.button === 0 && tool === 'pan')) { drag = {x: e.clientX, y: e.clientY, cx: view.cx, cy: view.cy}; canvas.setPointerCapture(e.pointerId); canvas.style.cursor = 'grabbing'; e.preventDefault(); return; }
    if (e.button !== 0) return;
    var pt = pointer(e);
    if (ed()) { ed().click(pt); draw(); renderProps(); return; }
    if (tool === 'select') { var sp = point(e); var dh = dimHits.filter(function (h) { return sp[0] >= h.x && sp[0] <= h.x + h.w && sp[1] >= h.y && sp[1] <= h.y + h.h; })[0]; if (dh) { pendingDim = dh; return; } press = {x: sp[0], y: sp[1], mode: selMode(e)}; canvas.setPointerCapture(e.pointerId); }
    else if (tool === 'measure') { if (!measure || measure.done) measure = {a: pt, b: null, done: false}; else { measure.b = constrain(measure.a, pt); measure.done = true; } }
    else if (tool === 'guide') guideClick(pt);
    draw(); renderProps();
  }
  function onMove(e) {
    var p = point(e); cursor = toWorld(p[0], p[1]); shiftKey = e.shiftKey;
    if (drag) { view.cx = drag.cx - (e.clientX - drag.x) / view.s; view.cy = drag.cy + (e.clientY - drag.y) / view.s; draw(); return; }
    if (press) {
      if (!box && Math.hypot(p[0] - press.x, p[1] - press.y) > DRAG_PX) box = {x0: press.x, y0: press.y, x1: p[0], y1: p[1]};
      if (box) { box.x1 = p[0]; box.y1 = p[1]; draw(); return; }
    }
    var pt = pointer(e);
    if (ed()) ed().move(pt);
    var h = tool === 'select' ? pickAt(cursor[0], cursor[1]) : null;
    if (h !== hover) { hover = h; if (!visibleSelection().length) renderProps(); }
    draw();
  }
  function onUp(e) {
    pointerDown = false;
    if (pendingPrompt) { var pp = pendingPrompt; pendingPrompt = null; openPrompt(pp.w, pp.initial, pp.done); return; }
    if (pendingDim) { var hit = pendingDim; pendingDim = null; openDimInput(hit); return; } // mở ô nhập sau khi nhả chuột, để trình duyệt không lấy lại tiêu điểm
    if (drag) { drag = null; try { canvas.releasePointerCapture(e.pointerId); } catch (x) { /* đã thả */ } canvas.style.cursor = tool === 'pan' ? 'grab' : 'default'; return; }
    if (press) {
      var mode = press.mode; press = null;
      if (box) { selectBox(box, mode); box = null; } else selectAt(world(e), mode);
      try { canvas.releasePointerCapture(e.pointerId); } catch (x) { /* đã thả */ }
      draw(); renderProps(); notifySelection();
    }
  }
  function onWheel(e) { e.preventDefault(); var p = point(e); zoomAt(p[0], p[1], Math.exp(-e.deltaY * 0.0015)); }
  // Gõ số + Enter: gióng song song cách nét đã chọn một khoảng (về phía con trỏ), hoặc đo điểm cuối theo độ dài (hướng về phía con trỏ).
  function vcb(text) {
    var n = Number(String(text).trim().replace(',', '.'));
    if (!isFinite(n) || n <= 0 || n > 1e6) { note = 'Hãy gõ một số dương (mm).'; return false; }
    var cur = snap ? snap.p : cursor;
    if (tool === 'guide' && draft && draft.ref) {
      var nrm = [-draft.ref.d[1], draft.ref.d[0]], side = cur && ((cur[0] - draft.ref.p[0]) * nrm[0] + (cur[1] - draft.ref.p[1]) * nrm[1]) < 0 ? -1 : 1;
      addGuide([draft.ref.p[0] + nrm[0] * side * n, draft.ref.p[1] + nrm[1] * side * n], draft.ref.d); note = 'Đã gióng song song cách ' + n + ' mm.'; draw(); return true;
    }
    if (edit && edit.handles(tool) && edit.typed) { var okTyped = edit.typed(n, cur); draw(); renderProps(); return okTyped; }
    if (modify && modify.handles(tool) && modify.typed) { var okM = modify.typed(n); draw(); renderProps(); return okM; }
    if (tool === 'measure' && measure && !measure.done && cur) {
      var u = unit([constrain(measure.a, cur)[0] - measure.a[0], constrain(measure.a, cur)[1] - measure.a[1]]);
      measure.b = [measure.a[0] + u[0] * n, measure.a[1] + u[1] * n]; measure.done = true; draw(); return true;
    }
    note = tool === 'guide' ? 'Hãy bấm một nét trước rồi gõ khoảng cách.' : tool === 'measure' ? 'Hãy bấm điểm đầu trước rồi gõ độ dài.' : 'Ô nhập số dùng cho công cụ Đo và Đường gióng (các lệnh vẽ ở cột mốc sau).';
    draw(); return false;
  }
  function onKey(e) {
    if (root.hidden) return;
    var t = e.target; if (t && /^(INPUT|SELECT|TEXTAREA)$/.test(t.tagName)) return;
    if (!$('pv-keys').hidden) { if (e.key === 'Escape') toggleKeys(); return; }
    var k = e.key;
    if (e.ctrlKey || e.metaKey) {
      var kl = k.toLowerCase();
      if (kl === 'z' && !e.shiftKey) { opts.undo(); e.preventDefault(); return; }
      if (kl === 'y' || (kl === 'z' && e.shiftKey)) { opts.redo(); e.preventDefault(); return; }
      if (kl === 'a') { selLevel = currentId; selection = shapes.filter(function (x) { return vis(x); }); draw(); renderProps(); notifySelection(); e.preventDefault(); } return; }
    if (e.altKey) return;
    if (k === 'Enter' && edit && edit.handles(tool) && edit.finish) { edit.finish(); draw(); renderProps(); e.preventDefault(); return; } // khép sàn / trần đa giác đang vẽ
    if (k === 'Backspace' && edit && edit.handles(tool) && edit.undoPoint && edit.undoPoint()) { draw(); e.preventDefault(); return; } // bỏ đỉnh cuối khi đang vẽ đa giác
    if (k === 'Delete' || k === 'Backspace') { deleteSelection(); e.preventDefault(); return; }
    if (k === 'Escape') {
      resetChord(); note = '';
      if (draft || measure || box || (edit && edit.busy()) || (modify && modify.busy())) { draft = null; measure = null; box = null; press = null; if (edit) edit.cancel(); if (modify) modify.cancel(); if (modify && modify.handles(tool) && !modify.active()) setTool('select'); draw(); } else { if (suPicking) opts.callSU('su_pick_stop', ''); setTool('select'); selection = []; renderProps(); draw(); notifySelection(); }
    } else if (k === 'Tab') {
      if (tool === 'select' && cursor) {
        var n = pickAll(cursor[0], cursor[1]).length; if (n > 1) { tabIdx = (tabIdx + (e.shiftKey ? -1 : 1) + n) % n; hover = pickAt(cursor[0], cursor[1]); renderProps(); draw(); e.preventDefault(); }
      }
    } else if (/^[a-z]$/i.test(k)) { onLetter(k.toUpperCase()); e.preventDefault(); }
  }

  var api = {
    init: function (options) {
      opts = options; edit = options.edit || null; notes = options.notes || null; modify = options.modify || null; root = $('tab-plan'); canvas = $('pv-canvas'); ctx = canvas.getContext('2d');
      status = {xy: $('pv-xy'), hint: $('pv-hint'), zoom: $('pv-zoom')};
      loadKeys(); buildTop($('pv-top')); buildSide($('pv-side')); buildKeys(); refreshBadges(); setTool('select'); renderProps();
      var box2 = $('pv-vcb'); box2.disabled = false; box2.placeholder = 'Gõ số + Enter';
      box2.onkeydown = function (e) { if (e.key === 'Enter') { if (vcb(box2.value)) { box2.value = ''; canvas.focus(); } e.preventDefault(); } else if (e.key === 'Escape') { box2.value = ''; canvas.focus(); } e.stopPropagation(); };
      canvas.addEventListener('pointerdown', onDown); canvas.addEventListener('pointermove', onMove); canvas.addEventListener('pointerup', onUp); canvas.addEventListener('pointercancel', onUp);
      canvas.addEventListener('pointerleave', function () { cursor = null; hover = null; snap = null; renderProps(); draw(); });
      canvas.addEventListener('wheel', onWheel, {passive: false});
      document.addEventListener('keydown', onKey);
      window.addEventListener('resize', resize);
      if (window.ResizeObserver) new ResizeObserver(resize).observe(canvas.parentNode);
      if (window.MutationObserver) new MutationObserver(draw).observe(document.documentElement, {attributes: true, attributeFilter: ['data-theme', 'class']});
      if (window.matchMedia) window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', draw);
    },
    // Danh sách tầng và tầng đang xem (đồng bộ với các tab khác).
    setLevels: function (levels, current) {
      levelList = levels.map(function (l) { return {id: l.id, name: l.name, elevation: l.elevation, slab: l.slab, screed: l.screed}; }); if (currentId !== current) { if (edit) edit.cancel(); if (modify) modify.cancel(); } if (currentId !== current && hiddenCount) { hiddenKeys = {}; hiddenCount = 0; hiddenMode = ''; refreshHiddenBar(); } currentId = current; if (data) { var keepSel = selLevel === currentId ? selection.map(function (x) { return x.kind + '|' + x.ref; }) : []; hover = null; buildShapes(); selection = shapes.filter(function (x) { return keepSel.indexOf(x.kind + '|' + x.ref) >= 0; }); draw(); } renderTabs(); renderProps(); renderOptions(); if (opts && opts.browser) opts.browser.render();
    },
    update: function (preview) {
      var keep = selLevel === currentId ? selection.map(function (x) { return x.kind + '|' + x.ref; }) : [];
      data = preview; hover = null; snap = null; draft = null; box = null; press = null;
      var b = worldBounds(data), key = b ? b.join(',') : '';
      buildShapes(); selection = shapes.filter(function (x) { return keep.indexOf(x.kind + '|' + x.ref) >= 0; });
      if (pendingSelect && pendingSelect.level === currentId) { var viaSU = pendingSelect.fromSU; applyKeys(pendingSelect.keys); pendingSelect = null; if (!viaSU) notifySelection(); }
      renderProps(); renderOptions();
      if (key !== boundsKey) { boundsKey = key; fitted = false; }
      if (!fitted && !root.hidden) { resize(); } else draw();
    },
    show: function () { resize(); },
    // Chọn phần tử theo mã (từ cây dự án): khác tầng thì chuyển tầng trước, chọn khi xem trước của tầng đó về tới.
    selectKeys: function (levelId, keys, viaSU) {
      if (levelId !== currentId) { pendingSelect = {level: levelId, keys: keys, fromSU: !!viaSU}; opts.onLevel(levelId); return; }
      applyKeys(keys); renderProps(); draw(); if (!viaSU) notifySelection();
    },
    // ---- Sự kiện từ SketchUp (P6) ----
    // Vùng chọn trong SketchUp đổi: chọn đúng các phần tử đó trên mặt bằng (tầng của phần tử đầu tiên); không dội lại cho SketchUp.
    modelSelection: function (data) {
      if (!syncOn || root.hidden) return;
      var items = (data && data.items) || [], groups = (data && data.groups) || [];
      if (!items.length && !groups.length) { if (lastFromSU && selection.length) { selection = []; lastFromSU = false; renderProps(); draw(); } return; }
      var level = items.length ? items[0].level : groups[0].level, keys = items.filter(function (i) { return i.level === level; }).map(function (i) { return {kind: i.kind, ref: i.ref}; });
      groups.filter(function (g) { return g.level === level; }).forEach(function (g) { ((opts.allKeys && opts.allKeys(level, g.kind)) || []).forEach(function (ref) { keys.push({kind: g.kind, ref: ref}); }); });
      lastFromSU = true; lastSent = '';
      api.selectKeys(level, keys, true);
    },
    modelStatus: function (d) { modelStatus = d; draw(); renderProps(); },
    selectResult: function (d) {
      if (d && d.missing && d.missing.length) { note = d.found ? 'SketchUp: chọn được ' + d.found + '/' + d.requested + ' (còn lại chưa dựng trong model).' : 'Chưa dựng trong model nên không chọn được trong SketchUp. Bấm "Dựng tầng này" trước.'; draw(); }
      else if (d && d.mode === 'groups') { note = 'Đã chọn nguyên nhóm trong SketchUp (các phần tử thuộc nhiều nhóm).'; draw(); }
    },
    suState: function (active) {
      suPicking = !!active; if (!active) lastGhostKey = ''; var b = $('pv-supick-btn'); if (b) { b.classList.toggle('on', suPicking); b.setAttribute('aria-pressed', String(suPicking)); }
      if (!active && note.indexOf('SketchUp') === 0) note = ''; draw();
    },
    suPoint: function (p) { injectClick([Number(p.x), Number(p.y)]); },
    // Phím và ô giá trị của SketchUp (Enter, Backspace, Esc, số) đi như bàn phím / ô nhập trên mặt bằng.
    suKey: function (k) { if (root.hidden) return; onKey({key: String(k), ctrlKey: false, metaKey: false, altKey: false, shiftKey: false, target: document.body, preventDefault: function () {}}); },
    suText: function (text) { if (root.hidden) return; var okT = vcb(String(text)); draw(); renderProps(); return okT; },
    startDrawTool: function (t) { setSuDraw(true); setTool(t); },
    suDrawOn: function () { return suDraw; },
    suMove: function (p) { injectMove([Number(p.x), Number(p.y)]); },
    statusOn: function () { return statusOn; },
    guides: function () { return levelGuides(); },
    // Đường (cạnh phần tử, trục, đường gióng) gần điểm w trong 10 px màn hình, kèm hướng: {p, d}; null nếu không có.
    lineAt: function (w) {
      var tolW = SNAP_PX / view.s, best = null;
      function distLine(l) { var t = (w[0] - l.p[0]) * l.d[0] + (w[1] - l.p[1]) * l.d[1]; return Math.hypot(w[0] - (l.p[0] + l.d[0] * t), w[1] - (l.p[1] + l.d[1] * t)); }
      axisLines().concat(levelGuides().map(function (g) { return {p: g.p, d: g.d}; })).forEach(function (l) { var d = distLine(l); if (d <= tolW && (!best || d < best.dist)) best = {p: l.p, d: l.d, dist: d}; });
      shapes.forEach(function (sh) {
        if (!vis(sh)) return;
        for (var i = 0; i < sh.poly.length; i++) {
          var a = sh.poly[i], b = sh.poly[(i + 1) % sh.poly.length], len = Math.hypot(b[0] - a[0], b[1] - a[1]); if (len < 1e-6) continue;
          var l = {p: a, d: [(b[0] - a[0]) / len, (b[1] - a[1]) / len]}, near = nearOnSegment(w, a, b), d = Math.hypot(near[0] - w[0], near[1] - w[1]);
          if (d <= tolW && (!best || d < best.dist)) best = {p: l.p, d: l.d, dist: d};
        }
      });
      return best;
    },
    say: function (text) { note = text; draw(); },
    shapeAt: function (w) { return pickAll(w[0], w[1])[0] || null; }, finish: function () { var m = modify ? modify.hint() : ''; setTool('select'); note = m; draw(); },
    refreshHistory: refreshHistory, scale: function () { return view.s; }, bounds: function () { return worldBounds(data) || [0, 0, 1000, 1000]; },
    snapPoint: function (w) { var r = snapOn ? snapAt(w[0], w[1]) : null; return r ? r.p : null; },
    reloadKeys: function () { loadKeys(); buildKeys(); refreshBadges(); },
    fit: fitView,
    // Dùng cho test: trạng thái xem và số phần tử đang vẽ.
    debug: function () {
      var counts = {}; shapes.forEach(function (s) { counts[s.layer] = (counts[s.layer] || 0) + 1; });
      return {view: {cx: view.cx, cy: view.cy, s: view.s}, size: size, tool: tool, counts: counts, hover: hover && hover.text, selected: selection.length === 1 ? selection[0].title : (selection.length ? selection.length + ' phần tử' : null), selection: selection.map(function (x) { return x.title; }), snap: snap && {p: snap.p, text: snap.text, rank: snap.rank}, guides: levelGuides().length, guideLines: levelGuides().map(function (g) { return {p: g.p, d: g.d}; }), measure: measure && {a: measure.a, b: measure.b, done: measure.done}, draft: draft && (draft.ref ? 'ref' : 'first'), browserOpen: !$('pv-browser').hidden, hidden: hiddenCount, hiddenMode: hiddenMode, suDraw: suDraw, snapOn: snapOn, sync: syncOn, statusOn: statusOn, suPicking: suPicking, badges: badgeCounts(), badgesDrawn: badgesDrawn, modelStatusLevel: modelStatus && modelStatus.level, lastSent: lastSent, edit: edit && edit.debug(), modify: modify && modify.debug(), dims: dimHits.length, dimHits: dimHits.map(function (h) { return {x: h.x, y: h.y, w: h.w, h: h.h, id: h.dim.id, value: h.dim.value}; }), dimList: lastDims.map(function (d) { return {id: d.id, value: d.value, editable: d.editable}; }), chord: chord, keymap: Object.assign({}, keymap), tabIdx: tabIdx, hoverCount: hoverCount, level: currentId, tabs: levelList.length, visible: Object.assign({}, visible), axes: data && data.ok ? data.axes.length : 0};
    },
    toScreen: toScreen, toWorld: toWorld, promptText: promptText
  };
  window.VGDPlan = api;
})();
