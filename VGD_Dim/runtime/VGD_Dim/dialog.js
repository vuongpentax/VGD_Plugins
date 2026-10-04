'use strict';
const field = id => document.getElementById(id);
window.VGDForm = {
  error(message) { field('error').textContent = message; field('error').hidden = false; },
  clearError() { field('error').hidden = true; field('error').textContent = ''; },
  busy(value) {
    ['apply','dim_info','text_info'].forEach(id => { field(id).disabled = value; });
    field('apply').textContent = value ? 'ĐANG ÁP DỤNG…' : 'ÁP DỤNG · APPLY';
  }
};
field('settings').addEventListener('submit', event => {
  event.preventDefault();
  VGDForm.clearError();
  sketchup.apply(JSON.stringify({
    dim_color: field('dim_color').value, text_color: field('text_color').value,
    dim_endpoint: field('dim_endpoint').value, label_endpoint: field('label_endpoint').value
  }));
});
field('dim_info').addEventListener('click', () => { VGDForm.clearError(); sketchup.dim_info(); });
field('text_info').addEventListener('click', () => { VGDForm.clearError(); sketchup.text_info(); });
field('cancel').addEventListener('click', () => sketchup.cancel());
