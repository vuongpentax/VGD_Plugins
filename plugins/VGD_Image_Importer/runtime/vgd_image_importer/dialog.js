/* Compatible with the Chromium version bundled in SketchUp 2022. */
(function () {
  'use strict';
  var $ = function (id) { return document.getElementById(id); };
  var state = { importType: 'comp_2d', files: [], busy: false, native: !!window.sketchup };
  var themeKey = 'vgd.image_importer.theme';
  function call(action, data) {
    if (window.sketchup && window.sketchup.vgd_importer) window.sketchup.vgd_importer(action, JSON.stringify(data || {}));
    else if (action !== 'ready') status('Mở plugin trong SketchUp để chọn và nhập ảnh.', true);
  }
  function status(message, error, success) {
    $('status').textContent = message;
    $('status').className = error ? 'error' : success ? 'success' : '';
  }
  // Body classes drive the logo swap in CSS; VGDTheme owns the saved choice and the button.
  function syncBodyClass(theme) {
    document.body.classList.toggle('dark', theme === 'dark');
    document.body.classList.toggle('light', theme !== 'dark');
  }
  document.addEventListener('vgdtheme', function (event) { syncBodyClass(event.detail.theme); });
  function config() {
    return { importType: state.importType, scaleMethod: $('scaleMethod').value,
      mmPerPixel: Number($('mmPerPixel').value), targetHeight: Number($('targetHeight').value),
      targetWidth: Number($('targetWidth').value), spacing: Number($('spacing').value),
      itemsPerRow: Number($('itemsPerRow').value), alwaysFaceCamera: $('alwaysFaceCamera').checked,
      recursive: $('recursive').checked, theme: VGDTheme.current() };
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
  var dropMimeExtensions = { 'image/jpeg': '.jpg', 'image/png': '.png', 'image/apng': '.apng', 'image/bmp': '.bmp', 'image/x-ms-bmp': '.bmp',
    'image/tiff': '.tiff', 'image/x-tga': '.tga', 'image/webp': '.webp', 'image/gif': '.gif', 'image/avif': '.avif',
    'image/x-icon': '.ico', 'image/vnd.microsoft.icon': '.ico', 'image/svg+xml': '.svg', 'image/heic': '.heic', 'image/heif': '.heif' };
  var acceptedDropExtensions = { '.jpg':1,'.jpeg':1,'.jfif':1,'.jpe':1,'.png':1,'.apng':1,'.bmp':1,'.dib':1,'.tif':1,'.tiff':1,'.tga':1,'.webp':1,'.gif':1,'.avif':1,'.ico':1,'.svg':1,'.heic':1,'.heif':1 };
  function droppedFile(file) {
    if (!file) return null;
    var name = file.name || 'image', ext = (name.match(/\.[^.\\/]+$/) || [''])[0].toLowerCase();
    if (!ext && dropMimeExtensions[file.type]) { ext = dropMimeExtensions[file.type]; name += ext; }
    return ext && acceptedDropExtensions[ext] ? { file: file, name: name } : null;
  }
  // Candidate web image URLs in priority order: direct image links, then <img> in the HTML, then page links.
  // Ruby downloads them (the browser fetch is blocked by CORS on most sites) and keeps the first valid image.
  function webImageCandidates(dataTransfer) {
    var direct = [], pages = [], fromHtml = [];
    (dataTransfer.getData('text/uri-list') || '').split(/\r?\n/).forEach(function (value) {
      if (!value || value.charAt(0) === '#') return;
      (/\.(jpe?g|jfif|png|apng|gif|webp|bmp|dib|tiff?|tga|avif|ico|svg|heic|heif)(?=$|[?#])/i.test(value) ? direct : pages).push(value);
    });
    var html = dataTransfer.getData('text/html');
    if (html) {
      var parsed = new DOMParser().parseFromString(html, 'text/html');
      Array.prototype.forEach.call(parsed.querySelectorAll('img[src]'), function (img) { fromHtml.push(img.getAttribute('src')); });
    }
    var seen = {};
    return direct.concat(fromHtml, pages).filter(function (url) {
      if (!/^https?:\/\//i.test(url) || seen[url]) return false;
      seen[url] = true;
      return true;
    });
  }
  async function sendDroppedFile(fileInfo) {
    var file = fileInfo.file, name = fileInfo.name || file.name;
    if (!file.size || file.size > 20 * 1024 * 1024) throw new Error(name + ': dung lượng ảnh tối đa 20 MiB.');
    var token = 'drop-' + Date.now() + '-' + Math.random().toString(16).slice(2);
    var chunkSize = 192 * 1024, chunks = Math.ceil(file.size / chunkSize);
    call('drop_start', { token: token, name: name, size: file.size, chunks: chunks });
    var bytes = new Uint8Array(await file.arrayBuffer());
    for (var index = 0; index < chunks; index++) {
      var part = bytes.subarray(index * chunkSize, Math.min((index + 1) * chunkSize, bytes.length)), binary = '';
      for (var offset = 0; offset < part.length; offset += 0x8000)
        binary += String.fromCharCode.apply(null, part.subarray(offset, Math.min(offset + 0x8000, part.length)));
      call('drop_chunk', { token: token, index: index, base64: btoa(binary) });
    }
    call('drop_finish', { token: token });
  }
  var dropDepth = 0;
  document.addEventListener('dragenter', function (event) {
    if (event.dataTransfer) { event.preventDefault(); dropDepth++; document.body.classList.add('drag-over'); }
  });
  document.addEventListener('dragover', function (event) {
    if (event.dataTransfer) { event.preventDefault(); event.dataTransfer.dropEffect = 'copy'; }
  });
  document.addEventListener('dragleave', function (event) {
    if (event.dataTransfer) { dropDepth = Math.max(0, dropDepth - 1); if (!dropDepth) document.body.classList.remove('drag-over'); }
  });
  document.addEventListener('drop', async function (event) {
    event.preventDefault(); dropDepth = 0; document.body.classList.remove('drag-over');
    var transfer = event.dataTransfer, files = Array.from(transfer.files || []).map(droppedFile).filter(Boolean);
    if (!files.length) {
      var items = Array.from(transfer.items || []);
      files = items.filter(function (item) { return item.kind === 'file'; }).map(function (item) { return droppedFile(item.getAsFile()); }).filter(Boolean);
    }
    if (!files.length) {
      var candidates = webImageCandidates(transfer);
      if (candidates.length) {
        state.busy = true; update(); status('Đang tải ảnh từ liên kết kéo vào…');
        call('drop_url', { urls: candidates });
        return;
      }
    }
    if (!files.length) { status('Hãy kéo file ảnh hoặc ảnh từ trang web vào cửa sổ.', true); return; }
    state.busy = true; update();
    try {
      for (var index = 0; index < files.length; index++) await sendDroppedFile(files[index]);
      status('Đã thêm ' + files.length + ' ảnh vào danh sách.');
    } catch (error) { status(error.message || 'Không thể đọc ảnh kéo vào.', true); }
    finally { state.busy = false; update(); }
  });
  window.VGDImporter = { receive: function (event, data) {
    if (event === 'settings') {
      Object.keys(data).forEach(function (key) {
        if (key === 'importType') state.importType = data[key];
        else if ($(key) && $(key).tagName !== 'BUTTON') {
          if ($(key).type === 'checkbox') $(key).checked = data[key]; else $(key).value = data[key];
        }
      });
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
  // Runs after VGDTheme has switched the theme, so the saved config carries the new value.
  $('theme').addEventListener('click', function () { setTimeout(function () { if (valid(false)) call('save', config()); }, 0); });
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
  VGDTheme.start({ key: themeKey, button: $('theme') });
  syncBodyClass(VGDTheme.current());
  update(); call('ready');
}());
