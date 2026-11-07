'use strict';
// Ảnh món đồ: cột Ảnh trong bảng, tab Hình ảnh, nút Cập nhật ảnh, kéo thả / dán / chọn file ảnh riêng.
// Ảnh chỉ được chụp khi người dùng bấm nút. Dùng các hàm chung của app.js ($, node, card, button, call, message, tableState...) vào lúc gọi.
const imagesState={rows:[],only:false,limit:24,target:null,full:new Map(),fullQueue:[],fullWaiting:null,thumbs:new Map(),thumbPending:new Set()};
const captureState={busy:false,done:0,total:0};
const THUMB_BATCH=60,PASTE_LIMIT=20*1024*1024,PNG_SAFE_CHARS=Math.floor(7*1024*1024*4/3); // dưới giới hạn 8 MB của phía Ruby
const imageRows=()=>[...(tableState.data?tableState.data.rows:[]),...imagesState.rows];
function dimsText(row){const u=LENGTH_UNITS[lengthUnit()];return [row.lenX,row.lenY,row.lenZ].map(v=>fmt(toUnit(v),u.digits)).join(' × ')+' '+lengthUnit();}

// ---- Ảnh nhỏ trong bảng ----
function thumbCell(td,row){
  td.classList.add('img');
  const holder=node('div',undefined,'thumb');
  if(row.pid&&row.has_image){const img=node('img',undefined,'thumb-img');img.alt='';img.dataset.pid=String(row.pid);img.draggable=false;holder.append(img);}
  else holder.append(node('span','+','thumb-empty'));
  td.append(holder);
  if(row.pid){td.title='Kéo thả ảnh vào đây hoặc chọn ô rồi dán (Ctrl+V)';bindImageTarget(td,row.pid);}
}
function fillThumbs(){
  document.querySelectorAll('img.thumb-img[data-pid]').forEach(img=>{const hit=imagesState.thumbs.get(Number(img.dataset.pid));if(hit&&hit.url&&img.getAttribute('src')!==hit.url)img.src=hit.url;});
}
// Xin ảnh nhỏ còn thiếu (từng lô) cho các dòng đang có ảnh.
function ensureThumbs(){
  if(!tableState.data)return;
  const need=[];
  tableState.data.rows.forEach(row=>{
    if(!row.pid||!row.has_image||imagesState.thumbPending.has(row.pid))return;
    const hit=imagesState.thumbs.get(row.pid);
    if(!hit||hit.stamp!==row.image_stamp)need.push(row);
  });
  if(!need.length||imagesState.thumbPending.size)return;
  need.slice(0,THUMB_BATCH).forEach(row=>{imagesState.thumbPending.add(row.pid);imagesState.thumbs.set(row.pid,{stamp:row.image_stamp,url:null});});
  call('image_thumbs',JSON.stringify([...imagesState.thumbPending]));
  setTimeout(()=>{if(imagesState.thumbPending.size){imagesState.thumbPending.clear();}},6000); // phòng khi không có phản hồi
}
function receiveThumbs(data){
  [...imagesState.thumbPending].forEach(pid=>{const entry=imagesState.thumbs.get(pid);if(entry)entry.url=(data.items||{})[String(pid)]||null;});
  imagesState.thumbPending.clear();
  fillThumbs();ensureThumbs();
}

// ---- Nhận ảnh từ người dùng: kéo thả, dán, chọn file ----
function isImageFile(file){return file&&/^image\/(png|jpe?g|webp|gif|bmp)$/.test(file.type);}
function scaledPng(bitmap,longest){
  const scale=Math.min(1,longest/Math.max(bitmap.width,bitmap.height));
  const canvas=document.createElement('canvas');canvas.width=Math.max(1,Math.round(bitmap.width*scale));canvas.height=Math.max(1,Math.round(bitmap.height*scale));
  canvas.getContext('2d').drawImage(bitmap,0,0,canvas.width,canvas.height);
  return canvas.toDataURL('image/png');
}
// Thu nhỏ về đúng cỡ ảnh trong Cài đặt, đổi sang PNG; nếu vẫn quá lớn thì thu nhỏ thêm cho tới khi vừa.
async function sendImage(pid,file){
  if(!isImageFile(file))throw Error('Hãy dùng file ảnh PNG, JPG, WebP hoặc BMP.');
  if(file.size>PASTE_LIMIT)throw Error('Ảnh quá lớn (tối đa 20 MB).');
  const bitmap=await createImageBitmap(file);
  let longest=(config.settings&&config.settings.image_size)||512,full=scaledPng(bitmap,longest);
  while(full.length>PNG_SAFE_CHARS&&longest>128){longest=Math.round(longest*0.7);full=scaledPng(bitmap,longest);}
  if(typeof bitmap.close==='function')bitmap.close();
  const thumb=await createImageBitmap(await (await fetch(full)).blob());
  const small=scaledPng(thumb,128);if(typeof thumb.close==='function')thumb.close();
  call('image_set',JSON.stringify({pid,full:full.split(',')[1],thumb:small.split(',')[1]}));
}
function guarded(task){task.catch(error=>message(error.message||'Không đọc được ảnh.',true));}
function bindImageTarget(el,pid){
  el.addEventListener('dragover',e=>{if(e.dataTransfer&&[...e.dataTransfer.types].includes('Files')){e.preventDefault();el.classList.add('drop');}});
  el.addEventListener('dragleave',()=>el.classList.remove('drop'));
  el.addEventListener('drop',e=>{
    e.preventDefault();el.classList.remove('drop');
    const file=[...(e.dataTransfer?e.dataTransfer.files:[])].find(isImageFile);
    if(!file)return message('Hãy thả file ảnh PNG, JPG, WebP hoặc BMP.',true);
    imagesState.target=pid;guarded(sendImage(pid,file));
  });
  el.addEventListener('mousedown',()=>{imagesState.target=pid;});
}
// Trình duyệt mặc định mở file khi thả ra ngoài ô; chặn để thả trượt không làm cửa sổ chuyển sang file ảnh.
window.addEventListener('dragover',e=>e.preventDefault());
window.addEventListener('drop',e=>e.preventDefault());
function pasteTargetPid(){
  if(config.mode==='images'){
    if(imagesState.target&&imagesState.rows.some(r=>r.pid===imagesState.target))return imagesState.target;
    return imagesState.rows.length===1?imagesState.rows[0].pid:null;
  }
  if(config.mode==='table'&&tableState.data&&tableState.sel.size===1){
    const row=tableState.data.rows.find(r=>r.index===[...tableState.sel][0]);return row?row.pid:null;
  }
  return null;
}
document.addEventListener('paste',e=>{
  if(e.target.closest&&e.target.closest('input,textarea,select'))return;
  const item=[...(e.clipboardData?e.clipboardData.items:[])].find(i=>i.kind==='file'&&/^image\//.test(i.type));
  if(!item)return;
  e.preventDefault();
  const pid=pasteTargetPid();
  if(!pid)return message('Hãy chọn đúng một đối tượng (hoặc bấm vào ô ảnh của nó) rồi dán ảnh.',true);
  guarded(sendImage(pid,item.getAsFile()));
});

// ---- Tab Hình ảnh ----
function syncBusy(){
  const run=$('cap-run'),stop=$('cap-stop'),text=$('cap-progress'),tbl=$('tbl-capture');
  if(run)run.disabled=captureState.busy||!imagesState.rows.length;
  if(stop)stop.hidden=!captureState.busy;
  if(text)text.textContent=captureState.busy?`Đang chụp ${captureState.done}/${captureState.total}…`:'';
  if(tbl)tbl.disabled=captureState.busy||!tableState.sel.size;
}
function runCapture(indexes,onlyMissing){
  const payload={only_missing:!!onlyMissing};if(indexes)payload.indexes=indexes;
  call('images_capture',JSON.stringify(payload));
}
function imagesView(data){
  imagesState.rows=data.rows;config.settings=data.settings.settings;
  if(!imagesState.rows.some(r=>r.pid===imagesState.target))imagesState.target=null;
  imagesState.full.clear();imagesState.fullQueue=[];imagesState.limit=24;
  $('content').replaceChildren();$('primary-actions').replaceChildren();
  const c=card('Hình ảnh');
  c.append(node('p',data.hint||'Ảnh chỉ được chụp khi bạn bấm "Cập nhật ảnh". Muốn dùng ảnh riêng: kéo thả file ảnh vào ô, bấm ô rồi dán (Ctrl+V), hoặc bấm "Chọn ảnh…".','hint'));
  const bar=node('div',undefined,'image-bar');
  const run=button('Cập nhật ảnh',()=>runCapture(null,imagesState.only),'primary');run.id='cap-run';
  const only=node('input');only.type='checkbox';only.checked=imagesState.only;only.id='cap-only';only.onchange=()=>{imagesState.only=only.checked;};
  const onlyLabel=node('label');onlyLabel.append(only,document.createTextNode(' Chỉ chụp đối tượng chưa có ảnh'));
  const stop=button('Dừng',()=>call('images_cancel'));stop.id='cap-stop';stop.hidden=true;
  const progress=node('span',undefined,'muted');progress.id='cap-progress';
  bar.append(run,onlyLabel,stop,progress,button('Mở thư mục ảnh',()=>call('images_open_dir')));
  c.append(bar);
  const list=node('div',undefined,'img-cards');list.id='img-cards';c.append(list);
  renderCards();syncBusy();
}
function renderCards(){
  const list=$('img-cards');if(!list)return;
  list.replaceChildren();
  const shown=imagesState.rows.slice(0,imagesState.limit);
  shown.forEach(row=>list.append(imageCard(row)));
  shown.forEach(row=>{if(row.has_image)wantFull(row);}); // sau khi thẻ đã nằm trong trang, để ảnh có sẵn trong bộ nhớ đệm vẽ được ngay
  if(imagesState.rows.length>imagesState.limit)list.append(button(`Hiện thêm (${imagesState.rows.length-imagesState.limit} đối tượng nữa)`,()=>{imagesState.limit+=24;renderCards();}));
}
function imageCard(row){
  const art=node('article',undefined,'img-card'+(imagesState.target===row.pid?' active':''));art.dataset.pid=String(row.pid||'');
  const frame=node('div',undefined,'img-frame');
  if(row.has_image){const img=node('img');img.alt=row.name||row.definition||'';img.dataset.full=String(row.pid);img.draggable=false;frame.append(img);}
  else{frame.append(node('span','Chưa có ảnh','img-empty'),node('span','Kéo thả ảnh vào đây hoặc dán (Ctrl+V)','muted'));}
  const name=row.name||row.definition||'Chưa đặt tên';
  const meta=node('div',undefined,'img-meta');meta.append(node('strong',name),node('span',dimsText(row),'muted'));
  const actions=node('div',undefined,'img-actions');
  const pick=node('input');pick.type='file';pick.accept='image/png,image/jpeg,image/webp,image/bmp';pick.hidden=true;
  pick.onchange=()=>{if(pick.files[0]){imagesState.target=row.pid;guarded(sendImage(row.pid,pick.files[0]));}pick.value='';};
  const snap=button(row.has_image?'Chụp lại':'Chụp ảnh',()=>runCapture([row.index],false));snap.disabled=captureState.busy;snap.classList.add('cap-one');
  actions.append(snap,button('Chọn ảnh…',()=>pick.click()),pick);
  if(row.has_image)actions.append(button('Xóa ảnh',()=>call('image_delete',row.pid)));
  art.append(frame,meta,actions);
  if(row.pid){bindImageTarget(art,row.pid);art.addEventListener('mousedown',()=>{document.querySelectorAll('.img-card.active').forEach(x=>x.classList.remove('active'));art.classList.add('active');});}
  return art;
}
// Ảnh lớn xin từng cái một để không dồn nhiều ảnh qua cầu nối Ruby – giao diện cùng lúc.
function wantFull(row){
  const hit=imagesState.full.get(row.pid);
  if(hit&&hit.stamp===row.image_stamp){paintFull(row.pid);return;}
  if(!imagesState.fullQueue.includes(row.pid))imagesState.fullQueue.push(row.pid);
  pumpFull();
}
function pumpFull(){
  if(imagesState.fullWaiting!==null||!imagesState.fullQueue.length)return;
  const pid=imagesState.fullQueue.shift();imagesState.fullWaiting=pid;
  call('image_full',pid);
  setTimeout(()=>{if(imagesState.fullWaiting===pid){imagesState.fullWaiting=null;pumpFull();}},5000);
}
function receiveFull(data){
  imagesState.full.set(data.pid,{stamp:data.stamp,url:data.url});
  if(imagesState.fullWaiting===data.pid)imagesState.fullWaiting=null;
  paintFull(data.pid);pumpFull();
}
function paintFull(pid){
  const hit=imagesState.full.get(pid);
  document.querySelectorAll(`img[data-full="${pid}"]`).forEach(img=>{if(hit&&hit.url)img.src=hit.url;else img.replaceWith(node('span','Không đọc được file ảnh','img-empty'));});
}

// ---- Cập nhật khi ảnh đổi hoặc đang chụp ----
function imagesChanged(items){
  items.forEach(item=>{
    imageRows().filter(row=>row.pid===item.pid).forEach(row=>{row.has_image=item.has;row.image_stamp=item.stamp;});
    imagesState.thumbs.delete(item.pid);imagesState.full.delete(item.pid);
  });
  if(config.mode==='images')renderCards();
  else if(config.mode==='table'&&tableState.data&&$('grid-host')){renderGrid($('grid-host'));ensureThumbs();}
}
function imagesProgress(data){
  captureState.busy=true;captureState.done=data.done;captureState.total=data.total;
  message(`Đang chụp ảnh ${data.done}/${data.total}…`);syncBusy();
}
function imagesDone(data){
  captureState.busy=false;syncBusy();
  const head=data.cancelled?`Đã dừng: chụp được ${data.ok}/${data.total} ảnh.`:`Đã chụp ${data.ok}/${data.total} ảnh.`;
  message(data.errors.length?`${head} Lỗi: ${data.errors.join(' | ')}`:head,data.errors.length>0&&data.ok===0);
}
