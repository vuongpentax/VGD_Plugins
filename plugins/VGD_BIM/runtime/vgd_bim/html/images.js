'use strict';
// Ảnh món đồ trong bảng: cột Ảnh (ảnh gốc, nút khi rê chuột), chụp khi bấm, kéo thả / dán / chọn file ảnh riêng.
// Ảnh chỉ được chụp khi người dùng bấm nút. Dùng các hàm chung của app.js ($, node, button, call, message, tableState...) vào lúc gọi.
const imagesState={only:false,target:null,fallback:new Map(),fallbackQueue:[],fallbackBusy:false,fallbackTimer:null,fallbackSoon:null,pickPid:null};
const captureState={busy:false,done:0,total:0};
const FALLBACK_BATCH=6,PASTE_LIMIT=20*1024*1024,PNG_SAFE_CHARS=Math.floor(7*1024*1024*4/3); // dưới giới hạn 8 MB của phía Ruby

// ---- Ảnh gốc trong bảng ----
// Ô ảnh hiện ảnh gốc trực tiếp bằng đường dẫn file (row.image_url): nhanh, không chuyển ảnh qua Ruby. Nếu cửa sổ không nạp được file
// thì xin Ruby gửi ảnh gốc dạng data URL (image_full, từng lô nhỏ) và nhớ lại để các lần vẽ bảng sau dùng luôn.
function imageCell(td,row){
  td.classList.add('img');
  const holder=node('div',undefined,'cell-pic');
  if(row.pid&&row.has_image){
    const img=node('img',undefined,'cell-img');img.alt='';img.dataset.pid=String(row.pid);img.draggable=false;img.loading='lazy';
    const backup=imagesState.fallback.get(row.pid);
    if(backup&&backup.stamp===row.image_stamp&&backup.url)img.src=backup.url;
    else if(row.image_url){img.onerror=()=>imageFailed(row);img.src=row.image_url;}
    else imageFailed(row);
    holder.append(img);
  }
  else holder.append(node('span','+','cell-empty'));
  td.append(holder);
  if(!row.pid)return;
  // Nút nhỏ hiện khi rê chuột: chụp lại, chọn file ảnh, xóa ảnh. Chỉ chụp khi bấm nút.
  const tools=node('div',undefined,'cell-tools');
  const tool=(text,title,handler)=>{const b=node('button',text,'cell-tool');b.type='button';b.title=title;b.setAttribute('aria-label',title);b.onclick=e=>{e.stopPropagation();handler();};b.ondblclick=e=>e.stopPropagation();return b;};
  tools.append(tool('↻',row.has_image?'Chụp lại':'Chụp ảnh',()=>runCapture([row.index],false)),tool('⋯','Chọn ảnh…',()=>pickImageFile(row.pid)));
  if(row.has_image)tools.append(tool('×','Xóa ảnh',()=>call('image_delete',row.pid)));
  holder.append(tools);
  td.title='Kéo thả ảnh vào đây hoặc chọn ô rồi dán (Ctrl+V)';
  bindImageTarget(td,row.pid);
}
// Ảnh không nạp được bằng đường dẫn file: xin Ruby gửi (mỗi mốc ảnh chỉ xin một lần).
function imageFailed(row){
  const known=imagesState.fallback.get(row.pid);
  if(known&&known.stamp===row.image_stamp)return;
  imagesState.fallback.set(row.pid,{stamp:row.image_stamp,url:null});
  imagesState.fallbackQueue.push(row.pid);
  clearTimeout(imagesState.fallbackSoon);imagesState.fallbackSoon=setTimeout(requestFallback,50); // gom các ảnh lỗi cùng lúc thành một lô
}
function requestFallback(){
  if(imagesState.fallbackBusy||!imagesState.fallbackQueue.length)return;
  const pids=imagesState.fallbackQueue.splice(0,FALLBACK_BATCH);
  imagesState.fallbackBusy=true;
  call('image_full',JSON.stringify(pids));
  imagesState.fallbackTimer=setTimeout(()=>{imagesState.fallbackBusy=false;requestFallback();},8000); // phòng khi không có phản hồi
}
function receiveImageData(data){
  clearTimeout(imagesState.fallbackTimer);
  Object.entries(data.items||{}).forEach(([pid,url])=>{const entry=imagesState.fallback.get(Number(pid));if(entry)entry.url=url;});
  imagesState.fallbackBusy=false;
  fillImages();requestFallback();
}
function fillImages(){
  document.querySelectorAll('img.cell-img[data-pid]').forEach(img=>{const hit=imagesState.fallback.get(Number(img.dataset.pid));if(hit&&hit.url&&img.getAttribute('src')!==hit.url){img.onerror=null;img.src=hit.url;}});
}

// ---- Nhận ảnh từ người dùng: kéo thả, dán, chọn file ----
function isImageFile(file){return file&&/^image\/(png|jpe?g|webp|gif|bmp)$/.test(file.type);}
function scaledPng(bitmap,width,height){
  const scale=Math.min(1,width/bitmap.width,height/bitmap.height);
  const canvas=document.createElement('canvas');canvas.width=Math.max(1,Math.round(bitmap.width*scale));canvas.height=Math.max(1,Math.round(bitmap.height*scale));
  canvas.getContext('2d').drawImage(bitmap,0,0,canvas.width,canvas.height);
  return canvas.toDataURL('image/png');
}
// Thu nhỏ vừa khung rộng x cao của preset (giữ tỉ lệ), đổi sang PNG; nếu vẫn quá lớn thì thu nhỏ thêm cho tới khi vừa.
async function sendImage(pid,file){
  if(!isImageFile(file))throw Error('Hãy dùng file ảnh PNG, JPG, WebP hoặc BMP.');
  if(file.size>PASTE_LIMIT)throw Error('Ảnh quá lớn (tối đa 20 MB).');
  const bitmap=await createImageBitmap(file),s=workSettings();
  let w=s.image_width,h=s.image_height,full=scaledPng(bitmap,w,h);
  while(full.length>PNG_SAFE_CHARS&&w>128){w=Math.round(w*0.7);h=Math.round(h*0.7);full=scaledPng(bitmap,w,h);}
  if(typeof bitmap.close==='function')bitmap.close();
  call('image_set',JSON.stringify({pid,full:full.split(',')[1]}));
}
function guarded(task){task.catch(error=>message(error.message||'Không đọc được ảnh.',true));}
function pickImageFile(pid){
  let input=$('img-file');
  if(!input){input=node('input');input.type='file';input.id='img-file';input.accept='image/png,image/jpeg,image/webp,image/bmp';input.hidden=true;document.body.append(input);}
  imagesState.pickPid=pid;
  input.onchange=()=>{const file=input.files[0];input.value='';if(file&&imagesState.pickPid){imagesState.target=imagesState.pickPid;guarded(sendImage(imagesState.pickPid,file));}};
  input.click();
}
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
  if(tableState.data&&tableState.sel.size===1){
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

// ---- Chụp ảnh: chỉ khi người dùng bấm ----
function syncBusy(){
  const run=$('cap-run'),stop=$('cap-stop'),text=$('cap-progress');
  if(run)run.disabled=captureState.busy;
  if(stop)stop.hidden=!captureState.busy;
  if(text)text.textContent=captureState.busy?`Đang chụp ${captureState.done}/${captureState.total}…`:'';
  document.querySelectorAll('.cell-tool').forEach(b=>{b.disabled=captureState.busy;});
}
// Thiết lập ảnh của preset đang dùng đi kèm lệnh chụp; phía Ruby kiểm tra lại.
function runCapture(indexes,onlyMissing){
  const s=workSettings();
  const payload={only_missing:!!onlyMissing,settings:{image_width:s.image_width,image_height:s.image_height,image_view:s.image_view,image_style:s.image_style,image_background:s.image_background}};
  if(indexes)payload.indexes=indexes;
  call('images_capture',JSON.stringify(payload));
}
function imagesChanged(items){
  items.forEach(item=>{
    (tableState.data?tableState.data.rows:[]).filter(row=>row.pid===item.pid).forEach(row=>{row.has_image=item.has;row.image_stamp=item.stamp;row.image_url=item.url||null;});
    imagesState.fallback.delete(item.pid);
  });
  if(tableState.data&&$('grid-host'))renderGrid($('grid-host'));
}
function imagesProgress(data){
  captureState.busy=true;captureState.done=data.done;captureState.total=data.total;
  message(`Đang chụp ảnh ${data.done}/${data.total}…`);syncBusy();
}
function imagesDone(data){
  captureState.busy=false;syncBusy();
  const head=data.cancelled?`Đã dừng: chụp được ${data.ok}/${data.total} ảnh.`:`Đã chụp ${data.ok}/${data.total} ảnh.`;
  const note=(data.notes&&data.notes.length)?` Lưu ý: ${data.notes.join('; ')}.`:'';
  message((data.errors.length?`${head} Lỗi: ${data.errors.join(' | ')}`:head)+note,data.errors.length>0&&data.ok===0);
}
