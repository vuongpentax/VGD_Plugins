/* Tab "Quản lý" của VGD Center: bật/tắt plugin, chuyển plugin giữa các bản SketchUp, xuất gói .rbz.
   Mã Ruby gọi lại qua window.VGDManager.<hàm> (xem manager/callbacks.rb).
   Mọi nội dung động được dựng bằng textContent nên an toàn với tên plugin có ký tự HTML.
   Ngôn ngữ: chữ tĩnh trong dialog.html do Center dịch (bảng englishText); chữ do file này sinh ra dùng I18N bên dưới,
   và mỗi lệnh gửi sang Ruby kèm lang để thông báo của Ruby cũng đúng ngôn ngữ. */
(function () {
  'use strict';

  var I18N = {
    vi: {
      state_on: 'Đang bật', state_off: 'Đã tắt', state_conflict: 'Trùng tên', state_pending: 'Chờ nạp',
      btn_load: 'Nạp ngay', tt_load: 'Nạp plugin này vào SketchUp đang chạy, không cần khởi động lại',
      tt_pending: 'Đã bật nhưng chưa chạy trong phiên này. Bấm Nạp ngay hoặc khởi động lại SketchUp.',
      bulk_load: 'Nạp tất cả chờ nạp ({n})', bulk_load_shown: 'Nạp tất cả đang hiện chờ nạp ({n})',
      pick_title: 'Chọn để lưu vào bộ',
      members_title: 'Gồm {n} mục: {list}', members_note: ' gồm cả: {list}',
      conflict_title: 'Plugin này có ở cả thư mục Plugins (đang chạy) và thư mục đã tắt. Xóa hoặc dời bản không cần để gạt được.',
      sw_conflict: 'Trùng tên, cần xử lý thủ công', sw_on: 'Bấm để tắt', sw_off: 'Bấm để bật',
      set_label: '{name} ({n} plugin{missing})', set_missing: ', {n} không còn',
      btn_set_off: 'Tắt bộ', btn_set_on: 'Bật bộ', btn_set_del: 'Xóa bộ',
      bulk_off: 'Tắt tất cả ({n})', bulk_on: 'Bật tất cả ({n})',
      bulk_off_shown: 'Tắt tất cả đang hiện ({n})', bulk_on_shown: 'Bật tất cả đang hiện ({n})',
      mig_few: 'Chỉ tìm thấy {n} phiên bản SketchUp trong AppData. Cần ít nhất 2 phiên bản để chuyển plugin.',
      mig_go: 'Chuyển sang bản {ver}', mig_go_default: 'Chuyển plugin',
      mig_count: 'Đã chọn {n}/{total}', mig_count_shown: 'Đã chọn {n}/{total}, đang hiện {shown}',
      mig_same: 'Phiên bản nguồn và đích phải khác nhau.', mig_none: 'Không tìm thấy plugin nào trong bản {ver}.',
      ph_search: 'Tìm plugin...', ph_setname: 'Tên bộ, ví dụ: Render',
      tt_open_plugins: 'Mở thư mục Plugins của SketchUp đang chạy', tt_open_disabled: 'Mở thư mục chứa các plugin đã tắt'
    },
    en: {
      state_on: 'Enabled', state_off: 'Disabled', state_conflict: 'Name clash', state_pending: 'Waiting to load',
      btn_load: 'Load now', tt_load: 'Load this plugin into the running SketchUp, no restart needed',
      tt_pending: 'Enabled but not running in this session. Click Load now or restart SketchUp.',
      bulk_load: 'Load all waiting ({n})', bulk_load_shown: 'Load all shown waiting ({n})',
      pick_title: 'Select to save into a set',
      members_title: 'Includes {n} items: {list}', members_note: ' also includes: {list}',
      conflict_title: 'This plugin exists in both the Plugins folder (running) and the disabled folder. Delete or move the copy you do not need to use the switch.',
      sw_conflict: 'Name clash, resolve it manually', sw_on: 'Click to disable', sw_off: 'Click to enable',
      set_label: '{name} ({n} plugin(s){missing})', set_missing: ', {n} missing',
      btn_set_off: 'Disable set', btn_set_on: 'Enable set', btn_set_del: 'Delete set',
      bulk_off: 'Disable all ({n})', bulk_on: 'Enable all ({n})',
      bulk_off_shown: 'Disable all shown ({n})', bulk_on_shown: 'Enable all shown ({n})',
      mig_few: 'Only {n} SketchUp version(s) found in AppData. You need at least 2 to migrate plugins.',
      mig_go: 'Migrate to version {ver}', mig_go_default: 'Migrate plugins',
      mig_count: 'Selected {n}/{total}', mig_count_shown: 'Selected {n}/{total}, showing {shown}',
      mig_same: 'The source and destination versions must be different.', mig_none: 'No plugins found in version {ver}.',
      ph_search: 'Search plugins...', ph_setname: 'Set name, e.g. Render',
      tt_open_plugins: 'Open the Plugins folder of the running SketchUp', tt_open_disabled: 'Open the folder that holds disabled plugins'
    }
  };

  var lang = 'vi';
  var S = { plugins: [], sets: [] };
  var checked = {};
  var versions = [];
  var mlistNote = null;   // thông báo đang hiện thay cho danh sách chuyển plugin: { key, vars }

  function t(key, vars) {
    var s = (I18N[lang] && I18N[lang][key]) || I18N.vi[key] || key;
    Object.keys(vars || {}).forEach(function (k) { s = s.split('{' + k + '}').join(String(vars[k])); });
    return s;
  }
  function byId(id) { return document.getElementById(id); }
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
  }
  // Gọi lệnh Ruby (mgr_*), luôn kèm lang. Không có sketchup (mở thử trong trình duyệt) thì bỏ qua.
  function call(name, payload) {
    if (!window.sketchup || typeof window.sketchup[name] !== 'function') return;
    var data = { lang: lang };
    Object.keys(payload || {}).forEach(function (k) { data[k] = payload[k]; });
    window.sketchup[name](JSON.stringify(data));
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
  function label(st) { return st === 'on' ? t('state_on') : (st === 'off' ? t('state_off') : t('state_conflict')); }
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
  // Plugin đang bật nhưng chưa chạy trong phiên này (Ruby tính, xem Toggle.state)
  function pendingNames() {
    return visiblePlugins().filter(function (p) { return p.pending; }).map(function (p) { return p.name; });
  }
  function updateBulk() {
    var filtered = !!byId('mgrQ').value;
    [['mgrBulkOff', 'disable', 'bulk_off'], ['mgrBulkOn', 'enable', 'bulk_on']].forEach(function (b) {
      var n = bulkNames(b[1]).length, e = byId(b[0]);
      e.textContent = t(filtered ? b[2] + '_shown' : b[2], { n: n });
      e.disabled = n === 0;
    });
    var nl = pendingNames().length, bl = byId('mgrBulkLoad');
    bl.textContent = t(filtered ? 'bulk_load_shown' : 'bulk_load', { n: nl });
    bl.disabled = nl === 0;
  }
  function updateMetrics() {
    var on = 0, off = 0;
    S.plugins.forEach(function (p) { if (p.status === 'on') on++; else if (p.status === 'off') off++; });
    byId('mgrCountOn').textContent = String(on);
    byId('mgrCountOff').textContent = String(off);
    byId('mgrCountSets').textContent = String(S.sets.length);
    byId('mgrYear').textContent = S.year ? 'SketchUp ' + S.year : '—';
  }
  function pluginRow(p) {
    var r = el('div', 'mgr-row' + (p.status === 'off' ? ' off' : '')), cb = document.createElement('input');
    cb.type = 'checkbox'; cb.checked = !!checked[p.name]; cb.title = t('pick_title');
    cb.addEventListener('change', function () { checked[p.name] = cb.checked; });
    var nm = el('span', 'nm', p.name);
    if (p.members && p.members.length > 1) {
      var others = p.members.filter(function (m) { return m !== p.name; });
      nm.title = t('members_title', { n: p.members.length, list: p.members.join(', ') });
      nm.appendChild(el('small', '', t('members_note', { list: others.join(', ') })));
    }
    r.appendChild(cb); r.appendChild(nm);
    if (p.status === 'conflict') {
      var badge = el('span', 'mgr-badge conflict', label(p.status));
      badge.title = t('conflict_title');
      r.appendChild(badge);
    }
    if (p.pending) {
      var wait = el('span', 'mgr-badge pending', t('state_pending'));
      wait.title = t('tt_pending');
      r.appendChild(wait);
      var ld = el('button', 'btn small primary', t('btn_load')); ld.type = 'button';
      ld.title = t('tt_load');
      ld.addEventListener('click', function () { call('mgr_load', { names: [p.name] }); });
      r.appendChild(ld);
    }
    var sw = el('button', 'mgr-switch'); sw.type = 'button';
    sw.setAttribute('role', 'switch');
    sw.setAttribute('aria-checked', p.status === 'on' ? 'true' : 'false');
    sw.setAttribute('aria-label', p.name + ': ' + label(p.status));
    sw.title = p.status === 'conflict' ? t('sw_conflict') : (p.status === 'on' ? t('sw_on') : t('sw_off'));
    if (p.status === 'conflict') sw.disabled = true;
    sw.addEventListener('click', function () { call('mgr_change', { names: [p.name], action: p.status === 'on' ? 'disable' : 'enable' }); });
    r.appendChild(sw);
    return r;
  }
  function setRow(s) {
    var r = el('div', 'mgr-set');
    var missing = s.missing ? t('set_missing', { n: s.missing }) : '';
    r.appendChild(el('span', 'nm', t('set_label', { name: s.name, n: s.count, missing: missing })));
    var a = el('button', 'btn small danger', t('btn_set_off')); a.type = 'button';
    a.addEventListener('click', function () { call('mgr_apply_set', { name: s.name, action: 'disable' }); });
    var b = el('button', 'btn small primary', t('btn_set_on')); b.type = 'button';
    b.addEventListener('click', function () { call('mgr_apply_set', { name: s.name, action: 'enable' }); });
    var c = el('button', 'btn small', t('btn_set_del')); c.type = 'button';
    c.addEventListener('click', function () { call('mgr_delete_set', { name: s.name }); });
    r.appendChild(a); r.appendChild(b); r.appendChild(c);
    return r;
  }
  function drawToggle() {
    updateBulk();
    updateMetrics();
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
    drawToggle();
    say(msg);
  }

  /* ---- Chuyển plugin ---- */
  // Thông báo thay cho danh sách (chưa đủ phiên bản, trùng bản, không có plugin)
  function showMlistNote() {
    var L = byId('mgrMlist'); L.innerHTML = '';
    L.appendChild(el('div', 'mgr-empty', t(mlistNote.key, mlistNote.vars)));
  }
  function setMlistNote(key, vars) {
    mlistNote = { key: key, vars: vars || {} };
    showMlistNote();
    updateMCount();
  }
  function updateGoLabel() {
    var d = byId('mgrDst').value;
    byId('mgrGo').textContent = d ? t('mig_go', { ver: d }) : t('mig_go_default');
  }
  function initMigrate(list) {
    versions = list;
    var s = byId('mgrSrc'), d = byId('mgrDst');
    [s, d].forEach(function (sel) {
      sel.innerHTML = '';
      list.forEach(function (v) { var o = document.createElement('option'); o.value = o.textContent = v; sel.appendChild(o); });
    });
    if (list.length < 2) {
      setMlistNote('mig_few', { n: list.length });
      byId('mgrGo').disabled = true;
      updateGoLabel();
      return;
    }
    byId('mgrGo').disabled = false;
    s.value = list[0]; d.value = list[list.length - 1];
    onVersion();
  }
  function onVersion() {
    var s = byId('mgrSrc').value, d = byId('mgrDst').value;
    updateGoLabel();
    if (s === d) { setMlistNote('mig_same'); return; }
    call('mgr_list', { src: s, dst: d });
  }
  function renderMigrate(d) {
    mlistNote = null;
    var L = byId('mgrMlist'); L.innerHTML = '';
    if (!d.plugins.length) { setMlistNote('mig_none', { ver: d.src }); return; }
    d.plugins.forEach(function (name) {
      var r = el('label', 'mgr-row'), cb = document.createElement('input');
      cb.type = 'checkbox'; cb.className = 'mgr-pl'; cb.value = name; cb.checked = true;
      cb.addEventListener('change', updateMCount);
      r.dataset.name = name;
      r.appendChild(cb); r.appendChild(el('span', 'nm', name)); L.appendChild(r);
    });
    filterMigrate();
  }
  // Ô tìm kiếm của danh sách chuyển plugin chỉ ẩn/hiện dòng; dấu chọn vẫn giữ, nên có dòng đếm số đã chọn
  function filterMigrate() {
    var q = byId('mgrMQ').value.toLowerCase();
    document.querySelectorAll('#mgrMlist .mgr-row').forEach(function (r) {
      r.hidden = !!q && (r.dataset.name || '').toLowerCase().indexOf(q) < 0;
    });
    updateMCount();
  }
  function updateMCount() {
    var all = document.querySelectorAll('#mgrMlist .mgr-pl'), n = 0, shown = 0;
    [].forEach.call(all, function (c) { if (c.checked) n++; if (!c.closest('.mgr-row').hidden) shown++; });
    byId('mgrMCount').textContent = !all.length ? '' :
      t(byId('mgrMQ').value ? 'mig_count_shown' : 'mig_count', { n: n, total: all.length, shown: shown });
  }
  // Chọn hết / Bỏ chọn hết chỉ áp cho các dòng đang hiện (giống tab Bật/tắt)
  function setAll(v) {
    document.querySelectorAll('#mgrMlist .mgr-row').forEach(function (r) { if (!r.hidden) r.querySelector('.mgr-pl').checked = v; });
    updateMCount();
  }
  function collect() {
    var p = [].slice.call(document.querySelectorAll('#mgr-panel-migrate .mgr-pl')).filter(function (c) { return c.checked; }).map(function (c) { return c.value; });
    return { src: byId('mgrSrc').value, dst: byId('mgrDst').value, plugins: p, overwrite: byId('mgrOverwrite').checked };
  }

  // Đổi ngôn ngữ: vẽ lại chữ do file này sinh ra và các thuộc tính (placeholder, tooltip)
  function applyAttributes() {
    byId('mgrQ').placeholder = t('ph_search');
    byId('mgrQ').setAttribute('aria-label', t('ph_search'));
    byId('mgrMQ').placeholder = t('ph_search');
    byId('mgrMQ').setAttribute('aria-label', t('ph_search'));
    byId('mgrSetName').placeholder = t('ph_setname');
    byId('mgrSetName').setAttribute('aria-label', t('ph_setname'));
    byId('mgrOpenPlugins').title = t('tt_open_plugins');
    byId('mgrOpenDisabled').title = t('tt_open_disabled');
  }
  function setLanguage(value) {
    lang = value === 'en' ? 'en' : 'vi';
    applyAttributes();
    drawToggle();
    updateGoLabel();
    updateMCount();
    if (mlistNote) showMlistNote();
  }

  function bind(id, fn) { byId(id).addEventListener('click', fn); }
  function init() {
    bind('mgr-tab-toggle', function () { showTab('toggle'); });
    bind('mgr-tab-migrate', function () { showTab('migrate'); });
    byId('mgrQ').addEventListener('input', drawToggle);
    byId('mgrMQ').addEventListener('input', filterMigrate);
    bind('mgrSelAll', function () { selAll(true); });
    bind('mgrSelNone', function () { selAll(false); });
    bind('mgrOpenPlugins', function () { call('mgr_open_plugins'); });
    bind('mgrOpenDisabled', function () { call('mgr_open_disabled'); });
    bind('mgrBulkOff', function () { bulk('disable'); });
    bind('mgrBulkOn', function () { bulk('enable'); });
    bind('mgrBulkLoad', function () { call('mgr_load', { names: pendingNames() }); });
    bind('mgrSaveSet', function () { call('mgr_save_set', { name: byId('mgrSetName').value, names: picked() }); });
    bind('mgrExportSets', function () { call('mgr_export_sets'); });
    bind('mgrImportSets', function () { call('mgr_import_sets'); });
    byId('mgrSrc').addEventListener('change', onVersion);
    byId('mgrDst').addEventListener('change', onVersion);
    bind('mgrSetAll', function () { setAll(true); });
    bind('mgrSetNone', function () { setAll(false); });
    bind('mgrGo', function () { call('mgr_migrate', collect()); });
    bind('mgrExportBundle', function () { call('mgr_export_bundle', collect()); });
    applyAttributes();
    drawToggle();
    updateGoLabel();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();

  window.VGDManager = {
    // Gọi mỗi lần mở tab: Ruby quét lại thư mục Plugins rồi gửi trạng thái mới
    open: function () { call('mgr_ready'); },
    renderToggle: renderToggle,
    renderMigrate: renderMigrate,
    initMigrate: initMigrate,
    showResult: say,
    setLanguage: setLanguage
  };
})();
