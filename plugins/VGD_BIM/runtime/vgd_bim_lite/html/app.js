'use strict';
const $ = id => document.getElementById(id);
let config = {}, locale = {};
const fieldKeys = ['category','item_type','code','description','unit','quantity_method','zone','floor','include_boq','finish_code','manufacturer','model_number','note'];
const advancedKeys = ['finish_code','manufacturer','model_number','note'];
const label = key => (locale.fields || {})[key] || key;
function translated(group, value) {return (locale[group] || {})[String(value)] || (value == null ? '' : String(value));}
function displayValue(key, value) {return value === true ? 'Có' : value === false ? 'Không' : translated(key, value);}
function itemValue(text) {const entry = Object.entries(locale.item_type || {}).find(([,name])=>name===text.trim());return entry ? entry[0] : text.trim();}
function node(tag, text, cls) {const el=document.createElement(tag);if(text!==undefined)el.textContent=text;if(cls)el.className=cls;return el;}
function call(name,...args) {if(window.sketchup && window.sketchup[name])window.sketchup[name](...args);}
function message(text,error=false) {$('message').textContent=text || 'Sẵn sàng.';$('message').className=error?'error':'';}
function button(text,handler,cls) {const b=node('button',text,cls);b.type='button';b.onclick=()=>{try{handler()}catch(error){message(error.message,true)}};return b;}
function card(title) {const c=node('section',undefined,'card');c.append(node('h2',title));$('content').append(c);return c;}
function badge(value) {return node('span',translated('status',value),'badge '+(value==='ERROR'?'error':value==='WARNING'?'warning':''));}
function table(parent,headers,rows,render) {const wrap=node('div',undefined,'table-wrap'),t=node('table'),head=node('thead'),tr=node('tr');headers.forEach(h=>tr.append(node('th',h)));head.append(tr);t.append(head);const body=node('tbody');rows.forEach((r,i)=>{const tr=node('tr');render(r,tr,i);body.append(tr)});t.append(body);wrap.append(t);parent.append(wrap);if(!rows.length)parent.append(node('p','Chưa có dữ liệu để hiển thị.','empty'));return body;}
function cell(tr,value) {const td=node('td');value instanceof Node?td.append(value):td.textContent=value==null?'':String(value);tr.append(td);return td;}
function number(value,digits=1) {return Number(value).toLocaleString('vi-VN',{maximumFractionDigits:digits});}
function dimensions(values) {return ['width','depth','height'].map(k=>number(values[k] || 0)).join(' × ');}
function metrics(values) {const wrap=node('div',undefined,'metrics');Object.entries(values).forEach(([k,v])=>{const m=node('div',undefined,'metric');m.append(node('b',typeof v==='number'?number(v):v),node('span',translated('metrics',k)));wrap.append(m)});$('content').append(wrap);}
function scope(options) {const wrap=node('div',undefined,'scope');options.forEach(([text,mode])=>wrap.append(button(text,()=>call('open_panel',mode),mode===config.mode?'active':'')));$('content').append(wrap);}
function fields(parent,values,enable=false) {
  const preset=node('select',undefined,'preset');preset.id='preset';preset.setAttribute('aria-label','Mẫu hạng mục');preset.append(new Option('Chọn mẫu hạng mục…',''));(config.presets || []).forEach((p,i)=>preset.append(new Option(translated('presets',p.name),String(i))));parent.append(preset);
  const grid=node('div',undefined,'fields');parent.append(grid);
  const extra=node('details',undefined,'extra-fields');extra.append(node('summary','Thông tin bổ sung · Hoàn thiện, hãng, sản phẩm, ghi chú'));const extraGrid=node('div',undefined,'fields');extra.append(extraGrid);parent.append(extra);
  fieldKeys.forEach(key=>{
    const row=node('div',undefined,'field'),check=node('input');check.type='checkbox';check.id='update-'+key;check.checked=enable && Object.prototype.hasOwnProperty.call(values,key);check.setAttribute('aria-label','Cập nhật '+label(key));
    const body=node('div'),caption=node('label',label(key));caption.htmlFor='field-'+key;let input;
    const options=key==='category'?config.categories:key==='unit'?config.units:key==='quantity_method'?config.methods:key==='include_boq'?['true','false']:null;
    if(options){input=node('select');input.append(new Option(values[key]===null?'Nhiều giá trị · Giữ nguyên':'Chưa chọn',''));options.forEach(v=>input.append(new Option(key==='include_boq'?(v==='true'?'Có':'Không'):translated(key,v),v)));}
    else {input=node(key==='note'?'textarea':'input');if(key!=='note')input.type='text';input.placeholder=values[key]===null?'Nhiều giá trị · Giữ nguyên':key==='description'?'Ví dụ: Tủ áo phòng ngủ chính':key==='zone'?'Ví dụ: Phòng khách':key==='floor'?'Ví dụ: Tầng 1':'';}
    input.id='field-'+key;input.value=values[key]==null?'':key==='item_type'?translated('item_type',values[key]):String(values[key]);input.disabled=!check.checked;
    if(key==='item_type'){input.setAttribute('list','item-types');const list=node('datalist');list.id='item-types';Object.values(locale.item_type || {}).forEach(v=>list.append(new Option(v,v)));body.append(list);}
    check.onchange=()=>{input.disabled=!check.checked};input.oninput=()=>{check.checked=true};body.append(caption,input);row.append(check,body);(advancedKeys.includes(key)?extraGrid:grid).append(row);
  });
  preset.onchange=()=>{if(preset.value==='')return;const data=config.presets[Number(preset.value)];fieldKeys.forEach(key=>{if(!Object.prototype.hasOwnProperty.call(data,key))return;$('update-'+key).checked=true;$('field-'+key).disabled=false;$('field-'+key).value=key==='item_type'?translated('item_type',data[key]):String(data[key]);});};
  parent.append(node('p','Đánh dấu các trường cần sửa. Trường không đánh dấu sẽ giữ nguyên; đánh dấu và để trống để xóa nội dung.','muted'));
}
function formData() {const data={};fieldKeys.forEach(key=>{if(!$('update-'+key).checked)return;const value=$('field-'+key).value;if(key==='include_boq'&&value==='')throw Error('Hãy chọn Có hoặc Không cho mục đưa vào bảng khối lượng.');data[key]=key==='include_boq'?value==='true':key==='item_type'?itemValue(value):value});return data;}
function information(data) {
  $('content').replaceChildren();scope([['Nhập / Sửa thông tin','information'],['Chuyển đổi lựa chọn','convert_selection']]);
  const convert=config.mode==='convert_selection',c=card(convert?'Chuyển đổi đối tượng đang chọn':'Thông tin đối tượng');
  c.append(node('p',data.count?`Đang chọn ${data.count} đối tượng trong SketchUp.`:'Hãy chọn nhóm hoặc đồ nội thất trong SketchUp để bắt đầu.','hint'));
  fields(c,data.fields,false);const actions=$('primary-actions');actions.replaceChildren();const apply=button(convert?'Xem trước chuyển đổi':'Áp dụng thông tin',()=>call(convert?'preview_convert':'apply',JSON.stringify(convert?{data:formData()}:formData())),'primary');apply.disabled=!data.count;actions.append(apply);
  if(!convert){const clear=button('Xóa dữ liệu VGD',()=>call('clear'));clear.disabled=!data.count;actions.append(clear);}
  const raw=card('Thông tin từ SketchUp · Chỉ xem');table(raw,['Loại / Nguồn','Tên đối tượng / Định nghĩa','Thẻ / Vật liệu','Rộng × Sâu × Cao (mm)','Trạng thái'],data.objects,(r,tr)=>{cell(tr,`${r.entity_type==='Group'?'Nhóm':'Thành phần'} / ${translated('source',r.source)}`);cell(tr,`${r.instance_name||'Chưa đặt tên'} / ${r.definition_name}`);cell(tr,`${r.tag} / ${r.material||'Chưa có vật liệu'}`);cell(tr,dimensions(r.dimensions));cell(tr,badge(r.locked?'LOCKED':r.status));});
}
function scan(data) {
  $('content').replaceChildren();metrics(data.summary);const components=card('Thống kê thành phần của mô hình');
  table(components,['Tên định nghĩa','Tên đối tượng','Số lượng','Thẻ / Vật liệu','Rộng × Sâu × Cao mẫu (mm)'],data.components,(r,tr)=>{cell(tr,r.definition_name||'Chưa đặt tên');cell(tr,r.names.join(', '));cell(tr,r.instances);cell(tr,r.tags.join(', ')+' / '+(r.material||'Chưa có vật liệu'));cell(tr,dimensions(r.dimensions)+(r.dimension_variants>1?` (${r.dimension_variants} biến thể)`:''));});
  const materials=card('Diện tích vật liệu · Khối lượng hình học gốc');materials.append(node('p','Diện tích mặt trước có tính vật liệu kế thừa. Mặt sau có sơn được báo riêng. Số liệu chưa trừ hao hụt hoặc phần che khuất.','hint'));
  table(materials,['Vật liệu','Mặt trước (m²)','Mặt sau có sơn (m²)','Số mặt trước'],data.materials,(r,tr)=>{cell(tr,r.material==='(Unpainted)'?'Chưa có vật liệu':r.material);cell(tr,number(r.area,3));cell(tr,number(r.back_area,3));cell(tr,r.faces);});materials.append(button('Xuất báo cáo để mở trong Excel',()=>call('open_panel','export'),'primary'));
}
function editMapping(row) {
  const old=$('mapping-editor');if(old)old.remove();const c=card(`Phân loại: ${row.source_value||'Chưa đặt tên'}`);c.id='mapping-editor';
  c.append(node('p',`${row.instances} lần xuất hiện · ${row.eligible} đối tượng có thể ghi · ${row.protected} lần xuất hiện được bảo vệ.`));fields(c,row.suggestion.data,true);
  const save=node('input');save.type='checkbox';save.id='save-rule';save.checked=row.kind==='material';const caption=node('label',' Lưu quy tắc để dùng lại');caption.prepend(save);c.append(caption);
  const actions=node('div',undefined,'actions');actions.append(button(row.kind==='material'?'Xem trước quy tắc vật liệu':'Xem trước chuyển đổi',()=>call('preview_convert',JSON.stringify({index:row.index,data:formData(),save_rule:save.checked})),'primary'));c.append(actions);c.scrollIntoView({block:'start'});
}
function mapping(data) {
  $('content').replaceChildren();const c=card('Phân loại / Chuyển đổi mô hình');c.append(node('p','Chọn một dòng → sửa thông tin → xem trước → xác nhận. Dữ liệu VGD đã có được giữ nguyên. Với vật liệu, chỉ lưu quy tắc phân loại.','hint'));
  const search=node('input');search.type='search';search.placeholder='Tìm tên đối tượng hoặc vật liệu…';search.className='search';c.append(search);
  const body=table(c,['Nguồn','Số lượng / Có thể ghi','Gợi ý hạng mục','Độ tin cậy / Căn cứ','Trạng thái','Thao tác'],data,(r,tr)=>{cell(tr,`${r.source_value||'Chưa đặt tên'} (${r.kind==='material'?'vật liệu':'đối tượng'})`);cell(tr,`${r.instances} / ${r.eligible}`);cell(tr,[translated('category',r.suggestion.data.category),translated('item_type',r.suggestion.data.item_type),translated('quantity_method',r.suggestion.data.quantity_method)].filter(Boolean).join(' / ')||'Chưa có gợi ý');cell(tr,`${translated('confidence',r.suggestion.confidence)} / ${translated('source',r.suggestion.source)}`);cell(tr,badge(r.status||'REVIEW'));const actions=node('div',undefined,'actions');actions.append(button('Chỉnh thông tin',()=>editMapping(r)),button('Bỏ qua',()=>{tr.classList.toggle('ignored')}));cell(tr,actions);});
  search.oninput=()=>Array.from(body.children).forEach((tr,i)=>{tr.hidden=!data[i].source_value.toLocaleLowerCase('vi').includes(search.value.toLocaleLowerCase('vi'))});
}
function validation(data) {
  $('content').replaceChildren();scope([['Toàn bộ mô hình','validate_model'],['Đối tượng đang chọn','validate_selection']]);const count=s=>data.filter(r=>r.issues.some(i=>i.severity===s)).length;
  metrics({'Đối tượng đã quét':data.length,'Sẵn sàng':data.filter(r=>r.status==='VGD READY').length,'Cảnh báo':count('WARNING'),'Có lỗi':count('ERROR'),'Chưa phân loại':data.filter(r=>r.status==='UNCLASSIFIED').length});
  const c=card('Kết quả kiểm tra');c.append(node('p','Bấm vào dòng kết quả để chọn và phóng tới đúng đối tượng trong SketchUp. Đối tượng chưa phân loại không bị coi là lỗi.','hint'));
  table(c,['Trạng thái','Đối tượng / Đường dẫn','Nội dung kiểm tra'],data,(r,tr)=>{tr.className='clickable';tr.tabIndex=0;tr.onclick=()=>call('select_entity',r.index);tr.onkeydown=e=>{if(e.key==='Enter')tr.click()};cell(tr,badge(r.status));cell(tr,r.instance_name||r.definition_name||r.path||'Chưa đặt tên');const issues=node('div');r.issues.forEach(i=>{const p=node('p');p.append(badge(i.severity),document.createTextNode(' '+i.message));issues.append(p)});cell(tr,issues);});c.append(button('Xuất kết quả kiểm tra',()=>call('open_panel','export')));
}
function editRule(rule={},index) {
  const old=$('rule-editor');if(old)old.remove();const c=card(index===undefined?'Thêm quy tắc phân loại':'Sửa quy tắc phân loại');c.id='rule-editor';
  const source=node('div',undefined,'rule-source'),typeLabel=node('label','Dựa trên'),type=node('select');type.id='rule-source-type';Object.keys(locale.source_type || {}).forEach(key=>type.append(new Option(translated('source_type',key),key)));type.value=rule.source_type||'definition_name';typeLabel.append(type);
  const valueLabel=node('label','Tên nguồn cần khớp'),value=node('input');value.id='rule-source-value';value.value=rule.source_value||'';valueLabel.append(value);source.append(typeLabel,valueLabel);c.append(source);fields(c,rule.data||{},true);
  c.append(button('Lưu quy tắc',()=>{if(!value.value.trim())throw Error('Hãy nhập tên nguồn cần khớp.');call('save_rule',JSON.stringify({...(index===undefined?{}:{index}),source_type:type.value,source_value:value.value.trim(),data:{...(rule.data||{}),...formData()}}));},'primary'));c.scrollIntoView({block:'start'});
}
function rules(data) {
  $('content').replaceChildren();const c=card('Quy tắc phân loại');c.append(node('p','Lưu cách phân loại theo tên để dùng lại. Quy tắc nằm trong file SketchUp; xuất / nhập để dùng ở model khác.','hint'));
  table(c,['Dựa trên','Tên nguồn','Hạng mục','Thao tác'],data,(r,tr,index)=>{cell(tr,translated('source_type',r.source_type));cell(tr,r.source_value);cell(tr,[translated('category',r.data.category),translated('item_type',r.data.item_type)].filter(Boolean).join(' / '));cell(tr,button('Sửa',()=>editRule(r,index)));});
  const actions=node('div',undefined,'actions');actions.append(button('Thêm quy tắc',()=>editRule()),button('Xuất bộ quy tắc',()=>call('export_rules')),button('Nhập bộ quy tắc',()=>call('import_rules')));c.append(actions);
  const advanced=node('details',undefined,'help');advanced.append(node('summary','Nâng cao · Chỉnh dữ liệu kỹ thuật'));const text=node('textarea');text.id='rules-json';text.className='rules';text.value=JSON.stringify(data,null,2);advanced.append(node('p','Tên trường kỹ thuật giữ nguyên để các plugin VGD dùng chung dữ liệu.'),text,button('Lưu dữ liệu kỹ thuật',()=>{let parsed;try{parsed=JSON.parse(text.value)}catch(_){throw Error('Dữ liệu kỹ thuật không đúng định dạng.')}call('save_rules',JSON.stringify(parsed));}));c.append(advanced);
}
function exportPanel(data) {
  $('content').replaceChildren();const c=card('Xuất báo cáo để mở trong Excel');c.append(node('p',`Đã quét ${data.objects} đối tượng và ${data.faces} mặt hình học. Chọn báo cáo, rồi chọn nơi lưu file. Tiêu đề và hạng mục xuất bằng tiếng Việt.`,'hint'));
  const list=node('div',undefined,'export-list');
  [['bim','Danh mục đối tượng','Mã, mô tả, nhóm hạng mục, khu vực, tầng, đơn vị, kích thước và nguồn dữ liệu.'],['components','Thống kê thành phần','Số lần xuất hiện theo định nghĩa, tên, thẻ, vật liệu và kích thước mẫu.'],['materials','Diện tích vật liệu gốc','Diện tích mặt trước và mặt sau có sơn. Chưa phải khối lượng báo giá đã kiểm duyệt.'],['validation','Kết quả kiểm tra','Danh sách thông tin thiếu, lỗi đơn vị và cảnh báo cần xem lại.']].forEach(([kind,title,hint])=>{const item=node('section',undefined,'export-item');item.append(node('h3',title),node('p',hint),button('Xuất CSV · '+title,()=>call('export_report',kind),'primary'));list.append(item);});c.append(list);
  c.append(node('p','Báo cáo chưa tính đơn giá hoặc thành tiền. File CSV dùng tiếng Việt UTF-8, dấu chấm phẩy tách cột và dấu phẩy thập phân. Nếu Excel chưa tách cột, vào Dữ liệu → Từ văn bản/CSV, chọn UTF-8 và dấu chấm phẩy.','muted'));
}
function preview(data) {
  const p=$('preview-content');p.replaceChildren();p.append(node('p',`Sẽ ghi dữ liệu cho ${data.objects} đối tượng (${data.occurrences} lần xuất hiện). Bỏ qua ${data.skipped} lần xuất hiện.`));
  if(data.material)p.append(node('p','Chỉ lưu quy tắc vật liệu; các mặt hình học không được chuyển thành đối tượng BIM.'));
  if(data.shared)p.append(node('p','Đối tượng lồng trong định nghĩa dùng chung sẽ nhận cùng dữ liệu ở mọi lần xuất hiện.'));
  if(data.rule)p.append(node('p','Quy tắc phân loại sẽ được lưu để dùng lại.'));
  const dl=node('dl',undefined,'preview-values');Object.entries(data.data).forEach(([key,value])=>dl.append(node('dt',label(key)),node('dd',displayValue(key,value))));p.append(dl,node('p','Giữ nguyên hình học, tên, thẻ và vật liệu.'));$('confirm-preview').disabled=false;$('preview').showModal();
}
window.VGD={receive(event,data){
  if(event==='config'){config=data;locale=data.locale||locale;$('subtitle').textContent=`${data.version} · ${translated('modes',data.mode)}`;document.querySelectorAll('[data-mode]').forEach(b=>{const active=b.dataset.mode===data.mode || (b.dataset.mode==='information'&&data.mode==='convert_selection') || (b.dataset.mode==='validate_model'&&data.mode==='validate_selection');b.classList.toggle('active',active);b.setAttribute('aria-selected',String(active));});$('preview').close();$('content').replaceChildren();$('primary-actions').replaceChildren();document.querySelector('main').scrollTop=0;message('Đang đọc dữ liệu…');}
  const renderers={information,scan,mapping,validation,rules,export:exportPanel};if(renderers[event]){renderers[event](data);message('Sẵn sàng.');}
  if(event==='progress')message(`Đang quét… ${number(data.count,0)} đối tượng hình học.`);
  if(event==='message')message(data.error||data.text,!!data.error);
  if(event==='preview')preview(data);
}};
$('refresh').onclick=()=>call('refresh');$('cancel-preview').onclick=()=>$('preview').close();$('confirm-preview').onclick=()=>{$('confirm-preview').disabled=true;$('preview').close();call('confirm_convert')};document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>call('open_panel',b.dataset.mode));
let dark=true;try{dark=localStorage.getItem('VGD_BIM_theme')!=='light'}catch(_){}applyTheme();
function applyTheme(){document.body.classList.toggle('dark',dark);document.body.classList.toggle('light',!dark);$('brand-logo').src=dark?'../assets/icons/vgd_primary_dark.svg':'../assets/icons/vgd_primary_light.svg';$('theme').textContent=dark?'Giao diện sáng':'Giao diện tối';$('theme').title=dark?'Chuyển sang giao diện sáng':'Chuyển sang giao diện tối';}
$('theme').onclick=()=>{dark=!dark;applyTheme();try{localStorage.setItem('VGD_BIM_theme',dark?'dark':'light')}catch(_){}};
document.addEventListener('DOMContentLoaded',()=>call('ready'));
