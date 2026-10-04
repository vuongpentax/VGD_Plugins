'use strict';
(() => {
  const $ = id => document.getElementById(id); let timer, busy = false;
  function options() { return { index:Number($('material').value),flatten:Number($('flatten').value),feather:Number($('feather').value),resolution:Number($('resolution').value),autoskip:$('autoskip').checked }; }
  function send(action) { if (busy && action !== 'close') return; busy = true; $('busy').textContent='Đang xử lý…'; if (window.sketchup) sketchup.seam(action,JSON.stringify(options())); }
  function idle() { busy=false; $('busy').textContent=''; }
  function later() { $('flattenValue').textContent=$('flatten').value+'%'; $('featherValue').textContent=$('feather').value+'%'; clearTimeout(timer); timer=setTimeout(() => send('preview'),350); }
  window.VGDSeam = {
    start(names) { $('material').replaceChildren(...names.map((name,i) => new Option(name,String(i)))); idle(); send('preview'); },
    preview(data) { if (data.index===Number($('material').value)) { $('before').style.backgroundImage=`url(${JSON.stringify(data.before)})`; $('after').style.backgroundImage=`url(${JSON.stringify(data.after)})`; $('beforeError').textContent='Lệch viền '+data.before_error; $('afterError').textContent='Lệch viền '+data.after_error; $('seamStatus').textContent=`Ảnh ${data.width} × ${data.height} px. Kích thước vật liệu thật được giữ khi áp dụng.`; } idle(); },
    message(text,error=false) { $('seamStatus').textContent=text; $('seamStatus').className=error?'error':''; idle(); }
  };
  $('preview').onclick=() => send('preview'); $('apply').onclick=() => send('apply'); $('all').onclick=() => send('all'); $('close').onclick=() => send('close');
  $('material').onchange=$('resolution').onchange=$('autoskip').onchange=() => send('preview'); $('flatten').oninput=$('feather').oninput=later;
  $('preset').onchange=() => { const presets={light:[20,2],medium:[50,4],strong:[80,7]}; const [a,b]=presets[$('preset').value]; $('flatten').value=a; $('feather').value=b; later(); };
  send('ready');
})();
