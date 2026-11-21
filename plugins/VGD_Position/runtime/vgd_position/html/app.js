'use strict';
// Giao diện VGD Position: danh sách món đang chọn, ô tọa độ X, Y, Z (mm), xem trước rồi mới áp dụng.
// Dữ liệu từ Ruby đến qua window.VGD.receive; lệnh đi qua window.sketchup (ui/panel.rb).
const $ = id => document.getElementById(id);
const node = (tag, text, cls) => { const el = document.createElement(tag); if (text !== undefined) el.textContent = text; if (cls) el.className = cls; return el; };
const call = (name, payload) => { if (window.sketchup && window.sketchup[name]) window.sketchup[name](payload === undefined ? '' : JSON.stringify(payload)); };
let previewed = false; // chỉ áp dụng sau khi đã xem trước đúng với các ô hiện tại

function message(text, isError) {
  const el = $('message');
  el.textContent = text;
  el.classList.toggle('error', !!isError);
}
function setPreviewed(value) {
  previewed = value;
  $('apply').disabled = !value;
}
function payload() {
  return {mode: $('mode').value, values: {x: $('x').value, y: $('y').value, z: $('z').value}};
}
function renderItems(data) {
  const list = $('items');
  list.replaceChildren();
  $('count').textContent = data.count ? `${data.count} món` : 'Chưa chọn món nào trong SketchUp.';
  data.items.forEach(item => {
    const li = node('li', undefined, 'item' + (item.locked ? ' locked' : ''));
    li.append(node('span', item.name, 'name'), node('span', `X ${item.origin[0]} · Y ${item.origin[1]} · Z ${item.origin[2]}`, 'pos'));
    if (item.locked) li.append(node('span', 'khóa', 'badge'));
    list.append(li);
  });
  const absolute = $('mode').querySelector('option[value="absolute"]');
  absolute.disabled = !data.can_absolute;
  if (!data.can_absolute && $('mode').value === 'absolute') $('mode').value = 'relative';
  $('result').replaceChildren();
  setPreviewed(false);
}
function renderPreview(data) {
  const box = $('result');
  box.replaceChildren();
  data.moves.forEach(m => box.append(node('p', `${m.name}: ΔX ${m.delta[0]} · ΔY ${m.delta[1]} · ΔZ ${m.delta[2]} mm, tới (${m.target.join(', ')})`)));
  data.skipped.forEach(s => box.append(node('p', `Bỏ qua ${s.name}: ${s.reason}`, 'muted')));
  setPreviewed(data.moves.length > 0);
  message(data.moves.length ? `Sẽ dời ${data.moves.length} món. Bấm Áp dụng để thực hiện.` : 'Không có món nào cần dời.');
}

window.VGD = {
  receive(event, data) {
    if (event === 'items') renderItems(data);
    else if (event === 'preview') renderPreview(data);
    else if (event === 'done') {
      $('result').replaceChildren();
      setPreviewed(false);
      const skipped = data.skipped.length ? ` Bỏ qua ${data.skipped.length} món.` : '';
      message(`Đã dời ${data.moved} món.${skipped}`);
    } else if (event === 'message') message(data.error || data.text, !!data.error);
  },
};

// Mọi thay đổi ô nhập hoặc chế độ thì phải xem trước lại.
['x', 'y', 'z', 'mode'].forEach(id => $(id).addEventListener('input', () => setPreviewed(false)));
$('mode').addEventListener('change', () => setPreviewed(false));
$('preview').addEventListener('click', () => call('preview', payload()));
$('apply').addEventListener('click', () => { if (previewed) call('apply', payload()); });

document.addEventListener('DOMContentLoaded', () => {
  VGDTheme.start({key: 'vgd.position.theme', button: $('theme')});
  call('ready');
});
