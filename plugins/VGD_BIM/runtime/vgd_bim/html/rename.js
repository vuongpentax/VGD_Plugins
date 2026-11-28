'use strict';
// Cửa sổ Đổi tên (rename.html). Ruby (ui/rename_window.rb) gửi các món đang chọn trong SketchUp ('items'), mẫu tên ('config', 'templates');
// giao diện ghép tên mới = tiền tố + tên + hậu tố (cách nhau một dấu cách), Thay → Bằng, CHỮ HOA, số thứ tự khi trùng, rồi gửi 'rename_apply'.
// Tên phần "tên" để trống thì lấy tên hiện tại. Mọi phần tính ở đây chỉ để xem trước và gửi đi; Ruby kiểm tra lại trước khi ghi.
const MAX_NAME = 200;          // như Rename::MAX_NAME
const MAX_TEMPLATE = 100;      // như RenameList::MAX_TEMPLATE
const PARTS = [{key: 'prefix', title: 'Tiền tố'}, {key: 'name', title: 'Tên'}, {key: 'suffix', title: 'Hậu tố'}];
const OPTIONS_KEY = 'VGD_BIM_rename_options';
const state = {items: [], total: 0, parts: new Map(), sel: new Set(), open: new Set(), last: null, edit: null, sort: null, desc: false,
  upper: false, numbered: true, hide: false, templates: {prefix: [], name: [], suffix: []}};

const $ = id => document.getElementById(id);
const el = (tag, cls, text) => { const n = document.createElement(tag); if (cls) n.className = cls; if (text !== undefined) n.textContent = text; return n; };
function call(name, ...args) { if (window.sketchup && window.sketchup[name]) window.sketchup[name](...args); }
function status(text, error) { const s = $('status'); s.textContent = text; s.classList.toggle('err', !!error); }

function loadOptions() {
  try { const o = JSON.parse(localStorage.getItem(OPTIONS_KEY) || '{}'); ['upper', 'numbered', 'hide'].forEach(k => { if (typeof o[k] === 'boolean') state[k] = o[k]; }); } catch (_) { /* không đọc được thì dùng mặc định */ }
}
function saveOptions() {
  try { localStorage.setItem(OPTIONS_KEY, JSON.stringify({upper: state.upper, numbered: state.numbered, hide: state.hide})); } catch (_) { /* không lưu được thì thôi */ }
}

// ---- Tên mới ----
const partsOf = id => state.parts.get(id) || {prefix: '', name: '', suffix: ''};
function setPart(id, key, value) { const p = Object.assign({}, partsOf(id), {[key]: value}); if (!p.prefix && !p.name && !p.suffix) state.parts.delete(id); else state.parts.set(id, p); }
// Tên mới trước khi đánh số.
function composed(item) {
  const p = partsOf(item.id), find = $('find').value;
  let base = p.name.trim() || item.name.trim();
  if (find) base = base.split(find).join($('repl').value).trim();
  let text = [p.prefix.trim(), base, p.suffix.trim()].filter(Boolean).join(' ');
  if (state.upper) text = text.toUpperCase();
  return text;
}
// {id => {text, status}}: status new (sẽ đổi), same (giữ nguyên), long (quá dài), locked, none (chưa có tên mới). Đánh số theo thứ tự chọn, không theo cách xếp.
function proposals() {
  const out = new Map(), groups = new Map();
  state.items.forEach(item => {
    if (item.locked) { out.set(item.id, {text: '', status: 'locked'}); return; }
    const text = composed(item);
    if (!text) { out.set(item.id, {text: '', status: 'none'}); return; }
    if (text === item.name) { out.set(item.id, {text, status: 'same'}); return; }
    out.set(item.id, {text, status: 'new'});
    if (!groups.has(text)) groups.set(text, []);
    groups.get(text).push(item.id);
  });
  if (state.numbered) groups.forEach(ids => {
    if (ids.length < 2) return;
    const width = Math.max(2, String(ids.length).length);
    ids.forEach((id, i) => { out.get(id).text += ' ' + String(i + 1).padStart(width, '0'); });
  });
  out.forEach(p => { if (p.status === 'new' && p.text.length > MAX_NAME) p.status = 'long'; });
  return out;
}

// ---- Dòng: món cùng định nghĩa (từ 2 món) gom thành một dòng mở ra được ----
function rows() {
  const byDef = new Map();
  state.items.forEach(item => { if (!byDef.has(item.def_id)) byDef.set(item.def_id, []); byDef.get(item.def_id).push(item); });
  const top = [];
  byDef.forEach((list, def) => top.push(list.length > 1 ? {key: 'd' + def, def, label: list[0].definition, kids: list} : {key: 'i' + list[0].id, item: list[0]}));
  return top;
}
function rowName(row) { return row.kids ? row.label : row.item.name; }
function rowNew(row, plan) { const list = row.kids || [row.item]; return plan.get(list[0].id).text; }
function visibleRows(plan) {
  let top = rows();
  if (state.sort) {
    const key = state.sort === 'name' ? rowName : r => rowNew(r, plan) || rowName(r);
    top = top.map((r, i) => [r, i]).sort((a, b) => key(a[0]).localeCompare(key(b[0]), 'vi', {numeric: true}) * (state.desc ? -1 : 1) || a[1] - b[1]).map(x => x[0]);
  }
  const out = [];
  top.forEach(r => { out.push(r); if (r.kids && state.open.has(r.key)) r.kids.forEach(item => out.push({key: 'i' + item.id, item, kid: true})); });
  return out;
}
const itemsOf = row => row.kids || [row.item];
function targets() {
  if (!state.sel.size) return state.items.filter(item => !item.locked);
  const out = new Map();
  visibleRows(proposals()).filter(r => state.sel.has(r.key)).forEach(r => itemsOf(r).forEach(item => { if (!item.locked) out.set(item.id, item); }));
  return [...out.values()];
}

const SAVE_ICON = '<svg viewBox="0 0 24 24"><rect x="8" y="8" width="14" height="14" rx="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>';
function newCell(row, plan) {
  const cell = el('span', 'c-new'), list = itemsOf(row);
  if (state.edit === row.key) {
    const names = [...new Set(list.map(item => partsOf(item.id).name))];
    const input = el('input', 'edit'); input.type = 'text'; input.maxLength = MAX_NAME; input.spellcheck = false;
    input.value = names.length === 1 ? names[0] : ''; input.placeholder = rowName(row) || 'Nhập tên mới'; input.setAttribute('aria-label', 'Tên mới');
    let done = false;
    const finish = keep => { if (done) return; done = true; if (keep) list.forEach(item => { if (!item.locked) setPart(item.id, 'name', input.value.trim()); }); state.edit = null; render(); };
    input.onkeydown = e => { e.stopPropagation(); if (e.key === 'Enter') finish(true); if (e.key === 'Escape') finish(false); };
    input.onblur = () => finish(true);
    input.onclick = e => e.stopPropagation();
    cell.append(input); setTimeout(() => { input.focus(); input.select(); }, 0);
    return cell;
  }
  if (list.every(item => item.locked)) { cell.append(el('span', 'txt lock', 'Bị khóa')); return cell; }
  const shown = [...new Set(list.map(item => plan.get(item.id)).filter(p => p.status !== 'locked').map(p => p.text + '\u0000' + p.status))];
  if (shown.length > 1) { cell.append(el('span', 'txt ph', 'Nhiều tên')); return cell; }
  const [text, kind] = shown[0].split('\u0000');
  if (!text || (kind === 'same' && !list.some(item => state.parts.has(item.id)))) return cell; // chưa đặt gì: để trống
  cell.append(el('span', 'txt ' + (kind === 'same' ? 'same' : kind === 'long' ? 'bad' : 'new'), text));
  if (kind === 'long') cell.title = `Tên mới dài quá ${MAX_NAME} ký tự, sẽ không đổi.`;
  return cell;
}
function render() {
  const plan = proposals(), host = $('rows');
  host.replaceChildren();
  let number = 0;
  visibleRows(plan).forEach(row => {
    const line = el('div', 'rn-row' + (state.sel.has(row.key) ? ' sel' : '') + (row.kid ? ' kid' : ''));
    line.dataset.key = row.key;
    line.append(el('span', 'c-id', row.kid ? '' : String(++number)));
    const name = el('span', 'c-name');
    if (row.kids) {
      const fold = el('span', 'fold' + (state.open.has(row.key) ? ' open' : ''), '›'); fold.title = 'Mở / thu các món cùng định nghĩa';
      fold.onclick = e => { e.stopPropagation(); state.open.has(row.key) ? state.open.delete(row.key) : state.open.add(row.key); render(); };
      name.append(fold);
    }
    const current = rowName(row);
    name.append(el('span', 'txt' + (current ? '' : ' ph'), current || 'Chưa đặt tên'));
    if (row.kids) name.append(el('span', 'cnt', String(row.kids.length)));
    if (current && !row.kids) {
      const save = el('span', 'copy'); save.title = 'Lưu tên này vào mẫu Tên'; save.innerHTML = SAVE_ICON;
      save.onclick = e => { e.stopPropagation(); addTemplate('name', current); };
      name.append(save);
    }
    line.append(name, newCell(row, plan));
    host.append(line);
  });
  if (!state.items.length) host.append(el('div', 'rn-empty', 'Chọn group hoặc component trong SketchUp để đổi tên. Danh sách tự cập nhật theo vùng chọn.'));
  const changes = [...plan.values()].filter(p => p.status === 'new').length;
  $('apply').textContent = changes ? `Áp dụng (${changes})` : 'Áp dụng';
  $('apply').disabled = !changes;
  $('scope').textContent = !state.total ? 'Chưa chọn món nào trong SketchUp'
    : state.total > state.items.length ? `Đang hiện ${state.items.length} / ${state.total} món đang chọn` : `${state.total} món đang chọn trong SketchUp`;
  $('sort-name').textContent = state.sort === 'name' ? (state.desc ? '▼' : '▲') : '';
  $('sort-new').textContent = state.sort === 'new' ? (state.desc ? '▼' : '▲') : '';
  $('upper').setAttribute('aria-pressed', String(state.upper));
  $('numbered').setAttribute('aria-pressed', String(state.numbered));
  $('auto-hide').setAttribute('aria-checked', String(state.hide));
  renderSets();
}
function pick(row, e) {
  const list = visibleRows(proposals()).map(r => r.key);
  if (e.shiftKey && state.last !== null && list.includes(state.last)) {
    const a = list.indexOf(state.last), b = list.indexOf(row.key);
    list.slice(Math.min(a, b), Math.max(a, b) + 1).forEach(key => state.sel.add(key));
  } else if (e.ctrlKey || e.metaKey) {
    state.sel.has(row.key) ? state.sel.delete(row.key) : state.sel.add(row.key);
    state.last = row.key;
  } else {
    state.sel = new Set([row.key]);
    state.last = row.key;
  }
  paintSelection();
}
// Chỉ tô lại dòng đang chọn và mẫu tên, không vẽ lại danh sách (vẽ lại giữa hai lần bấm làm mất nhấp đúp).
function paintSelection() {
  $('rows').querySelectorAll('.rn-row').forEach(line => line.classList.toggle('sel', state.sel.has(line.dataset.key)));
  renderSets();
}

// ---- Mẫu tên ----
// Bấm một mẫu: đặt phần đó cho các món đang chọn; mọi món đã có đúng mẫu đó thì bấm lại để bỏ.
function useTemplate(key, word) {
  const list = targets();
  if (!list.length) return status('Không có món nào để đặt tên (món bị khóa không đổi được).', true);
  const all = list.every(item => partsOf(item.id)[key] === word);
  list.forEach(item => setPart(item.id, key, all ? '' : word));
  render();
  const part = PARTS.find(p => p.key === key).title.toLowerCase();
  status(all ? `Đã bỏ ${part} "${word}" của ${list.length} món.` : `Đã đặt ${part} "${word}" cho ${list.length} món. Bấm Áp dụng để ghi vào model.`);
}
function addTemplate(key, raw) {
  const word = String(raw || '').trim();
  if (!word) return;
  if (word.length > MAX_TEMPLATE || /[\u0000-\u001f\u007f]/.test(word)) return status(`Mẫu tên tối đa ${MAX_TEMPLATE} ký tự, không có ký tự điều khiển.`, true);
  if (state.templates[key].includes(word)) return status(`"${word}" đã có trong mẫu.`);
  state.templates[key] = [...state.templates[key], word];
  saveTemplates();
  status(`Đã lưu "${word}" vào mẫu ${PARTS.find(p => p.key === key).title.toLowerCase()}.`);
}
function removeTemplate(key, word) { state.templates[key] = state.templates[key].filter(w => w !== word); saveTemplates(); }
function saveTemplates() { call('rename_templates', JSON.stringify(state.templates)); render(); }
function renderSets() {
  const host = $('sets'), list = targets();
  const focus = document.activeElement && document.activeElement.dataset ? document.activeElement.dataset.part : null;
  const drafts = {};
  host.querySelectorAll('input[data-part]').forEach(input => { drafts[input.dataset.part] = input.value; });
  host.replaceChildren();
  PARTS.forEach(part => {
    const words = state.templates[part.key] || [];
    const box = el('div', 'set');
    const title = el('div', 'set-title', part.title); title.append(el('span', 'cnt', String(words.length)));
    const chips = el('div', 'set-list');
    words.forEach(word => {
      const on = list.length > 0 && list.every(item => partsOf(item.id)[part.key] === word);
      const chip = el('div', 'chip' + (on ? ' on' : '')); chip.title = on ? 'Bấm lại để bỏ khỏi các món đang chọn' : 'Bấm để đặt cho các món đang chọn';
      chip.append(el('span', 'txt', word));
      const x = el('button', 'x', '×'); x.type = 'button'; x.title = 'Xóa khỏi mẫu'; x.setAttribute('aria-label', 'Xóa khỏi mẫu');
      x.onclick = e => { e.stopPropagation(); removeTemplate(part.key, word); };
      chip.append(x); chip.onclick = () => useTemplate(part.key, word);
      chips.append(chip);
    });
    if (!words.length) chips.append(el('div', 'set-empty', 'Chưa có mẫu nào'));
    const entry = el('div', 'entry');
    const add = el('button', '', '+'); add.type = 'button'; add.title = 'Thêm vào mẫu'; add.setAttribute('aria-label', 'Thêm vào mẫu');
    const input = el('input'); input.type = 'text'; input.maxLength = MAX_TEMPLATE; input.spellcheck = false; input.dataset.part = part.key;
    input.placeholder = `Thêm ${part.title.toLowerCase()}...`; input.setAttribute('aria-label', `Thêm ${part.title.toLowerCase()}`);
    input.value = drafts[part.key] || '';
    const keep = () => { const v = input.value; input.value = ''; addTemplate(part.key, v); };
    add.onclick = keep; input.onkeydown = e => { e.stopPropagation(); if (e.key === 'Enter') keep(); };
    entry.append(add, input);
    box.append(title, chips, entry); host.append(box);
    if (focus === part.key) setTimeout(() => input.focus(), 0);
  });
}

// ---- Áp dụng ----
function apply() {
  const plan = proposals();
  const changes = state.items.filter(item => plan.get(item.id).status === 'new').map(item => ({id: item.id, name: plan.get(item.id).text}));
  if (!changes.length) return;
  call('rename_apply', JSON.stringify({changes, hide: state.hide}));
}

window.VGD = {receive(event, data) {
  if (event === 'config') {
    if (typeof VGD_I18N !== 'undefined') VGD_I18N.setLanguage(data.language || 'vi'); // VGD_I18N là const của i18n.js, không nằm trên window
    state.templates = Object.assign({prefix: [], name: [], suffix: []}, data.templates || {});
    render();
  }
  if (event === 'templates') { state.templates = Object.assign({prefix: [], name: [], suffix: []}, data || {}); render(); }
  if (event === 'items') {
    state.items = Array.isArray(data.items) ? data.items : [];
    state.total = data.total || state.items.length;
    const ids = new Set(state.items.map(item => item.id));
    [...state.parts.keys()].forEach(id => { if (!ids.has(id)) state.parts.delete(id); });
    const keys = new Set(rows().flatMap(r => [r.key, ...(r.kids || []).map(item => 'i' + item.id)]));
    state.sel = new Set([...state.sel].filter(key => keys.has(key)));
    state.edit = null;
    render();
  }
  if (event === 'applied') { state.parts.clear(); state.sel.clear(); render(); status(data.text || 'Đã đổi tên.'); }
  if (event === 'message') status(data.error || data.text || '', !!data.error);
}};

$('upper').onclick = () => { state.upper = !state.upper; saveOptions(); render(); };
$('numbered').onclick = () => { state.numbered = !state.numbered; saveOptions(); render(); };
$('auto-hide').onclick = () => { state.hide = !state.hide; saveOptions(); render(); status(state.hide ? 'Đổi tên xong sẽ ẩn các món đó trong SketchUp (Edit > Unhide để hiện lại).' : 'Đổi tên xong các món vẫn hiện như cũ.'); };
$('reset').onclick = () => { const list = targets(); list.forEach(item => state.parts.delete(item.id)); render(); status(`Đã bỏ tên mới chưa áp dụng của ${list.length} món.`); };
['find', 'repl'].forEach(id => { $(id).oninput = render; });
$('apply').onclick = apply;
// Bấm / nhấp đúp gắn ở khung danh sách vì mỗi lần bấm dòng được vẽ lại (nhấp đúp vẫn tìm đúng dòng theo data-key).
const rowAt = e => { const line = e.target.closest('.rn-row'); return line ? visibleRows(proposals()).find(r => r.key === line.dataset.key) : null; };
$('rows').onclick = e => { if (e.target.closest('input')) return; const row = rowAt(e); if (row) pick(row, e); };
$('rows').ondblclick = e => { if (e.target.closest('input')) return; const row = rowAt(e); if (row && itemsOf(row).some(item => !item.locked)) { state.edit = row.key; render(); } };
const sortBy = key => { if (state.sort === key) { if (state.desc) { state.sort = null; state.desc = false; } else state.desc = true; } else { state.sort = key; state.desc = false; } render(); };
$('sort-by-name').onclick = () => sortBy('name');
$('sort-by-new').onclick = () => sortBy('new');
document.addEventListener('keydown', e => {
  if (e.target.closest && e.target.closest('input')) return;
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'a') { e.preventDefault(); state.sel = new Set(visibleRows(proposals()).filter(r => !r.kid).map(r => r.key)); paintSelection(); }
  if (e.key === 'Escape' && state.sel.size) { state.sel.clear(); paintSelection(); }
});
// Kéo thanh chia để đổi chiều cao vùng mẫu tên ở dưới.
$('split').onmousedown = e => {
  e.preventDefault(); document.body.classList.add('resizing');
  const sets = $('sets'), start = e.clientY, h0 = sets.offsetHeight;
  const move = ev => { sets.style.height = Math.max(90, Math.min(window.innerHeight - 220, h0 - (ev.clientY - start))) + 'px'; };
  const up = () => { document.body.classList.remove('resizing'); removeEventListener('mousemove', move); removeEventListener('mouseup', up); };
  addEventListener('mousemove', move); addEventListener('mouseup', up);
};
if (window.VGDTheme) VGDTheme.start({key: 'VGD_BIM_theme', button: $('theme')});
loadOptions();
render();
call('ready');
