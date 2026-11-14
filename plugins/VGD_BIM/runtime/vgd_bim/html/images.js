'use strict';
// Ảnh món đồ trong bảng: cột Ảnh (ảnh gốc, nút khi rê chuột), chụp khi bấm, kéo thả / dán / chọn file ảnh riêng.
// Ảnh chỉ được chụp khi người dùng bấm nút. Dùng các hàm chung của app.js ($, node, button, call, message, tableState...) vào lúc gọi.
const imagesState={only:false,target:null,fallback:new Map(),fallbackQueue:[],fallbackBusy:false,fallbackTimer:null,fallbackSoon:null,pickPid:null};
const captureState={busy:false,done:0,total:0};
// Ảnh món (cột Ảnh) và ảnh vị trí trong công trình (cột Ảnh vị trí) dùng chung cách vẽ ô; mỗi loại đọc các trường riêng của dòng.
const IMG_FIELDS={full:{has:'has_image',stamp:'image_stamp',url:'image_url'},location:{has:'has_location',stamp:'location_stamp',url:'location_url'},
  extra1:{has:'has_extra1',stamp:'extra1_stamp',url:'extra1_url'},extra2:{has:'has_extra2',stamp:'extra2_stamp',url:'extra2_url'}};
// Ảnh phụ (cột Ảnh 3 / Ảnh 4: chụp thêm góc khác của cùng món) có thiết lập riêng x1_* / x2_* như ảnh vị trí có loc_*.
const IMG_PREFIX={full:'image',location:'loc',extra1:'x1',extra2:'x2'};
const IMG_NAMES={full:'Ảnh chính',location:'Ảnh vị trí',extra1:'Ảnh 3',extra2:'Ảnh 4'};
const imgField=kind=>IMG_FIELDS[kind]||IMG_FIELDS.full;
const imgPrefix=kind=>IMG_PREFIX[kind]||'image';
const photoKey=kind=>IMG_FIELDS[kind]&&kind!=='full'?'photo_'+kind:'photo_full';
const FALLBACK_BATCH=6,PASTE_LIMIT=20*1024*1024,PNG_SAFE_CHARS=Math.floor(7*1024*1024*4/3); // dưới giới hạn 8 MB của phía Ruby

// ---- Ảnh gốc trong bảng ----
// Ô ảnh hiện ảnh gốc trực tiếp bằng đường dẫn file (row.image_url): nhanh, không chuyển ảnh qua Ruby. Nếu cửa sổ không nạp được file
// thì xin Ruby gửi ảnh gốc dạng data URL (image_full, từng lô nhỏ) và nhớ lại để các lần vẽ bảng sau dùng luôn.
// kind: 'full' (ảnh món), 'location' (ảnh vị trí) hoặc 'extra1' / 'extra2' (ảnh 3 / ảnh 4); loại khác 'full' không có đường dự phòng qua Ruby, ảnh lỗi thì ẩn đi.
function imageCell(td,row,kind='full'){
  const f=imgField(kind),place=kind!=='full',isLoc=kind==='location';
  td.classList.add('img');
  const holder=node('div',undefined,'cell-pic');
  if(row.pid&&row[f.has]){
    const img=node('img',undefined,'cell-img');img.alt='';img.draggable=false;img.loading='lazy';
    if(place){img.dataset.kind=kind;img.onerror=()=>{img.style.visibility='hidden';};img.src=row[f.url];}
    else{
      img.dataset.pid=String(row.pid);
      const backup=imagesState.fallback.get(row.pid);
      if(backup&&backup.stamp===row.image_stamp&&backup.url)img.src=backup.url;
      else if(row.image_url){img.onerror=()=>imageFailed(row);img.src=row.image_url;}
      else imageFailed(row);
    }
    holder.append(img);
  }
  else holder.append(node('span','+','cell-empty'));
  td.append(holder);
  if(!row.pid)return;
  // Nút nhỏ hiện khi rê chuột: chụp lại, chọn file ảnh, xóa ảnh. Chỉ chụp khi bấm nút.
  const tools=node('div',undefined,'cell-tools');
  const tool=(text,title,handler)=>{const b=node('button',text,'cell-tool');b.type='button';b.title=title;b.setAttribute('aria-label',title);b.onclick=e=>{e.stopPropagation();handler();};b.ondblclick=e=>e.stopPropagation();return b;};
  const kindArg=place?kind:undefined;
  // Hàng nút trên đầu ảnh: ⚙ mở khung thông số ảnh riêng của món (nổi màu khi món đã có thông số riêng).
  // Ô ảnh quá thấp để chứa hai hàng nút (hàng Gọn, hoặc độ cao tự chọn nhỏ): ⚙ đứng đầu hàng nút dưới thay vì hàng riêng ở trên.
  const own=row[photoKey(kind)];
  const gear=tool('⚙','Thông số ảnh riêng của món này',()=>openPhotoPop(row,kind,gear));
  if(own&&Object.keys(own).length)gear.classList.add('own');
  const eye=tool('','Xem trước góc chụp',()=>runPreview([row.index],false,undefined,kindArg));
  eye.append(eyeIcon());
  const lowPic=(tableState.rowHeight>0?tableState.rowHeight-5:({dense:26,roomy:64}[tableState.density]||46))<40; // hai hàng nút cao 20 + 20
  if(!lowPic){const top=node('div',undefined,'cell-tools top');top.append(gear,eye);holder.append(top);}
  tools.append(tool('◉','Chụp view hiện tại',()=>runCapture([row.index],false,undefined,kindArg,{view:'current'})),tool('◣',isLoc?'Chụp vị trí từ bên trái (Iso)':'Chụp Iso từ bên trái',()=>runCapture([row.index],false,'left',kindArg)),tool('◢',isLoc?'Chụp vị trí từ bên phải (Iso)':'Chụp Iso từ bên phải',()=>runCapture([row.index],false,'right',kindArg)),
    tool('↻',row[f.has]?'Chụp lại':'Chụp ảnh',()=>runCapture([row.index],false,undefined,kindArg)),pasteTool(tool,row.pid,kind),tool('⋯','Chọn ảnh…',()=>pickImageFile(row.pid,kind)));
  if(row[f.has])tools.append(tool('×',place?'Xóa '+IMG_NAMES[kind].toLowerCase():'Xóa ảnh',()=>call(place?`image_${kind}_delete`:'image_delete',row.pid)));
  if(lowPic){tools.prepend(gear,eye);tools.classList.add('wide');} // 8 nút: hàng quá rộng để căn giữa ô hẹp (bị cắt ở mép bảng), nên bắt đầu từ mép trái ô và tràn sang phải
  holder.append(tools);
  td.title=place?'Kéo thả ảnh vào đây để dùng làm '+IMG_NAMES[kind].toLowerCase():'Kéo thả ảnh vào đây hoặc chọn ô rồi dán (Ctrl+V)';
  bindImageTarget(td,row.pid,kind);
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
async function sendImage(pid,file,kind='full'){
  if(!isImageFile(file))throw Error('Hãy dùng file ảnh PNG, JPG, WebP hoặc BMP.');
  if(file.size>PASTE_LIMIT)throw Error('Ảnh quá lớn (tối đa 20 MB).');
  const bitmap=await createImageBitmap(file),s=workSettings();
  let w=s[imgPrefix(kind)+'_width'],h=s[imgPrefix(kind)+'_height'],full=scaledPng(bitmap,w,h); // cỡ theo thiết lập của đúng loại ảnh
  while(full.length>PNG_SAFE_CHARS&&w>128){w=Math.round(w*0.7);h=Math.round(h*0.7);full=scaledPng(bitmap,w,h);}
  if(typeof bitmap.close==='function')bitmap.close();
  call('image_set',JSON.stringify(kind!=='full'&&IMG_FIELDS[kind]?{pid,kind,full:full.split(',')[1]}:{pid,full:full.split(',')[1]}));
}
function guarded(task){task.catch(error=>message(error.message||'Không đọc được ảnh.',true));}
function pickImageFile(pid,kind='full'){
  let input=$('img-file');
  if(!input){input=node('input');input.type='file';input.id='img-file';input.accept='image/png,image/jpeg,image/webp,image/bmp';input.hidden=true;document.body.append(input);}
  imagesState.pickPid=pid;imagesState.pickKind=kind;
  input.onchange=()=>{const file=input.files[0];input.value='';if(file&&imagesState.pickPid){if(imagesState.pickKind==='full')imagesState.target=imagesState.pickPid;guarded(sendImage(imagesState.pickPid,file,imagesState.pickKind));}};
  input.click();
}
function bindImageTarget(el,pid,kind='full'){
  el.addEventListener('dragover',e=>{if(e.dataTransfer&&[...e.dataTransfer.types].includes('Files')){e.preventDefault();el.classList.add('drop');}});
  el.addEventListener('dragleave',()=>el.classList.remove('drop'));
  el.addEventListener('drop',e=>{
    e.preventDefault();el.classList.remove('drop');
    const file=[...(e.dataTransfer?e.dataTransfer.files:[])].find(isImageFile);
    if(!file)return message('Hãy thả file ảnh PNG, JPG, WebP hoặc BMP.',true);
    if(kind==='full')imagesState.target=pid;
    guarded(sendImage(pid,file,kind));
  });
  el.addEventListener('mousedown',()=>{if(kind==='full')imagesState.target=pid;imagesState.last={pid,kind};}); // ô vừa bấm là nơi nhận ảnh khi nhấn Ctrl+V
}
document.addEventListener('mousedown',()=>{imagesState.last=null;},true); // bấm chỗ khác: bỏ ô đã nhớ (ô ảnh tự đặt lại ngay sau đó)
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
  const target=imagesState.last||(pasteTargetPid()?{pid:pasteTargetPid(),kind:'full'}:null);
  if(!target)return message('Hãy chọn đúng một đối tượng (hoặc bấm vào ô ảnh của nó) rồi dán ảnh.',true);
  guarded(sendImage(target.pid,item.getAsFile(),target.kind));
});
// Nút dán trên ô ảnh: đọc ảnh đang có trong clipboard (chụp màn hình, hoặc copy ảnh) bằng API clipboard của cửa sổ rồi lưu cho món.
// Cửa sổ không cho đọc clipboard bằng nút (hoặc người dùng từ chối quyền) thì nhớ ô này làm nơi nhận và hướng dẫn nhấn Ctrl+V.
async function pasteImageFromClipboard(pid,kind){
  imagesState.last={pid,kind};
  const hint='Không đọc được clipboard bằng nút. Hãy bấm vào ô ảnh rồi nhấn Ctrl+V.';
  if(!navigator.clipboard||typeof navigator.clipboard.read!=='function')throw Error(hint);
  let items;
  try{items=await navigator.clipboard.read();}catch(error){throw Error(hint);}
  for(const item of items){
    const type=item.types.find(t=>/^image\//.test(t));
    if(type)return sendImage(pid,await item.getType(type),kind);
  }
  throw Error('Trong clipboard chưa có ảnh. Hãy chụp màn hình hoặc copy ảnh rồi bấm lại.');
}

// ---- Chụp ảnh: chỉ khi người dùng bấm ----
function syncBusy(){
  const run=$('cap-run'),stop=$('cap-stop'),text=$('cap-progress');
  if(run)run.disabled=captureState.busy;
  if(stop)stop.hidden=!captureState.busy;
  if(text)text.textContent=captureState.busy?`Đang chụp ${captureState.done}/${captureState.total}…`:'';
  document.querySelectorAll('.cell-tool').forEach(b=>{b.disabled=captureState.busy;});
}
// Thiết lập ảnh của preset đang dùng đi kèm lệnh chụp; phía Ruby kiểm tra lại.
// isoSide ('left' | 'right'): chụp một lần theo góc Iso từ bên đó, bất kể góc nhìn của preset (nút ◣ ◢ trong ô ảnh).
// kind 'location': chụp ảnh vị trí trong công trình (không cô lập, vùng nhìn rộng theo image_location_scale) cho cột Ảnh vị trí.
// extra.view: chụp một lần theo góc nhìn đó (nút ◉ Khung nhìn hiện tại) bất kể thiết lập preset và góc nhìn riêng của món; extra.itemSettings: thông số trong khung ⚙, dùng thay cho thông số đã lưu của món.
function capturePayload(indexes,onlyMissing,isoSide,kind,extra){
  const s=workSettings();
  const settings={image_width:s.image_width,image_height:s.image_height,image_view:s.image_view,image_style:s.image_style,image_background:s.image_background,image_margin:s.image_margin,image_yaw:s.image_yaw,image_pitch:s.image_pitch,
    image_location_scale:s.image_location_scale,loc_width:s.loc_width,loc_height:s.loc_height,loc_view:s.loc_view,loc_style:s.loc_style,loc_background:s.loc_background,loc_margin:s.loc_margin,loc_yaw:s.loc_yaw,loc_pitch:s.loc_pitch};
  ['x1','x2'].forEach(p=>['width','height','view','style','background','margin','yaw','pitch'].forEach(k=>{settings[p+'_'+k]=s[p+'_'+k];}));
  const viewKey=imgPrefix(kind)+'_view';
  if(isoSide)settings[viewKey]='isometric'; // nút ◣ ◢: chụp Iso một lần, không đổi thiết lập của preset
  if(extra&&extra.view)settings[viewKey]=extra.view;
  const payload={only_missing:!!onlyMissing,settings};
  if(isoSide||(extra&&extra.view))payload.force_view=true; // bấm nút chụp một lần: bỏ qua góc nhìn riêng của món
  if(extra&&extra.itemSettings)payload.item_settings=extra.itemSettings;
  if(kind&&kind!=='full'&&IMG_FIELDS[kind])payload.kind=kind;
  if(isoSide)payload.iso_side=isoSide;
  if(indexes)payload.indexes=indexes;
  return payload;
}
function runCapture(indexes,onlyMissing,isoSide,kind,extra){call('images_capture',JSON.stringify(capturePayload(indexes,onlyMissing,isoSide,kind,extra)));}
// Xem trước góc chụp: cùng thông số như chụp thật (kể cả thông số riêng của từng món) nhưng chỉ vẽ ảnh nháp nhỏ trong bảng xem trước, không lưu ảnh.
function runPreview(indexes,onlyMissing,isoSide,kind,extra){
  const f=imgField(kind),rows=tableState.data?tableState.data.rows:[];
  const list=(indexes||captureTargets()).filter(i=>!onlyMissing||!(rows.find(r=>r.index===i)||{})[f.has]);
  if(!list.length){message('Không có đối tượng nào cần chụp.',true);return;}
  const payload=capturePayload(list,false,isoSide,kind,extra);
  openPreviewBoard(payload);
  call('images_preview',JSON.stringify(payload));
}
function imagesChanged(items){
  items.forEach(item=>{
    const f=imgField(item.kind);
    (tableState.data?tableState.data.rows:[]).filter(row=>row.pid===item.pid).forEach(row=>{row[f.has]=item.has;row[f.stamp]=item.stamp;row[f.url]=item.url||null;});
    if(!item.kind||item.kind==='full')imagesState.fallback.delete(item.pid);
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

// ---- Khung thông số ảnh riêng của một món (nút ⚙ trên đầu ô ảnh) ----
// Mỗi mục để trống nghĩa là theo preset; Ruby kiểm tra lại và lưu trong chính đối tượng (xem core/photo_settings.rb).
let photoPop=null;
function closePhotoPop(){
  if(photoPop){photoPop.remove();photoPop=null;}
  document.removeEventListener('mousedown',photoPopOutside,true);document.removeEventListener('keydown',photoPopKey,true);
}
function photoPopOutside(e){if(photoPop&&!photoPop.contains(e.target)&&!e.target.closest('.cell-tool'))closePhotoPop();}
function photoPopKey(e){if(e.key==='Escape')closePhotoPop();}
function openPhotoPop(row,kind,anchor){
  closePhotoPop();
  const place=kind==='location',s=workSettings(),own=row[photoKey(kind)]||{},px=imgPrefix(kind);
  const preset={view:s[px+'_view'],yaw:s[px+'_yaw'],pitch:s[px+'_pitch'],margin:s[px+'_margin']};
  const pop=node('div',undefined,'photo-pop');pop.setAttribute('role','dialog');
  pop.append(node('div',kind==='full'||!IMG_FIELDS[kind]?'Thông số ảnh chính của món này':`Thông số ${IMG_NAMES[kind].toLowerCase()} của món này`,'pop-title'));
  const field=(label,control)=>{const line=node('div',undefined,'pop-field');line.append(node('label',label),control);pop.append(line);return control;};
  const select=(label,aria,options,value)=>{
    const sel=node('select');sel.setAttribute('aria-label',aria);options.forEach(([v,t])=>sel.append(new Option(t,v)));sel.value=value||'';
    return field(label,sel);
  };
  const number=(label,aria,min,max,value,hint)=>{
    const input=node('input');input.type='number';input.min=String(min);input.max=String(max);input.step='1';input.placeholder=String(hint);
    input.value=value==null?'':String(value);input.setAttribute('aria-label',aria);
    return field(label,input);
  };
  const view=select('Góc nhìn','Góc nhìn riêng',[['','Theo preset'],['current','Khung nhìn hiện tại'],['isometric','Phối cảnh iso'],['front','Chính diện']],own.view);
  const side=select('Bên Iso','Bên Iso riêng',[['','Theo preset'],['right','Iso phải'],['left','Iso trái']],own.side);
  const yaw=number('Lệch trái / phải (độ)','Lệch trái / phải riêng',-90,90,own.yaw,preset.yaw);
  const pitch=number('Góc cao (độ)','Góc cao riêng',-30,80,own.pitch,preset.pitch);
  const margin=number('Chừa lề (%)','Chừa lề riêng',0,100,own.margin,preset.margin);
  const scale=place?number('Vùng nhìn (lần)','Vùng nhìn riêng',1,20,own.scale,s.image_location_scale):null;
  const gate=()=>{const effective=view.value||preset.view;side.disabled=effective!=='isometric';yaw.disabled=pitch.disabled=effective!=='front';};
  view.onchange=gate;gate();
  const collect=()=>{
    const out={};
    if(view.value)out.view=view.value;
    if(side.value&&!side.disabled)out.side=side.value;
    [['yaw',yaw],['pitch',pitch],['margin',margin],['scale',scale]].forEach(([key,input])=>{if(input&&input.value.trim()!==''&&!input.disabled)out[key]=Number(input.value);});
    return out;
  };
  const save=settings=>call('image_item_save',JSON.stringify({index:row.index,kind,settings}));
  const buttons=node('div',undefined,'pop-actions');
  buttons.append(
    button('Lưu',()=>{save(collect());closePhotoPop();},'primary'),
    button('Lưu và chụp',()=>{const own=collect();save(own);closePhotoPop();runCapture([row.index],false,undefined,kind,{itemSettings:own});}),
    button('Về theo preset',()=>{save({});closePhotoPop();}),
    button('Đóng',closePhotoPop));
  pop.append(buttons);
  document.body.append(pop);photoPop=pop;
  const box=anchor.getBoundingClientRect(),width=pop.offsetWidth,height=pop.offsetHeight;
  pop.style.left=Math.max(8,Math.min(innerWidth-width-8,box.left-4))+'px';
  pop.style.top=Math.max(8,Math.min(innerHeight-height-8,box.bottom+4))+'px';
  document.addEventListener('mousedown',photoPopOutside,true);document.addEventListener('keydown',photoPopKey,true);
  view.focus();
}
// Ruby báo đã lưu / bỏ thông số riêng của một món: cập nhật dòng rồi vẽ lại bảng.
function receivePhotoSettings(data){
  const key=photoKey(data.kind);
  if(tableState.data)tableState.data.rows.filter(r=>r.pid===data.pid).forEach(r=>{r[key]=data.settings||{};});
  if(tableState.data&&$('grid-host'))renderGrid($('grid-host'));
}

function pasteTool(tool,pid,kind){
  const button=tool('','Dán ảnh từ clipboard',()=>guarded(pasteImageFromClipboard(pid,kind)));
  const ns='http://www.w3.org/2000/svg',svg=document.createElementNS(ns,'svg');
  svg.setAttribute('viewBox','0 0 24 24');svg.setAttribute('width','12');svg.setAttribute('height','12');svg.setAttribute('fill','none');svg.setAttribute('stroke','currentColor');svg.setAttribute('stroke-width','2.4');svg.setAttribute('stroke-linecap','round');svg.setAttribute('stroke-linejoin','round');svg.setAttribute('aria-hidden','true');
  [['rect',{x:5,y:4,width:14,height:18,rx:2}],['path',{d:'M9 4V3a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v1'}],['path',{d:'M9 13h6M9 17h4'}]].forEach(([tag,attrs])=>{const el=document.createElementNS(ns,tag);Object.entries(attrs).forEach(([k,v])=>el.setAttribute(k,v));svg.append(el);});
  button.append(svg);return button;
}
// ---- Bảng xem trước góc chụp ----
// Hiện ảnh nháp của từng món sắp chụp (Ruby gửi từng khung qua 'image_preview'); người dùng bỏ tick món bị cấn vật thể rồi chụp các món còn lại.
const previewState={board:null,payload:null,busy:false,cards:new Map()};
function eyeIcon(){
  const ns='http://www.w3.org/2000/svg',svg=document.createElementNS(ns,'svg');
  svg.setAttribute('viewBox','0 0 24 24');svg.setAttribute('width','12');svg.setAttribute('height','12');svg.setAttribute('fill','none');svg.setAttribute('stroke','currentColor');svg.setAttribute('stroke-width','2.4');svg.setAttribute('stroke-linecap','round');svg.setAttribute('stroke-linejoin','round');svg.setAttribute('aria-hidden','true');
  [['path',{d:'M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z'}],['circle',{cx:12,cy:12,r:3}]].forEach(([tag,attrs])=>{const el=document.createElementNS(ns,tag);Object.entries(attrs).forEach(([k,v])=>el.setAttribute(k,v));svg.append(el);});
  return svg;
}
function previewKeyHandler(e){if(e.key==='Escape')closePreviewBoard();}
function closePreviewBoard(){
  if(previewState.busy)call('images_cancel'); // đang vẽ dở: dừng
  previewState.busy=false;
  if(previewState.board){previewState.board.remove();previewState.board=null;}
  previewState.cards=new Map();previewState.payload=null;
  document.removeEventListener('keydown',previewKeyHandler,true);
}
function previewChosen(){return [...previewState.cards.entries()].filter(([,card])=>card.box.checked).map(([index])=>index);}
function updatePreviewBoard(){
  const board=previewState.board;if(!board)return;
  const chosen=previewChosen().length;
  board.querySelector('.pb-count').textContent=String(chosen);
  board.querySelector('.pb-run').disabled=previewState.busy||!chosen;
  board.querySelector('.pb-stop').hidden=!previewState.busy;
}
function openPreviewBoard(payload){
  closePreviewBoard();
  const rows=tableState.data?tableState.data.rows:[];
  previewState.payload=payload;previewState.busy=true;
  const board=node('div',undefined,'preview-board');board.setAttribute('role','dialog');board.setAttribute('aria-modal','true');
  const panel=node('div',undefined,'pb-panel');
  const head=node('div',undefined,'pb-head');
  head.append(node('strong','Xem trước góc chụp'),node('span',IMG_NAMES[payload.kind]||IMG_NAMES.full,'muted pb-kind'));
  const status=node('span',undefined,'muted pb-status');status.append(node('span','Đang vẽ','pb-state'),document.createTextNode(' '),node('span','0/'+payload.indexes.length,'pb-num'));
  head.append(status);
  const bar=node('div',undefined,'pb-bar');
  const all=button('Chọn hết',()=>{previewState.cards.forEach(card=>{if(!card.box.disabled)card.box.checked=true;});updatePreviewBoard();});
  const none=button('Bỏ chọn hết',()=>{previewState.cards.forEach(card=>{card.box.checked=false;});updatePreviewBoard();});
  const stop=button('Dừng',()=>call('images_cancel'),'pb-stop');
  const run=button('Chụp các món đã chọn',()=>{
    const indexes=previewChosen();if(!indexes.length)return;
    const payload=previewState.payload;closePreviewBoard();
    call('images_capture',JSON.stringify({...payload,indexes}));
  },'primary pb-run');
  run.append(document.createTextNode(' '),node('span','0','pb-count'));
  const close=button('Đóng',closePreviewBoard);
  bar.append(all,none,node('span',undefined,'grow'),stop,run,close);
  const grid=node('div',undefined,'pb-grid');
  payload.indexes.forEach(index=>{
    const row=rows.find(r=>r.index===index)||{};
    const card=node('div',undefined,'pb-card');card.dataset.index=String(index);
    const label=node('label',undefined,'pb-name');const box=node('input');box.type='checkbox';box.checked=true;box.disabled=true;box.onchange=updatePreviewBoard;
    label.append(box,document.createTextNode(' '+(row.name||row.definition||'—')));
    const shot=node('div','Đang vẽ…','pb-shot');
    card.append(label,shot);grid.append(card);
    previewState.cards.set(index,{box,shot,card,pending:true});
  });
  panel.append(head,bar,grid);board.append(panel);document.body.append(board);previewState.board=board;
  document.addEventListener('keydown',previewKeyHandler,true);
  updatePreviewBoard();
}
function receivePreviewFrame(data){
  const card=previewState.cards.get(data.index);if(!card)return;
  card.shot.replaceChildren();card.pending=false;
  if(data.error){
    card.card.classList.add('error');card.box.checked=false;card.box.disabled=true;
    const failed=node('span',undefined,'pb-error');failed.append(node('span','Không vẽ được'),document.createTextNode(': '),node('span',data.error)); // lý do do Ruby báo (tiếng Việt, được dịch nếu có trong từ điển)
    card.shot.append(failed);
  }else{
    const img=node('img',undefined,'pb-img');img.alt='';img.draggable=false;img.src=data.image;
    if(data.note)img.title=data.note;
    card.shot.append(img);card.box.disabled=false;card.box.checked=true;
  }
  updatePreviewBoard();
}
function receivePreviewProgress(data){
  const board=previewState.board;if(!board)return;
  previewState.busy=data.done<data.total;
  board.querySelector('.pb-num').textContent=`${data.done}/${data.total}`;
  updatePreviewBoard();
}
function receivePreviewDone(data){
  const board=previewState.board;if(!board)return;
  previewState.busy=false;
  board.querySelector('.pb-state').textContent=data.cancelled?'Đã dừng':'Đã vẽ xong';
  board.querySelector('.pb-num').textContent=`${data.ok}/${data.total}`;
  // khung chưa vẽ tới (bấm Dừng) không chụp được: bỏ tick
  previewState.cards.forEach(card=>{if(card.pending){card.shot.textContent='Chưa vẽ';card.box.checked=false;card.box.disabled=true;}});
  updatePreviewBoard();
}
