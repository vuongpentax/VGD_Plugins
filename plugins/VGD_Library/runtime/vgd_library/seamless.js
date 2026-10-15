'use strict';
(() => {
  const $ = id => document.getElementById(id); let timer, busy = false;
  function setTheme(theme) {
    const dark = theme === 'dark'; document.body.classList.toggle('dark', dark);
    $('themeToggle').setAttribute('aria-pressed', String(dark));
    $('themeLabel').textContent = dark ? 'Giao diện sáng' : 'Giao diện tối';
    $('themeToggle').title = dark ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối';
    $('themeIcon').innerHTML = dark
      ? '<circle cx="12" cy="12" r="3.5"/><path d="M12 2.5v2m0 15v2M4.3 4.3l1.4 1.4m12.6 12.6 1.4 1.4M2.5 12h2m15 0h2M4.3 19.7l1.4-1.4M18.3 5.7l1.4-1.4"/>'
      : '<path d="M20 14.4A8 8 0 0 1 9.6 4 8 8 0 1 0 20 14.4Z"/>';
    try { localStorage.setItem('VGD.Library.Theme', dark ? 'dark' : 'light'); } catch (_) {}
  }
  let savedTheme = 'dark'; try { savedTheme = localStorage.getItem('VGD.Library.Theme') || savedTheme; } catch (_) {}
  setTheme(savedTheme); $('themeToggle').addEventListener('click', () => setTheme(document.body.classList.contains('dark') ? 'light' : 'dark'));
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
