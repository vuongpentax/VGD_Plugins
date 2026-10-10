'use strict';
(() => {
  const $ = id => document.getElementById(id);
  const state = { items: [], roots: [], onlineRoots: [], favorites: new Set(), materials: [], view: 'library', root: '', page: 0, selected: null, scanning: false, current: null, modelId: null, thumbnailRequested: new Set() };
  const PAGE_SIZE = 60;
  document.querySelectorAll(".nav[data-view], .sidebar>.subtle, #addFolder").forEach(button => {
    const label = button.querySelector("span")?.textContent.trim() || button.textContent.replace(/\s+/g, " ").trim();
    button.setAttribute("aria-label", label);
    button.setAttribute("title", label);
  });
  let renderTimer;
  function setTheme(theme) {
    const dark = theme === 'dark';
    document.body.classList.toggle('dark', dark);
    $('themeToggle').setAttribute('aria-pressed', String(dark));
    $('themeLabel').textContent = dark ? 'Giao diện sáng' : 'Giao diện tối';
    $('themeToggle').title = dark ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối';
    $('themeIcon').innerHTML = dark
      ? '<circle cx="12" cy="12" r="3.5"/><path d="M12 2.5v2m0 15v2M4.3 4.3l1.4 1.4m12.6 12.6 1.4 1.4M2.5 12h2m15 0h2M4.3 19.7l1.4-1.4M18.3 5.7l1.4-1.4"/>'
      : '<path d="M20 14.4A8 8 0 0 1 9.6 4 8 8 0 1 0 20 14.4Z"/>';
    try { localStorage.setItem('VGD.Library.Theme', dark ? 'dark' : 'light'); } catch (_) {}
  }
  let savedTheme = 'dark';
  try { savedTheme = localStorage.getItem('VGD.Library.Theme') || savedTheme; } catch (_) {}
  setTheme(savedTheme);
  $('themeToggle').addEventListener('click', () => setTheme(document.body.classList.contains('dark') ? 'light' : 'dark'));
  function send(action, args = {}) {
    if (['apply','apply_model','export','rotate','random_rotate','shuffle','fit','auto_scale','restore','reset_uv','clear','reapply','resize','swap','rotate_face','paint','swap_pick','replace_pick','seamless','audit','aux','save_model','flow','fix_nesting','trace','insert'].includes(action)) {
      if (!state.modelId) { feedback('Đợi model sẵn sàng hoặc bấm Làm mới.', true); return; }
      args = { ...args, model_id: state.modelId };
    }
    if (window.sketchup && typeof window.sketchup.vgd === 'function') window.sketchup.vgd(action, JSON.stringify(args));
    else feedback('Mở giao diện từ VGD_Library trong SketchUp để dùng công cụ.', true);
  }
  function feedback(text, error = false) {
    text = String(text == null ? '' : text);
    if (/<(?:!doctype|html|head|body|div)\b/i.test(text)) text = 'Nguồn trả về trang web, không phải danh mục JSON. Kiểm tra lại URL nguồn online.';
    text = text.replace(/[\r\n\t]+/g, ' ');
    if (text.length > 500) text = text.slice(0, 497) + '…';
    $('status').textContent = text; $('status').title = text; $('status').className = error ? 'error' : 'success';
  }
  function normalized(value) { return String(value).normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/đ/g, 'd').replace(/Đ/g, 'D').toLowerCase(); }
  function button(text, title, callback, className = '') { const el = document.createElement('button'); el.textContent = text; el.title = title; el.className = className; el.addEventListener('click', callback); return el; }
  function displayName(path) { return path.replace(/[\\/]+$/, '').split(/[\\/]/).pop() || path; }
  function imageBox(container, item, large = false) {
    container.replaceChildren(); container.style.backgroundColor = item.color || '';
    if (item.preview) {
      const img = document.createElement('img'); img.src = item.preview; img.alt = item.name; img.loading = 'lazy';
      img.addEventListener('error', () => { img.remove(); const placeholder = document.createElement('span'); placeholder.className = 'placeholder'; placeholder.textContent = item.format || 'VGD'; container.append(placeholder); });
      container.append(img);
    } else { const text = document.createElement('span'); text.className = 'placeholder'; text.textContent = large ? 'VGD' : (item.format || '◇'); container.append(text); }
  }
  function selected() {
    const item = state.selected;
    $('apply').disabled = !item;
    $('apply').textContent = item && item.kind === 'model' ? 'Đưa model vào bản vẽ' : 'Tô lên vùng chọn';
    document.querySelector('.inspector > .eyebrow').textContent = item && item.kind === 'model' ? 'MODEL ĐANG CHỌN' : 'VẬT LIỆU ĐANG CHỌN';
    document.querySelector('.inspector > .hint').textContent = item && item.kind === 'model' ? 'Bấm để đặt model. Phím ←/→ xoay 90°, Esc thoát.' : 'Không chọn đối tượng: bật xô sơn. Có vùng chọn: tô các mặt trước bên trong.';
    $('selectedName').textContent = item ? (item.label || item.name) : 'Chọn một vật liệu';
    $('selectedDetail').textContent = item ? (item.kind === 'model' ? 'Model SKP · ' + item.category : (item.category || (item.width ? `${item.width} × ${item.height} mm` : 'Vật liệu màu trong model'))) : 'Bấm vào mẫu để xem và tô / đặt model.';
    imageBox($('preview'), item || {}, true);
    if (item && item.model && item.width) { $('width').value = item.width; $('height').value = item.height; }
  }
  function filtered() {
    let items = state.view === 'model' ? state.materials.map(m => ({ ...m, id: 'model:' + m.name, model: true, format: m.width ? 'MAP' : 'MÀU' })) : state.items;
    if (state.view === 'library') items = items.filter(item => item.kind !== 'model');
    if (state.view === 'models') items = items.filter(item => item.kind === 'model');
    if (state.view === 'online') items = items.filter(item => item.online);
    if (state.view === 'favorites') items = items.filter(item => state.favorites.has(item.id));
    if (state.root && state.view !== 'model') items = items.filter(item => item.root === state.root);
    const query = normalized($('search').value.trim()), category = $('category').value;
    if (query) items = items.filter(item => normalized([item.name, item.label, item.category, item.format].join(' ')).includes(query));
    if (category && state.view !== 'model') items = items.filter(item => item.category === category);
    return [...items].sort((a, b) => ($('sort').value === 'format' ? a.format.localeCompare(b.format) : 0) || (a.label || a.name).localeCompare(b.label || b.name, 'vi', { numeric: true }));
  }
  function render() {
    const tools = state.view === 'tools';
    $('toolsPanel').hidden = !tools; document.querySelector('.filters').hidden = tools; document.querySelector('.result-line').hidden = tools; $('grid').hidden = tools;
    if (tools) { $('empty').hidden = true; $('pagination').hidden = true; return; }
    const items = filtered(), pages = Math.max(1, Math.ceil(items.length / PAGE_SIZE));
    state.page = Math.min(state.page, pages - 1);
    $('grid').replaceChildren();
    for (const item of items.slice(state.page * PAGE_SIZE, (state.page + 1) * PAGE_SIZE)) {
      const card = document.createElement('article'); card.className = 'card' + (state.selected && state.selected.id === item.id ? ' selected' : '');
      const swatch = button('', 'Chọn ' + (item.label || item.name), () => { state.selected = item; selected(); render(); }, 'swatch'); imageBox(swatch, item);
      swatch.addEventListener('dblclick', apply); card.append(swatch);
      if (!item.model) { const favorite = button('', (state.favorites.has(item.id) ? 'Bỏ yêu thích ' : 'Yêu thích ') + item.name, () => send('favorite', { id: item.id }), 'favorite' + (state.favorites.has(item.id) ? ' on' : '')); favorite.setAttribute('aria-pressed', String(state.favorites.has(item.id))); favorite.innerHTML = '<svg class="ui-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 20s-7.5-4.5-7.5-10a4.2 4.2 0 0 1 7.5-2.5A4.2 4.2 0 0 1 19.5 10c0 5.5-7.5 10-7.5 10Z"/></svg>'; card.append(favorite); }
      const title = document.createElement('h3'); title.textContent = item.label || item.name; title.title = title.textContent; card.append(title);
      const detail = document.createElement('p'); detail.textContent = item.model ? (item.width ? `${item.width} × ${item.height} mm` : 'Màu đơn') : `${item.category} · ${item.format}`; detail.title = detail.textContent; card.append(detail); $('grid').append(card);
    }
    $('results').textContent = `${items.length} ${state.view === 'models' ? 'model' : 'mẫu'}`;
    $('scanState').textContent = state.scanning ? 'Đang đọc thư viện…' : '';
    $('total').textContent = state.items.filter(i => i.kind !== 'model').length; $('skpTotal').textContent = state.items.filter(i => i.kind === 'model').length; $('onlineTotal').textContent = state.items.filter(i => i.online).length; $('favTotal').textContent = state.items.filter(i => state.favorites.has(i.id)).length; $('modelTotal').textContent = state.materials.length;
    $('empty').hidden = items.length > 0 || state.scanning;
    const isFirst = state.items.length === 0 && state.roots.length === 0 && state.view === 'library';
    $('empty').querySelector('h2').textContent = isFirst ? 'Thư viện của riêng bạn' : 'Chưa có mẫu phù hợp';
    $('empty').querySelector('p').textContent = state.view === 'models' ? 'Thêm thư mục chứa model SKP. Kho Drive 03 MTL hiện chỉ có vật liệu.' : (isFirst ? 'Chọn thư mục chứa ảnh vân gỗ, đá, vải hoặc vật liệu SKM. Thư mục con sẽ tự trở thành các nhóm vật liệu.' : 'Thử tìm bằng tên khác, đổi nhóm hoặc thêm thư mục thư viện.');
    $('emptyAdd').hidden = state.view === 'model'; $('pagination').hidden = pages <= 1;
    $('prev').disabled = state.page === 0; $('next').disabled = state.page === pages - 1; $('pageLabel').textContent = `${state.page + 1} / ${pages}`;
    const thumbnailIds = items.slice(state.page * PAGE_SIZE, (state.page + 1) * PAGE_SIZE).filter(i => !i.preview && !i.model && !i.online && ['SKP','SKM'].includes(i.format) && !state.thumbnailRequested.has(i.id)).map(i => i.id);
    if (thumbnailIds.length) { thumbnailIds.forEach(id => state.thumbnailRequested.add(id)); send('thumbnails', { ids:thumbnailIds }); }
  }
  function scheduleRender() { if (!renderTimer) renderTimer = setTimeout(() => { renderTimer = null; categories(); render(); }, 100); }
  function categories() {
    const previous = $('category').value; $('category').replaceChildren(new Option('Tất cả nhóm', ''));
    [...new Set(state.items.filter(i => !state.root || i.root === state.root).map(i => i.category))].sort().forEach(c => $('category').append(new Option(c, c)));
    if ([...$('category').options].some(o => o.value === previous)) $('category').value = previous;
    $('category').hidden = state.view === 'model';
  }
  function folders() {
    $('folders').replaceChildren();
    for (const root of [...state.roots, ...state.onlineRoots.map(source => source.id)]) {
      const row = document.createElement('div'); row.className = 'folder-row' + (root === state.root ? ' active' : '');
      const source = state.onlineRoots.find(source => source.id === root);
      row.append(button((source ? 'Nguồn · ' : 'Thư mục · ') + (source ? source.label : displayName(root)), root, () => { if (state.view === 'model' || state.view === 'tools') setView('library'); state.root = state.root === root ? '' : root; state.page = 0; folders(); categories(); render(); }));
      const remove = button('', 'Bỏ thư mục khỏi danh sách (giữ nguyên tệp)', () => send('remove_folder', { root }), 'remove'); remove.innerHTML = '<svg class="ui-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18"/></svg>'; row.append(remove); $('folders').append(row);
    }
  }
  function setView(view) {
    state.view = view; state.page = 0; state.root = ''; $('category').value = '';
    document.querySelectorAll('[data-view]').forEach(b => b.classList.toggle('active', b.dataset.view === view));
    $('heading').textContent = { library: 'Thư viện vật liệu', models:'Thư viện model', online:'Thư viện online', favorites: 'Bộ sưu tập yêu thích', model: 'Vật liệu trong bản vẽ', tools:'Bộ công cụ VGD' }[view];
    $('search').placeholder = view === 'models' ? 'Tìm tên model, mã hoặc nhóm…' : 'Tìm tên vật liệu, mã hoặc nhóm…';
    if (view === 'model') send('model'); folders(); categories(); render();
  }
  function sizes() { return { width: $('width').value, height: $('height').value }; }
  function apply() {
    const item = state.selected; if (!item) return;
    if (item.model) send('apply_model', { name: item.name }); else send(item.kind === 'model' ? 'insert' : 'apply', { id: item.id, ...sizes() });
  }
  window.VGD = {
    begin(data) { state.items = []; state.roots = data.roots; state.onlineRoots = data.online_roots || []; state.thumbnailRequested.clear(); state.favorites = new Set(data.favorites); state.scanning = true; state.selected = null; state.page = 0; if (![...state.roots, ...state.onlineRoots.map(s => s.id)].includes(state.root)) state.root = ''; $('version').textContent = data.version; folders(); categories(); selected(); if(data.view) setView(data.view); render(); },
    append(items, complete, warnings) { state.items.push(...items); state.scanning = !complete; if (complete) { categories(); render(); feedback(warnings.length ? warnings.join(' · ') : `Đã đọc ${state.items.length} mẫu từ ${state.roots.length} thư mục.`, warnings.length > 0); } else scheduleRender(); },
    favorites(ids) { state.favorites = new Set(ids); render(); },
    model(data) { state.materials = data.materials; state.current = data.current; state.modelId = data.model_id; const prior = $('swapSource').value; $('swapSource').replaceChildren(new Option('Chọn nguồn cần thay', '')); for (const m of data.materials) $('swapSource').append(new Option(m.label, m.name)); $('swapSource').value = prior; const current = state.materials.find(m => m.name === data.current); $('resize').disabled = !(current && current.width); $('currentMaterial').textContent = current ? 'Trong model: ' + current.label : 'Trong model: chưa chọn vật liệu.'; render(); },
    thumbnail(id,url) { const item=state.items.find(i => i.id===id); if(item && url) { item.preview=url; if(state.selected && state.selected.id===id) selected(); render(); } },
    audit(rows) { setView('tools'); $('auditResult').replaceChildren(); if(!rows.length) { $('auditResult').textContent='Không thấy vật liệu mặt xung đột với vỏ.'; return; } const summary=document.createElement('strong'); summary.textContent=rows.length+' mặt khác vật liệu vỏ'; $('auditResult').append(summary); for(const row of rows.slice(0,30)) { const detail=document.createElement('div'); detail.textContent=`Mặt ${row.id}: ${row.face} · Vỏ: ${row.shell}`; $('auditResult').append(detail); } },
    feedback, state, setView
  };
  document.querySelectorAll('[data-view]').forEach(b => b.addEventListener('click', () => setView(b.dataset.view)));
  function toolOptions() { return { scope:$('swapScope').value,replace_scope:$('replaceScope').value,keep_size:$('keepSize').checked,redraw_dc:$('redrawDC').checked,strategy:$('nestStrategy').value,trace_resolution:$('traceResolution').value,colors:$('traceColors').value,tolerance:$('traceTolerance').value,remove_background:$('removeBackground').checked,hide_original:$('hideOriginal').checked,kind:$('auxKind').value,strength:$('auxStrength').value,resolution:$('auxResolution').value }; }
  document.querySelectorAll('[data-action]').forEach(b => b.addEventListener('click', () => send(b.dataset.action, toolOptions())));
  $('addFolder').onclick = $('emptyAdd').onclick = () => send('add_folder'); $('refresh').onclick = () => send('refresh');
  $('search').addEventListener('input', () => { state.page = 0; render(); }); $('category').onchange = $('sort').onchange = () => { state.page = 0; render(); };
  $('apply').onclick = apply; $('resize').onclick = () => send('resize', sizes()); $('rotateAngle').onclick = () => send('rotate', { angle: $('angle').value });
  $('swap').onclick = () => send('swap', { source: $('swapSource').value,scope:$('swapScope').value }); $('export').onclick = () => send('export'); $('addOnline').onclick = () => send('add_online'); $('importCatalog').onclick = () => send('import_catalog');
  $('connectDrive').onclick = () => send('connect_drive'); $('openDrive').onclick = () => send('open_drive');
  $('prev').onclick = () => { state.page--; render(); }; $('next').onclick = () => { state.page++; render(); };
  selected(); render(); send('ready');
})();
