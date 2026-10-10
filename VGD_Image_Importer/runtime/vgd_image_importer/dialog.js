/* Compatible with the Chromium version bundled in SketchUp 2022. */
(function () {
  'use strict';
  var $ = function (id) { return document.getElementById(id); };
  var state = { importType: 'comp_2d', files: [], busy: false, native: !!window.sketchup };
  var themeIcons = {
    dark: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="3.5"/><path d="M12 2.5v2M12 19.5v2M4.93 4.93l1.42 1.42m11.3 11.3 1.42 1.42M2.5 12h2m15 0h2M4.93 19.07l1.42-1.42m11.3-11.3 1.42-1.42"/></svg>',
    light: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20.2 15.1A8.2 8.2 0 0 1 8.9 3.8 8.2 8.2 0 1 0 20.2 15.1Z"/></svg>'
  };
  var themeKey = 'vgd.image_importer.theme';
  function call(action, data) {
    if (window.sketchup && window.sketchup.vgd_importer) window.sketchup.vgd_importer(action, JSON.stringify(data || {}));
    else if (action !== 'ready') status('Mở plugin trong SketchUp để chọn và nhập ảnh.', true);
  }
  function status(message, error, success) {
    $('status').textContent = message;
    $('status').className = error ? 'error' : success ? 'success' : '';
  }
  function theme(dark) {
    document.body.classList.toggle('dark', dark);
    document.body.classList.toggle('light', !dark);
    document.documentElement.style.colorScheme = dark ? 'dark' : 'light';
    $('theme').setAttribute('aria-pressed', String(dark));
    $('theme').innerHTML = themeIcons[dark ? 'dark' : 'light'];
    var themeLabel = dark ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối';
    $('theme').title = themeLabel;
    $('theme').setAttribute('aria-label', themeLabel);
    try { localStorage.setItem(themeKey, dark ? 'dark' : 'light'); } catch (_) {}
  }
  function config() {
    return { importType: state.importType, scaleMethod: $('scaleMethod').value,
      mmPerPixel: Number($('mmPerPixel').value), targetHeight: Number($('targetHeight').value),
      targetWidth: Number($('targetWidth').value), spacing: Number($('spacing').value),
      itemsPerRow: Number($('itemsPerRow').value), alwaysFaceCamera: $('alwaysFaceCamera').checked,
      recursive: $('recursive').checked, theme: document.body.classList.contains('dark') ? 'dark' : 'light' };
  }
  function valid(show) {
    var cfg = config();
    var fields = ['mmPerPixel', 'targetHeight', 'targetWidth', 'spacing', 'itemsPerRow'];
    for (var i = 0; i < fields.length; i++) {
      var key = fields[i], value = cfg[key];
      if (!Number.isFinite(value) || (key === 'spacing' ? value < 0 : value <= 0) ||
          (key === 'itemsPerRow' && (!Number.isInteger(value) || value > 1000))) {
        if (show) { status('Kiểm tra kích thước, khoảng hở và số ảnh mỗi hàng.', true); $(key).focus(); }
        return false;
      }
    }
    return true;
  }
  function update() {
    ['pixel', 'height', 'width'].forEach(function (method) { $(method + 'Row').hidden = $('scaleMethod').value !== method; });
    $('layoutCard').hidden = state.importType === 'texture_only';
    $('faceCamRow').hidden = state.importType !== 'comp_2d';
    document.querySelectorAll('[data-type]').forEach(function (button) { button.setAttribute('aria-pressed', String(button.dataset.type === state.importType)); });
    $('import').disabled = state.busy || !state.files.length;
    $('import').textContent = state.busy ? 'Đang nhập…' : 'Nhập ' + (state.files.length ? state.files.length + ' ' : '') + (state.importType === 'texture_only' ? 'vật liệu' : 'ảnh');
    $('clear').disabled = state.busy || !state.files.length;
    $('chooseFolder').disabled = $('chooseFiles').disabled = state.busy;
    document.querySelectorAll('#config input, #config select, #config button, #recursive, #theme, .remove').forEach(function (element) { element.disabled = state.busy; });
  }
  function fileUrl(path) {
    var normalized = path.replace(/\\/g, '/');
    return (normalized.slice(0, 2) === '//' ? 'file:' : 'file:///') + normalized.split('/').map(function (part, index) {
      return index === 0 && /^[A-Za-z]:$/.test(part) ? part : encodeURIComponent(part);
    }).join('/');
  }
  function renderFiles(files) {
    state.files = files;
    var list = $('fileList');
    list.textContent = '';
    $('count').textContent = files.length + ' ảnh';
    $('empty').hidden = files.length > 0;
    files.forEach(function (file) {
      var row = document.createElement('div'); row.className = 'file-row';
      var placeholder = document.createElement('span'); placeholder.className = 'thumb thumb-placeholder';
      placeholder.textContent = (file.name.split('.').pop() || 'ẢNH').toUpperCase();
      if (/\.(png|apng|jpe?g|jfif|jpe|bmp|webp|gif|avif|ico|svg)$/i.test(file.name)) {
        var image = document.createElement('img'); image.className = 'thumb'; image.alt = ''; image.loading = 'lazy';
        image.onerror = function () { image.replaceWith(placeholder); };
        image.src = fileUrl(file.path); row.appendChild(image);
      } else row.appendChild(placeholder);
      var info = document.createElement('div'); info.className = 'file-info';
      var name = document.createElement('strong'); name.textContent = file.name; name.title = file.name;
      var path = document.createElement('small'); path.textContent = file.path; path.title = file.path;
      info.appendChild(name); info.appendChild(path); row.appendChild(info);
      var remove = document.createElement('button'); remove.className = 'remove'; remove.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18"/></svg>';
      remove.setAttribute('aria-label', 'Bỏ ' + file.name); remove.onclick = function () { call('remove', { id: file.id }); };
      row.appendChild(remove); list.appendChild(row);
    });
    update();
  }
  function convertImage(data) {
    status('Đang chuẩn bị: ' + data.name + '…');
    var image = new Image(), finished = false;
    var timer = setTimeout(function () { done({ error: 'Quá thời gian giải mã ảnh.' }); }, 45000);
    function done(result) {
      if (finished) return;
      finished = true; clearTimeout(timer);
      image.onload = image.onerror = null; image.src = '';
      result.token = data.token; result.id = data.id;
      call('converted', result);
    }
    image.onload = function () {
      try {
        if (!image.naturalWidth || !image.naturalHeight) throw new Error('Ảnh có kích thước không hợp lệ.');
        var canvas = document.createElement('canvas');
        canvas.width = image.naturalWidth; canvas.height = image.naturalHeight;
        var context = canvas.getContext('2d');
        if (!context) throw new Error('Không tạo được bộ giải mã ảnh.');
        context.drawImage(image, 0, 0);
        var png = canvas.toDataURL('image/png');
        if (png.slice(0, 22) !== 'data:image/png;base64,') throw new Error('Ảnh quá lớn để chuyển sang PNG.');
        done({ base64: png.slice(22) });
        canvas.width = canvas.height = 0;
      } catch (error) { done({ error: error.message }); }
    };
    image.onerror = function () { done({ error: 'Không giải mã được ảnh: file hỏng hoặc định dạng không được hỗ trợ.' }); };
    image.src = 'data:' + data.mime + ';base64,' + data.base64;
  }
  window.VGDImporter = { receive: function (event, data) {
    if (event === 'settings') {
      Object.keys(data).forEach(function (key) {
        if (key === 'importType') state.importType = data[key];
        else if ($(key) && $(key).tagName !== 'BUTTON') {
          if ($(key).type === 'checkbox') $(key).checked = data[key]; else $(key).value = data[key];
        }
      });
      theme(data.theme === 'dark');
      $('version').textContent = 'VGD TOOLS · v' + data.version;
      update();
    } else if (event === 'files') renderFiles(data);
    else if (event === 'convert') convertImage(data);
    else if (event === 'status') { state.busy = false; status(data.message, data.error); update(); }
    else if (event === 'result') {
      state.busy = false; update();
      var summary = 'Đã nhập ' + data.imported + ' ảnh / vật liệu' + (data.failed ? ' · ' + data.failed + ' ảnh lỗi.' : '.');
      status(summary, data.imported === 0, data.imported > 0);
      $('resultSummary').textContent = summary; $('errors').textContent = '';
      data.errors.forEach(function (error) { var item = document.createElement('li'); item.textContent = error.name + ': ' + error.message; $('errors').appendChild(item); });
      if (!$('resultDialog').open) $('resultDialog').showModal();
    }
  } };
  document.querySelectorAll('[data-type]').forEach(function (button) { button.onclick = function () { state.importType = button.dataset.type; update(); if (valid(false)) call('save', config()); }; });
  $('config').addEventListener('submit', function (event) { event.preventDefault(); });
  $('config').addEventListener('change', function () { update(); if (valid(false)) call('save', config()); });
  $('recursive').onchange = function () { if (valid(false)) call('save', config()); };
  $('theme').onclick = function () { theme(!document.body.classList.contains('dark')); if (valid(false)) call('save', config()); };
  $('chooseFolder').onclick = function () { call('choose', { kind: 'folder', recursive: $('recursive').checked }); };
  $('chooseFiles').onclick = function () { call('choose', { kind: 'files' }); };
  $('clear').onclick = function () { call('clear'); };
  $('closeResult').onclick = function () { $('resultDialog').close(); };
  $('import').onclick = function () {
    if (state.busy || !state.files.length || !valid(true)) return;
    if (!state.native) { status('Mở plugin trong SketchUp để nhập ảnh.', true); return; }
    state.busy = true; update(); status('Đang nhập ảnh. Lượt nhập lớn có thể mất một lúc…');
    // Let Chromium paint feedback before entering the native import callback.
    setTimeout(function () { call('import', config()); }, 30);
  };
  // Used by the native integration harness; follows exactly the same UI path.
  window.VGDImporter.startImport = function () { $('import').click(); };
  try {
    var savedTheme = localStorage.getItem(themeKey);
    theme(savedTheme ? savedTheme === 'dark' : document.body.classList.contains('dark'));
  } catch (_) { theme(document.body.classList.contains('dark')); }
  update(); call('ready');
}());
