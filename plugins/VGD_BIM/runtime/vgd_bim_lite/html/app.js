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
  $('content').replaceChildren();
  const c=card('Thông tin đối tượng');
  c.append(node('p',data.count?`Đang chọn ${data.count} đối tượng trong SketchUp.`:'Hãy chọn nhóm hoặc đồ nội thất trong SketchUp để bắt đầu.','hint'));
  fields(c,data.fields,false);const actions=$('primary-actions');actions.replaceChildren();const apply=button('Áp dụng thông tin',()=>call('apply',JSON.stringify(formData())),'primary');apply.disabled=!data.count;actions.append(apply);
  const clear=button('Xóa dữ liệu VGD',()=>call('clear'));clear.disabled=!data.count;actions.append(clear);
  const raw=card('Thông tin từ SketchUp · Chỉ xem');table(raw,['Loại / Nguồn','Tên đối tượng / Định nghĩa','Thẻ / Vật liệu','Rộng × Sâu × Cao (mm)','Trạng thái'],data.objects,(r,tr)=>{cell(tr,`${r.entity_type==='Group'?'Nhóm':'Thành phần'} / ${translated('source',r.source)}`);cell(tr,`${r.instance_name||'Chưa đặt tên'} / ${r.definition_name}`);cell(tr,`${r.tag} / ${r.material||'Chưa có vật liệu'}`);cell(tr,dimensions(r.dimensions));cell(tr,badge(r.locked?'LOCKED':r.status));});
}
function scanOptionsBar(parent) {
  const opts=config.scan_options||{scope:'model',faces:true};
  const bar=node('div',undefined,'scan-options');
  const scopeLabel=node('label','Phạm vi quét ');const scope=node('select');scope.setAttribute('aria-label','Phạm vi quét');
  [['model','Toàn bộ model'],['selection','Group / đối tượng đang chọn']].forEach(([v,t])=>scope.append(new Option(t,v)));scope.value=opts.scope;scopeLabel.append(scope);
  const faces=node('input');faces.type='checkbox';faces.checked=!!opts.faces;faces.id='scan-faces';
  const faceLabel=node('label');faceLabel.append(faces,document.createTextNode(' Quét cả mặt (để tính m²)'));
  const apply=()=>call('scan_options',JSON.stringify({scope:scope.value,faces:faces.checked}));
  scope.onchange=apply;faces.onchange=apply;
  bar.append(scopeLabel,faceLabel);
  bar.append(node('p',faces.checked?'Quét cả mặt sẽ chậm hơn với model lớn. Tắt nếu chỉ cần đếm group / component.':'Đang tắt quét mặt: diện tích và số liệu theo mặt sẽ để trống.','muted'));
  parent.append(bar);
}
function scan(data) {
  $('content').replaceChildren();scanOptionsBar($('content'));metrics(data.summary);const components=card('Thống kê thành phần của mô hình');
  table(components,['Tên định nghĩa','Tên đối tượng','Số lượng','Thẻ / Vật liệu','Rộng × Sâu × Cao mẫu (mm)'],data.components,(r,tr)=>{cell(tr,r.definition_name||'Chưa đặt tên');cell(tr,r.names.join(', '));cell(tr,r.instances);cell(tr,r.tags.join(', ')+' / '+(r.material||'Chưa có vật liệu'));cell(tr,dimensions(r.dimensions)+(r.dimension_variants>1?` (${r.dimension_variants} biến thể)`:''));});
  const materials=card('Diện tích vật liệu · Khối lượng hình học gốc');materials.append(node('p','Diện tích mặt trước có tính vật liệu kế thừa. Mặt sau có sơn được báo riêng. Số liệu chưa trừ hao hụt hoặc phần che khuất.','hint'));
  table(materials,['Vật liệu','Mặt trước (m²)','Mặt sau có sơn (m²)','Số mặt trước'],data.materials,(r,tr)=>{cell(tr,r.material==='(Unpainted)'?'Chưa có vật liệu':r.material);cell(tr,number(r.area,3));cell(tr,number(r.back_area,3));cell(tr,r.faces);});if(data.export)exportCard(data.export);
}
function editMapping(row) {
  const old=$('mapping-editor');if(old)old.remove();const c=card(`Phân loại: ${row.source_value||'Chưa đặt tên'}`);c.id='mapping-editor';
  c.append(node('p',`${row.instances} lần xuất hiện · ${row.eligible} đối tượng có thể ghi · ${row.protected} lần xuất hiện được bảo vệ.`));fields(c,row.suggestion.data,true);
  const save=node('input');save.type='checkbox';save.id='save-rule';save.checked=row.kind==='material';const caption=node('label',' Lưu quy tắc để dùng lại');caption.prepend(save);c.append(caption);
  const actions=node('div',undefined,'actions');actions.append(button(row.kind==='material'?'Xem trước quy tắc vật liệu':'Xem trước chuyển đổi',()=>call('preview_convert',JSON.stringify({index:row.index,data:formData(),save_rule:save.checked})),'primary'));c.append(actions);c.scrollIntoView({block:'start'});
}
// Tab Phân loại gồm 3 phần: Phân loại · Quy tắc · Kiểm tra.
function subTabs() {const wrap=node('div',undefined,'scope subtabs');const now=config.mode==='validate_selection'?'validate_model':config.mode;[['Phân loại','mapping'],['Quy tắc','rules'],['Kiểm tra','validate_model']].forEach(([text,mode])=>wrap.append(button(text,()=>call('open_panel',mode),mode===now?'active':'')));$('content').append(wrap);}
function mapping(data) {
  $('content').replaceChildren();subTabs();scanOptionsBar($('content'));const c=card('Phân loại / Chuyển đổi mô hình');c.append(node('p','Chọn một dòng → sửa thông tin → xem trước → xác nhận. Dữ liệu VGD đã có được giữ nguyên. Với vật liệu, chỉ lưu quy tắc phân loại.','hint'));
  const search=node('input');search.type='search';search.placeholder='Tìm tên đối tượng hoặc vật liệu…';search.className='search';c.append(search);
  const body=table(c,['Nguồn','Số lượng / Có thể ghi','Gợi ý hạng mục','Độ tin cậy / Căn cứ','Trạng thái','Thao tác'],data,(r,tr)=>{cell(tr,`${r.source_value||'Chưa đặt tên'} (${r.kind==='material'?'vật liệu':'đối tượng'})`);cell(tr,`${r.instances} / ${r.eligible}`);cell(tr,[translated('category',r.suggestion.data.category),translated('item_type',r.suggestion.data.item_type),translated('quantity_method',r.suggestion.data.quantity_method)].filter(Boolean).join(' / ')||'Chưa có gợi ý');cell(tr,`${translated('confidence',r.suggestion.confidence)} / ${translated('source',r.suggestion.source)}`);cell(tr,badge(r.status||'REVIEW'));const actions=node('div',undefined,'actions');actions.append(button('Chỉnh thông tin',()=>editMapping(r)),button('Bỏ qua',()=>{tr.classList.toggle('ignored')}));cell(tr,actions);});
  search.oninput=()=>Array.from(body.children).forEach((tr,i)=>{tr.hidden=!data[i].source_value.toLocaleLowerCase('vi').includes(search.value.toLocaleLowerCase('vi'))});
}
function validation(data) {
  $('content').replaceChildren();subTabs();scope([['Toàn bộ mô hình','validate_model'],['Đối tượng đang chọn','validate_selection']]);const count=s=>data.filter(r=>r.issues.some(i=>i.severity===s)).length;
  metrics({'Đối tượng đã quét':data.length,'Sẵn sàng':data.filter(r=>r.status==='VGD READY').length,'Cảnh báo':count('WARNING'),'Có lỗi':count('ERROR'),'Chưa phân loại':data.filter(r=>r.status==='UNCLASSIFIED').length});
  const c=card('Kết quả kiểm tra');c.append(node('p','Bấm vào dòng kết quả để chọn và phóng tới đúng đối tượng trong SketchUp. Đối tượng chưa phân loại không bị coi là lỗi.','hint'));
  table(c,['Trạng thái','Đối tượng / Đường dẫn','Nội dung kiểm tra'],data,(r,tr)=>{tr.className='clickable';tr.tabIndex=0;tr.onclick=()=>call('select_entity',r.index);tr.onkeydown=e=>{if(e.key==='Enter')tr.click()};cell(tr,badge(r.status));cell(tr,r.instance_name||r.definition_name||r.path||'Chưa đặt tên');const issues=node('div');r.issues.forEach(i=>{const p=node('p');p.append(badge(i.severity),document.createTextNode(' '+i.message));issues.append(p)});cell(tr,issues);});c.append(button('Xuất kết quả kiểm tra',()=>call('open_panel','scan')));
}
function editRule(rule={},index) {
  const old=$('rule-editor');if(old)old.remove();const c=card(index===undefined?'Thêm quy tắc phân loại':'Sửa quy tắc phân loại');c.id='rule-editor';
  const source=node('div',undefined,'rule-source'),typeLabel=node('label','Dựa trên'),type=node('select');type.id='rule-source-type';Object.keys(locale.source_type || {}).forEach(key=>type.append(new Option(translated('source_type',key),key)));type.value=rule.source_type||'definition_name';typeLabel.append(type);
  const valueLabel=node('label','Tên nguồn cần khớp'),value=node('input');value.id='rule-source-value';value.value=rule.source_value||'';valueLabel.append(value);source.append(typeLabel,valueLabel);c.append(source);fields(c,rule.data||{},true);
  c.append(button('Lưu quy tắc',()=>{if(!value.value.trim())throw Error('Hãy nhập tên nguồn cần khớp.');call('save_rule',JSON.stringify({...(index===undefined?{}:{index}),source_type:type.value,source_value:value.value.trim(),data:{...(rule.data||{}),...formData()}}));},'primary'));c.scrollIntoView({block:'start'});
}
function rules(data) {
  $('content').replaceChildren();subTabs();const c=card('Quy tắc phân loại');c.append(node('p','Lưu cách phân loại theo tên để dùng lại. Quy tắc nằm trong file SketchUp; xuất / nhập để dùng ở model khác.','hint'));
  table(c,['Dựa trên','Tên nguồn','Hạng mục','Thao tác'],data,(r,tr,index)=>{cell(tr,translated('source_type',r.source_type));cell(tr,r.source_value);cell(tr,[translated('category',r.data.category),translated('item_type',r.data.item_type)].filter(Boolean).join(' / '));cell(tr,button('Sửa',()=>editRule(r,index)));});
  const actions=node('div',undefined,'actions');actions.append(button('Thêm quy tắc',()=>editRule()),button('Xuất bộ quy tắc',()=>call('export_rules')),button('Nhập bộ quy tắc',()=>call('import_rules')));c.append(actions);
  const advanced=node('details',undefined,'help');advanced.append(node('summary','Nâng cao · Chỉnh dữ liệu kỹ thuật'));const text=node('textarea');text.id='rules-json';text.className='rules';text.value=JSON.stringify(data,null,2);advanced.append(node('p','Tên trường kỹ thuật giữ nguyên để các plugin VGD dùng chung dữ liệu.'),text,button('Lưu dữ liệu kỹ thuật',()=>{let parsed;try{parsed=JSON.parse(text.value)}catch(_){throw Error('Dữ liệu kỹ thuật không đúng định dạng.')}call('save_rules',JSON.stringify(parsed));}));c.append(advanced);
}
function tagEditor(data) {
  $('content').replaceChildren();
  const c=card('Soạn tag');
  c.append(node('p','Soạn bộ tag một lần rồi dùng lại cho mọi model. Tên không phân biệt chữ hoa, chữ thường. Bộ tag lưu trên máy này, không nằm trong file model.','hint'));
  const wrap=node('div',undefined,'table-wrap'),t=node('table'),head=node('thead'),htr=node('tr');
  ['Tên tag','Nhóm','Trong model','Thao tác'].forEach(h=>htr.append(node('th',h)));head.append(htr);t.append(head);
  const tbody=node('tbody');t.append(tbody);wrap.append(t);c.append(wrap);
  const rows=[];
  const choose=(values,current,text)=>{const select=node('select');values.forEach(v=>select.append(new Option(text?text(v):v,v)));select.value=current;return select;};
  const addRow=tag=>{
    const tr=node('tr'),name=node('input');name.type='text';name.value=tag.name||'';name.setAttribute('aria-label','Tên tag');
    const group=choose(data.groups,tag.group||data.groups[0]);group.setAttribute('aria-label','Nhóm');
    const status=tag.in_model===undefined?'Mới':tag.in_model?(tag.visible?'Có trong model':'Có trong model · đang ẩn'):'Chưa có trong model';
    const row={name,group,tr,removed:false};
    cell(tr,name);cell(tr,group);cell(tr,status);
    cell(tr,button('Xóa',()=>{row.removed=true;tr.remove();}));
    rows.push(row);tbody.append(tr);
  };
  (data.tags||[]).forEach(addRow);
  const actions=node('div',undefined,'actions');
  actions.append(button('Thêm tag',()=>addRow({name:'',group:data.groups[0]})),button('Lưu bộ tag',()=>{
    const list=rows.filter(r=>!r.removed).map(r=>({name:r.name.value.trim(),group:r.group.value})).filter(r=>r.name!=='');
    call('save_tags',JSON.stringify(list));
  },'primary'));
  c.append(actions);
  const io=node('div',undefined,'actions');
  io.append(button('Nhập Excel (CSV)',()=>call('import_tags','csv')),button('Nhập JSON',()=>call('import_tags','json')),button('Xuất Excel (CSV)',()=>call('export_tags','csv')),button('Xuất JSON',()=>call('export_tags','json')));
  c.append(io,node('p','Xuất / nhập áp dụng cho bộ tag đã lưu. Excel dùng file CSV, mở và lưu được bằng Excel. Nếu Excel báo lỗi, hãy lưu lại file dưới dạng CSV UTF-8.','muted'));
  const assign=card('Gán tag cho đối tượng đang chọn');
  const info=node('p',`Đang chọn ${data.selection} đối tượng hoặc mặt trong SketchUp.`,'hint');info.id='tag-selection-text';
  const pick=node('select');pick.id='tag-pick';pick.setAttribute('aria-label','Chọn tag');
  (data.tags||[]).forEach(tag=>pick.append(new Option(tag.name,tag.name)));
  const go=button('Gán tag',()=>{if(!pick.value)throw Error('Hãy lưu bộ tag trước, rồi chọn tag để gán.');call('assign_tag',JSON.stringify({name:pick.value}));},'primary');
  go.id='tag-assign';go.disabled=!data.selection||!(data.tags||[]).length;
  assign.append(info,pick,go,node('p','Gán tag cho các đối tượng được chọn trực tiếp. Nếu tag đang tắt hiển thị, các đối tượng gán vào sẽ bị ẩn.','muted'));
}
function exportCard(data) {
  const c=card('Xuất báo cáo để mở trong Excel');c.append(node('p',`Đã quét ${data.objects} đối tượng và ${data.faces} mặt hình học. Chọn báo cáo, rồi chọn nơi lưu file. Tiêu đề và hạng mục xuất bằng tiếng Việt.`,'hint'));
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
// ---- Bảng đối tượng kiểu Auto Info ----
const tableState={restored:false,savedView:'',data:null,preset:'Tất cả',group:'',search:'',order:[],visible:new Set(),sort:null,widths:{},onlyTop:true,showTotals:true,density:'',sel:new Set(),anchor:null,displayed:[],groupBy:'',merge:false,collapsed:new Set(),panel:null,colSearch:'',dragKey:null};
const NUMERIC=new Set(['lenX','lenY','lenZ','areaXZ','areaXY','areaFace','volume','quantity']);
const DIGITS={areaXZ:2,areaXY:2,areaFace:2,volume:3,quantity:0};
const UNIT_TEXT={lenX:'mm',lenY:'mm',lenZ:'mm',areaXZ:'m²',areaXY:'m²',areaFace:'m²',volume:'m³',quantity:'cái'};
const WIDTHS={ordinal:44,entity:90,definition:150,instance:180,description:200,status:120,tag:130,tag_group:130,material:150,quantity:80};
const digitsFor=key=>key.startsWith('len')?0:(DIGITS[key]??2);
const fmt=(value,digits)=>value==null||value===''?'':Number(value).toLocaleString('vi-VN',{minimumFractionDigits:digits,maximumFractionDigits:digits});
const widthOf=key=>tableState.widths[key]||WIDTHS[key]||110;
const colByKey=key=>tableState.data.columns.find(c=>c.key===key);
function presetByName(name){const list=tableState.data.presets||[];return list.find(p=>p.name===name)||list[0];}
function applyPreset(name){
  const p=presetByName(name);if(!p)return;
  tableState.preset=p.name;tableState.group=p.group||'';
  const rest=tableState.data.columns.map(c=>c.key).filter(k=>!p.columns.includes(k));
  tableState.order=[...p.columns,...rest];tableState.visible=new Set(p.columns);
}
// Lưu trạng thái bảng (preset, cột, thứ tự, độ rộng, nhóm, ...) để lần mở sau vẫn như cũ.
let viewTimer=null;
function viewState(){return {preset:tableState.preset,group:tableState.group,order:tableState.order,visible:[...tableState.visible],widths:tableState.widths,density:tableState.density,showTotals:tableState.showTotals,onlyTop:tableState.onlyTop};}
function persistView(){clearTimeout(viewTimer);viewTimer=setTimeout(()=>{const json=JSON.stringify(viewState());if(json===tableState.savedView)return;tableState.savedView=json;call('table_view',json);},400);}
function restoreView(data){
  tableState.restored=true;const v=data.view||{};if(!v.preset&&!(v.order||[]).length)return false;
  const keys=data.columns.map(c=>c.key);
  if((data.presets||[]).some(p=>p.name===v.preset))tableState.preset=v.preset;
  if(typeof v.group==='string')tableState.group=v.group;
  const order=(v.order||[]).filter(k=>keys.includes(k));tableState.order=[...order,...keys.filter(k=>!order.includes(k))];
  tableState.visible=new Set((v.visible||[]).filter(k=>keys.includes(k)));
  if(!tableState.visible.size)return false;
  tableState.widths=v.widths||{};if(typeof v.density==='string')tableState.density=v.density;
  if(typeof v.showTotals==='boolean')tableState.showTotals=v.showTotals;if(typeof v.onlyTop==='boolean')tableState.onlyTop=v.onlyTop;
  tableState.savedView=JSON.stringify(viewState());return true;
}
// Đang dùng preset tự tạo: đổi cột thì cập nhật luôn vào preset đó.
function syncCustomPreset(){const p=(tableState.data.presets||[]).find(x=>x.name===tableState.preset);if(p&&!p.builtin&&orderedKeys().length)call('table_preset',JSON.stringify({action:'save',name:p.name,group:tableState.group,columns:orderedKeys(),silent:true}));}
function orderedKeys(){return tableState.order.filter(k=>tableState.visible.has(k));}
function cellText(row,key){
  const statuses=tableState.data.statuses||{};
  switch(key){
    case 'entity':return row.entity_type;
    case 'definition':return row.definition;
    case 'instance':return row.name;
    case 'description':return row.description;
    case 'lenXZ':return `${fmt(row.lenX,0)} × ${fmt(row.lenZ,0)}`;
    case 'lenXY':return `${fmt(row.lenX,0)} × ${fmt(row.lenY,0)}`;
    case 'lenXYZ':return `${fmt(row.lenX,0)} × ${fmt(row.lenY,0)} × ${fmt(row.lenZ,0)}`;
    case 'tag':return row.tag;
    case 'tag_group':return row.tag_group;
    case 'material':return row.material;
    case 'status':return statuses[row.status]||row.status;
    default:return '';
  }
}
function sortValue(row,key){if(NUMERIC.has(key))return row[key]==null?-Infinity:row[key];return String(cellText(row,key)||'').toLocaleLowerCase('vi');}
function filteredRows(){
  const q=tableState.search.trim().toLocaleLowerCase('vi');
  return tableState.data.rows.filter(r=>(!tableState.group||r.tag_group===tableState.group)&&(!q||[r.name,r.definition,r.description,r.tag,r.material].some(v=>String(v||'').toLocaleLowerCase('vi').includes(q))));
}
// Chọn dòng kiểu Excel: bấm = một dòng; Ctrl (hoặc Cmd) = thêm / bớt một dòng; Shift = cả dãy từ dòng gốc; Ctrl+Shift = thêm cả dãy;
// Ctrl+A = chọn hết các dòng đang hiện; Esc = bỏ chọn. SketchUp chọn theo các đối tượng đó (xem table_select trong dialog.rb).
// Dòng gộp (Gộp dòng giống nhau) có nhiều đối tượng: chọn dòng gộp là chọn mọi đối tượng của nó.
const membersOf=row=>row.members||[row.index];
function paintSelection(){
  document.querySelectorAll('.grid tbody tr[data-members]').forEach(tr=>tr.classList.toggle('selected',tr.dataset.members.split(',').every(i=>tableState.sel.has(Number(i)))));
  const count=document.querySelector('.sel-count');
  if(count&&tableState.data)count.textContent=tableState.sel.size?`Đã chọn ${tableState.sel.size} / ${tableState.data.rows.length} dòng`:'';
  tableState.rename.preview=null; // phạm vi đổi tên đã đổi nên bản xem trước cũ không còn đúng
  if(tableState.panel==='rename'&&tableState.data)tableView(tableState.data);
}
function pickRows(indexes,field){
  tableState.sel=new Set(indexes);paintSelection();
  if(!tableState.sel.size){call('table_clear');return;}
  call('table_select',JSON.stringify({indexes:[...tableState.sel],field:tableState.sel.size===1?(field||''):''}));
}
function clickRow(row,field,e){
  const members=membersOf(row),order=tableState.displayed,additive=e.ctrlKey||e.metaKey;
  const pos=order.findIndex(r=>r.index===row.index),anchorPos=order.findIndex(r=>r.index===tableState.anchor);
  if(e.shiftKey&&anchorPos>=0&&pos>=0){
    const span=order.slice(Math.min(anchorPos,pos),Math.max(anchorPos,pos)+1).flatMap(membersOf);
    pickRows(additive?[...new Set([...tableState.sel,...span])]:[...new Set(span)],'');
    return;
  }
  tableState.anchor=row.index;
  if(additive){
    const next=new Set(tableState.sel),all=members.every(m=>next.has(m));
    members.forEach(m=>{if(all)next.delete(m);else next.add(m);});
    pickRows([...next],'');return;
  }
  pickRows(members,field);
}
function highlightRows(indexes){
  tableState.sel=new Set(indexes||[]);paintSelection();
  const first=[...tableState.sel][0];
  if(first===undefined)return;
  const tr=document.querySelector(`.grid tr[data-index="${first}"]`);
  if(tr)tr.scrollIntoView({block:'nearest'});
}
// Sửa bằng nhấp đúp. Tên, mô tả: ô nhập ngay trong ô. Tình trạng, tag, vật liệu: bảng chọn có ô tìm kiếm.
// Nhấp đúp vào một dòng nằm trong vùng chọn nhiều dòng thì sửa cho cả vùng chọn.
function editTargets(row){
  const members=membersOf(row);
  return tableState.sel.size>members.length&&members.every(m=>tableState.sel.has(m))?[...tableState.sel]:members;
}
function commitEdit(row,field,value){call('table_edit',JSON.stringify({indexes:editTargets(row),field,value}));}
let cellMenu=null;
function closeMenu(){if(cellMenu){cellMenu.remove();cellMenu=null;document.removeEventListener('mousedown',outsideMenu,true);}}
function outsideMenu(e){if(cellMenu&&!cellMenu.contains(e.target))closeMenu();}
function inlineEdit(td,row,col){
  closeMenu();
  const field=col.editable,original=String(field==='name'?row.name:row[field]||'');
  const input=node('input');input.type='text';input.value=original;input.maxLength=200;input.setAttribute('aria-label',col.label);
  td.classList.add('editing');td.replaceChildren(input);input.focus();input.select();
  let done=false;
  const finish=commit=>{if(done)return;done=true;if(commit&&input.value!==original)commitEdit(row,field,input.value);renderGrid($('grid-host'));};
  input.onkeydown=e=>{e.stopPropagation();if(e.key==='Enter'){e.preventDefault();finish(true);}else if(e.key==='Escape'){e.preventDefault();finish(false);}};
  input.onblur=()=>finish(true);
}
function menuItems(field){
  const d=tableState.data,choices=d.choices||{tags:[],materials:[]};
  if(field==='status')return Object.entries(d.statuses||{}).map(([value,label])=>({value,label}));
  if(field==='tag')return [{value:'',label:'(Không có tag)'},...choices.tags.map(name=>({value:name,label:name}))];
  return [{value:'',label:'(Không vật liệu)'},...choices.materials.map(name=>({value:name,label:name}))];
}
function menuEdit(td,row,col){
  closeMenu();
  const field=col.editable,current=field==='status'?row.status:(field==='tag'?row.tag:row.material),all=menuItems(field);
  const menu=node('div',undefined,'cell-menu');menu.setAttribute('role','listbox');
  const search=node('input');search.type='search';search.placeholder='Tìm...';search.setAttribute('aria-label','Tìm trong danh sách');
  const list=node('div',undefined,'cell-menu-list');
  const pick=value=>{closeMenu();commitEdit(row,field,value);};
  const draw=()=>{
    const q=search.value.trim().toLocaleLowerCase('vi');
    const shown=all.filter(item=>!q||item.label.toLocaleLowerCase('vi').includes(q));
    if(field==='tag'&&q&&!all.some(item=>item.label.toLocaleLowerCase('vi')===q))shown.push({value:search.value.trim(),label:`Tạo tag "${search.value.trim()}"`});
    list.replaceChildren();
    shown.forEach(item=>{
      const line=node('div',undefined,'cell-item'+(item.value===current?' current':''));line.setAttribute('role','option');
      line.append(node('span',item.label),node('span',item.value===current?'✓':'','tick'));
      line.onmousedown=e=>{e.preventDefault();pick(item.value);};
      list.append(line);
    });
    if(!shown.length)list.append(node('div','Không có mục nào khớp.','cell-empty'));
    menu.firstShown=shown[0];
  };
  search.oninput=draw;
  search.onkeydown=e=>{
    e.stopPropagation();
    if(e.key==='Escape'){e.preventDefault();closeMenu();}
    else if(e.key==='Enter'){e.preventDefault();if(menu.firstShown)pick(menu.firstShown.value);}
  };
  menu.append(search,list);document.body.append(menu);cellMenu=menu;draw();
  const rect=td.getBoundingClientRect();
  menu.style.minWidth=Math.max(rect.width,220)+'px';
  menu.style.left=Math.min(rect.left,window.innerWidth-menu.offsetWidth-8)+'px';
  const below=window.innerHeight-rect.bottom,height=menu.offsetHeight;
  menu.style.top=(below>=Math.min(height,260)||rect.top<height?rect.bottom:rect.top-height)+'px';
  document.addEventListener('mousedown',outsideMenu,true);
  search.focus();
  const currentLine=list.querySelector('.current');if(currentLine)currentLine.scrollIntoView({block:'nearest'});
}
function editCell(td,row,col){
  if(!col.editable)return;
  if(row.locked&&!row.members)return message('Đối tượng đang bị khóa nên không sửa được.',true);
  if(col.editable==='name'||col.editable==='description')inlineEdit(td,row,col);else menuEdit(td,row,col);
}
function startResize(event,key,host,cols){
  event.preventDefault();event.stopPropagation();
  const startX=event.clientX,startW=widthOf(key),index=cols.findIndex(col=>col.key===key);
  const move=e=>{
    tableState.widths[key]=Math.max(48,startW+e.clientX-startX);
    const table=host.querySelector('table');if(!table)return;
    const cg=table.querySelectorAll('col')[index];if(cg)cg.style.width=tableState.widths[key]+'px';
    table.style.width=cols.reduce((sum,col)=>sum+widthOf(col.key),0)+'px';
  };
  const up=()=>{document.removeEventListener('mousemove',move);document.removeEventListener('mouseup',up);persistView();};
  document.addEventListener('mousemove',move);document.addEventListener('mouseup',up);
}
// Nhóm theo và gộp dòng giống nhau (chỉ đổi cách hiển thị, không đổi dữ liệu).
const GROUP_OPTIONS=[['','Không nhóm'],['parent','Cha (Parent)'],['entity','Loại (Entity)'],['definition','Tên họ (Definition)'],['instance','Tên (Instance)'],['material','Vật liệu'],['tag','Tag'],['tag_group','Nhóm hạng mục'],['status','Tình trạng']];
const SUM_KEYS=['areaXZ','areaXY','areaFace','volume','quantity'];
function groupLabel(row,key){
  switch(key){
    case 'parent':return row.parent||'(Gốc)';
    case 'entity':return row.entity_type;
    case 'definition':return row.definition||'(Chưa đặt tên)';
    case 'instance':return row.name||'(Chưa đặt tên)';
    case 'material':return row.material||'(Không vật liệu)';
    case 'tag':return row.tag||'(Untagged)';
    case 'tag_group':return row.tag_group||'(Chưa phân loại)';
    case 'status':return (tableState.data.statuses||{})[row.status]||row.status;
    default:return '';
  }
}
// Gộp các dòng giống hệt nhau (cùng loại, họ, tên, mô tả, kích thước, tag, vật liệu, tình trạng) thành một dòng:
// Số lượng, diện tích và thể tích là tổng của các dòng gộp; kích thước giữ theo từng đối tượng.
function mergeRows(rows){
  const map=new Map();
  rows.forEach(row=>{
    const key=JSON.stringify([row.entity_type,row.definition,row.name,row.description,row.lenX,row.lenY,row.lenZ,row.tag,row.material,row.status]);
    const hit=map.get(key);
    if(!hit){map.set(key,{...row,members:[row.index]});return;}
    hit.members.push(row.index);
    SUM_KEYS.forEach(k=>{if(typeof row[k]==='number')hit[k]=(typeof hit[k]==='number'?hit[k]:0)+row[k];});
    hit.locked=hit.locked||row.locked;
  });
  return [...map.values()];
}
function renderGrid(host){
  const data=tableState.data;
  const cols=orderedKeys().map(colByKey).filter(Boolean);
  const filtered=filteredRows();
  const shown=new Set(filtered.map(r=>r.index));
  const rows=tableState.merge?mergeRows(filtered):filtered;
  const ordered=tableState.sort?[...rows].sort((a,b)=>{const va=sortValue(a,tableState.sort.key),vb=sortValue(b,tableState.sort.key);if(va<vb)return -tableState.sort.dir;if(va>vb)return tableState.sort.dir;return a.index-b.index;}):rows;
  // Cộng tổng: mặc định chỉ cộng đối tượng cấp cao nhất để không đếm trùng group lồng nhau.
  const counted=list=>list.filter(r=>!(tableState.onlyTop&&r.parents.some(p=>shown.has(p))));
  const sumOf=(list,key)=>counted(list).reduce((s,r)=>s+(typeof r[key]==='number'?r[key]:0),0);
  const countOf=list=>counted(list).reduce((s,r)=>s+membersOf(r).length,0);
  // Danh sách theo thứ tự hiển thị: các nhóm (nếu có) rồi các dòng của nhóm chưa thu gọn.
  let sections=[{label:null,rows:ordered}];
  if(tableState.groupBy){
    const map=new Map();
    ordered.forEach(row=>{const label=groupLabel(row,tableState.groupBy);if(!map.has(label))map.set(label,[]);map.get(label).push(row);});
    sections=[...map.entries()].sort((a,b)=>a[0].localeCompare(b[0],'vi',{numeric:true})).map(([label,list])=>({label,rows:list}));
  }
  const collapsedKey=section=>`${tableState.groupBy}:${section.label}`;
  const visibleRows=sections.flatMap(section=>section.label!==null&&tableState.collapsed.has(collapsedKey(section))?[]:section.rows);
  tableState.displayed=visibleRows.map(row=>({index:row.index,members:membersOf(row)})); // thứ tự dòng đang hiện, dùng cho chọn dãy bằng Shift
  closeMenu();
  host.replaceChildren();
  const wrap=node('div',undefined,'grid-wrap');
  wrap.tabIndex=0;
  wrap.onscroll=closeMenu;
  wrap.onkeydown=e=>{
    if(e.target.closest('input,select,textarea'))return;
    if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='a'){e.preventDefault();pickRows(tableState.displayed.flatMap(membersOf),'');}
    else if(e.key==='Escape'&&tableState.sel.size){pickRows([],'');}
  };
  const t=node('table',undefined,'grid'+(tableState.density?' '+tableState.density:''));
  t.style.width=cols.reduce((sum,col)=>sum+widthOf(col.key),0)+'px';
  const colgroup=node('colgroup');cols.forEach(col=>{const cg=node('col');cg.style.width=widthOf(col.key)+'px';colgroup.append(cg);});t.append(colgroup);
  const thead=node('thead'),head=node('tr');
  cols.forEach(col=>{
    const active=tableState.sort&&tableState.sort.key===col.key;
    const th=node('th',col.label+(active?(tableState.sort.dir>0?' ▲':' ▼'):''));
    th.title='Bấm để sắp xếp';
    th.onclick=()=>{tableState.sort=active?{key:col.key,dir:-tableState.sort.dir}:{key:col.key,dir:1};renderGrid(host);};
    const handle=node('span',undefined,'rz');handle.setAttribute('aria-hidden','true');
    handle.onclick=e=>e.stopPropagation();
    handle.onmousedown=e=>startResize(e,col.key,host,cols);
    th.append(handle);head.append(th);
  });
  thead.append(head);
  // Hàng đơn vị dưới tiêu đề, kiểu Auto Info.
  const unitRow=node('tr',undefined,'unit-row');
  cols.forEach(col=>{const th=node('th');if(UNIT_TEXT[col.key])th.append(node('span',UNIT_TEXT[col.key],'pill'));unitRow.append(th);});
  thead.append(unitRow);t.append(thead);
  // Nhãn "Tổng cộng" / tên nhóm đặt ở cột rộng nhất có sẵn (Tên, rồi Họ, rồi Loại) để không bị cắt.
  const labelKey=['instance','definition','entity'].find(k=>cols.some(c=>c.key===k));
  const labelIndex=Math.max(0,cols.findIndex(col=>col.key===labelKey));
  const tbody=node('tbody');
  let pos=0;
  sections.forEach(section=>{
    if(section.label!==null){
      const key=collapsedKey(section),closed=tableState.collapsed.has(key);
      const head=node('tr',undefined,'group-row');head.dataset.group=section.label;
      const memberIds=section.rows.flatMap(membersOf);
      head.title='Bấm để chọn cả nhóm';
      head.onclick=e=>{if(e.target.closest('.chev'))return;clickRow({index:section.rows[0].index,members:memberIds},'',e);};
      cols.forEach((col,i)=>{
        const td=node('td');
        if(i===labelIndex){
          const chev=node('button',closed?'▸':'▾','chev');chev.type='button';chev.title=closed?'Mở nhóm':'Thu gọn nhóm';chev.setAttribute('aria-label',chev.title);
          chev.onclick=e=>{e.stopPropagation();if(closed)tableState.collapsed.delete(key);else tableState.collapsed.add(key);renderGrid(host);};
          td.append(chev,document.createTextNode(` ${section.label} · ${countOf(section.rows)}`));
        }else if(col.kind==='sum'){td.textContent=fmt(sumOf(section.rows,col.key),digitsFor(col.key));td.className='num';}
        head.append(td);
      });
      tbody.append(head);
      if(closed)return;
    }
    section.rows.forEach(row=>{
      pos++;
      const members=membersOf(row);
      const tr=node('tr');tr.dataset.index=String(row.index);tr.dataset.members=members.join(',');
      if(members.every(m=>tableState.sel.has(m)))tr.classList.add('selected');
      tr.onclick=e=>{
        if(e.target.closest('input,select,button'))return; // đang gõ trong ô sửa
        const td=e.target.closest('td');
        const plain=!(e.ctrlKey||e.metaKey||e.shiftKey);
        clearTimeout(tableState.clickTimer);
        // Bấm thường vào dòng đang nằm trong vùng chọn nhiều dòng: đợi một nhịp xem có phải nhấp đúp để sửa cả vùng chọn không.
        if(plain&&tableState.sel.size>members.length&&members.every(m=>tableState.sel.has(m))){
          tableState.clickTimer=setTimeout(()=>clickRow(row,td?td.dataset.key:'',e),260);return;
        }
        clickRow(row,td?td.dataset.key:'',e);
      };
      tr.ondblclick=e=>{
        clearTimeout(tableState.clickTimer);
        const td=e.target.closest('td');if(!td)return;
        const col=cols.find(c=>c.key===td.dataset.key);
        if(col&&col.editable)editCell(td,row,col);
      };
      cols.forEach(col=>{
        const td=node('td');td.dataset.key=col.key;
        if(col.editable)td.classList.add('editable');
        if(col.key==='ordinal')td.textContent=String(pos);
        else if(NUMERIC.has(col.key)){td.textContent=fmt(row[col.key],digitsFor(col.key));td.className='num';}
        else td.textContent=cellText(row,col.key);
        tr.append(td);
      });
      tbody.append(tr);
    });
  });
  t.append(tbody);
  if(tableState.showTotals){
    const foot=node('tr');
    cols.forEach((col,i)=>{
      const td=node('td');
      if(i===labelIndex)td.textContent=`Tổng cộng · ${countOf(rows)} đối tượng`;
      else if(col.kind==='sum'){td.textContent=fmt(sumOf(rows,col.key),digitsFor(col.key));td.className='num';}
      foot.append(td);
    });
    const tfoot=node('tfoot');tfoot.append(foot);t.append(tfoot);
  }
  wrap.append(t);host.append(wrap);
  if(!rows.length)host.append(node('p','Không có đối tượng nào khớp bộ lọc.','empty'));
}
// Đổi tên hàng loạt cho các dòng đang có trong bảng. Giá trị các ô nhập nằm trong tableState.rename để không mất khi bảng vẽ lại.
const RENAME_TOKENS=['{tên}','{họ}','{phân loại}','{nhóm}','{số}'];
const RENAME_STATUS={ok:'Sẽ đổi',same:'Giữ nguyên',locked:'Bị khóa',empty:'Tên trống',long:'Quá dài'};
tableState.rename={template:'{tên}',find:'',replace:'',prefix:'',suffix:'',case:'none',start:1,pad:2,step:1,order:'table',preview:null};
function renameOptions(){const r=tableState.rename;return {template:r.template,find:r.find,replace:r.replace,prefix:r.prefix,suffix:r.suffix,case:r.case,start:r.start,pad:r.pad,step:r.step,order:r.order,indexes:[...tableState.sel]};}
function renamePreview(box){
  const pv=tableState.rename.preview;if(!pv)return;
  const c=pv.counts;
  box.append(node('p',`Sẽ đổi ${c.ok} · giữ nguyên ${c.same} · bị khóa ${c.locked}`+(c.empty?` · tên trống ${c.empty}`:'')+(c.long?` · quá dài ${c.long}`:'')+(c.duplicate?` · trùng tên ${c.duplicate}`:''),'rename-summary'));
  const table=node('table',undefined,'rename-table');
  pv.rows.slice(0,200).forEach(row=>{
    const tr=node('tr');tr.className='st-'+row.status+(row.duplicate?' dup':'');
    tr.append(node('td',row.old||'(trống)'),node('td','→'),node('td',row.status==='ok'||row.status==='same'?(row.new||'(trống)'):'—'),node('td',RENAME_STATUS[row.status]+(row.duplicate?' · trùng':'')));
    table.append(tr);
  });
  box.append(table);
  if(pv.rows.length>200)box.append(node('p',`Chỉ hiện 200 dòng đầu trong ${pv.rows.length} dòng.`,'muted'));
}
function renamePanel(){
  const r=tableState.rename;
  const p=node('div',undefined,'popover right rename');
  p.append(node('div','Đổi tên hàng loạt','pop-title'));
  const total=tableState.data.rows.length,chosen=tableState.sel.size;
  p.append(node('p',(chosen?`Áp dụng cho ${chosen} dòng đang chọn trong bảng`:`Áp dụng cho mọi ${total} dòng trong bảng (chưa chọn dòng nào)`)+'. Chỉ đổi tên đối tượng, không đổi tên định nghĩa, hình học hay dữ liệu hạng mục. Cả đợt là một bước hoàn tác.','rename-scope'));
  const box=node('div');
  const apply=button('Áp dụng',()=>{call('rename_apply',JSON.stringify(renameOptions()));r.preview=null;tableState.panel=null;},'primary');
  apply.disabled=!(r.preview&&r.preview.counts.ok>0);
  const stale=()=>{r.preview=null;apply.disabled=true;box.replaceChildren();};
  const field=(label,key,attrs)=>{
    const wrap=node('label',undefined,'rename-field');wrap.append(node('span',label));
    const input=node('input');input.type='text';Object.assign(input,attrs||{});input.value=String(r[key]);
    input.oninput=()=>{r[key]=input.value;stale();};
    wrap.append(input);return {wrap,input};
  };
  const pick=(label,key,options)=>{
    const wrap=node('label',undefined,'rename-field');wrap.append(node('span',label));
    const select=node('select');options.forEach(([value,text])=>select.append(new Option(text,value)));select.value=r[key];
    select.onchange=()=>{r[key]=select.value;stale();};
    wrap.append(select);return wrap;
  };
  const template=field('Mẫu tên','template',{maxLength:400});
  const chips=node('div',undefined,'chip-row');
  RENAME_TOKENS.forEach(token=>chips.append(button(token,()=>{
    const input=template.input;const start=input.selectionStart===null?input.value.length:input.selectionStart;const end=input.selectionEnd===null?start:input.selectionEnd;
    input.value=input.value.slice(0,start)+token+input.value.slice(end);r.template=input.value;stale();input.focus();
  })));
  const findRow=node('div',undefined,'rename-row');findRow.append(field('Tìm','find',{maxLength:400}).wrap,field('Thay bằng','replace',{maxLength:400}).wrap);
  const fixRow=node('div',undefined,'rename-row');fixRow.append(field('Tiền tố','prefix',{maxLength:400}).wrap,field('Hậu tố','suffix',{maxLength:400}).wrap);
  const numRow=node('div',undefined,'rename-row');numRow.append(field('Số bắt đầu','start').wrap,field('Số chữ số','pad').wrap,field('Bước nhảy','step').wrap);
  const styleRow=node('div',undefined,'rename-row');
  styleRow.append(pick('Kiểu chữ','case',[['none','Giữ nguyên'],['upper','CHỮ HOA'],['lower','chữ thường'],['title','Viết Hoa Chữ Đầu']]),
    pick('Đánh số theo','order',[['table','Thứ tự trong bảng'],['position','Vị trí (X, rồi Y, rồi Z)'],['name','Tên hiện tại']]));
  const actions=node('div',undefined,'rename-actions');
  actions.append(button('Xem trước',()=>call('rename_preview',JSON.stringify(renameOptions())),'primary'),apply,button('Đóng',()=>{tableState.panel=null;tableView(tableState.data);}));
  p.append(template.wrap,chips,findRow,fixRow,numRow,styleRow,box,actions);
  renamePreview(box);
  return p;
}
function groupPanel(){
  const p=node('div',undefined,'popover left group-panel');
  p.append(node('div','Nhóm theo','pop-title'));
  const list=node('div',undefined,'pop-list');
  GROUP_OPTIONS.forEach(([value,label])=>list.append(button(label,()=>{tableState.groupBy=value;tableState.panel=null;tableView(tableState.data);},'pop-pick'+(value===tableState.groupBy?' primary':''))));
  const merge=node('label',undefined,'merge-opt');
  const box=node('input');box.type='checkbox';box.checked=tableState.merge;
  box.onchange=()=>{tableState.merge=box.checked;renderGrid($('grid-host'));};
  merge.append(box,document.createTextNode(' Gộp dòng giống nhau'));
  p.append(list,merge,node('p','Chỉ đổi cách hiển thị. Dòng gộp: Số lượng, diện tích, thể tích là tổng của các dòng gộp.','muted'));
  return p;
}
function toolbar(){
  const d=tableState.data;const bar=node('div',undefined,'toolbar');
  const cols=button('Chọn cột',()=>{tableState.panel=tableState.panel==='columns'?null:'columns';tableView(tableState.data);},'primary');
  cols.setAttribute('aria-expanded',String(tableState.panel==='columns'));
  const search=node('input');search.type='search';search.placeholder='Tìm kiếm...';search.value=tableState.search;search.setAttribute('aria-label','Tìm trong bảng');
  search.oninput=()=>{tableState.search=search.value;renderGrid($('grid-host'));};
  const group=node('select');group.setAttribute('aria-label','Nhóm hạng mục');group.append(new Option('Tất cả nhóm',''));(d.groups||[]).forEach(g=>group.append(new Option(g,g)));
  group.value=tableState.group;group.onchange=()=>{tableState.group=group.value;renderGrid($('grid-host'));persistView();};
  const preset=button(`${tableState.preset} ▾`,()=>{tableState.panel=tableState.panel==='presets'?null:'presets';tableView(tableState.data);});
  preset.classList.add('preset-btn');preset.setAttribute('aria-expanded',String(tableState.panel==='presets'));
  const rename=button('Đổi tên',()=>{tableState.panel=tableState.panel==='rename'?null:'rename';tableView(tableState.data);});
  rename.setAttribute('aria-expanded',String(tableState.panel==='rename'));
  const count=node('span',tableState.sel.size?`Đã chọn ${tableState.sel.size} / ${d.rows.length} dòng`:'','sel-count');
  const groupLabelText=(GROUP_OPTIONS.find(o=>o[0]===tableState.groupBy)||GROUP_OPTIONS[0])[1];
  const grouping=button(`Nhóm theo: ${groupLabelText} ▾`,()=>{tableState.panel=tableState.panel==='group'?null:'group';tableView(tableState.data);});
  grouping.setAttribute('aria-expanded',String(tableState.panel==='group'));
  bar.append(cols,search,group,grouping,preset,rename,count);
  return bar;
}
function columnPanel(){
  const d=tableState.data;const total=d.columns.length;
  const p=node('div',undefined,'popover left');
  const head=node('div',undefined,'pop-head');
  const all=node('input');all.type='checkbox';all.checked=tableState.visible.size===total;all.setAttribute('aria-label','Chọn tất cả cột');
  all.onchange=()=>{tableState.visible=all.checked?new Set(d.columns.map(c=>c.key)):new Set();tableView(d);syncCustomPreset();};
  const allLabel=node('label');allLabel.append(all,document.createTextNode(' Bỏ chọn tất cả'));
  head.append(allLabel,node('span',`${tableState.visible.size} / ${total}`,'badge'));
  const search=node('input');search.type='search';search.placeholder='Tìm cột...';search.value=tableState.colSearch;search.className='pop-search';
  const list=node('div',undefined,'pop-cols');
  search.oninput=()=>{tableState.colSearch=search.value;renderColumnList(list);};
  renderColumnList(list);
  p.append(head,search,list);
  return p;
}
function renderColumnList(list){
  const d=tableState.data;const q=tableState.colSearch.trim().toLocaleLowerCase('vi');
  list.replaceChildren();
  tableState.order.forEach(key=>{
    const col=colByKey(key);if(!col)return;
    if(q&&!col.label.toLocaleLowerCase('vi').includes(q))return;
    const item=node('div',undefined,'pop-col');item.draggable=true;
    item.ondragstart=e=>{tableState.dragKey=key;e.dataTransfer.effectAllowed='move';e.dataTransfer.setData('text/plain',key);};
    item.ondragover=e=>e.preventDefault();
    item.ondrop=e=>{e.preventDefault();const from=tableState.dragKey;tableState.dragKey=null;if(!from||from===key)return;const order=tableState.order.filter(k=>k!==from);order.splice(order.indexOf(key),0,from);tableState.order=order;tableView(d);syncCustomPreset();};
    const box=node('input');box.type='checkbox';box.checked=tableState.visible.has(key);
    box.onchange=()=>{if(box.checked)tableState.visible.add(key);else tableState.visible.delete(key);tableView(d);syncCustomPreset();};
    const label=node('label');label.append(box,document.createTextNode(' '+col.label));
    const grip=node('span','⠿','drag');grip.setAttribute('aria-hidden','true');
    item.append(label,grip);list.append(item);
  });
}
function presetPanel(){
  const d=tableState.data;
  const p=node('div',undefined,'popover right');
  p.append(node('div','Preset','pop-title'));
  const row=node('div',undefined,'pop-new');
  const input=node('input');input.type='text';input.placeholder='Tạo mới...';input.maxLength=40;input.setAttribute('aria-label','Tên preset mới');
  const add=button('+',()=>{const name=input.value.trim();if(!name)throw Error('Hãy nhập tên preset.');tableState.preset=name;call('table_preset',JSON.stringify({action:'save',name,group:tableState.group,columns:orderedKeys()}));},'primary');
  row.append(input,add);
  const list=node('div',undefined,'pop-list');
  (d.presets||[]).forEach(preset=>{
    const line=node('div',undefined,'pop-line');
    const pick=button(preset.name,()=>{applyPreset(preset.name);tableView(tableState.data);},preset.name===tableState.preset?'primary pop-pick':'pop-pick');
    const tail=button(preset.builtin?'↻':'×',()=>{
      if(preset.builtin){applyPreset(preset.name);tableView(tableState.data);}
      else call('table_preset',JSON.stringify({action:'delete',name:preset.name}));
    });
    tail.title=preset.builtin?'Khôi phục cột gốc của preset':'Xóa preset';tail.setAttribute('aria-label',tail.title+': '+preset.name);
    line.append(pick,tail);list.append(line);
  });
  p.append(row,list,node('p','Preset lưu cột đang hiển thị, thứ tự cột và nhóm hạng mục, lưu trên máy này. Đang dùng preset tự tạo thì đổi cột sẽ tự cập nhật vào preset đó.','muted'));
  return p;
}
function toggleButton(text,on,handler){const b=node('button',text,'toggle');b.setAttribute('aria-pressed',String(!!on));b.onclick=handler;return b;}
function bottomBar(){
  const d=tableState.data;const bar=node('div',undefined,'bottombar');
  bar.append(toggleButton('Thu phóng đối tượng',d.options.zoom,()=>call('table_option',JSON.stringify({zoom:!d.options.zoom}))));
  bar.append(toggleButton('Cô lập đối tượng chọn',d.options.isolate,()=>call('table_option',JSON.stringify({isolate:!d.options.isolate}))));
  bar.append(toggleButton('Chọn sâu bên trong',d.options.deep,()=>call('table_option',JSON.stringify({deep:!d.options.deep}))));
  bar.append(toggleButton('Hiển thị dòng tính tổng',tableState.showTotals,()=>{tableState.showTotals=!tableState.showTotals;tableView(d);}));
  bar.append(toggleButton('Tổng chỉ cấp cao nhất',tableState.onlyTop,()=>{tableState.onlyTop=!tableState.onlyTop;tableView(d);}));
  const density=node('select');density.setAttribute('aria-label','Độ cao hàng');
  [['','Hàng: Vừa'],['dense','Hàng: Gọn'],['roomy','Hàng: Thoáng']].forEach(([v,t])=>density.append(new Option(t,v)));
  density.value=tableState.density;density.onchange=()=>{tableState.density=density.value;renderGrid($('grid-host'));persistView();};
  bar.append(density);
  return bar;
}
function tableView(data){
  tableState.data=data;
  const restored=!tableState.restored&&restoreView(data);
  if(!restored&&!tableState.order.length)applyPreset(tableState.preset);
  if(!(data.presets||[]).some(p=>p.name===tableState.preset))applyPreset((data.presets||[])[0].name);
  const content=$('content');const old=content.querySelector('.grid-wrap');const scroll=old?{top:old.scrollTop,left:old.scrollLeft}:null;
  content.replaceChildren();
  const view=node('div',undefined,'table-view');content.append(view);
  if(data.hint)view.append(node('p',data.hint,'hint'));
  else view.append(node('p','Chọn đối tượng trong SketchUp là bảng tự đọc. Bấm một ô để đánh dấu đối tượng và hiện nội dung ô đó; giữ Shift hoặc Ctrl để chọn nhiều dòng, Ctrl+A chọn hết. Nhấp đúp vào ô để sửa: Tên, Mô tả (gõ), Tình trạng, Tag, Vật liệu (chọn từ danh sách).','hint'));
  const bar=node('div',undefined,'toolbar-wrap');
  bar.append(toolbar());
  if(tableState.panel==='columns')bar.append(columnPanel());
  if(tableState.panel==='presets')bar.append(presetPanel());
  if(tableState.panel==='group')bar.append(groupPanel());
  if(tableState.panel==='rename')bar.append(renamePanel());
  view.append(bar);
  const host=node('div');host.id='grid-host';view.append(host);
  renderGrid(host);
  if(scroll){const wrap=host.querySelector('.grid-wrap');if(wrap){wrap.scrollTop=scroll.top;wrap.scrollLeft=scroll.left;}}
  view.append(bottomBar());
  persistView();
  view.append(node('p','Đơn vị: mm (chiều dài), m² (diện tích), m³ (thể tích), cái (số lượng). Diện tích (X*Z), (X*Y) theo khung bao quanh. Thể tích chỉ có cho group kín. Số liệu chưa trừ hao hụt hoặc phần che khuất.','muted'));
  $('primary-actions').replaceChildren(button('Bỏ chọn',()=>call('table_clear'),'primary'));
}
// Phần nằm chung trong một tab.
const TAB_OF={rules:'mapping',validate_model:'mapping',validate_selection:'mapping',export:'scan',convert_selection:'information'};
window.VGD={receive(event,data){
  if(event==='config'){config=data;locale=data.locale||locale;$('subtitle').textContent=`${data.version} · ${translated('modes',data.mode)}`;document.querySelectorAll('[data-mode]').forEach(b=>{const active=b.dataset.mode===(TAB_OF[data.mode]||data.mode);b.classList.toggle('active',active);b.setAttribute('aria-selected',String(active));});$('preview').close();$('content').replaceChildren();$('primary-actions').replaceChildren();document.querySelector('main').scrollTop=0;message('Đang đọc dữ liệu…');}
  if(event==='table'){tableState.rename.preview=null;tableState.sel=new Set(Array.isArray(data.selected)?data.selected:[]);if(!tableState.sel.has(tableState.anchor))tableState.anchor=null;} // bảng đổi thì bản xem trước đổi tên cũ không còn đúng
  const renderers={information,scan,mapping,validation,rules,tags:tagEditor,table:tableView};if(renderers[event]){renderers[event](data);message('Sẵn sàng.');}
  if(event==='highlight')highlightRows(data.indexes);
  if(event==='options'&&tableState.data){tableState.data.options=data;tableView(tableState.data);}
  if(event==='presets'&&tableState.data){tableState.data.presets=data;tableView(tableState.data);}
  if(event==='rename_preview'){tableState.rename.preview=data;if(tableState.panel==='rename'&&tableState.data)tableView(tableState.data);}
  if(event==='progress')message(`Đang quét… ${number(data.count,0)} đối tượng hình học.`);
  if(event==='message')message(data.error||data.text,!!data.error);
  if(event==='preview')preview(data);
  if(event==='selection'){const text=$('tag-selection-text'),go=$('tag-assign');if(text)text.textContent=`Đang chọn ${data.count} đối tượng hoặc mặt trong SketchUp.`;if(go)go.disabled=!data.count;}
}};
$('cancel-preview').onclick=()=>$('preview').close();$('confirm-preview').onclick=()=>{$('confirm-preview').disabled=true;$('preview').close();call('confirm_convert')};document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>call('open_panel',b.dataset.mode));
document.addEventListener('vgdtheme',e=>{const dark=e.detail.theme==='dark';document.body.classList.toggle('dark',dark);document.body.classList.toggle('light',!dark);$('brand-logo').src=dark?'../assets/icons/vgd_primary_dark.svg':'../assets/icons/vgd_primary_light.svg';});
VGDTheme.start({key:'VGD_BIM_theme',button:$('theme')});
document.addEventListener('DOMContentLoaded',()=>call('ready'));
