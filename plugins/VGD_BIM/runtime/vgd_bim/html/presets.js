'use strict';
// Thanh đầu: nút preset (cạnh nút Sáng/Tối) mở bảng preset gồm Đơn vị, Hình ảnh và danh sách preset; nút ⚙ chỉ để chọn ngôn ngữ.
// Thiết lập (đơn vị, số lẻ, tiền tệ, cỡ / góc nhìn / kiểu ảnh) lưu theo preset; ngôn ngữ và thư mục ảnh dùng chung mọi preset.
// Dùng các hàm chung của app.js ($, node, button, call, message, tableState, applyPreset...) vào lúc gọi.
const VIEW_LABELS={current:'Khung nhìn hiện tại',isometric:'Phối cảnh iso',front:'Chính diện'};
const STYLE_LABELS={color:'Màu (có texture)',current:'Kiểu hiện tại'};
const BACKGROUND_LABELS={transparent:'Nền trong suốt',white:'Nền trắng'};
const digitsLabel=d=>d?'0.'+'0'.repeat(d):'0';
const presetChoices=()=>(config.preset_info&&config.preset_info.choices)||{length_units:['mm','cm','m','in','ft'],area_units:['m2','cm2','ft2'],volume_units:['m3','cm3','ft3'],separators:['.',','],currencies:['VND','USD','EUR','GBP'],views:['current','isometric','front'],styles:['color','current'],backgrounds:['transparent','white'],digits:[0,1,2,3,4],sizes:[256,512,768,1024,1536,2048]};
const presetsList=()=>(tableState.data&&tableState.data.presets)||(config.table&&config.table.presets)||[];
const presetColumns=()=>(tableState.data&&tableState.data.columns)||(config.table&&config.table.columns)||[];
let openPanel=null;

function closePanels(){
  ['preset-panel','gear-panel'].forEach(id=>{const el=$(id);if(el)el.hidden=true;});
  ['preset-btn','gear'].forEach(id=>{const el=$(id);if(el)el.setAttribute('aria-expanded','false');});
  openPanel=null;
}
function togglePanel(id,button,build){
  const wasOpen=openPanel===id;
  closePanels();
  if(wasOpen)return;
  let panel=$(id);
  if(!panel){panel=node('div',undefined,'header-panel');panel.id=id;panel.hidden=true;document.body.append(panel);}
  build(panel);panel.hidden=false;button.setAttribute('aria-expanded','true');openPanel=id;
}
document.addEventListener('mousedown',e=>{
  if(!openPanel)return;
  const panel=$(openPanel),btn=$(openPanel==='preset-panel'?'preset-btn':'gear');
  if(panel&&!panel.contains(e.target)&&!(btn&&btn.contains(e.target)))closePanels();
},true);
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&openPanel)closePanels();});

function updatePresetButton(){
  const btn=$('preset-btn');if(!btn)return;
  btn.textContent=tableState.preset||'Preset';btn.title='Preset: cột, đơn vị và ảnh của bảng';
}
// Sau khi đổi preset hoặc thiết lập: lưu trạng thái, cập nhật preset tự tạo, vẽ lại bảng nếu đang mở.
function afterPresetChange(rebuild=true){
  updatePresetButton();persistView();
  if(rebuild&&tableState.data&&config.mode==='table')tableView(tableState.data);
}
function setSetting(key,value){
  tableState.settings={...workSettings(),[key]:value};
  syncCustomPreset();afterPresetChange();
}
function selectOf(options,current,label,onChange){
  const select=node('select');select.setAttribute('aria-label',label);
  const list=options.some(o=>String(o[0])===String(current))?options:[...options,[current,String(current)]];
  list.forEach(([value,text])=>select.append(new Option(text,String(value))));select.value=String(current);
  select.onchange=()=>onChange(select.value);return select;
}
function unitRow(title,digitsKey,unitKey,units,fixed){
  const s=workSettings(),c=presetChoices();
  const row=node('div',undefined,'pp-row');row.append(node('label',title));
  row.append(selectOf(c.digits.map(d=>[d,digitsLabel(d)]),s[digitsKey],title+': số lẻ',v=>setSetting(digitsKey,Number(v))));
  if(units)row.append(selectOf(units.map(u=>[u,unitLabel(u)]),s[unitKey],title+': đơn vị',v=>setSetting(unitKey,v)));
  return row;
}
// Khối thiết lập ảnh dùng cho cả ảnh chính và ảnh vị trí: cỡ, góc nhìn, kiểu hiển thị, lề, (vùng nhìn), góc lệch / góc cao (chỉ Chính diện), nền.
// keys: tên các mục trong thiết lập của preset; suffix: đuôi của nhãn đọc màn hình để hai khối không trùng nhãn.
function imageSettingsRows(left,s,c,keys,suffix,withScale){
  const size=node('div',undefined,'pp-row');
  size.append(selectOf(c.sizes.map(n=>[n,String(n)]),s[keys.width],'Chiều rộng ảnh'+suffix,v=>setSetting(keys.width,Number(v))),selectOf(c.sizes.map(n=>[n,String(n)]),s[keys.height],'Chiều cao ảnh'+suffix,v=>setSetting(keys.height,Number(v))));
  left.append(size);
  const angle=(label,key,min,max,tip)=>{
    const input=node('input');input.type='number';input.min=String(min);input.max=String(max);input.step='5';input.value=String(s[key]||0);
    input.setAttribute('aria-label',label+(suffix?' ảnh vị trí':'')+' (độ)');input.title=tip;
    input.onchange=()=>{const n=Number(input.value),v=Math.min(max,Math.max(min,Math.round(input.value.trim()!==''&&Number.isFinite(n)?n:0)));input.value=String(v);setSetting(key,v);};
    return input;
  };
  const yaw=angle('Lệch trái / phải',keys.yaw,-90,90,'Chỉ dùng khi góc nhìn là Chính diện: lệch camera sang phải (số dương) hoặc sang trái (số âm) so với nhìn thẳng, để thấy một chút bên hông món. 0 = nhìn thẳng.');
  const pitch=angle('Góc cao',keys.pitch,-30,80,'Chỉ dùng khi góc nhìn là Chính diện: nâng camera lên nhìn từ trên xuống (số dương). 0 = nhìn ngang.');
  const gate=view=>{yaw.disabled=pitch.disabled=view!=='front';};
  const look=node('div',undefined,'pp-row');
  look.append(selectOf(c.views.map(v=>[v,VIEW_LABELS[v]||v]),s[keys.view],'Góc nhìn ảnh'+suffix,v=>{gate(v);setSetting(keys.view,v);}),selectOf(c.styles.map(v=>[v,STYLE_LABELS[v]||v]),s[keys.style],'Kiểu hiển thị ảnh'+suffix,v=>setSetting(keys.style,v)));
  left.append(look);
  const margin=node('div',undefined,'pp-row');
  const marginInput=node('input');marginInput.type='number';marginInput.min='0';marginInput.max='100';marginInput.step='5';marginInput.value=String(s[keys.margin]);
  marginInput.setAttribute('aria-label','Chừa lề'+(suffix?' ảnh vị trí':'')+' (%)');marginInput.title='Chừa lề quanh món khi chụp ảnh Iso / Chính diện, tính theo %: 0 = ôm sát món, 20 = chừa 20%.';
  marginInput.onchange=()=>{const v=Math.min(100,Math.max(0,Math.round(Number(marginInput.value)||0)));marginInput.value=String(v);setSetting(keys.margin,v);};
  margin.append(node('label','Chừa lề (%)'),marginInput);left.append(margin);
  if(withScale){
    const scale=node('div',undefined,'pp-row');
    const scaleInput=node('input');scaleInput.type='number';scaleInput.min='1';scaleInput.max='20';scaleInput.step='1';scaleInput.value=String(s.image_location_scale);
    scaleInput.setAttribute('aria-label','Vùng nhìn ảnh vị trí (lần)');scaleInput.title='Ảnh vị trí nhìn vùng quanh món rộng gấp bao nhiêu lần kích thước món: 1 = đúng như ảnh Iso, 2 = gần, 4 = vừa, 10 = xa (thấy cả căn phòng).';
    scaleInput.onchange=()=>{const n=Number(scaleInput.value),v=Math.min(20,Math.max(1,Math.round(scaleInput.value.trim()!==''&&Number.isFinite(n)?n:4))); /* ô trống hoặc không phải số: về 4; số 0 trở xuống: về 1 */scaleInput.value=String(v);setSetting('image_location_scale',v);};
    scale.append(node('label','Vùng nhìn ảnh vị trí (lần)'),scaleInput);left.append(scale);
  }
  const tilt=node('div',undefined,'pp-row');tilt.append(node('label','Lệch trái / phải (độ)'),yaw);left.append(tilt);
  const raise=node('div',undefined,'pp-row');raise.append(node('label','Góc cao (độ)'),pitch);left.append(raise);
  gate(s[keys.view]);
  const bg=node('div',undefined,'pp-row');bg.append(selectOf(c.backgrounds.map(v=>[v,BACKGROUND_LABELS[v]||v]),s[keys.background],'Nền ảnh'+suffix,v=>setSetting(keys.background,v)));left.append(bg);
}
function presetPanel(panel){
  panel.replaceChildren();
  const s=workSettings(),c=presetChoices(),app=config.app||{settings:{image_dir:''},dir:''};
  const grid=node('div',undefined,'pp-grid');
  // ---- Cột trái: thiết lập theo preset ----
  const left=node('div',undefined,'pp-left');
  left.append(node('h3','Đơn vị'));
  left.append(unitRow('Chiều dài','length_digits','length_unit',c.length_units));
  left.append(unitRow('Diện tích','area_digits','area_unit',c.area_units));
  left.append(unitRow('Thể tích','volume_digits','volume_unit',c.volume_units));
  const money=node('div',undefined,'pp-row');money.append(node('label','Tiền tệ'),selectOf(c.currencies.map(x=>[x,x]),s.currency,'Tiền tệ',v=>setSetting('currency',v)));left.append(money);
  const sep=node('div',undefined,'pp-row');sep.append(node('label','Dấu thập phân'),selectOf(c.separators.map(x=>[x,x]),s.decimal_separator,'Dấu thập phân',v=>setSetting('decimal_separator',v)));left.append(sep);
  left.append(node('h3','Hình ảnh'));
  imageSettingsRows(left,s,c,{width:'image_width',height:'image_height',view:'image_view',style:'image_style',background:'image_background',margin:'image_margin',yaw:'image_yaw',pitch:'image_pitch'},'');
  // Ảnh vị trí (cột Ảnh vị trí) có bộ thiết lập riêng, cùng loại với ảnh chính; thêm ô Vùng nhìn.
  left.append(node('h3','Ảnh vị trí'));
  imageSettingsRows(left,s,c,{width:'loc_width',height:'loc_height',view:'loc_view',style:'loc_style',background:'loc_background',margin:'loc_margin',yaw:'loc_yaw',pitch:'loc_pitch'},' vị trí',true);
  const folder=node('div',undefined,'pp-row pp-folder');
  const dir=node('input');dir.type='text';dir.value=app.settings.image_dir;dir.placeholder=app.dir||'Thư mục lưu ảnh…';dir.maxLength=240;dir.setAttribute('aria-label','Thư mục lưu ảnh');dir.title='Thư mục lưu ảnh (dùng chung mọi preset). Để trống để dùng thư mục mặc định.';
  const commit=()=>{if(dir.value.trim()!==app.settings.image_dir)call('settings_save',JSON.stringify({image_dir:dir.value.trim()}));};
  dir.onchange=commit;dir.onkeydown=e=>{if(e.key==='Enter'){e.preventDefault();commit();}};
  const pick=button('📁',()=>call('settings_pick_dir'));pick.title='Chọn thư mục lưu ảnh';pick.setAttribute('aria-label','Chọn thư mục lưu ảnh');
  const open=button('↗',()=>call('images_open_dir'));open.title='Mở thư mục ảnh';open.setAttribute('aria-label','Mở thư mục ảnh');
  folder.append(dir,pick,open);left.append(folder);
  if(app.dir)left.append(node('p',`Đang dùng: ${app.dir}`+(app.dir_exists?'':' (chưa có, sẽ được tạo khi chụp ảnh đầu tiên)'),'muted pp-dir'));
  // ---- Số đo thân: bỏ tay nắm / phần nhô khỏi Rộng, Dài, Cao (dùng chung mọi preset, chỉ cho Bảng khối lượng) ----
  left.append(node('h3','Số đo thân'));
  const words=node('input');words.type='text';words.id='exclude-words';words.value=app.settings.exclude_words||'';words.maxLength=200;words.placeholder='tay nam, handle, knob';words.setAttribute('aria-label','Từ khóa loại trừ khỏi số đo');
  words.title='Group, component hoặc tag có tên chứa một trong các từ này (cách nhau dấu phẩy, không phân biệt hoa thường và dấu) không được tính vào Rộng / Dài / Cao.';
  const commitWords=()=>{if(words.value.trim()!==(app.settings.exclude_words||''))call('settings_save',JSON.stringify({exclude_words:words.value.trim()}));};
  words.onchange=commitWords;words.onkeydown=e=>{if(e.key==='Enter'){e.preventDefault();commitWords();}};
  const wordsRow=node('div',undefined,'pp-row pp-folder');wordsRow.append(words);left.append(wordsRow);
  left.append(node('p','Bỏ khỏi Rộng / Dài / Cao các phần có tên hoặc tag chứa từ khóa (xem cột Ghi chú số đo).','muted pp-note'));
  // ---- Cột phải: danh sách preset ----
  const right=node('div',undefined,'pp-right');
  const create=node('div',undefined,'pp-new');
  const name=node('input');name.type='text';name.placeholder='Tạo mới...';name.maxLength=40;name.setAttribute('aria-label','Tên preset mới');
  const add=button('+',()=>{
    const text=name.value.trim();if(!text)throw Error('Hãy nhập tên preset.');
    tableState.preset=text;
    call('table_preset',JSON.stringify({action:'save',name:text,group:tableState.group,columns:orderedKeys(),headers:tableState.headers,settings:workSettings()}));
  },'primary');add.setAttribute('aria-label','Tạo preset từ bảng hiện tại');
  name.onkeydown=e=>{if(e.key==='Enter'){e.preventDefault();add.click();}};
  create.append(name,add);right.append(create);
  const list=node('div',undefined,'pp-list');
  presetsList().forEach(preset=>{
    const line=node('div',undefined,'pp-line');
    const pick=button(preset.name,()=>{applyPreset(preset.name);afterPresetChange();presetPanel(panel);},'pp-pick'+(preset.name===tableState.preset?' active':''));
    const tail=button(preset.builtin?'↻':'×',()=>{
      if(preset.builtin){applyPreset(preset.name);afterPresetChange();presetPanel(panel);}
      else call('table_preset',JSON.stringify({action:'delete',name:preset.name}));
    },'pp-tail');
    tail.title=preset.builtin?'Khôi phục cột, tiêu đề và thiết lập gốc của preset':'Xóa preset';tail.setAttribute('aria-label',tail.title+': '+preset.name);
    line.append(pick,tail);list.append(line);
  });
  right.append(list,node('p','Preset lưu cột hiển thị, thứ tự, tiêu đề cột, đơn vị và cách chụp ảnh, trên máy này. Đang dùng preset tự tạo thì mọi thay đổi tự cập nhật vào preset đó.','muted'));
  grid.append(left,right);panel.append(grid);
}
function languagePanel(panel){
  panel.replaceChildren();
  const app=config.app||{settings:{language:'vi'}};
  const row=node('div',undefined,'pp-row');row.append(node('label','Ngôn ngữ'));
  row.append(selectOf([['vi','Tiếng Việt'],['en','English']],app.settings.language,'Ngôn ngữ',v=>call('settings_save',JSON.stringify({language:v}))));
  panel.append(row,node('p','Đổi ngôn ngữ sẽ tải lại cửa sổ. Báo cáo CSV luôn xuất bằng tiếng Việt.','muted'));
}
$('preset-btn').onclick=()=>togglePanel('preset-panel',$('preset-btn'),presetPanel);
$('gear').onclick=()=>togglePanel('gear-panel',$('gear'),languagePanel);
