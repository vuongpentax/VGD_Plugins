'use strict';
document.addEventListener('DOMContentLoaded', () => {
  const $ = id => document.getElementById(id);
  const settingsKeys = ['project','template','axis_mode','grouping','isolate','width','height','margin','grid','format','transparent','paper','section_axis','section_percent','section_offset','section_flip','section_name','normal_x','normal_y','normal_z','ratio_locked','export_scale','date_folder'];
  const numeric = new Set(['width','height','margin','section_percent','section_offset','normal_x','normal_y','normal_z','export_scale']);
  const booleans = new Set(['isolate','transparent','section_flip','ratio_locked','date_folder']);
  let context = null, busy = false, selected = new Set(), pendingModal = null, lastPath = null;
  let transfer = null, transferSelected = new Set();
  let dragging = null, dropMarker = null, dragY = 0, scrollFrame = null, navigationId = null;
  let savedFrameSignature = null, presetSignature = null;
  let frameFailureEpoch = 0;
  const primaryActions = {views:$('generate'),sections:$('section'),export:$('exportButton')};
  Object.values(primaryActions).forEach(button => $('primarySlot').append(button));
  Object.entries(primaryActions).forEach(([name,button]) => {button.hidden=name!=='views';});
  let theme = 'light';
  try { theme = localStorage.getItem('VGD.Scenes.Theme') || 'light'; } catch (_) {}
  document.body.classList.toggle('dark', theme === 'dark');
  function status(message, error = false) { $('status').textContent = message || 'Thao tác không thành công.'; $('status').classList.toggle('error', error); }
  function settings() {
    applyRatioInput();
    const out = {};
    for (const key of settingsKeys) out[key] = booleans.has(key) ? $(key).checked : numeric.has(key) ? Number($(key).value) : $(key).value;
    out.views = [...document.querySelectorAll('[data-view][aria-pressed=true]')].map(button => button.dataset.view);
    if (settingsKeys.filter(key => numeric.has(key)).some(key => !Number.isFinite(out[key]) || $(key).value.trim() === '')) throw Error('Điền đầy đủ các thông số số.');
    if (out.width < 100 || out.height < 100 || out.width > 12000 || out.height > 12000 || out.width*out.height > 64000000) throw Error('Kích thước ảnh: 100–12000 px, tối đa 64 triệu pixel.');
    if (out.margin < 0 || out.margin > 100) throw Error('Lề cần nằm trong 0–100%.');
    if (out.section_percent < 0 || out.section_percent > 100) throw Error('Vị trí cắt cần nằm trong 0–100%.');
    if (!(out.export_scale > 0)) throw Error('Scale xuất phải lớn hơn 0.');
    return out;
  }
  function enable() {
    document.querySelectorAll('button:not(#theme):not(#modalCancel):not(#modalConfirm):not(#cancel):not(#openFolder)').forEach(button => { button.disabled = !context || busy; });
    document.querySelectorAll('[data-needs-selection]').forEach(button => { button.disabled = !context || busy || context.selection === 0; });
    document.querySelectorAll('[data-needs-scenes]').forEach(button => { button.disabled = !context || busy || selected.size === 0; });
    $('update').disabled = !context || busy || selected.size === 0 || context.scenes.some(scene => selected.has(scene.id) && !scene.owned);
    $('selectedCount').textContent = selected.size + ' đã chọn';
    $('exportSelection').textContent = selected.size ? selected.size + ' scene đã chọn · Xuất theo thứ tự trong bảng VGD.' : 'Chưa chọn scene. Đánh dấu trong mục Scene.';
    $('cancel').hidden = !busy;
    $('openFolder').hidden = !lastPath || busy;
    document.querySelectorAll('#sceneList input').forEach(input => { input.disabled = busy; });
    $('copyScenes').disabled = !context || busy || (!selected.size && !context.scenes.some(scene => scene.selected));
    $('saveScenes').disabled = !context || busy || ($('sceneScope').value === 'all' ? !context.scenes.length : !selected.size);
    $('transferApply').disabled = !context || busy || !transfer || !transferSelected.size;
    document.querySelectorAll('#transferList input').forEach(input => { input.disabled = busy; });
    document.querySelectorAll('.scene-grip').forEach(button => { button.disabled = !context || busy || !!context.editing; button.draggable = !button.disabled; });
    $('cameraApply').disabled = !context || busy || context.editing || !context.camera || !context.camera.supported;
    document.querySelectorAll('[data-align],#previewLens').forEach(button => { button.disabled = $('cameraApply').disabled; });
    $('selectGroup').disabled = !context || busy || !context.scenes.some(scene=>scene.selected);
    $('updateCurrentView').disabled = !context || busy || context.editing || !context.scenes.some(scene=>scene.selected);
    $('deletePreset').disabled = !context || busy || !$('namedPreset').value;
    $('removeAllFrames').disabled = !context || busy || context.editing || !(context.frame_cleanup && context.frame_cleanup.count || context.frame_active);
    $('restoreAllFrames').disabled = !context || busy || context.editing || !(context.frame_cleanup && context.frame_cleanup.restore);
  }
  function send(action, extra = {}, lock = true) {
    if (!context || (busy && !['cancel','refresh'].includes(action))) return;
    if (!window.sketchup) { status('Bản xem trước: thao tác thực hiện trong SketchUp.'); return; }
    if (lock) { busy = true; enable(); }
    window.sketchup.action(JSON.stringify({ action, model: context.model, ...extra }));
  }
  function runSettings(action) { try { const opts = settings(); if (action === 'generate' && !opts.views.length) throw Error('Chọn ít nhất một góc nhìn.'); if (action === 'section' && !opts.section_name.trim()) throw Error('Điền tên mặt cắt.'); if (action === 'section' && opts.section_axis === 'CUSTOM' && ![opts.normal_x,opts.normal_y,opts.normal_z].some(n => Math.abs(n)>1e-9)) throw Error('Vector pháp tuyến không được bằng 0.'); send(action, { settings: opts }); } catch (error) { status(error.message, true); } }
  function tab(name) {
    document.querySelectorAll('.tab').forEach(panel => { panel.hidden = panel.id !== name; });
    document.querySelectorAll('[data-tab]').forEach(button => button.setAttribute('aria-selected', String(button.dataset.tab === name)));
    document.querySelector('main').scrollTop = 0;
    Object.entries(primaryActions).forEach(([key,button]) => {button.hidden=key!==name;});
  }
  function filtered() { if (!context) return []; const query = $('search').value.toLocaleLowerCase(); return context.scenes.filter(scene => (!$('onlyVGD').checked || scene.owned || scene.imported) && scene.name.toLocaleLowerCase().includes(query)); }
  function modal(title, text, callback, value) {
    pendingModal = callback; $('modalTitle').textContent = title; $('modalText').textContent = text;
    $('renameInput').hidden = value === undefined; $('renameInput').value = value || '';
    $('modal').hidden = false; (value === undefined ? $('modalCancel') : $('renameInput')).focus();
    if (value !== undefined) $('renameInput').select();
  }
  function closeModal() { $('modal').hidden = true; pendingModal = null; }
  function clearTransfer() { transfer = null; transferSelected.clear(); $('transferModal').hidden = true; }
  function renderTransfer() {
    const list = $('transferList'); list.replaceChildren();
    if (!transfer) return;
    const mode = $('transferMode').value;
    for (const scene of transfer.scenes) {
      const row = document.createElement('div'); row.className = 'transfer-row';
      const label = document.createElement('label');
      const check = document.createElement('input'); check.type = 'checkbox'; check.checked = transferSelected.has(scene.id); check.setAttribute('aria-label','Nhập ' + scene.name);
      check.addEventListener('change', () => { check.checked ? transferSelected.add(scene.id) : transferSelected.delete(scene.id); renderTransfer(); });
      const name = document.createElement('span'); name.className = 'transfer-name'; name.textContent = scene.name; name.title = scene.name;
      const detail = document.createElement('small'); detail.textContent = mode === 'new' ? 'Tạo mới' : scene.ambiguous ? 'Trùng nhiều · cần kiểm tra' : scene.match ? (mode === 'skip' ? 'Bỏ qua: ' : 'Cập nhật: ') + scene.match : 'Tạo mới'; detail.title = detail.textContent;
      label.append(check,name); row.append(label,detail); list.append(row);
    }
    $('transferCount').textContent = transferSelected.size + '/' + transfer.scenes.length + ' đã chọn'; enable();
  }
  function showTransfer(data) {
    if (!data) { clearTransfer(); return; }
    if (transfer && transfer.token === data.token) return;
    closeModal(); tab('scenes'); transfer = data; transferSelected = new Set(data.scenes.map(scene => scene.id)); $('transferMode').value = 'new';
    $('transferSource').textContent = (data.title || 'Model chưa lưu') + ' · ' + data.scenes.length + ' góc nhìn';
    $('transferModal').hidden = false; renderTransfer(); $('transferMode').focus();
  }
  function render() {
    const list = $('sceneList'), active = document.activeElement;
    // Polling must never replace a field while a dimension is being typed.
    if (active && list.contains(active) && active.matches('input:not([type=checkbox])') && active.closest('.scene-row').dataset.model===context.model) { enable(); return; }
    const focusedRow = active && active.closest('.scene-row');
    const focusedId = focusedRow && focusedRow.dataset.id;
    const focusedIndex = focusedRow ? [...focusedRow.children].indexOf(active) : -1;
    list.replaceChildren(); const scenes = filtered();
    if (!scenes.length) { const empty = document.createElement('div'); empty.className = 'empty'; empty.textContent = context && context.scenes.length ? 'Không có scene khớp bộ lọc.' : 'Chưa có scene. Tạo ở mục Góc nhìn hoặc Mặt cắt.'; list.append(empty); }
    for (const scene of scenes) {
      const row = document.createElement('div'); row.className = 'scene-row' + (scene.selected ? ' current' : ''); row.dataset.id = scene.id; row.dataset.model=context.model;
      const check = document.createElement('input'); check.type = 'checkbox'; check.checked = selected.has(scene.id); check.setAttribute('aria-label','Chọn ' + scene.name);
      check.addEventListener('change', () => { check.checked ? selected.add(scene.id) : selected.delete(scene.id); enable(); });
      const name = document.createElement('button'); name.className = 'scene-name'; name.textContent = scene.name; name.title = scene.name; name.addEventListener('click', () => { navigationId = scene.id; list.focus({preventScroll:true}); send('visit',{id:scene.id}); });
      const badge = document.createElement('span'); badge.className = 'badge'; badge.textContent = scene.owned ? (scene.kind === 'SECTION' ? 'VGD · Cắt' : 'VGD') : scene.imported ? 'VGD · Nhập' : 'Scene';
      const rename = document.createElement('button'); rename.className = 'row-action'; rename.textContent = 'Tên'; rename.title = 'Đổi tên scene'; rename.addEventListener('click', () => modal('Đổi tên scene',scene.name,() => send('rename',{id:scene.id,name:$('renameInput').value.trim()}),scene.name));
      const capture = document.createElement('button'); capture.className = 'row-action'; capture.textContent = 'Lưu view'; capture.title = 'Cập nhật scene bằng góc nhìn hiện tại'; capture.addEventListener('click', () => modal('Lưu góc nhìn hiện tại','Cập nhật camera, visibility và mặt cắt hiện tại vào “' + scene.name + '”?',() => send('capture',{id:scene.id})));
      const grip = document.createElement('button'); grip.className = 'scene-grip'; grip.title = 'Kéo để sắp xếp bảng VGD'; grip.setAttribute('aria-label','Sắp xếp ' + scene.name);
      for (let i=0;i<3;i++) grip.append(document.createElement('span'));
      grip.addEventListener('dragstart',event => {
        if (busy || context.editing) { event.preventDefault(); return; }
        dragging = { id:scene.id, model:context.model, order:context.scenes.map(item=>item.id), before:scene.id };
        event.dataTransfer.setData('text/plain',scene.id); event.dataTransfer.effectAllowed = 'move'; row.classList.add('dragging');
        dragY = event.clientY; scrollFrame = requestAnimationFrame(scrollDrag);
      });
      grip.addEventListener('dragend',finishDrag);
      row.append(check,name,badge,rename,capture,grip); list.append(row);
      const frame = scene.frame || {width:1920,height:1080,margin:10};
      const fields = document.createElement('div'); fields.className = 'row-frame';
      const inputs = {};
      for (const [key,labelText] of [['width','Rộng px'],['height','Cao px'],['ratio','Tỷ lệ'],['margin','Lề %']]) {
        const label = document.createElement('label'); label.textContent = labelText;
        const input = document.createElement('input'); input.type = key==='ratio'?'text':'number'; input.dataset.frameKey = key;
        input.setAttribute('aria-label',labelText+' · '+scene.name);
        input.value = key==='ratio'?ratioText(frame.width,frame.height):frame[key];
        if (key!=='ratio') { input.min = key==='margin'?'0':'100'; input.max = key==='margin'?'100':'12000'; }
        inputs[key] = input; label.append(input); fields.append(label);
      }
      let lastFrame = JSON.stringify(frame);
      let committedEpoch = frameFailureEpoch;
      function commitRow(key) { try {
        if(row.dataset.model!==context.model || busy) return;
        if (key==='ratio') { const pair = dimensionsForRatio(inputs.ratio.value,Math.max(Number(inputs.width.value),Number(inputs.height.value))); inputs.width.value=pair[0];inputs.height.value=pair[1]; }
        const value = readFrame(inputs.width,inputs.height,inputs.margin); inputs.ratio.value=ratioText(value.width,value.height);
        const signature = JSON.stringify(value); if (signature===lastFrame && committedEpoch===frameFailureEpoch) return;
        lastFrame=signature; committedEpoch=frameFailureEpoch; send('saveFrames',{ids:[scene.id],frame:value},false);
      } catch(error) { status(error.message,true); } }
      for (const [key,input] of Object.entries(inputs)) onCommit(input,()=>commitRow(key));
      row.append(fields);
      if (focusedId === scene.id && focusedIndex >= 0) row.children[focusedIndex].focus({preventScroll:true});
    }
    enable();
  }
  function finishDrag() {
    dragging = null;
    if (scrollFrame !== null) cancelAnimationFrame(scrollFrame); scrollFrame = null;
    if (dropMarker) { dropMarker.classList.remove('drop-before','drop-after'); dropMarker = null; }
    document.querySelectorAll('.scene-row.dragging').forEach(row=>row.classList.remove('dragging'));
  }
  function scrollDrag() {
    if (!dragging) return;
    const pane = document.querySelector('main'), rect = pane.getBoundingClientRect();
    if (dragY < rect.top+38) pane.scrollTop -= 10;
    else if (dragY > rect.bottom-38) pane.scrollTop += 10;
    scrollFrame = requestAnimationFrame(scrollDrag);
  }
  $('sceneList').addEventListener('dragover',event => {
    if (!dragging || busy || dragging.model !== context.model) return;
    event.preventDefault(); event.dataTransfer.dropEffect = 'move'; dragY = event.clientY;
    if (dropMarker) dropMarker.classList.remove('drop-before','drop-after');
    const row = event.target.closest('.scene-row'); dropMarker = row;
    if (!row) { dragging.before = null; return; }
    const rect = row.getBoundingClientRect(), after = event.clientY > rect.top+rect.height/2;
    const index = context.scenes.findIndex(scene=>scene.id===row.dataset.id);
    dragging.before = after ? (context.scenes[index+1] ? context.scenes[index+1].id : null) : row.dataset.id;
    row.classList.add(after?'drop-after':'drop-before');
  });
  $('sceneList').addEventListener('drop',event => {
    if (!dragging) return;
    event.preventDefault(); const action = dragging; finishDrag();
    if (context.model !== action.model || busy) return;
    $('sceneList').focus({preventScroll:true});
    send('reorder',{id:action.id,before:action.before,order:action.order});
  });
  function cameraMode() { const floor = $('cameraMode').value === 'floor'; $('cameraAbsolute').hidden = floor; $('cameraFloorFields').hidden = !floor; }
  function applyCamera() {
    try {
      const mode = $('cameraMode').value, keys = mode === 'floor' ? ['cameraFloor','cameraHeight'] : ['cameraZ'];
      if (keys.some(key=>$(key).value.trim()==='' || !Number.isFinite(Number($(key).value)))) throw Error('Nhập cao độ camera bằng số hữu hạn.');
      if (mode === 'floor' && Number($('cameraHeight').value)<0) throw Error('Eye Height cần lớn hơn hoặc bằng 0.');
      send('cameraElevation',{camera:{mode,z:Number($('cameraZ').value),floor:Number($('cameraFloor').value),height:Number($('cameraHeight').value),keep_direction:$('cameraKeep').checked}});
    } catch(error) { status(error.message,true); }
  }
  $('cameraMode').addEventListener('change',cameraMode);
  $('cameraApply').addEventListener('click',applyCamera);
  ['cameraZ','cameraFloor','cameraHeight'].forEach(key=>$(key).addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();applyCamera();}}));
  function showFormat() { const isPng = $('format').value === 'png'; $('transparent').disabled = !isPng; $('transparentLabel').style.opacity = isPng ? '1' : '.45'; $('alphaHint').hidden = !isPng; $('paperLabel').hidden = $('format').value !== 'pdf'; }
  function frameStatus(frameActive, gridActive) {
    $('toggleFrame').setAttribute('aria-pressed',String(frameActive)); $('toggleFrame').textContent = frameActive ? 'Tắt khung' : 'Bật khung';
    $('toggleGrid').setAttribute('aria-pressed',String(gridActive)); $('toggleGrid').textContent = gridActive ? 'Tắt lưới' : 'Bật lưới';
  }
  function lockStatus() {
    const locked = $('ratio_locked').checked;
    $('lockRatio').setAttribute('aria-pressed',String(locked));
    $('lockRatio').textContent = locked ? 'Tỷ lệ đã khóa' : 'Khóa tỷ lệ';
  }
  window.VGDScenes = { receive(event, data) {
    if (event === 'state' && data && Array.isArray(data.scenes)) {
      if (dragging) {
        if (dragging.model === data.model && JSON.stringify(dragging.order) === JSON.stringify(data.scenes.map(scene=>scene.id)) && !data.busy && !data.editing) return;
        finishDrag();
      }
      const changed = !context || context.model !== data.model;
      const currentId = value => value && value.scenes.find(scene => scene.selected)?.id;
      const frameChanged = changed || currentId(context) !== currentId(data);
      const frameUpdated = !frameChanged && JSON.stringify(context.current_frame)!==JSON.stringify(data.current_frame);
      if (changed) { selected.clear(); closeModal(); clearTransfer(); lastPath = null; for (const key of settingsKeys) if (data.settings[key] !== undefined) booleans.has(key) ? $(key).checked = data.settings[key] : $(key).value = data.settings[key]; document.querySelectorAll('[data-view]').forEach(button => button.setAttribute('aria-pressed',String(data.settings.views.includes(button.dataset.view)))); }
      context = data; busy = !!data.busy; selected = new Set([...selected].filter(id => data.scenes.some(scene => scene.id === id)));
      if ((frameChanged || frameUpdated && !['width','height','margin','ratioInput'].includes(document.activeElement.id)) && data.current_frame) {
        ['width','height','margin'].forEach(key => { $(key).value = data.current_frame[key]; });
      }
      if (frameChanged || frameUpdated && !['width','height','margin','ratioInput'].includes(document.activeElement.id)) syncRatio();
      if (frameChanged) savedFrameSignature = data.current_frame ? JSON.stringify([data.model,currentId(data),data.current_frame]) : null;
      if (frameChanged) navigationId = currentId(data) || null;
      if (changed) { $('cameraMode').value = 'absolute'; $('cameraFloor').value = '0'; $('cameraHeight').value = '1500'; $('cameraKeep').checked = true; }
      if (frameChanged && data.camera) $('cameraZ').value = Math.round(data.camera.eye_z_mm*100)/100;
      if (data.camera) $('cameraCurrent').textContent = 'Z mắt hiện tại: ' + (Math.round(data.camera.eye_z_mm*100)/100).toLocaleString('vi-VN') + ' mm' + (data.camera.supported ? '' : ' · Hai điểm / Match Photo chưa hỗ trợ');
      if (data.camera) {
        $('fovField').hidden=!data.camera.perspective; $('parallelField').hidden=!!data.camera.perspective;
        $('fovAxis').textContent=data.camera.perspective ? 'FOV API SketchUp · đo theo '+(data.camera.fov_vertical?'chiều dọc':'chiều ngang')+' của khung hiện tại. 1–120°. Chỉ xem trước.' : 'Parallel Projection dùng chiều cao vùng nhìn, không dùng FOV.';
        if (document.activeElement!==$('cameraFov') && data.camera.fov != null) $('cameraFov').value=Math.round(data.camera.fov*1000000)/1000000;
        if (document.activeElement!==$('parallelHeight') && data.camera.height_mm != null) $('parallelHeight').value=Math.round(data.camera.height_mm*1000)/1000;
      }
      renderPresets();
      cameraMode();
      $('selection').textContent = data.selection ? data.selection + ' đối tượng đang chọn' + (data.editing ? ' · đang edit group' : '') : 'Chọn Group / Component trong model';
      $('modelTitle').textContent = data.title; $('sceneCount').textContent = String(data.scenes.length);
      $('frameCleanupCount').textContent = (data.frame_cleanup ? data.frame_cleanup.count : 0) + ' scene đang khóa khung camera';
      $('customNormal').hidden = $('section_axis').value !== 'CUSTOM'; $('sectionSlider').value = $('section_percent').value;
      frameStatus(!!data.frame_active, !!data.grid_active); lockStatus(); showFormat(); render(); showTransfer(data.transfer);
    } else if (event === 'frame' && data) { frameStatus(!!data.frame_active, !!data.grid_active);
    } else if (event === 'result') {
      busy = false; status(data && data.message, !(data && (data.success || data.cancelled)));
      if (!(data && data.success)) { savedFrameSignature=null; frameFailureEpoch++; }
      if (!(data && data.success)) navigationId = context && (context.scenes.find(scene=>scene.selected) || {}).id || null;
      if (data && data.ids) selected = new Set(data.ids);
      enable();
    } else if (event === 'started') {
      busy = true; lastPath = null; $('progress').hidden = false; $('progress').value = 0; $('progress').max = data.total; status('Đang xuất ' + data.total + ' scene…'); enable();
    } else if (event === 'progress' && data) {
      $('progress').value = data.current; status('Đang xuất ' + data.current + '/' + data.total + ': ' + data.name);
    } else if (event === 'exported') {
      busy = false; $('progress').hidden = true; lastPath = data && data.path;
      const detail = data && data.errors && data.errors.length ? '\n' + data.errors.map(error => error.page + ': ' + error.error).join('\n') : '';
      status((data && data.message || 'Xuất không thành công.') + detail, !(data && (data.success || data.cancelled))); enable();
    }
  }};
  document.querySelectorAll('[data-tab]').forEach(button => button.addEventListener('click', () => tab(button.dataset.tab)));
  document.querySelectorAll('[data-view]').forEach(button => button.addEventListener('click', () => button.setAttribute('aria-pressed',String(button.getAttribute('aria-pressed') !== 'true'))));
  function preset(views) { document.querySelectorAll('[data-view]').forEach(button => button.setAttribute('aria-pressed',String(views.includes(button.dataset.view)))); }
  $('preset4').addEventListener('click', () => preset(['ISO','TOP','FRONT','RIGHT'])); $('preset6').addEventListener('click', () => preset(['ISO','TOP','FRONT','RIGHT','BACK','LEFT'])); $('presetNone').addEventListener('click', () => preset([]));
  $('generate').addEventListener('click', () => runSettings('generate')); $('section').addEventListener('click', () => runSettings('section'));
  $('frame').addEventListener('click',()=>commitFrame(true)); $('fit').addEventListener('click',()=>runSettings('fit')); $('toggleGrid').addEventListener('click', () => runSettings('grid'));
  $('toggleFrame').addEventListener('click', () => runSettings('toggle_frame'));
  $('section_axis').addEventListener('change', () => { $('customNormal').hidden = $('section_axis').value !== 'CUSTOM'; });
  $('sectionSlider').addEventListener('input', () => { $('section_percent').value = $('sectionSlider').value; }); $('section_percent').addEventListener('input', () => { $('sectionSlider').value = $('section_percent').value; });
  $('search').addEventListener('input', render); $('onlyVGD').addEventListener('change', render);
  $('selectAll').addEventListener('click', () => { filtered().forEach(scene => selected.add(scene.id)); render(); }); $('selectNone').addEventListener('click', () => { selected.clear(); render(); });
  $('update').addEventListener('click', () => modal('Cập nhật từ đối tượng','Đổi tên và căn lại ' + selected.size + ' scene VGD theo tên, hình học và thiết lập nguồn đã lưu; không cần chọn lại đối tượng. Bố cục camera chỉnh tay sẽ được thay bằng góc tự động.',() => send('update',{ids:[...selected]})));
  $('delete').addEventListener('click', () => modal('Xóa scene đã chọn','Xóa ' + selected.size + ' scene đã đánh dấu?',() => send('delete',{ids:[...selected]})));
  $('goExport').addEventListener('click', () => tab('export')); $('exportButton').addEventListener('click', () => { try { send('export',{ids:[...selected],settings:settings()}); } catch (error) { status(error.message,true); } });
  $('copyScenes').addEventListener('click', () => send('copyScenes',{ids:[...selected]}));
  $('saveScenes').addEventListener('click', () => send('saveScenes',{ids:[...selected],scope:$('sceneScope').value}));
  ['pasteScenes','loadScenes'].forEach(action => $(action).addEventListener('click', () => send(action)));
  $('sceneScope').addEventListener('change',enable);
  $('transferMode').addEventListener('change',renderTransfer);
  $('transferAll').addEventListener('click', () => { if (transfer) transferSelected = new Set(transfer.scenes.map(scene => scene.id)); renderTransfer(); });
  $('transferNone').addEventListener('click', () => { transferSelected.clear(); renderTransfer(); });
  $('transferCancel').addEventListener('click', () => { if (!busy) { clearTransfer(); send('cancelTransfer'); } });
  $('transferApply').addEventListener('click', () => { if (transfer) send('applyTransfer',{token:transfer.token,ids:[...transferSelected],mode:$('transferMode').value}); });
  $('cancel').addEventListener('click', () => send('cancel',{},false)); $('refresh').addEventListener('click', () => send('refresh',{},false));
  $('openFolder').addEventListener('click', () => { if (window.sketchup && lastPath) send('openOutput',{path:lastPath},false); });
  $('format').addEventListener('change',showFormat);
  const ratios = {'16:9':[1920,1080],'4:3':[1600,1200],'3:4':[1200,1600],'1:1':[1500,1500],'9:16':[1080,1920],'A4_L':[2480,1754],'A4_P':[1754,2480]};
  let ratioDirty = false;
  let lockedAspect = 16/9, lockedRatioText = '16:9';
  function syncRatio(updateLock = true) {
    const width = Number($('width').value), height = Number($('height').value);
    if (!(width > 0 && height > 0)) return;
    const gcd = (a,b) => b ? gcd(b,a%b) : a;
    const divisor = gcd(Math.round(width),Math.round(height));
    $('ratioInput').value = Math.round(width)/divisor + ':' + Math.round(height)/divisor;
    if (updateLock) { lockedAspect = width/height; lockedRatioText = $('ratioInput').value; }
    else if ($('ratio_locked').checked) $('ratioInput').value = lockedRatioText;
    const match = Object.entries(ratios).find(([,pair]) => Math.abs(width/height-pair[0]/pair[1]) < 0.000001);
    $('ratio').value = match ? match[0] : 'CUSTOM';
    ratioDirty = false;
  }
  function applyRatioInput() {
    if (!ratioDirty) return;
    const match = $('ratioInput').value.trim().match(/^(\d+(?:\.\d+)?)\s*[:\/]\s*(\d+(?:\.\d+)?)$/);
    if (!match || !(Number(match[1]) > 0 && Number(match[2]) > 0)) throw Error('Nhập tỷ lệ rộng:cao hợp lệ, ví dụ 3:4 hoặc 16:9.');
    const aspect = Number(match[1])/Number(match[2]);
    const edge = Math.max(Number($('width').value),Number($('height').value)) || 1920;
    const width = Math.round(aspect >= 1 ? edge : edge*aspect), height = Math.round(aspect >= 1 ? edge/aspect : edge);
    if (width < 100 || height < 100 || width > 12000 || height > 12000 || width*height > 64000000) throw Error('Tỷ lệ tạo kích thước ngoài 100–12000 px hoặc vượt 64 triệu pixel.');
    $('width').value = width; $('height').value = height; syncRatio();
    lockedAspect = aspect; lockedRatioText = match[1]+':'+match[2];
    if ($('ratio_locked').checked) $('ratioInput').value = lockedRatioText;
  }
  $('ratioInput').addEventListener('input', () => { ratioDirty = true; });
  onCommit($('ratioInput'),()=>commitFrame());
  $('ratio').addEventListener('change', () => { const pair = ratios[$('ratio').value]; if (pair) { $('width').value=pair[0]; $('height').value=pair[1]; syncRatio(); commitFrame(); } });
  $('swapRatio').addEventListener('click', () => { try {
    applyRatioInput(); const aspect = lockedAspect, text = lockedRatioText;
    const width = $('width').value; $('width').value = $('height').value; $('height').value = width; syncRatio();
    if ($('ratio_locked').checked) { lockedAspect = 1/aspect; lockedRatioText = text.split(':').reverse().join(':'); $('ratioInput').value = lockedRatioText; }
    commitFrame();
  } catch(error) { status(error.message,true); } });
  $('lockRatio').addEventListener('click', () => { try { applyRatioInput(); $('ratio_locked').checked = !$('ratio_locked').checked; syncRatio(); lockStatus(); } catch(error) { status(error.message,true); } });
  ['width','height'].forEach(key => $(key).addEventListener('input', () => {
    const value = Number($(key).value);
    if ($('ratio_locked').checked && Number.isFinite(value) && value > 0) {
      $(key === 'width' ? 'height' : 'width').value = Math.round(key === 'width' ? value/lockedAspect : value*lockedAspect);
    }
    syncRatio(!$('ratio_locked').checked);
  }));
  ['width','height','margin'].forEach(key=>onCommit($(key),()=>commitFrame()));

  function onCommit(input, callback) {
    input.addEventListener('blur',callback);
    input.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();callback();}});
  }
  function ratioText(width,height) {
    const gcd=(a,b)=>b?gcd(b,a%b):a, divisor=gcd(Math.round(width),Math.round(height));
    return Math.round(width)/divisor+':'+Math.round(height)/divisor;
  }
  function dimensionsForRatio(text,edge) {
    const match=text.trim().match(/^(\d+(?:\.\d+)?)\s*[:\/]\s*(\d+(?:\.\d+)?)$/);
    if(!match || !(Number(match[1])>0 && Number(match[2])>0)) throw Error('Nhập tỷ lệ hợp lệ, ví dụ 3:4.');
    const aspect=Number(match[1])/Number(match[2]);
    return aspect>=1?[Math.round(edge),Math.round(edge/aspect)]:[Math.round(edge*aspect),Math.round(edge)];
  }
  function readFrame(width,height,margin) {
    if([width,height,margin].some(input=>!input.value.trim() || !Number.isFinite(Number(input.value)))) throw Error('Nhập đầy đủ rộng, cao và lề.');
    const value={width:Math.round(Number(width.value)),height:Math.round(Number(height.value)),margin:Number(margin.value)};
    if(value.width<100 || value.height<100 || value.width>12000 || value.height>12000 || value.width*value.height>64000000) throw Error('Khung: 100–12000 px, tối đa 64 triệu pixel.');
    if(value.margin<0 || value.margin>100) throw Error('Lề cần nằm trong 0–100%.');
    return value;
  }
  function commitFrame(force=false) { try {
    if(!context || busy) return;
    applyRatioInput(); const value=readFrame($('width'),$('height'),$('margin'));
    const current=context.scenes.find(scene=>scene.selected);
    const signature=JSON.stringify([context.model,current?.id,value]);
    if(!force && signature===savedFrameSignature) return;
    savedFrameSignature=signature;
    if(current) send('saveFrames',{ids:[current.id],frame:value},false);
    else send('frame',{settings:{...context.settings,...value}},false);
  } catch(error) { status(error.message,true); } }
  function renderPresets() {
    const signature=JSON.stringify([context.model,context.presets || {}]); if(signature===presetSignature) return;
    presetSignature=signature;
    ['namedPreset','batchPreset'].forEach(id=>{const select=$(id),previous=select.value;select.replaceChildren(new Option('Chọn preset…',''));Object.keys(context.presets || {}).sort().forEach(name=>select.add(new Option(name,name)));select.value=previous;});
  }
  $('namedPreset').addEventListener('change',()=>{const name=$('namedPreset').value,value=context.presets?.[name];if(value){['width','height','margin'].forEach(key=>$(key).value=value[key]);$('presetName').value=name;syncRatio();commitFrame();}enable();});
  $('batchPreset').addEventListener('change',()=>{const value=context.presets?.[$('batchPreset').value];if(value){$('batchWidth').value=value.width;$('batchHeight').value=value.height;$('batchMargin').value=value.margin;}});
  $('savePreset').addEventListener('click',()=>{try {applyRatioInput();const name=$('presetName').value.trim();if(!name) throw Error('Nhập tên preset.');send('framePreset',{name,frame:readFrame($('width'),$('height'),$('margin'))});}catch(error){status(error.message,true);}});
  $('deletePreset').addEventListener('click',()=>send('framePreset',{name:$('namedPreset').value,delete:true}));
  $('applyBatchFrame').addEventListener('click',()=>{try {send('saveFrames',{ids:[...selected],frame:readFrame($('batchWidth'),$('batchHeight'),$('batchMargin')),keep_ratio:$('batchKeepRatio').checked});}catch(error){status(error.message,true);}});
  function groupName(scene) {return scene.group || scene.name.replace(/_(ISO|TOP|FRONT|RIGHT|BACK|LEFT|BOTTOM|SEC.*?)(_\d+)?$/i,'');}
  function selectGroup(query,exact=false) {
    const key=query.trim().toLocaleLowerCase(); if(!key) {status('Nhập tên nhóm scene.',true);return;}
    const matches=context.scenes.filter(scene=>exact?groupName(scene).toLocaleLowerCase()===key:(groupName(scene)+' '+scene.name).toLocaleLowerCase().includes(key));
    matches.forEach(scene=>selected.add(scene.id));render();status('Đã đánh dấu '+matches.length+' scene theo tên.');
  }
  $('selectGroup').addEventListener('click',()=>{const scene=context.scenes.find(scene=>scene.selected);if(scene)selectGroup(groupName(scene),true);});
  $('selectByName').addEventListener('click',()=>selectGroup($('groupQuery').value));
  $('groupQuery').addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();selectGroup($('groupQuery').value);}});
  function previewLens() {try {
    const perspective=context.camera?.perspective,input=perspective?$('cameraFov'):$('parallelHeight');
    const value=Number(input.value);if(!input.value.trim() || !Number.isFinite(value) || (perspective?(value<1 || value>120):value<=0)) throw Error(perspective?'FOV phải từ 1–120°.':'Chiều cao vùng nhìn phải lớn hơn 0.');
    send('cameraPreview',{camera:{kind:'lens',...(perspective?{fov:value}:{height_mm:value})}});
  }catch(error){status(error.message,true);}}
  $('previewLens').addEventListener('click',previewLens);
  ['cameraFov','parallelHeight'].forEach(key=>$(key).addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();previewLens();}}));
  document.querySelectorAll('[data-align]').forEach(button=>button.addEventListener('click',()=>send('cameraPreview',{camera:{kind:'align',axis_mode:$('alignAxes').value,direction:button.dataset.align}})));
  $('updateCurrentView').addEventListener('click',()=>{const scene=context.scenes.find(scene=>scene.selected);if(scene)send('capture',{id:scene.id});});
  $('modalCancel').addEventListener('click',closeModal); $('modalConfirm').addEventListener('click', () => { const action = pendingModal; if (action) action(); closeModal(); });
  document.addEventListener('keydown',event => {
    if (event.key === 'Escape') { finishDrag(); closeModal(); if (!$('transferModal').hidden && !busy) $('transferCancel').click(); }
    if (event.key === 'Enter' && !$('modal').hidden && document.activeElement === $('renameInput')) $('modalConfirm').click();
    const active = document.activeElement;
    if (!['ArrowUp','ArrowDown'].includes(event.key) || !context || busy || dragging || context.editing || !$('modal').hidden || !$('transferModal').hidden || !$('sceneList').contains(active) || active.matches('input,select,textarea,[contenteditable]') || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return;
    const scenes = filtered(); if (!scenes.length) return;
    let index = scenes.findIndex(scene=>scene.id===(navigationId || (context.scenes.find(item=>item.selected) || {}).id));
    index = index<0 ? (event.key==='ArrowDown'?0:scenes.length-1) : Math.max(0,Math.min(scenes.length-1,index+(event.key==='ArrowDown'?1:-1)));
    event.preventDefault(); if (scenes[index].id === navigationId) return;
    navigationId = scenes[index].id; $('sceneList').focus({preventScroll:true});
    send('visit',{id:navigationId});
    const row = [...$('sceneList').children].find(item=>item.dataset.id===navigationId); if(row) row.scrollIntoView({block:'nearest'});
  });
  $('removeAllFrames').addEventListener('click', () => modal('Bỏ khung xám để gửi SKP','Bỏ khung xám của tất cả ' + context.frame_cleanup.count + ' scene có khung trong model và view hiện tại, kể cả scene ngoài VGD. Giữ kích thước xuất VGD đã lưu; khung nhìn theo cửa sổ SketchUp. Sau đó lưu SKP để gửi. Có thể dùng Khôi phục khung nếu cần.',()=>send('removeAllFrames')));
  $('restoreAllFrames').addEventListener('click', () => send('restoreAllFrames'));
  $('theme').addEventListener('click', () => { document.body.classList.toggle('dark'); try { localStorage.setItem('VGD.Scenes.Theme',document.body.classList.contains('dark')?'dark':'light'); } catch (_) {} });
  enable(); showFormat(); cameraMode();
  if (window.sketchup) window.sketchup.ready();
  setInterval(() => { if (context && !busy && !dragging && $('modal').hidden && window.sketchup) send('refresh',{},false); },2000);
});
