/* Tab "Quản lý" của VGD Center: bật/tắt plugin, chuyển plugin giữa các bản SketchUp, xuất gói .rbz.
   Chuyển từ giao diện của VGD Plugin Manager. Mã Ruby gọi lại qua window.VGDManager.<hàm> (xem manager/callbacks.rb).
   Mọi nội dung động được dựng bằng textContent nên an toàn với tên plugin có ký tự HTML. */
(function () {
  'use strict';

  var S = { plugins: [], sets: [] };
  var checked = {};

  function byId(id) { return document.getElementById(id); }
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
  }
  // Gọi lệnh Ruby (mgr_*). Không có sketchup (mở thử trong trình duyệt) thì bỏ qua.
  function call(name, payload) {
    if (!window.sketchup || typeof window.sketchup[name] !== 'function') return;
    if (payload === undefined) window.sketchup[name](); else window.sketchup[name](JSON.stringify(payload));
  }
  function say(msg) {
    var o = byId('mgrOut');
    if (msg) { o.style.display = 'block'; o.textContent = msg; } else { o.style.display = 'none'; }
  }

  function showTab(name) {
    ['toggle', 'migrate'].forEach(function (n) {
      byId('mgr-panel-' + n).hidden = n !== name;
      byId('mgr-tab-' + n).setAttribute('aria-selected', n === name ? 'true' : 'false');
    });
    say('');
  }

  /* ---- Bật/tắt ---- */
  function label(st) { return st === 'on' ? 'Đang bật' : (st === 'off' ? 'Đã tắt' : 'Trùng tên'); }
  function query() { return byId('mgrQ').value.toLowerCase(); }
  function visiblePlugins() {
    var q = query();
    return S.plugins.filter(function (p) { return !q || p.name.toLowerCase().indexOf(q) >= 0; });
  }
  function bulkNames(action) {
    var want = action === 'disable' ? 'on' : 'off';
    return visiblePlugins().filter(function (p) { return p.status === want; }).map(function (p) { return p.name; });
  }
  function bulk(action) { call('mgr_bulk', { action: action, names: bulkNames(action) }); }
  function updateBulk() {
    var filtered = !!byId('mgrQ').value;
    [['mgrBulkOff', 'disable', 'Tắt tất cả'], ['mgrBulkOn', 'enable', 'Bật tất cả']].forEach(function (b) {
      var n = bulkNames(b[1]).length, e = byId(b[0]);
      e.textContent = filtered ? b[2] + ' đang hiện (' + n + ')' : b[2] + ' (' + n + ')';
      e.disabled = n === 0;
    });
  }
  function pluginRow(p) {
    var r = el('div', 'mgr-row' + (p.status === 'off' ? ' off' : '')), cb = document.createElement('input');
    cb.type = 'checkbox'; cb.checked = !!checked[p.name]; cb.title = 'Chọn để lưu vào bộ';
    cb.addEventListener('change', function () { checked[p.name] = cb.checked; });
    var nm = el('span', 'nm', p.name);
    if (p.members && p.members.length > 1) {
      var others = p.members.filter(function (m) { return m !== p.name; });
      nm.title = 'Gồm ' + p.members.length + ' mục: ' + p.members.join(', ');
      nm.appendChild(el('small', '', ' gồm cả: ' + others.join(', ')));
    }
    r.appendChild(cb); r.appendChild(nm);
    if (p.status === 'conflict') {
      var badge = el('span', 'mgr-badge conflict', label(p.status));
      badge.title = 'Plugin này có ở cả thư mục Plugins (đang chạy) và thư mục đã tắt. Xóa hoặc dời bản không cần để gạt được.';
      r.appendChild(badge);
    }
    var sw = el('button', 'mgr-switch'); sw.type = 'button';
    sw.setAttribute('role', 'switch');
    sw.setAttribute('aria-checked', p.status === 'on' ? 'true' : 'false');
    sw.setAttribute('aria-label', p.name + ': ' + label(p.status));
    sw.title = p.status === 'conflict' ? 'Trùng tên, cần xử lý thủ công' : (p.status === 'on' ? 'Bấm để tắt' : 'Bấm để bật');
    if (p.status === 'conflict') sw.disabled = true;
    sw.addEventListener('click', function () { call('mgr_change', { names: [p.name], action: p.status === 'on' ? 'disable' : 'enable' }); });
    r.appendChild(sw);
    return r;
  }
  function setRow(s) {
    var r = el('div', 'mgr-set');
    r.appendChild(el('span', 'nm', s.name + ' (' + s.count + ' plugin' + (s.missing ? ', ' + s.missing + ' không còn' : '') + ')'));
    var a = el('button', 'btn small danger', 'Tắt bộ'); a.type = 'button';
    a.addEventListener('click', function () { call('mgr_apply_set', { name: s.name, action: 'disable' }); });
    var b = el('button', 'btn small primary', 'Bật bộ'); b.type = 'button';
    b.addEventListener('click', function () { call('mgr_apply_set', { name: s.name, action: 'enable' }); });
    var c = el('button', 'btn small', 'Xóa bộ'); c.type = 'button';
    c.addEventListener('click', function () { call('mgr_delete_set', { name: s.name }); });
    r.appendChild(a); r.appendChild(b); r.appendChild(c);
    return r;
  }
  function drawToggle() {
    updateBulk();
    var L = byId('mgrList'), T = byId('mgrSets');
    L.innerHTML = '';
    visiblePlugins().forEach(function (p) { L.appendChild(pluginRow(p)); });
    T.innerHTML = '';
    S.sets.forEach(function (s) { T.appendChild(setRow(s)); });
  }
  function picked() { return Object.keys(checked).filter(function (k) { return checked[k]; }); }
  function selAll(v) {
    visiblePlugins().forEach(function (p) { checked[p.name] = v; });
    drawToggle();
  }
  function renderToggle(s, msg) {
    S = s;
    byId('mgrVer').textContent = 'SketchUp ' + s.year;
    byId('mgrDir').textContent = 'Thư mục chứa plugin đã tắt: ' + s.disabled_dir;
    drawToggle();
    say(msg);
  }

  /* ---- Chuyển plugin ---- */
  function initMigrate(versions) {
    var s = byId('mgrSrc'), d = byId('mgrDst');
    [s, d].forEach(function (sel) {
      sel.innerHTML = '';
      versions.forEach(function (v) { var o = document.createElement('option'); o.value = o.textContent = v; sel.appendChild(o); });
    });
    if (versions.length < 2) {
      byId('mgrMlist').textContent = 'Chỉ tìm thấy ' + versions.length + ' phiên bản SketchUp trong AppData. Cần ít nhất 2 phiên bản để chuyển plugin.';
      byId('mgrGo').disabled = true;
      return;
    }
    byId('mgrGo').disabled = false;
    s.value = versions[0]; d.value = versions[versions.length - 1];
    onVersion();
  }
  function onVersion() {
    var s = byId('mgrSrc').value, d = byId('mgrDst').value;
    byId('mgrGo').textContent = 'Chuyển sang bản ' + d;
    if (s === d) { byId('mgrMlist').textContent = 'Phiên bản nguồn và đích phải khác nhau.'; return; }
    call('mgr_list', { src: s, dst: d });
  }
  function renderMigrate(d) {
    var L = byId('mgrMlist'); L.innerHTML = '';
    if (!d.plugins.length) { L.textContent = 'Không tìm thấy plugin nào trong bản ' + d.src + '.'; return; }
    d.plugins.forEach(function (name, i) {
      var r = el('label', 'mgr-row'), cb = document.createElement('input');
      cb.type = 'checkbox'; cb.className = 'mgr-pl'; cb.value = name; cb.checked = true;
      r.appendChild(cb); r.appendChild(el('span', '', (i + 1) + '. ' + name)); L.appendChild(r);
    });
  }
  function setAll(v) { document.querySelectorAll('#mgr-panel-migrate .mgr-pl').forEach(function (c) { c.checked = v; }); }
  function collect() {
    var p = [].slice.call(document.querySelectorAll('#mgr-panel-migrate .mgr-pl')).filter(function (c) { return c.checked; }).map(function (c) { return c.value; });
    return { src: byId('mgrSrc').value, dst: byId('mgrDst').value, plugins: p, overwrite: byId('mgrOverwrite').checked };
  }

  function bind(id, fn) { byId(id).addEventListener('click', fn); }
  function init() {
    bind('mgr-tab-toggle', function () { showTab('toggle'); });
    bind('mgr-tab-migrate', function () { showTab('migrate'); });
    byId('mgrQ').addEventListener('input', drawToggle);
    bind('mgrSelAll', function () { selAll(true); });
    bind('mgrSelNone', function () { selAll(false); });
    bind('mgrOpenPlugins', function () { call('mgr_open_plugins'); });
    bind('mgrOpenDisabled', function () { call('mgr_open_disabled'); });
    bind('mgrBulkOff', function () { bulk('disable'); });
    bind('mgrBulkOn', function () { bulk('enable'); });
    bind('mgrSaveSet', function () { call('mgr_save_set', { name: byId('mgrSetName').value, names: picked() }); });
    bind('mgrExportSets', function () { call('mgr_export_sets'); });
    bind('mgrImportSets', function () { call('mgr_import_sets'); });
    byId('mgrSrc').addEventListener('change', onVersion);
    byId('mgrDst').addEventListener('change', onVersion);
    bind('mgrSetAll', function () { setAll(true); });
    bind('mgrSetNone', function () { setAll(false); });
    bind('mgrGo', function () { call('mgr_migrate', collect()); });
    bind('mgrExportBundle', function () { call('mgr_export_bundle', collect()); });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();

  window.VGDManager = {
    // Gọi mỗi lần mở tab: Ruby quét lại thư mục Plugins rồi gửi trạng thái mới
    open: function () { call('mgr_ready'); },
    renderToggle: renderToggle,
    renderMigrate: renderMigrate,
    initMigrate: initMigrate,
    showResult: say
  };
})();
