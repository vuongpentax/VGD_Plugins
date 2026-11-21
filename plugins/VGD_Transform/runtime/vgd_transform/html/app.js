'use strict';
// Giao diện VGD Transform, theo hộp Transform Type-In của 3ds Max:
// - ô Tuyệt đối hiện giá trị hiện tại của món, chỉ gửi ô người dùng đã sửa; ô Tương đối về 0 sau khi áp dụng;
// - Enter trong ô là thực hiện luôn (không có nút Áp dụng, để cửa sổ gọn);
// - nút ▲▼: bấm, giữ để lặp, kéo lên xuống để đổi nhanh (Ctrl ×10, Alt ×0,1), chuột phải về mặc định;
// - "Xem trực tiếp khi kéo": món chạy theo ▲▼, cả lần kéo là một bước Ctrl+Z.
// Ruby đọc chuỗi người dùng nhập và tự đổi đơn vị. Dữ liệu từ Ruby đến qua window.VGD.receive; lệnh đi qua window.sketchup.
const $ = id => document.getElementById(id);
const node = (tag, text, cls) => { const el = document.createElement(tag); if (text !== undefined) el.textContent = text; if (cls) el.className = cls; return el; };
const call = (name, payload) => { if (window.sketchup && window.sketchup[name]) window.sketchup[name](payload === undefined ? '' : JSON.stringify(payload)); };
const store = { get(key) { try { return localStorage.getItem(key); } catch (_) { return null; } }, set(key, value) { try { localStorage.setItem(key, value); } catch (_) { /* không lưu được thì thôi */ } } };

const LIVE_KEY = 'vgd.transform.live';
const LIVE_INTERVAL_MS = 40;        // gửi tối đa ~25 lần/giây khi kéo trực tiếp
const DRAG_PIXELS_PER_STEP = 2;
const DRAG_START_PIXELS = 3;
const REPEAT_DELAY_MS = 350;
const REPEAT_EVERY_MS = 60;
// Bước của ô độ dài theo đơn vị (khoảng 1 mm)
const LENGTH_STEP = { mm: 1, cm: 0.1, m: 0.001, in: 0.1, ft: 0.01, yd: 0.01 };
const COORD_TEXT = { world: 'World', local: 'Local' };

let state = { unit: 'mm', count: 0, origin: null, center: null, scale: null };

// Dòng đáy bảng: ghi chú (data-note) của chỗ đang rê chuột; còn lại hiện thông báo gần nhất (kết quả / lỗi).
let lastMessage = { text: '', error: false };
let hovering = null;
function renderNote() {
  const el = $('note');
  const note = hovering && hovering.dataset.note;
  el.textContent = note || lastMessage.text;
  el.classList.toggle('error', !note && lastMessage.error);
  el.classList.toggle('hint', !!note);
}
// Thông báo mới được ưu tiên (che ghi chú) cho tới khi chuột rê sang chỗ khác, để không mất kết quả / lỗi sau khi nhấn Enter.
function message(text, isError) {
  lastMessage = { text, error: !!isError };
  hovering = null;
  renderNote();
}
document.addEventListener('pointerover', event => {
  hovering = event.target.closest ? event.target.closest('[data-note]') : null;
  renderNote();
});
document.documentElement.addEventListener('pointerleave', () => { hovering = null; renderNote(); });
const fmt = value => (value === null || value === undefined ? '' : String(Number(Number(value).toFixed(3))));
const boxOf = input => input.closest('.box');
const panelOf = input => boxOf(input).dataset.panel;
const isAbsolute = panel => document.querySelector(`.box[data-panel="${panel}"]`).dataset.kind === 'absolute';
const liveOn = () => $('live').getAttribute('aria-checked') === 'true';

// ----- Đọc ô nhập -----
const xyz = prefix => ({ x: $(`${prefix}-x`).value, y: $(`${prefix}-y`).value, z: $(`${prefix}-z`).value });
// Ô Tuyệt đối: chỉ gửi ô đã sửa, ô còn lại để trống nghĩa là giữ nguyên (tránh làm tròn số hiển thị dời món).
const dirtyXyz = prefix => Object.fromEntries(['x', 'y', 'z'].map(a => { const el = $(`${prefix}-${a}`); return [a, el.dataset.dirty ? el.value : '']; }));
const scaleUniform = () => $('scale-uniform').checked;
function payloadFor(panel) {
  const pivot = $('pivot').value;
  const coord = $('coord').value;
  switch (panel) {
    case 'move_abs': return { tool: panel, values: dirtyXyz(panel), pivot };
    case 'move_off': return { tool: panel, values: xyz(panel), coord };
    case 'rotate': return { tool: panel, values: xyz(panel), pivot, coord };
    case 'scale_abs': return { tool: panel, values: dirtyXyz(panel), pivot };
    default: return scaleUniform()
      ? { tool: 'scale', uniform: true, values: { x: $('scale-u').value }, pivot, coord }
      : { tool: 'scale', uniform: false, values: xyz('scale'), pivot, coord };
  }
}
function apply(panel) {
  call('apply', payloadFor(panel));
}
function inputsOf(panel) {
  return [...document.querySelectorAll(`.box[data-panel="${panel}"] input[type="text"]`)];
}

// ----- Hiển thị trạng thái và giá trị hiện tại -----
// Dòng trạng thái ngắn (cửa sổ gọn); câu đầy đủ ở chú thích khi rê chuột.
function renderStatus() {
  const short = [`${state.unit}${state.unit_known === false ? '?' : ''}`, `${state.count || 0} món`];
  const full = [state.count ? `${state.count} món đang chọn` : 'Chưa chọn group / component nào',
    `đơn vị file: ${state.unit}${state.unit_known === false ? ' (SketchUp trả đơn vị lạ, tạm dùng mm)' : ''}`];
  if (state.skipped) {
    short.push(`bỏ ${state.skipped}`);
    full.push(`bỏ qua ${state.skipped} đối tượng không phải group / component`);
  }
  $('status').textContent = short.join(' · ');
  $('status').dataset.note = full.join(' · ');
  $('status').classList.toggle('warn', !!state.skipped || state.unit_known === false);
}
// Nút khóa như Lock của SketchUp: khóa hết (ổ đóng, tô màu), không khóa (ổ mở), lẫn lộn (ổ đóng, tô nhạt).
function renderLock() {
  const button = $('lock');
  button.dataset.state = state.lock || 'none';
  button.disabled = !state.lock;
  button.setAttribute('aria-pressed', state.lock === 'all' ? 'true' : state.lock === 'mixed' ? 'mixed' : 'false');
}
function fillAbsolute() {
  const fill = (panel, values) => ['x', 'y', 'z'].forEach((a, i) => {
    const input = $(`${panel}-${a}`);
    if (input.dataset.dirty && document.activeElement === input) return; // đang gõ thì không ghi đè
    delete input.dataset.dirty;
    const value = values ? values[i] : null;
    input.value = fmt(value);
    input.placeholder = state.count === 0 ? '—' : (value === null || value === undefined ? 'khác nhau' : '');
  });
  fill('move_abs', $('pivot').value === 'item' ? state.origin : state.center);
  fill('scale_abs', state.scale);
}
function resetOffset(panel) {
  inputsOf(panel).forEach(input => { input.value = input.dataset.default; delete input.dataset.dirty; });
}
function updateCoordTitles() {
  const text = COORD_TEXT[$('coord').value];
  document.querySelectorAll('.coord-title').forEach(h => { h.textContent = `${h.dataset.title} · ${text}`; });
}

// ----- Kéo trực tiếp: gửi tối đa mỗi LIVE_INTERVAL_MS, lần cuối luôn được gửi -----
let livePanel = null;
let liveTimer = null;
function liveBegin(panel) {
  livePanel = panel;
  call('live_start');
}
function liveChanged() {
  if (!livePanel || liveTimer) return;
  liveTimer = setTimeout(() => { liveTimer = null; if (livePanel) call('live', payloadFor(livePanel)); }, LIVE_INTERVAL_MS);
}
function liveEnd() {
  if (!livePanel) return;
  clearTimeout(liveTimer);
  liveTimer = null;
  const panel = livePanel;
  call('live', payloadFor(panel));
  livePanel = null;
  call('live_end');
  // Như spinner Offset của 3ds Max: kéo xong thì ô tương đối về 0 (món đã ở chỗ mới)
  if (isAbsolute(panel)) inputsOf(panel).forEach(input => delete input.dataset.dirty);
  else resetOffset(panel);
}

// ----- Ô số -----
const numberParts = text => {
  const match = /^\s*([+-]?(?:\d+\.?\d*|\.\d+))\s*([a-zA-Z]*)\s*$/.exec(text || '');
  return match ? { value: Number(match[1]), unit: match[2] } : null;
};
function stepOf(input, unit, event) {
  const spin = input.dataset.spin;
  const base = unit ? (LENGTH_STEP[unit.toLowerCase()] || 1) : spin === 'len' ? (LENGTH_STEP[state.unit] || 1) : Number(spin) || 1;
  return base * (event.ctrlKey ? 10 : event.altKey ? 0.1 : 1);
}
function setValue(input, value, unit) {
  input.value = `${Number(value.toFixed(4))}${unit}`;
  input.dataset.dirty = '1';
  if (livePanel) liveChanged();
}
function enhanceSpinner(input) {
  const wrap = node('span', undefined, 'spin');
  input.replaceWith(wrap);
  const arrows = node('span', undefined, 'arrows');
  const up = node('button', '▲', 'up');
  const down = node('button', '▼', 'down');
  [up, down].forEach(b => { b.type = 'button'; b.tabIndex = -1; });
  up.setAttribute('aria-label', 'Tăng (kéo lên xuống để đổi nhanh, chuột phải về mặc định)');
  down.setAttribute('aria-label', 'Giảm (kéo lên xuống để đổi nhanh, chuột phải về mặc định)');
  arrows.dataset.note = '▲▼: bấm một bước, giữ để lặp, kéo lên xuống để đổi nhanh (Ctrl ×10, Alt ×0,1); chuột phải về mặc định.';
  arrows.append(up, down);
  wrap.append(input, arrows);

  let press = null;
  const stopRepeat = () => { if (press) { clearTimeout(press.timer); clearInterval(press.timer); press.timer = null; } };
  [[up, 1], [down, -1]].forEach(([button, direction]) => {
    button.addEventListener('pointerdown', event => {
      if (event.button !== 0) return;
      event.preventDefault();
      const parts = numberParts(input.value);
      if (!parts && input.value.trim() === '' && isAbsolute(panelOf(input)) && state.count > 1) {
        message('Các món khác nhau trên trục này. Gõ số rồi nhấn Enter.', true);
        return;
      }
      const start = parts || { value: 0, unit: '' };
      press = { y: event.clientY, start, moved: false, timer: null };
      if (button.setPointerCapture && event.pointerId !== undefined) { try { button.setPointerCapture(event.pointerId); } catch (_) { /* bỏ qua */ } }
      if (liveOn()) liveBegin(panelOf(input));
      const step = () => { const p = numberParts(input.value) || start; setValue(input, p.value + direction * stepOf(input, p.unit, event), p.unit); };
      step();
      press.timer = setTimeout(() => { press.timer = setInterval(step, REPEAT_EVERY_MS); }, REPEAT_DELAY_MS);
    });
    button.addEventListener('pointermove', event => {
      if (!press || !(event.buttons & 1)) return;
      const dy = press.y - event.clientY;
      if (!press.moved && Math.abs(dy) < DRAG_START_PIXELS) return;
      press.moved = true;
      stopRepeat();
      const steps = Math.round(dy / DRAG_PIXELS_PER_STEP);
      setValue(input, press.start.value + steps * stepOf(input, press.start.unit, event), press.start.unit);
    });
    const release = () => { if (!press) return; stopRepeat(); press = null; liveEnd(); };
    ['pointerup', 'pointercancel', 'lostpointercapture'].forEach(name => button.addEventListener(name, release));
    // Chuột phải: về giá trị mặc định (Tuyệt đối dời 0, scale 1; ô tương đối trống = 0)
    button.addEventListener('contextmenu', event => {
      event.preventDefault();
      input.value = input.dataset.default;
      if (input.dataset.default === '') delete input.dataset.dirty; else input.dataset.dirty = '1';
      if (liveOn() && isAbsolute(panelOf(input))) apply(panelOf(input));
    });
  });
}

// ----- Dữ liệu từ Ruby -----
window.VGD = {
  receive(event, data) {
    if (event === 'state') {
      state = data;
      renderStatus();
      renderLock();
      fillAbsolute();
    } else if (event === 'done') {
      const skipped = data.skipped ? ` Bỏ qua ${data.skipped} đối tượng không phải group / component.` : '';
      message(`Đã biến đổi ${data.moved} món.${skipped}`);
      if (isAbsolute(data.tool)) inputsOf(data.tool).forEach(input => delete input.dataset.dirty);
      else resetOffset(data.tool);
    } else if (event === 'tool') {
      showTool(data.tool);
    } else if (event === 'message') {
      message(data.error || data.text, !!data.error);
    }
  },
};

// ----- Tab, lựa chọn, Enter -----
function showTool(tool) {
  document.querySelectorAll('.tabs .tab').forEach(tab => tab.setAttribute('aria-selected', String(tab.dataset.tab === tool)));
  document.querySelectorAll('section.tool').forEach(section => { section.hidden = section.dataset.tool !== tool; });
}
document.querySelectorAll('.tabs .tab').forEach(tab => tab.addEventListener('click', () => showTool(tab.dataset.tab)));
$('scale-uniform').addEventListener('change', () => {
  $('scale-one').hidden = !scaleUniform();
  $('scale-xyz').hidden = scaleUniform();
});
$('pivot').addEventListener('change', fillAbsolute);
$('coord').addEventListener('change', updateCoordTitles);
$('live-label').addEventListener('click', () => $('live').click());
$('lock').addEventListener('click', () => call('lock'));
$('live').addEventListener('click', () => {
  const next = !liveOn();
  $('live').setAttribute('aria-checked', String(next));
  store.set(LIVE_KEY, next ? '1' : '0');
});

document.querySelectorAll('input[type="text"]').forEach(input => {
  input.addEventListener('input', () => { input.dataset.dirty = '1'; });
  input.addEventListener('keydown', event => {
    if (event.key !== 'Enter') return;
    event.preventDefault();
    apply(panelOf(input));
  });
});
document.querySelectorAll('input[type="text"][data-spin]').forEach(enhanceSpinner);

document.addEventListener('DOMContentLoaded', () => {
  VGDTheme.start({ key: 'vgd.transform.theme', button: $('theme') });
  if (store.get(LIVE_KEY) === '0') $('live').setAttribute('aria-checked', 'false');
  showTool('move');
  updateCoordTitles();
  call('ready');
});
