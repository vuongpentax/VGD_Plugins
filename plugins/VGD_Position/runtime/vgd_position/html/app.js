'use strict';
// Giao diện VGD Position: danh sách món đang chọn, ba công cụ Dời / Xoay / Scale, ô số có nút ▲▼ và kéo lên xuống.
// Mỗi khung có Xem trước rồi mới Áp dụng; đổi ô thì phải xem trước lại. Ruby đọc chuỗi người dùng nhập và tự đổi đơn vị.
// Dữ liệu từ Ruby đến qua window.VGD.receive; lệnh đi qua window.sketchup (ui/panel.rb).
const $ = id => document.getElementById(id);
const node = (tag, text, cls) => { const el = document.createElement(tag); if (text !== undefined) el.textContent = text; if (cls) el.className = cls; return el; };
const call = (name, payload) => { if (window.sketchup && window.sketchup[name]) window.sketchup[name](payload === undefined ? '' : JSON.stringify(payload)); };

let currentTool = 'move';
let previewed = {};        // khung -> chuỗi JSON của lần xem trước gần nhất (chỉ áp dụng khi khớp với ô hiện tại)
let pendingPreview = null; // {panel, json} đang chờ Ruby trả kết quả xem trước

function message(text, isError) {
  const el = $('message');
  el.textContent = text;
  el.classList.toggle('error', !!isError);
}

// ----- Đọc ô nhập theo từng khung -----
const xyz = prefix => ({x: $(`${prefix}-x`).value, y: $(`${prefix}-y`).value, z: $(`${prefix}-z`).value});
const scaleUniform = () => document.querySelector('input[name="scale-mode"]:checked').value === 'uniform';
function payloadFor(panel) {
  if (panel === 'move_abs' || panel === 'move_off') return {tool: panel, values: xyz(panel)};
  if (panel === 'rotate') return {tool: 'rotate', values: xyz('rotate'), pivot: $('pivot').value};
  // scale: khung "Đều" chỉ có một ô (đọc như hệ số chung), khung "Không đều" có ba ô.
  if (scaleUniform()) return {tool: 'scale', uniform: true, values: {x: $('scale-u').value}, pivot: $('pivot').value};
  return {tool: 'scale', uniform: false, values: xyz('scale'), pivot: $('pivot').value};
}

// ----- Nút Xem trước / Áp dụng -----
function updateButtons() {
  document.querySelectorAll('button[data-action="apply"]').forEach(btn => {
    const panel = btn.dataset.panel;
    btn.disabled = previewed[panel] !== JSON.stringify(payloadFor(panel));
  });
}
function clearPreviews() {
  previewed = {};
  pendingPreview = null;
  updateButtons();
}

// ----- Ô số: nút ▲▼ (giữ để lặp), kéo lên xuống trên ô để đổi nhanh -----
const DRAG_PIXELS_PER_STEP = 2;
const DRAG_START_PIXELS = 3;
const numberParts = text => {
  const match = /^\s*([+-]?(?:\d+\.?\d*|\.\d+))\s*([a-zA-Z]*)\s*$/.exec(text || '');
  return match ? {value: Number(match[1]), unit: match[2]} : null;
};
function stepInput(input, direction) {
  const step = Number(input.dataset.spin) || 1;
  const parts = numberParts(input.value) || {value: 0, unit: ''};
  const next = Number((parts.value + direction * step).toFixed(3));
  input.value = `${next}${parts.unit}`;
  input.dispatchEvent(new Event('input', {bubbles: true}));
}
function enhanceSpinner(input) {
  const wrap = node('span', undefined, 'spin');
  input.replaceWith(wrap);
  const arrows = node('span', undefined, 'arrows');
  const up = node('button', '▲', 'up');
  const down = node('button', '▼', 'down');
  up.type = down.type = 'button';
  up.tabIndex = down.tabIndex = -1;
  up.setAttribute('aria-label', 'Tăng');
  down.setAttribute('aria-label', 'Giảm');
  arrows.append(up, down);
  wrap.append(input, arrows);
  // Nhấn giữ nút: đổi một bước, sau 350 ms thì lặp mỗi 60 ms cho tới khi thả
  [[up, 1], [down, -1]].forEach(([button, direction]) => {
    let timer = null;
    const stop = () => { clearTimeout(timer); clearInterval(timer); timer = null; };
    button.addEventListener('pointerdown', event => {
      event.preventDefault();
      stepInput(input, direction);
      timer = setTimeout(() => { timer = setInterval(() => stepInput(input, direction), 60); }, 350);
    });
    ['pointerup', 'pointerleave', 'pointercancel'].forEach(name => button.addEventListener(name, stop));
  });
  // Kéo trên ô: giữ chuột rồi trượt lên (tăng) hoặc xuống (giảm)
  let drag = null;
  input.addEventListener('pointerdown', event => {
    drag = {y: event.clientY, start: Number(numberParts(input.value)?.value ?? 0), unit: numberParts(input.value)?.unit ?? '', moved: false};
  });
  input.addEventListener('pointermove', event => {
    if (!drag || event.buttons !== 1) return;
    const dy = drag.y - event.clientY;
    if (!drag.moved && Math.abs(dy) < DRAG_START_PIXELS) return;
    drag.moved = true;
    const step = Number(input.dataset.spin) || 1;
    const next = Number((drag.start + Math.round(dy / DRAG_PIXELS_PER_STEP) * step).toFixed(3));
    input.value = `${next}${drag.unit}`;
    input.dispatchEvent(new Event('input', {bubbles: true}));
  });
  ['pointerup', 'pointercancel'].forEach(name => input.addEventListener(name, () => { drag = null; }));
}

// ----- Dữ liệu từ Ruby -----
function renderItems(data) {
  const list = $('items');
  list.replaceChildren();
  $('count').textContent = data.count ? `${data.count} món đang chọn` : 'Chưa chọn món nào trong SketchUp.';
  $('unit').textContent = `Đơn vị của file: ${data.unit}. Gõ thêm mm, cm, m, in hoặc ft sau số để đổi đơn vị cho số đó (ví dụ 1m).`;
  data.items.forEach(item => {
    const li = node('li', undefined, 'item' + (item.locked ? ' locked' : ''));
    li.append(node('span', item.name, 'name'), node('span', `X ${item.origin[0]} · Y ${item.origin[1]} · Z ${item.origin[2]}`, 'pos'));
    if (item.locked) li.append(node('span', 'khóa', 'badge'));
    list.append(li);
  });
  $('result').replaceChildren();
  clearPreviews();
}
function renderPreview(data) {
  const box = $('result');
  box.replaceChildren();
  data.moves.forEach(m => box.append(node('p', `${m.name}: ${m.text}`)));
  if (pendingPreview) {
    previewed[pendingPreview.panel] = pendingPreview.json;
    pendingPreview = null;
  }
  updateButtons();
  message(data.moves.length ? `Sẽ biến đổi ${data.moves.length} món. Bấm Áp dụng để thực hiện.` : 'Không có món nào cần biến đổi.');
}

window.VGD = {
  receive(event, data) {
    if (event === 'items') renderItems(data);
    else if (event === 'preview') renderPreview(data);
    else if (event === 'done') {
      $('result').replaceChildren();
      clearPreviews();
      message(`Đã biến đổi ${data.moved} món.`);
    } else if (event === 'message') {
      pendingPreview = null;
      message(data.error || data.text, !!data.error);
      updateButtons();
    }
  },
};

// ----- Tab, kiểu scale, nút -----
function showTool(tool) {
  currentTool = tool;
  document.querySelectorAll('.tab').forEach(tab => tab.setAttribute('aria-selected', String(tab.dataset.tab === tool)));
  document.querySelectorAll('section.tool').forEach(section => { section.hidden = section.dataset.tool !== tool; });
  $('pivot-row').hidden = tool === 'move';
  updateButtons();
}
document.querySelectorAll('.tab').forEach(tab => tab.addEventListener('click', () => showTool(tab.dataset.tab)));
document.querySelectorAll('input[name="scale-mode"]').forEach(radio => radio.addEventListener('change', () => {
  const uniform = scaleUniform();
  $('scale-uniform').hidden = !uniform;
  $('scale-nonuniform').hidden = uniform;
  updateButtons();
}));

document.querySelectorAll('button[data-action="preview"]').forEach(btn => btn.addEventListener('click', () => {
  const panel = btn.dataset.panel;
  pendingPreview = {panel, json: JSON.stringify(payloadFor(panel))};
  call('preview', payloadFor(panel));
}));
document.querySelectorAll('button[data-action="apply"]').forEach(btn => btn.addEventListener('click', () => {
  const panel = btn.dataset.panel;
  if (previewed[panel] === JSON.stringify(payloadFor(panel))) call('apply', payloadFor(panel));
}));

// Mọi thay đổi ô nhập thì phải xem trước lại
document.querySelectorAll('input[type="text"]').forEach(input => input.addEventListener('input', updateButtons));
document.querySelectorAll('#pivot').forEach(select => select.addEventListener('change', updateButtons));
document.querySelectorAll('input[type="text"][data-spin]').forEach(enhanceSpinner);

document.addEventListener('DOMContentLoaded', () => {
  VGDTheme.start({key: 'vgd.position.theme', button: $('theme')});
  showTool(currentTool);
  call('ready');
});
