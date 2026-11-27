'use strict';
const $ = id => document.getElementById(id);
// Bỏ dấu và chữ hoa / thường để tìm và lọc: "bàn", "BAN", "Ban" đều khớp nhau (đ / Đ thành d). Dùng cho mọi ô tìm.
const foldText = text => String(text ?? '').normalize('NFD').replace(/\p{Mn}/gu, '').replace(/[đĐ]/g, 'd').toLowerCase();
let config = {}, locale = {}, appliedLanguage = null;
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
function card(title,parent) {const c=node('section',undefined,'card');c.append(node('h2',title));(parent||$('content')).append(c);return c;}
function badge(value) {return node('span',translated('status',value),'badge '+(value==='ERROR'?'error':value==='WARNING'?'warning':''));}
function table(parent,headers,rows,render) {const wrap=node('div',undefined,'table-wrap'),t=node('table'),head=node('thead'),tr=node('tr');headers.forEach(h=>tr.append(node('th',h)));head.append(tr);t.append(head);const body=node('tbody');rows.forEach((r,i)=>{const tr=node('tr');render(r,tr,i);body.append(tr)});t.append(body);wrap.append(t);parent.append(wrap);if(!rows.length)parent.append(node('p','Chưa có dữ liệu để hiển thị.','empty'));return body;}
function cell(tr,value) {const td=node('td');value instanceof Node?td.append(value):td.textContent=value==null?'':String(value);tr.append(td);return td;}
function dimensions(values) {return ['width','depth','height'].map(k=>number(toUnit(values[k] || 0),workSettings().length_digits+1)).join(' × ');}
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
  const raw=card('Thông tin từ SketchUp · Chỉ xem');table(raw,['Loại / Nguồn','Tên đối tượng / Định nghĩa','Thẻ / Vật liệu',withUnit('Rộng × Sâu × Cao (mm)'),'Trạng thái'],data.objects,(r,tr)=>{cell(tr,`${r.entity_type==='Group'?'Nhóm':'Thành phần'} / ${translated('source',r.source)}`);cell(tr,`${r.instance_name||'Chưa đặt tên'} / ${r.definition_name}`);cell(tr,`${r.tag} / ${r.material||'Chưa có vật liệu'}`);cell(tr,dimensions(r.dimensions));cell(tr,badge(r.locked?'LOCKED':r.status));});
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
// Tab quét (Quét & xuất, Phân loại, Kiểm tra) không tự quét khi mở: quét cả file có thể treo máy với model lớn, nên chỉ quét khi bấm Quét ngay.
const SCAN_TITLES={scan:'Quét & xuất',mapping:'Phân loại',validate_model:'Kiểm tra',validate_selection:'Kiểm tra'};
function scanPending(data) {
  $('content').replaceChildren();
  if(['mapping','validate_model','validate_selection'].includes(data.mode))subTabs();
  if(['validate_model','validate_selection'].includes(data.mode))scope([['Toàn bộ mô hình','validate_model'],['Đối tượng đang chọn','validate_selection']]);
  if(['scan','mapping'].includes(data.mode))scanOptionsBar($('content'));
  const c=card(SCAN_TITLES[data.mode]||'Quét');
  c.append(node('p','Chưa quét. Quét toàn bộ model có thể mất vài phút và làm SketchUp đứng hình với model lớn. Chọn phạm vi rồi bấm Quét ngay khi bạn sẵn sàng.','hint'));
  const run=button('Quét ngay',()=>call('scan_start'),'primary');run.id='scan-start';c.append(run);
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
  search.oninput=()=>Array.from(body.children).forEach((tr,i)=>{tr.hidden=!foldText(data[i].source_value).includes(foldText(search.value))});
}
function validation(data) {
  $('content').replaceChildren();subTabs();scope([['Toàn bộ mô hình','validate_model'],['Đối tượng đang chọn','validate_selection']]);const count=s=>data.filter(r=>r.issues.some(i=>i.severity===s)).length;
  metrics({'Đối tượng đã quét':data.length,'Sẵn sàng':data.filter(r=>r.status==='VGD READY').length,'Cảnh báo':count('WARNING'),'Có lỗi':count('ERROR'),'Chưa phân loại':data.filter(r=>r.status==='UNCLASSIFIED').length});
  const c=card('Kết quả kiểm tra');c.append(node('p','Bấm vào dòng kết quả để chọn và phóng tới đúng đối tượng trong SketchUp. Đối tượng chưa phân loại không bị coi là lỗi.','hint'));
  const noId=data.filter(r=>r.issues.some(i=>i.code==='missing_id')).length;if(noId){const bar=node('div',undefined,'actions');bar.append(button(`Gán VGD ID cho tất cả món chưa có (${noId})`,()=>call('validation_assign_ids'),'primary'));c.append(bar);}
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
// Hộp thông báo sau khi xuất Excel. Giao diện chỉ hiện chữ; đường dẫn file do Ruby giữ, các nút chỉ gọi lệnh không kèm đường dẫn.
function showExportDone(data){
  $('export-done-text').textContent=data.text||'';
  $('export-done-path').textContent=data.path||'';
  $('export-done').showModal();
}
// ---- Bảng đối tượng kiểu Auto Info ----
const tableState={replace:'',headers:{},settings:null,shownRows:[],restored:false,savedView:'',data:null,preset:'Tất cả',group:'',search:'',order:[],visible:new Set(),sort:null,widths:{},onlyTop:true,showTotals:true,density:'',rowHeight:0,sel:new Set(),anchor:null,displayed:[],groupBy:'',merge:false,collapsed:new Set(),panel:null,colSearch:'',dragKey:null,manual:[],dragRow:null,dragCol:null,sheets:null,sheet:0};
// Mỗi file SketchUp có cài đặt riêng (settings.json cạnh file): sang file khác thì bỏ trạng thái bảng của file trước, nạp lại của file mới (file mới: mặc định).
let currentFileId=null;
function syncFile(data){
  const id=data.file||'';
  if(currentFileId!==null&&id!==currentFileId)resetTableState();
  currentFileId=id;
}
function resetTableState(){
  clearTimeout(viewTimer);clearTimeout(excludeTimer);
  Object.assign(tableState,{lockKey:null,replace:'',headers:{},settings:null,shownRows:[],restored:false,savedView:'',data:null,preset:'Tất cả',group:'',search:'',order:[],visible:new Set(),sort:null,widths:{},onlyTop:true,showTotals:true,density:'',rowHeight:0,sel:new Set(),anchor:null,displayed:[],groupBy:'',merge:false,collapsed:new Set(),panel:null,colSearch:'',manual:[],sheets:null,sheet:0,excludeTags:null,excludePending:false,projectedChecked:false,snapshots:null,snapshotDiff:null,checkResults:null,bridge:{file:null,match_by:'vgd_id',match_column:'',mapping:{},preview:null,skip:new Set(),shown:200}});
  const view=document.querySelector('.table-view');if(view)view.remove();
}
const NUMERIC=new Set(['lenX','lenY','lenZ','areaXZ','areaXY','areaFace','areaProjected','volume','quantity','price','total','calc_qty','calc_total','mat_price','mat_waste','mat_qty','mat_cost']);
// Khối lượng tính theo tag (xem core/quantity.rb): nhãn cách tính, đơn vị và số lẻ cố định theo từng cách (m, m², m³ không đổi theo đơn vị của preset).
const METHOD_LABELS={count:'Theo cái',area:'Theo diện tích',length:'Theo mét dài',volume:'Theo thể tích',none:'Không tính'};
const CALC_UNIT={count:'cái',area:'m²',length:'m',volume:'m³'};
const CALC_DIGITS={count:0,area:2,length:2,volume:3};
const CALC_ORDER=['count','area','length','volume'];
const CATEGORY_LABELS={architecture:'Kiến trúc',finish:'Hoàn thiện',furniture:'Nội thất',electrical:'Điện',equipment:'Thiết bị',plumbing:'Cấp thoát nước',hvac:'Điều hòa / Thông gió',other:'Khác',wall:'Tường',floor:'Sàn',ceiling:'Trần',door:'Cửa đi',window:'Cửa sổ',column:'Cột',beam:'Dầm',stair:'Cầu thang',cabinet:'Tủ',sanitary:'Thiết bị vệ sinh',lighting:'Chiếu sáng',generic:'Chung'};
const CALC_SOURCES={item:'Theo dữ liệu đã ghi trong món',tag:'Theo cách tính bạn đặt cho tag',keyword:'Theo từ khóa trong tên tag',group:'Theo nhóm tag',default:'Mặc định (theo cái)'};
// Cột ảnh phụ (Ảnh 3, Ảnh 4): kind của cột => loại ảnh (xem images.js).
const IMAGE_EXTRA_KINDS={image_extra1:'extra1',image_extra2:'extra2'};
const IMAGE_EXTRA_KEYS=['image_extra1','image_extra2'];
const isImageColumn=col=>col.kind==='image'||col.kind==='image_location'||!!IMAGE_EXTRA_KINDS[col.kind];
const WIDTHS={image_location:110,image_extra1:110,image_extra2:110,measure_note:260,front:80,front_state:150,ordinal:44,image:72,entity:90,definition:150,instance:180,description:200,status:120,tag:130,tag_group:130,material:150,quantity:80,areaProjected:110,ifc:120,owner:120,url:170,size:110,price:110,total:120};
const unitTextOf=key=>LEN_KEYS.has(key)?lengthLabel():AREA_KEYS.has(key)?areaLabel():key==='volume'?volumeLabel():key==='quantity'?'cái':(key==='price'||key==='total')?workSettings().currency:undefined;
const colLabel=col=>(tableState.headers&&tableState.headers[col.key])||withUnit(col.label);
const lenText=value=>fmt(toUnit(value),digitsFor('lenX'));
const widthOf=key=>tableState.widths[key]||WIDTHS[key]||110;
// ---- Độ cao hàng: giữ Ctrl + lăn chuột giữa trên bảng; mọi hàng dữ liệu cao đều nhau, cột Ảnh rộng theo ----
const ROW_MIN=28,ROW_MAX=640,ROW_DEFAULT=50; // điểm ảnh (khớp giới hạn phía Ruby); 50 ≈ độ cao hàng có ảnh khi chưa chỉnh
function rowStyle(t){ // tableState.rowHeight: 0 = theo mật độ hàng; > 0 = độ cao do người dùng chọn
  const h=tableState.rowHeight;
  t.classList.toggle('rh',h>0);
  if(h>0)t.style.setProperty('--row-h',h+'px');else t.style.removeProperty('--row-h');
}
function wheelRowHeight(e,t){
  if(!(e.ctrlKey||e.metaKey))return; // không giữ Ctrl: lăn chuột vẫn là cuộn bảng
  e.preventDefault();
  const first=t.querySelector('tbody tr[data-members]');
  const base=tableState.rowHeight||(first?Math.round(first.getBoundingClientRect().height):ROW_DEFAULT);
  const step=Math.max(2,Math.round(base*0.1)); // mỗi nấc đổi khoảng 10%
  const next=Math.min(ROW_MAX,Math.max(ROW_MIN,base+(e.deltaY<0?step:-step)));
  if(next===tableState.rowHeight)return;
  tableState.rowHeight=next;
  tableState.widths.image=Math.max(WIDTHS.image,next+8); // cột Ảnh rộng theo độ cao hàng để ảnh to ra thật sự; vẫn kéo tay đổi được
  tableState.widths.image_location=Math.max(WIDTHS.image_location,Math.round((next+8)*1.5)); // ảnh vị trí là cảnh rộng nên cột rộng hơn
  IMAGE_EXTRA_KEYS.forEach(key=>{tableState.widths[key]=Math.max(WIDTHS[key],next+8);}); // ảnh phụ vuông như ảnh chính
  rowStyle(t);
  const heads=[...t.querySelectorAll('thead tr:first-child th')];
  const index=heads.findIndex(th=>th.dataset.key==='image'),locIndex=heads.findIndex(th=>th.dataset.key==='image_location');
  const extraIndexes=IMAGE_EXTRA_KEYS.map(key=>[key,heads.findIndex(th=>th.dataset.key===key)]).filter(([,i])=>i>=0);
  if(index>=0||locIndex>=0||extraIndexes.length){
    const cols=t.querySelectorAll('col');if(index>=0)cols[index].style.width=tableState.widths.image+'px';if(locIndex>=0)cols[locIndex].style.width=tableState.widths.image_location+'px';extraIndexes.forEach(([key,i])=>{cols[i].style.width=tableState.widths[key]+'px';});
    t.style.width=[...cols].reduce((sum,c)=>sum+(parseFloat(c.style.width)||0),0)+'px';
  }
  persistView();
}
const colByKey=key=>tableState.data.columns.find(c=>c.key===key);
function presetByName(name){const list=presetsList();return list.find(p=>p.name===name)||list[0];}
function applyPreset(name){
  const p=presetByName(name);if(!p)return;
  tableState.preset=p.name;tableState.group=p.group||'';
  const rest=presetColumns().map(c=>c.key).filter(k=>!p.columns.includes(k));
  tableState.order=[...p.columns,...rest];tableState.visible=new Set(p.columns);
  tableState.headers={...(p.headers||{})};tableState.settings={...defaultSettings(),...(p.settings||{})};
  ensureProjected();
}
// Cột Diện tích chiếu cần Ruby tính thêm từ pháp tuyến từng mặt, nên chỉ tính khi cột đang hiện: bật công tắc cho người dùng.
function ensureProjected(){if(tableState.visible.has('areaProjected')&&tableState.data&&tableState.data.options&&!tableState.data.options.projected)call('table_option',JSON.stringify({projected:true}));}
// Lưu trạng thái bảng (preset, cột, thứ tự, độ rộng, nhóm, ...) để lần mở sau vẫn như cũ.
let viewTimer=null;
function viewState(){return {headers:tableState.headers,settings:workSettings(),preset:tableState.preset,group:tableState.group,order:tableState.order,visible:[...tableState.visible],widths:tableState.widths,density:tableState.density,rowHeight:tableState.rowHeight,showTotals:tableState.showTotals,onlyTop:tableState.onlyTop,sheets:sheetsForSave(),sheet:tableState.sheet};}
function persistView(){clearTimeout(viewTimer);viewTimer=setTimeout(()=>{const json=JSON.stringify(viewState());if(json===tableState.savedView)return;tableState.savedView=json;call('table_view',JSON.stringify({...viewState(),file:currentFileId}));},400);}
// ---- Sheet (như sheet của Excel): mỗi sheet nhớ cột hiện / thứ tự / độ rộng, sắp xếp, nhóm theo, bộ lọc và tag loại trừ riêng ----
const SHEET_LIMIT=20,SHEET_NAME_MAX=40;
const sheetNow=()=>({visible:[...tableState.visible],order:[...tableState.order],widths:{...tableState.widths},sort:tableState.sort?{...tableState.sort}:null,groupBy:tableState.groupBy||'',merge:!!tableState.merge,group:tableState.group||'',search:tableState.search||'',exclude_tags:[...excludedTags()]});
function ensureSheets(){if(Array.isArray(tableState.sheets)&&tableState.sheets.length)return;tableState.sheets=[{name:'Sheet1',...sheetNow()}];tableState.sheet=0;}
function stashSheet(){ensureSheets();const cur=tableState.sheets[tableState.sheet];if(cur)tableState.sheets[tableState.sheet]={...cur,...sheetNow()};}
function sheetsForSave(){if(!tableState.data)return tableState.sheets||undefined;stashSheet();return tableState.sheets.map(s=>s.sort?s:{...s,sort:undefined});}
// Nạp cài đặt của một sheet vào bảng (cột, sắp xếp, nhóm, bộ lọc). Cột không còn trong model thì bỏ.
function loadSheet(s,columns){
  const keys=(columns||tableState.data.columns).map(c=>c.key),known=new Set(keys);
  const visible=(s.visible||[]).filter(k=>known.has(k));
  if(visible.length)tableState.visible=new Set(visible);
  const order=(s.order||[]).filter(k=>known.has(k));tableState.order=[...order,...keys.filter(k=>!order.includes(k))];
  tableState.widths=s.widths&&typeof s.widths==='object'?{...s.widths}:{};
  tableState.sort=s.sort&&known.has(s.sort.key)?{key:s.sort.key,dir:s.sort.dir===-1?-1:1}:null;
  tableState.groupBy=typeof s.groupBy==='string'?s.groupBy:'';tableState.merge=!!s.merge;
  tableState.group=typeof s.group==='string'?s.group:'';tableState.search=typeof s.search==='string'?s.search:'';
}
// Tag loại trừ của sheet khác với đang dùng: lưu lại cho Ruby tính lại số đo thân (giống lúc bạn đổi tick trong ngăn Loại trừ tag).
function applySheetExclude(s){
  if(!Array.isArray(s.exclude_tags))return false;
  const cur=[...excludedTags()];
  if(s.exclude_tags.length===cur.length&&s.exclude_tags.every(t=>cur.includes(t)))return false;
  tableState.excludeTags=new Set(s.exclude_tags);clearTimeout(excludeTimer);tableState.excludePending=false;
  call('settings_save',JSON.stringify({exclude_tags:s.exclude_tags}));
  message('Đang tính lại số đo theo tag loại trừ của sheet…');
  return true;
}
function activateSheet(i){
  const s=tableState.sheets[i];tableState.sheet=i;loadSheet(s);ensureProjected();applySheetExclude(s);
  applyRowsLock(s.lock||null);
  persistView();tableView(tableState.data);
}
// Khóa sheet: khi sheet đang khóa được mở, Ruby giữ đúng các món đã khóa (không theo lựa chọn). tableState.lockKey là khóa đang có trong Ruby (null = theo lựa chọn).
const lockKeyOf=lock=>lock?JSON.stringify(lock):null;
function applyRowsLock(lock){
  const key=lockKeyOf(lock);
  if(key===tableState.lockKey)return false;
  tableState.lockKey=key;call('table_lock_apply',JSON.stringify({lock:lock||null}));
  return true; // Ruby sẽ gửi bảng mới
}
function toggleSheetLock(){
  ensureSheets();const s=tableState.sheets[tableState.sheet];
  if(!s)return;
  if(s.lock){s.lock=null;persistView();applyRowsLock(null);if(tableState.data)tableView(tableState.data);return;} // vẽ lại ngay để nút khóa đổi trạng thái
  call('table_lock',JSON.stringify({action:'on'})); // Ruby trả khóa qua sự kiện sheet_lock
}
function switchSheet(i){if(i===tableState.sheet||!tableState.sheets||!tableState.sheets[i])return;stashSheet();activateSheet(i);}
function uniqueSheetName(base,skip){const used=new Set(tableState.sheets.map((s,i)=>i===skip?'':s.name.toLowerCase()));let name=base,n=2;while(used.has(name.toLowerCase()))name=`${base.slice(0,SHEET_NAME_MAX-6)} (${n++})`;return name;}
function addSheet(copyOf){
  stashSheet();
  if(tableState.sheets.length>=SHEET_LIMIT){message(`Tối đa ${SHEET_LIMIT} sheet.`,true);return;}
  const src=copyOf===undefined?tableState.sheets[tableState.sheet]:tableState.sheets[copyOf];
  const base=copyOf===undefined?`Sheet${tableState.sheets.length+1}`:`${src.name} (2)`;
  tableState.sheets.push({...JSON.parse(JSON.stringify(src)),lock:null,name:uniqueSheetName(base.slice(0,SHEET_NAME_MAX))});
  activateSheet(tableState.sheets.length-1);
}
function renameSheet(i,raw){
  const name=String(raw||'').trim().slice(0,SHEET_NAME_MAX);
  if(!name){message('Tên sheet không được để trống.',true);return false;}
  if(tableState.sheets.some((s,k)=>k!==i&&s.name.toLowerCase()===name.toLowerCase())){message('Đã có sheet tên này. Hãy đặt tên khác.',true);return false;}
  tableState.sheets[i]={...tableState.sheets[i],name};persistView();return true;
}
function deleteSheet(i){
  if(tableState.sheets.length<=1){message('Phải còn ít nhất một sheet.',true);return;}
  stashSheet();const name=tableState.sheets[i].name;tableState.sheets.splice(i,1);
  const next=Math.min(i<tableState.sheet?tableState.sheet-1:tableState.sheet,tableState.sheets.length-1);
  if(i===tableState.sheet)activateSheet(Math.min(i,tableState.sheets.length-1));else{tableState.sheet=next;persistView();syncSheetBar($('content').querySelector('.table-view'));}
  message(`Đã xóa sheet “${name}”.`);
}
let sheetMenuEl=null;
function closeSheetMenu(){if(sheetMenuEl){sheetMenuEl.remove();sheetMenuEl=null;document.removeEventListener('mousedown',outsideSheetMenu,true);}}
function outsideSheetMenu(e){if(sheetMenuEl&&!sheetMenuEl.contains(e.target))closeSheetMenu();}
function sheetMenu(e,i,tab){
  closeSheetMenu();
  const menu=node('div',undefined,'cell-menu sheet-menu');menu.setAttribute('role','menu');
  const item=(text,fn,cls)=>{const b=button(text,fn,cls);b.setAttribute('role','menuitem');menu.append(b);return b;};
  item('Đổi tên',()=>{closeSheetMenu();renameInline(tab,i);});
  item('Nhân đôi',()=>{closeSheetMenu();addSheet(i);});
  const del=item('Xóa sheet',()=>{if(del.dataset.sure){closeSheetMenu();deleteSheet(i);}else{del.dataset.sure='1';del.textContent='Bấm lần nữa để xóa';}},'danger');
  if(tableState.sheets.length<=1)del.disabled=true;
  document.body.append(menu);sheetMenuEl=menu;
  const w=menu.offsetWidth,h=menu.offsetHeight;menu.style.left=Math.max(4,Math.min(e.clientX,innerWidth-w-4))+'px';menu.style.top=Math.max(4,e.clientY-h-4)+'px';
  document.addEventListener('mousedown',outsideSheetMenu,true);
}
function renameInline(tab,i){
  if(!tab||!tab.isConnected)return;
  const input=node('input',undefined,'sheet-rename');input.type='text';input.value=tableState.sheets[i].name;input.maxLength=SHEET_NAME_MAX;input.setAttribute('aria-label','Tên sheet');
  tab.replaceWith(input);input.focus();input.select();
  let done=false;
  const finish=commit=>{if(done)return;done=true;if(commit&&input.value.trim()!==tableState.sheets[i].name)renameSheet(i,input.value);input.remove();syncSheetBar($('content').querySelector('.table-view'));};
  input.onkeydown=e=>{e.stopPropagation();if(e.key==='Enter'){e.preventDefault();finish(true);}else if(e.key==='Escape'){e.preventDefault();finish(false);}};
  input.onblur=()=>finish(true);
}
// Kéo đổi chỗ sheet: kéo thả HTML5, đổi chỗ trực tiếp khi kéo, các tab khác trượt bằng FLIP (150 ms), chốt thứ tự khi thả (dragend).
let dragSheet=null;
const tabIndex=tab=>Number(tab.dataset.index);
function moveSheetTab(bar,from,to){
  const tabs=[...bar.querySelectorAll('.sheet-tab')],moved=tabs[from],active=tableState.sheets[tableState.sheet];
  const before=new Map(tabs.map(t=>[t,t.getBoundingClientRect().left]));
  const [sheet]=tableState.sheets.splice(from,1);tableState.sheets.splice(to,0,sheet);
  tableState.sheet=tableState.sheets.indexOf(active);
  const order=tabs.filter(t=>t!==moved);order.splice(to,0,moved);
  const add=bar.querySelector('.sheet-add');
  order.forEach((t,i)=>{bar.insertBefore(t,add);t.dataset.index=String(i);t.setAttribute('aria-selected',String(i===tableState.sheet));});
  order.forEach(t=>{
    const dx=before.get(t)-t.getBoundingClientRect().left;if(!dx)return;
    t.style.transition='none';t.style.transform=`translateX(${dx}px)`;void t.offsetWidth;
    t.style.transition='';t.style.transform='';
  });
}
function bindSheetDrag(b){
  b.draggable=true;
  b.ondragstart=e=>{dragSheet=tabIndex(b);e.dataTransfer.effectAllowed='move';e.dataTransfer.setData('text/plain',b.textContent);b.classList.add('dragging');};
  b.ondragover=e=>{if(dragSheet===null)return;e.preventDefault();e.dataTransfer.dropEffect='move';const to=tabIndex(b);if(to!==dragSheet){moveSheetTab(b.parentNode,dragSheet,to);dragSheet=to;}};
  b.ondrop=e=>e.preventDefault();
  b.ondragend=()=>{if(dragSheet===null)return;dragSheet=null;b.classList.remove('dragging');persistView();};
}
function sheetBar(){
  ensureSheets();
  const bar=node('div',undefined,'sheetbar');bar.setAttribute('role','tablist');bar.setAttribute('aria-label','Sheet');
  tableState.sheets.forEach((s,i)=>{
    const b=node('button',s.name,'sheet-tab');b.type='button';b.setAttribute('role','tab');b.setAttribute('aria-selected',String(i===tableState.sheet));
    b.dataset.index=String(i);
    if(s.lock)b.classList.add('locked');
    b.title='Bấm để mở · kéo để đổi chỗ · bấm đúp hoặc F2 để đổi tên · bấm phải để nhân đôi hoặc xóa';
    b.onclick=()=>switchSheet(tabIndex(b));b.ondblclick=()=>renameInline(b,tabIndex(b));
    b.oncontextmenu=e=>{e.preventDefault();sheetMenu(e,tabIndex(b),b);};
    b.onkeydown=e=>{if(e.key==='F2'){e.preventDefault();renameInline(b,tabIndex(b));}};
    bindSheetDrag(b);
    bar.append(b);
  });
  const add=node('button','+','sheet-add');add.type='button';add.title='Thêm sheet (sao chép cài đặt của sheet đang mở)';add.setAttribute('aria-label','Thêm sheet');add.onclick=()=>addSheet();
  const active=tableState.sheets[tableState.sheet],locked=!!(active&&active.lock);
  const lock=node('button',locked?'🔒':'🔓','sheet-lock');lock.type='button';lock.setAttribute('aria-pressed',String(locked));
  lock.title=locked?'Đang khóa: sheet giữ các món đã khóa, không đổi theo lựa chọn. Bấm để mở khóa.':'Khóa sheet này: giữ các món đang có trong bảng, không đổi khi chọn món khác trong SketchUp.';
  lock.setAttribute('aria-label',locked?'Mở khóa sheet này':'Khóa sheet này');lock.onclick=()=>toggleSheetLock();
  bar.append(add,lock);
  return bar;
}
function syncSheetBar(view){
  if(!view)return;
  const old=view.querySelector(':scope>.sheetbar');
  if(old&&old.querySelector('input'))return; // đang đổi tên: không vẽ lại giữa chừng
  const fresh=sheetBar();if(old)old.replaceWith(fresh);else view.append(fresh);
}
function restoreView(data){
  tableState.restored=true;const v=data.view||{};if(!v.preset&&!(v.order||[]).length)return false;
  const keys=data.columns.map(c=>c.key);
  if((data.presets||presetsList()).some(p=>p.name===v.preset))tableState.preset=v.preset;
  if(typeof v.group==='string')tableState.group=v.group;
  const order=(v.order||[]).filter(k=>keys.includes(k));tableState.order=[...order,...keys.filter(k=>!order.includes(k))];
  tableState.visible=new Set((v.visible||[]).filter(k=>keys.includes(k)));
  if(!tableState.visible.size)return false;
  tableState.widths=v.widths||{};if(typeof v.density==='string')tableState.density=v.density;tableState.rowHeight=typeof v.rowHeight==='number'?v.rowHeight:0;
  if(typeof v.showTotals==='boolean')tableState.showTotals=v.showTotals;if(typeof v.onlyTop==='boolean')tableState.onlyTop=v.onlyTop;
  const p=presetByName(tableState.preset);
  tableState.headers=v.headers&&typeof v.headers==='object'?{...v.headers}:{...((p&&p.headers)||{})};
  tableState.settings={...defaultSettings(),...(v.settings||(p&&p.settings)||{})};
  if(Array.isArray(v.sheets)&&v.sheets.length){
    tableState.sheets=v.sheets.map(s=>({...s}));tableState.sheet=Number.isInteger(v.sheet)&&v.sheet>=0&&v.sheet<tableState.sheets.length?v.sheet:0;
    loadSheet(tableState.sheets[tableState.sheet],data.columns);applySheetExclude(tableState.sheets[tableState.sheet]);
    applyRowsLock(tableState.sheets[tableState.sheet].lock||null);
  }
  tableState.savedView=JSON.stringify(viewState());return true;
}
// Đang dùng preset tự tạo: đổi cột thì cập nhật luôn vào preset đó.
function syncCustomPreset(){const p=presetsList().find(x=>x.name===tableState.preset);if(p&&!p.builtin&&orderedKeys().length)call('table_preset',JSON.stringify({action:'save',name:p.name,group:tableState.group,columns:orderedKeys(),headers:tableState.headers,settings:workSettings(),silent:true}));}
function orderedKeys(){return tableState.order.filter(k=>tableState.visible.has(k));}
function cellText(row,key){
  const statuses=tableState.data.statuses||{};
  switch(key){
    case 'entity':return row.entity_type;
    case 'definition':return row.definition;
    case 'instance':return row.name;
    case 'code':return row.code||'';
    case 'mat_code':return row.mat_code||'';
    case 'level':return row.level||'';
    case 'room':return row.room||'';
    case 'vgd_id':return row.vgd_id?'VGD-'+String(row.vgd_id).slice(0,6).toUpperCase()+(row.vgd_dup?' (trùng)':''):''; // dạng ngắn; ID đầy đủ ở chú thích ô
    case 'description':return row.description;
    case 'lenXZ':return `${lenText(row.lenX)} × ${lenText(row.lenZ)}`;
    case 'lenXY':return `${lenText(row.lenX)} × ${lenText(row.lenY)}`;
    case 'lenXYZ':return `${lenText(row.lenX)} × ${lenText(row.lenY)} × ${lenText(row.lenZ)}`;
    case 'owner':return row.owner;
    case 'url':return row.url;
    case 'size':return row.size;
    case 'ifc':return row.ifc;
    case 'tag':return row.tag;
    case 'tag_group':return row.tag_group;
    case 'material':return row.material;
    case 'status':return statuses[row.status]||row.status;
    case 'front':return row.front||'';
    case 'front_state':return row.front_state||'';
    case 'measure_note':return row.measure_note||'';
    case 'calc_category':return CATEGORY_LABELS[row.calc_category]||'';
    case 'calc_method':return METHOD_LABELS[row.calc_method]||'';
    case 'calc_unit':return CALC_UNIT[row.calc_method]||'';
    default:return key.startsWith('custom_')&&row[key]!=null?String(row[key]):''; // cột thêm tay: chữ do Ruby đọc sẵn
  }
}
function sortValue(row,key){if(NUMERIC.has(key))return row[key]==null?-Infinity:row[key];return String(cellText(row,key)||'').toLocaleLowerCase('vi');}
// Thứ tự dòng do người dùng kéo tay: danh sách mã món lưu trong model (xem core/row_order.rb). Món chưa có trong danh sách (món mới) xuống cuối, theo thứ tự quét.
function pidMap(){const map=new Map();tableState.data.rows.forEach(r=>{if(Number.isInteger(r.pid)&&r.pid>0)map.set(r.index,r.pid);});return map;}
function manualSorted(rows){
  if(!tableState.manual.length)return rows;
  const rank=new Map(),pids=pidMap();tableState.manual.forEach((pid,i)=>rank.set(pid,i));
  const rankOf=row=>{let best=Infinity;membersOf(row).forEach(i=>{const r=rank.get(pids.get(i));if(r!==undefined&&r<best)best=r;});return best;};
  return rows.map(row=>({row,rank:rankOf(row)})).sort((a,b)=>a.rank===b.rank?a.row.index-b.row.index:(a.rank<b.rank?-1:1)).map(k=>k.row);
}
function filteredRows(){
  const q=foldText(tableState.search.trim());
  return tableState.data.rows.filter(r=>(!tableState.group||r.tag_group===tableState.group)&&(!q||[r.name,r.definition,r.description,r.tag,r.material].some(v=>foldText(v).includes(q))));
}
// Chọn dòng kiểu Excel: bấm = một dòng; Ctrl (hoặc Cmd) = thêm / bớt một dòng; Shift = cả dãy từ dòng gốc; Ctrl+Shift = thêm cả dãy;
// Ctrl+A = chọn hết các dòng đang hiện; Esc = bỏ chọn. SketchUp chọn theo các đối tượng đó (xem table_select trong dialog.rb).
// Dòng gộp (Gộp dòng giống nhau) có nhiều đối tượng: chọn dòng gộp là chọn mọi đối tượng của nó.
const membersOf=row=>row.members||[row.index];
// Các món đang chọn LÚC BẤM (không dùng danh sách chụp lúc mở bảng nổi, vì chọn thêm dòng không dựng lại bảng nổi). Dòng gộp gửi đủ mọi món đang chọn.
const selectedIndexes=()=>[...new Set(tableState.displayed.flatMap(r=>membersOf(r).filter(m=>tableState.sel.has(m))))];
// Số dòng đã chọn hiện ở chân trang, bên phải dòng thông báo (chỗ cố định để chân trang không nhảy chiều cao); chỉ có ở tab Bảng khối lượng và khi có dòng được chọn.
function updateSelInfo(){
  const el=$('sel-info');if(!el)return;
  const text=document.body.classList.contains('table-mode')&&tableState.data&&tableState.sel.size?`Đã chọn ${tableState.sel.size} / ${tableState.data.rows.length} dòng`:'';
  el.textContent=text;
}
function paintSelection(){
  document.querySelectorAll('.grid tbody tr[data-members]').forEach(tr=>tr.classList.toggle('selected',tr.dataset.members.split(',').every(i=>tableState.sel.has(Number(i)))));
  updateSelInfo();
  if(typeof syncBusy==='function')syncBusy();
  tableState.rename.preview=null; // phạm vi đổi tên đã đổi nên bản xem trước cũ không còn đúng
  if(tableState.panel==='rename'&&tableState.data)tableView(tableState.data);
}
function pickRows(indexes,field){
  clearTimeout(tableState.stepTimer);
  tableState.sel=new Set(indexes);paintSelection();
  if(!tableState.sel.size){tableState.cursor=null;call('table_clear');return;}
  call('table_select',JSON.stringify({indexes:[...tableState.sel],field:tableState.sel.size===1?(field||''):''}));
}
function clickRow(row,field,e){
  tableState.cursor=row.index;
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
// Mũi tên lên / xuống trong bảng: chuyển sang dòng liền trước / liền sau (theo thứ tự đang hiện), như bấm vào dòng đó: SketchUp chọn, thu phóng,
// cô lập... theo tuỳ chọn đang bật. Shift + mũi tên mở rộng vùng chọn từ dòng mốc. Chưa chọn gì: xuống = dòng đầu, lên = dòng cuối.
// Hiện dòng ngay nhưng chỉ gửi lệnh chọn cho SketchUp sau một khoảng ngắn không bấm nữa, để giữ phím không làm SketchUp thu phóng liên tục.
function stepRow(delta,extend){
  const order=tableState.displayed;
  if(!order||!order.length)return;
  let from=order.findIndex(r=>r.index===tableState.cursor);
  if(from<0)order.forEach((r,i)=>{if(r.members.some(m=>tableState.sel.has(m)))from=i;}); // dòng đang chọn cuối cùng trong thứ tự hiện
  const to=from<0?(delta>0?0:order.length-1):Math.min(order.length-1,Math.max(0,from+delta));
  const row=order[to];
  tableState.cursor=row.index;
  let picked=row.members;
  const anchorPos=order.findIndex(r=>r.index===tableState.anchor);
  if(extend&&anchorPos>=0)picked=[...new Set(order.slice(Math.min(anchorPos,to),Math.max(anchorPos,to)+1).flatMap(r=>r.members))];
  else tableState.anchor=row.index;
  clearTimeout(tableState.stepTimer);
  tableState.sel=new Set(picked);paintSelection();revealRow(row.index);
  tableState.stepTimer=setTimeout(()=>call('table_select',JSON.stringify({indexes:[...tableState.sel],field:''})),STEP_SELECT_MS);
}
const STEP_SELECT_MS=120;
// Cuộn bảng cho dòng hiện trọn vẹn, tránh hàng tiêu đề và dòng tổng cộng cố định.
function revealRow(index){
  const wrap=document.querySelector('.grid-wrap'),tr=wrap&&wrap.querySelector(`tbody tr[data-index="${index}"]`);
  if(!tr)return;
  const head=wrap.querySelector('thead'),foot=wrap.querySelector('tfoot');
  const top=wrap.getBoundingClientRect().top+(head?head.getBoundingClientRect().height:0),bottom=wrap.getBoundingClientRect().bottom-(foot?foot.getBoundingClientRect().height:0);
  const box=tr.getBoundingClientRect();
  if(box.top<top)wrap.scrollTop-=top-box.top;else if(box.bottom>bottom)wrap.scrollTop+=box.bottom-bottom;
}
function highlightRows(indexes){
  tableState.cursor=null; // vùng chọn do SketchUp đặt: mũi tên đi tiếp từ dòng chọn cuối cùng
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
function commitEdit(row,field,value){rememberSuggestion(field,value);call('table_edit',JSON.stringify({indexes:editTargets(row),field,value}));}
// ---- Gợi ý nhập kiểu Excel: gõ vài chữ đầu của Tên, Mô tả, Hãng, Cỡ hoặc cột chữ thêm tay thì phần còn lại hiện mờ, Enter / Tab nhận ----
const suggestible=field=>field==='name'||field==='description'||field==='owner'||field==='size'||String(field).startsWith('custom_');
const SUGGEST_MAX=150,SUGGEST_LEN=120;
function suggestionsFor(field){
  const d=tableState.data||{},history=((d.choices||{}).suggest||{})[field]||[],seen=new Set(),out=[];
  const add=value=>{const text=String(value==null?'':value).trim(),key=text.toLowerCase();if(!text||text.length>SUGGEST_LEN||seen.has(key))return;seen.add(key);out.push(text);};
  history.forEach(add);(d.rows||[]).forEach(r=>add(field==='name'?r.name:r[field]));
  return out;
}
// Ruby cũng ghi nhớ (trong file SketchUp); nhớ ngay phía giao diện để lần gõ kế tiếp có gợi ý mà không chờ bảng nạp lại.
function rememberSuggestion(field,value){
  const text=String(value||'').trim();if(!suggestible(field)||!text||text.length>SUGGEST_LEN||!tableState.data)return;
  const choices=tableState.data.choices=tableState.data.choices||{},all=choices.suggest=choices.suggest||{};
  all[field]=[text,...(all[field]||[]).filter(t=>t.toLowerCase()!==text.toLowerCase())].slice(0,SUGGEST_MAX);
}
// Trả về {el, accept()}: el là khung chứa ô nhập và lớp chữ mờ; accept() điền trọn gợi ý đang hiện (true nếu có).
function suggestBox(input,list){
  const wrap=node('div',undefined,'ac-wrap'),ghost=node('div',undefined,'ac-ghost');ghost.setAttribute('aria-hidden','true');
  let hit='';
  const styleGhost=()=>{const cs=getComputedStyle(input);['fontFamily','fontSize','fontWeight','letterSpacing'].forEach(k=>{ghost.style[k]=cs[k];});ghost.style.paddingLeft=`calc(${cs.paddingLeft} + ${cs.borderLeftWidth})`;ghost.style.paddingRight=cs.paddingRight;};
  const refresh=typing=>{
    hit='';ghost.replaceChildren();
    const v=input.value;
    if(!typing||!v||input.selectionStart!==v.length||input.selectionEnd!==v.length)return;
    // Gợi ý theo chữ đã gõ, không phân biệt hoa thường và dấu; phần còn lại cắt theo chữ gốc (vị trí có thể khác vì bỏ dấu).
    const low=foldText(v),found=list.find(t=>foldText(t).length>low.length&&foldText(t).startsWith(low));
    if(!found)return;
    let cut=0;while(cut<found.length&&foldText(found.slice(0,cut))!==low)cut++;
    if(cut>=found.length)return;
    hit=found;styleGhost();
    const typed=node('span',v);typed.style.visibility='hidden';ghost.append(typed,node('span',found.slice(cut),'ac-rest'));
  };
  input.addEventListener('input',e=>refresh(!/^delete/.test(e.inputType||'')));
  input.addEventListener('blur',()=>{hit='';ghost.replaceChildren();});
  wrap.append(input,ghost);
  return {el:wrap,accept(){if(!hit)return false;input.value=hit;hit='';ghost.replaceChildren();input.setSelectionRange(input.value.length,input.value.length);return true;}};
}
let cellMenu=null;
function closeMenu(){if(cellMenu){cellMenu.remove();cellMenu=null;document.removeEventListener('mousedown',outsideMenu,true);}}
function outsideMenu(e){if(cellMenu&&!cellMenu.contains(e.target))closeMenu();}
function inlineEdit(td,row,col){
  closeMenu();
  const field=col.editable,original=String(field==='name'?row.name:field==='price'?(row.price==null?'':row.price):row[field]||'');
  const input=node('input');input.type='text';input.value=original;input.maxLength=200;input.setAttribute('aria-label',col.label);
  const ac=suggestible(field)?suggestBox(input,suggestionsFor(field)):null;
  td.classList.add('editing');td.replaceChildren(ac?ac.el:input);input.focus();input.select();
  let done=false;
  const finish=commit=>{if(done)return;done=true;if(commit&&input.value!==original)commitEdit(row,field,input.value);renderGrid($('grid-host'));};
  input.onkeydown=e=>{
    e.stopPropagation();
    if(e.key==='Enter'){e.preventDefault();if(ac)ac.accept();finish(true);}
    else if(e.key==='Tab'&&ac&&ac.accept()){e.preventDefault();finish(true);}
    else if(e.key==='ArrowRight'&&ac&&ac.accept()){e.preventDefault();}
    else if(e.key==='Escape'){e.preventDefault();finish(false);}
  };
  input.onblur=()=>finish(true);
}
function menuItems(field){
  const d=tableState.data,choices=d.choices||{tags:[],materials:[]};
  if(field==='status')return Object.entries(d.statuses||{}).map(([value,label])=>({value,label}));
  if(field==='calc_method')return [{value:'',label:'Theo từ khóa / nhóm tag (bỏ cách tính riêng)'},...Object.entries(METHOD_LABELS).map(([value,label])=>({value,label}))];
  if(field==='room')return [{value:'',label:'(Không có phòng)'},...(choices.rooms||[])];
  if(field==='level')return [{value:'',label:'(Không có tầng)'},...(choices.levels||[])];
  if(field==='tag')return [{value:'',label:'(Không có tag)'},...choices.tags.map(name=>({value:name,label:name}))];
  return [{value:'',label:'(Không vật liệu)'},...choices.materials.map(name=>({value:name,label:name}))];
}
function menuEdit(td,row,col){
  closeMenu();
  const field=col.editable,current=field==='room'?row.room_id:field==='level'?row.level_id:field==='status'?row.status:(field==='tag'?row.tag:(field==='calc_method'?row.calc_method:row.material)),all=menuItems(field);
  const menu=node('div',undefined,'cell-menu');menu.setAttribute('role','listbox');
  const search=node('input');search.type='search';search.placeholder='Tìm...';search.setAttribute('aria-label','Tìm trong danh sách');
  const list=node('div',undefined,'cell-menu-list');
  const pick=value=>{closeMenu();commitEdit(row,field,value);};
  const draw=()=>{
    const q=foldText(search.value.trim());
    const shown=all.filter(item=>!q||foldText(item.label).includes(q));
    if(field==='tag'&&q&&!all.some(item=>foldText(item.label)===q))shown.push({value:search.value.trim(),label:`Tạo tag "${search.value.trim()}"`});
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
  if(['name','description','owner','url','size','price'].includes(col.editable)||col.editable.startsWith('custom_'))inlineEdit(td,row,col);else menuEdit(td,row,col);
}
// Đổi tên tiêu đề cột (lưu theo preset). Để trống hoặc trùng tên gốc thì dùng lại tên gốc.
function editHeader(th,col){
  th.draggable=false; // đang gõ trong ô: kéo chuột là chọn chữ, không dời cột
  const input=node('input');input.type='text';input.maxLength=60;input.value=colLabel(col);input.setAttribute('aria-label','Tên cột');input.className='header-input';
  th.replaceChildren(input);input.focus();input.select();
  let done=false;
  const finish=commit=>{
    if(done)return;done=true;
    if(commit){const text=input.value.trim();if(!text||text===withUnit(col.label))delete tableState.headers[col.key];else tableState.headers[col.key]=text;syncCustomPreset();persistView();}
    renderGrid($('grid-host'));
  };
  input.onkeydown=e=>{e.stopPropagation();if(e.key==='Enter'){e.preventDefault();finish(true);}else if(e.key==='Escape'){e.preventDefault();finish(false);}};
  input.onclick=e=>e.stopPropagation();
  input.onblur=()=>finish(true);
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
const GROUP_OPTIONS=[['','Không nhóm'],['parent','Cha (Parent)'],['entity','Loại (Entity)'],['definition','Tên họ (Definition)'],['instance','Tên (Instance)'],['material','Vật liệu'],['tag','Tag'],['tag_group','Nhóm hạng mục'],['status','Tình trạng'],['level','Tầng'],['room','Phòng'],['front_state','Mặt trước (độ tin cậy)']];
const SUM_KEYS=['areaXZ','areaXY','areaFace','areaProjected','volume','quantity','total','calc_qty','calc_total','mat_cost'];
function groupLabel(row,key){
  switch(key){
    case 'parent':return row.parent||'(Gốc)';
    case 'level':return row.level||'(Chưa gán tầng)';
    case 'room':return row.room||'(Chưa gán phòng)';
    case 'entity':return row.entity_type;
    case 'definition':return row.definition||'(Chưa đặt tên)';
    case 'instance':return row.name||'(Chưa đặt tên)';
    case 'material':return row.material||'(Không vật liệu)';
    case 'tag':return row.tag||'(Untagged)';
    case 'tag_group':return row.tag_group||'(Chưa phân loại)';
    case 'front_state':return row.front_state||'(Chưa có mặt trước)';
    case 'status':return (tableState.data.statuses||{})[row.status]||row.status;
    default:return '';
  }
}
// Gộp các dòng giống hệt nhau (cùng loại, họ, tên, mô tả, kích thước, tag, vật liệu, tình trạng) thành một dòng:
// Số lượng, diện tích và thể tích là tổng của các dòng gộp; kích thước giữ theo từng đối tượng.
function mergeRows(rows){
  const map=new Map();
  rows.forEach(row=>{
    const key=JSON.stringify([row.entity_type,row.definition,row.name,row.description,row.lenX,row.lenY,row.lenZ,row.tag,row.material,row.status,row.calc_method]);
    const hit=map.get(key);
    if(!hit){map.set(key,{...row,members:[row.index]});return;}
    hit.members.push(row.index);
    SUM_KEYS.forEach(k=>{if(typeof row[k]==='number')hit[k]=(typeof hit[k]==='number'?hit[k]:0)+row[k];});
    hit.locked=hit.locked||row.locked;
  });
  return [...map.values()];
}
// Dòng, nhóm và tổng đúng như bảng đang hiện (lọc, gộp, sắp xếp, nhóm theo, cộng tổng chỉ cấp cao nhất). Dùng cho vẽ bảng và xuất Excel / PDF.
// full = true (xuất): luôn từng món, không gộp dòng; nhóm thu gọn vẫn đủ món (xem exportRows).
function viewModel(full=false){
  const cols=orderedKeys().map(colByKey).filter(Boolean);
  const filtered=filteredRows();
  const shown=new Set(filtered.map(r=>r.index));
  const rows=tableState.merge&&!full?mergeRows(filtered):filtered;
  const placed=manualSorted(rows); // sắp theo cột là sắp ổn định trên thứ tự này nên các dòng bằng nhau giữ thứ tự tay (không có thứ tự tay thì là thứ tự quét)
  const ordered=tableState.sort?[...placed].sort((a,b)=>{const va=sortValue(a,tableState.sort.key),vb=sortValue(b,tableState.sort.key);if(va<vb)return -tableState.sort.dir;if(va>vb)return tableState.sort.dir;return 0;}):placed;
  // Cộng tổng: mặc định chỉ cộng đối tượng cấp cao nhất để không đếm trùng group lồng nhau.
  const counted=list=>list.filter(r=>!(tableState.onlyTop&&r.parents.some(p=>shown.has(p))));
  const sumOf=(list,key)=>counted(list).reduce((s,r)=>s+(typeof r[key]==='number'?r[key]:0),0);
  const countOf=list=>counted(list).reduce((s,r)=>s+membersOf(r).length,0);
  // Khối lượng tính cộng theo từng đơn vị (m², cái... không cộng lẫn nhau): "4,25 m² · 3 cái"
  const calcText=list=>{const by={};counted(list).forEach(r=>{if(r.calc_qty!=null&&CALC_UNIT[r.calc_method])by[r.calc_method]=(by[r.calc_method]||0)+r.calc_qty;});return CALC_ORDER.filter(k=>by[k]!=null).map(k=>`${fmt(by[k],CALC_DIGITS[k])} ${exportText(CALC_UNIT[k])}`).join(' · ');}; // đơn vị dịch theo ngôn ngữ đang dùng
  // Danh sách theo thứ tự hiển thị: các nhóm (nếu có) rồi các dòng của nhóm chưa thu gọn.
  let sections=[{label:null,rows:ordered}];
  if(tableState.groupBy){
    const map=new Map();
    ordered.forEach(row=>{const label=groupLabel(row,tableState.groupBy);if(!map.has(label))map.set(label,[]);map.get(label).push(row);});
    sections=[...map.entries()].sort((a,b)=>a[0].localeCompare(b[0],'vi',{numeric:true})).map(([label,list])=>({label,rows:list}));
  }
  return {cols,rows,sections,sumOf,countOf,calcText};
}
// Kéo tiêu đề cột để dời chỗ ngay trên bảng (cùng thứ tự với bảng Chọn cột): các cột đang hiện chiếm lại đúng những chỗ của chúng, cột ẩn giữ nguyên chỗ.
function columnDrag(th,col,host){
  th.draggable=true;
  const side=e=>e.clientX>th.getBoundingClientRect().left+th.getBoundingClientRect().width/2;
  th.ondragstart=e=>{
    tableState.dragCol=col.key;
    e.dataTransfer.effectAllowed='move';e.dataTransfer.setData('text/plain','vgd-col');
    setTimeout(()=>th.classList.add('col-dragging'),0);
  };
  th.ondragend=()=>clearColumnDrag(host);
  th.ondragover=e=>{
    if(!tableState.dragCol)return; // kéo ảnh từ ngoài vào hoặc kéo dòng: để nguyên
    e.preventDefault();e.dataTransfer.dropEffect='move';
    const after=side(e);
    host.querySelectorAll('th.drop-left,th.drop-right').forEach(el=>{if(el!==th)el.classList.remove('drop-left','drop-right');});
    th.classList.toggle('drop-left',!after);th.classList.toggle('drop-right',after);
  };
  th.ondrop=e=>{
    if(!tableState.dragCol)return;
    e.preventDefault();const after=side(e),from=tableState.dragCol;clearColumnDrag(host);dropColumn(from,col.key,after);
  };
}
function clearColumnDrag(host){
  tableState.dragCol=null;
  host.querySelectorAll('th.col-dragging,th.drop-left,th.drop-right').forEach(el=>el.classList.remove('col-dragging','drop-left','drop-right'));
}
function dropColumn(from,target,after){
  if(from===target)return;
  const shown=orderedKeys(),keys=shown.filter(k=>k!==from);
  if(!shown.includes(from)||!keys.includes(target))return;
  keys.splice(keys.indexOf(target)+(after?1:0),0,from);
  if(keys.every((k,i)=>k===shown[i]))return; // thả về đúng chỗ cũ
  applyListOrder(keys);refreshColumns();
  const side=$('col-side'),list=side&&side.dataset.kind==='columns'?side.querySelector('.pop-cols'):null;
  if(list)renderColumnList(list); // bảng Chọn cột đang mở thì đổi theo
}
// Kéo thả dòng bằng tay nắm ở ô đầu: chỉ đổi chỗ trong cùng một nhóm; kéo một dòng đang được chọn cùng nhiều dòng chọn thì dời cả cụm.
function rowGrip(tr,row,section,pids,host){
  if(!membersOf(row).every(i=>pids.has(i)))return; // món không có mã bền thì không lưu được chỗ
  const first=tr.firstElementChild;if(!first)return;
  const grip=node('span','⋮⋮','row-grip');grip.draggable=true;grip.title='Kéo để đổi vị trí dòng';grip.setAttribute('aria-hidden','true');
  grip.ondblclick=e=>e.stopPropagation();
  grip.ondragstart=e=>{
    const picked=section.rows.filter(r=>membersOf(r).every(m=>tableState.sel.has(m)));
    const moving=picked.length>1&&picked.some(r=>r.index===row.index)?picked:[row];
    tableState.dragRow={section,moving};
    e.dataTransfer.effectAllowed='move';e.dataTransfer.setData('text/plain','vgd-row');e.dataTransfer.setDragImage(tr,12,12);
    setTimeout(()=>moving.forEach(r=>{const el=host.querySelector(`tr[data-index="${r.index}"]`);if(el)el.classList.add('dragging');}),0);
  };
  grip.ondragend=()=>clearRowDrag(host);
  first.classList.add('has-grip');first.prepend(grip);
}
function rowDrag(tr,row,section,pids,host){
  const side=e=>{const box=tr.getBoundingClientRect();return e.clientY>box.top+box.height/2;};
  tr.ondragover=e=>{
    const drag=tableState.dragRow;if(!drag||drag.section!==section)return; // kéo ảnh từ ngoài vào, hoặc sang nhóm khác: để nguyên
    e.preventDefault();e.dataTransfer.dropEffect='move';
    const after=side(e);
    host.querySelectorAll('tr.drop-before,tr.drop-after').forEach(el=>{if(el!==tr)el.classList.remove('drop-before','drop-after');});
    tr.classList.toggle('drop-before',!after);tr.classList.toggle('drop-after',after);
  };
  tr.ondrop=e=>{
    const drag=tableState.dragRow;if(!drag||drag.section!==section)return;
    e.preventDefault();const after=side(e);clearRowDrag(host);dropRows(drag,row,after);
  };
}
function clearRowDrag(host){
  tableState.dragRow=null;
  host.querySelectorAll('tr.dragging,tr.drop-before,tr.drop-after').forEach(el=>el.classList.remove('dragging','drop-before','drop-after'));
}
function dropRows(drag,target,after){
  const list=drag.section.rows,moving=new Set(drag.moving.map(r=>r.index));
  if(moving.has(target.index))return;
  const lifted=list.filter(r=>moving.has(r.index)),rest=list.filter(r=>!moving.has(r.index));
  const at=rest.findIndex(r=>r.index===target.index)+(after?1:0);
  const next=[...rest.slice(0,at),...lifted,...rest.slice(at)];
  if(next.every((r,i)=>r.index===list[i].index))return; // thả về đúng chỗ cũ
  commitManualOrder(list,next);
}
// Các dòng của nhóm chiếm lại đúng những chỗ của chúng trong thứ tự chung theo thứ tự mới; dòng bị lọc hoặc ở nhóm khác giữ nguyên chỗ.
function commitManualOrder(oldList,newList){
  const pids=pidMap(),pidsOf=rows=>rows.flatMap(r=>membersOf(r).map(i=>pids.get(i)));
  const full=manualSorted(tableState.data.rows).map(r=>pids.get(r.index)).filter(pid=>pid!==undefined);
  const owned=new Set(pidsOf(oldList)),fill=pidsOf(newList),result=[...full];let n=0;
  full.forEach((pid,i)=>{if(owned.has(pid))result[i]=fill[n++];});
  tableState.manual=result;
  if(tableState.sort){tableState.sort=null;message('Đã bỏ sắp xếp theo cột để giữ thứ tự bạn vừa kéo.');}
  call('table_order',JSON.stringify({order:result}));
  tableView(tableState.data);
}
function resetManualOrder(){
  const own=[...pidMap().values()],set=new Set(own);
  tableState.manual=tableState.manual.filter(pid=>!set.has(pid));
  call('table_order',JSON.stringify({reset:own}));
  tableView(tableState.data);
}
function renderGrid(host){
  const data=tableState.data;
  const {cols,rows,sections,sumOf,countOf,calcText}=viewModel();
  const collapsedKey=section=>`${tableState.groupBy}:${section.label}`;
  const visibleRows=sections.flatMap(section=>section.label!==null&&tableState.collapsed.has(collapsedKey(section))?[]:section.rows);
  tableState.shownRows=visibleRows;
  tableState.displayed=visibleRows.map(row=>({index:row.index,members:membersOf(row)})); // thứ tự dòng đang hiện, dùng cho chọn dãy bằng Shift
  closeMenu();
  const hadFocus=!!document.activeElement&&document.activeElement.classList&&document.activeElement.classList.contains('grid-wrap'); // vẽ lại bảng không được làm mất phím mũi tên
  const oldWrap=host.querySelector('.grid-wrap'),scroll=oldWrap?{top:oldWrap.scrollTop,left:oldWrap.scrollLeft}:null; // giữ vị trí cuộn: sửa tên / ảnh / ô ở dòng dưới không được nhảy về đầu bảng
  host.replaceChildren();
  const wrap=node('div',undefined,'grid-wrap');
  wrap.tabIndex=0;
  wrap.onscroll=closeMenu;
  wrap.onkeydown=e=>{
    if(e.target.closest('input,select,textarea'))return;
    if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='a'){e.preventDefault();pickRows(tableState.displayed.flatMap(membersOf),'');}
    else if(e.key==='Escape'&&tableState.sel.size){pickRows([],'');}
    else if((e.key==='ArrowDown'||e.key==='ArrowUp')&&!e.ctrlKey&&!e.metaKey&&!e.altKey){e.preventDefault();stepRow(e.key==='ArrowDown'?1:-1,e.shiftKey);}
  };
  const t=node('table',undefined,'grid'+(tableState.density?' '+tableState.density:''));
  t.style.width=cols.reduce((sum,col)=>sum+widthOf(col.key),0)+'px';rowStyle(t);
  wrap.addEventListener('wheel',e=>wheelRowHeight(e,t),{passive:false}); // không thụ động: cần chặn phóng to trang của trình duyệt khi giữ Ctrl
  const colgroup=node('colgroup');cols.forEach(col=>{const cg=node('col');cg.style.width=widthOf(col.key)+'px';colgroup.append(cg);});t.append(colgroup);
  const thead=node('thead'),head=node('tr');
  cols.forEach(col=>{
    const active=tableState.sort&&tableState.sort.key===col.key;
    const th=node('th',colLabel(col)+(active?(tableState.sort.dir>0?' ▲':' ▼'):''));
    th.dataset.key=col.key;th.title='Nhấp để sắp xếp · nhấp đúp để đổi tên cột · kéo để dời cột';
    columnDrag(th,col,host);
    // Nhấp đúp = đổi tên cột, nên việc sắp xếp chờ một nhịp xem có phải nhấp đúp không.
    th.onclick=()=>{clearTimeout(th._sort);th._sort=setTimeout(()=>{tableState.sort=active?{key:col.key,dir:-tableState.sort.dir}:{key:col.key,dir:1};renderGrid(host);},260);};
    th.ondblclick=e=>{clearTimeout(th._sort);e.stopPropagation();editHeader(th,col);};
    const handle=node('span',undefined,'rz');handle.setAttribute('aria-hidden','true');
    handle.onclick=e=>e.stopPropagation();
    handle.onmousedown=e=>startResize(e,col.key,host,cols);
    th.append(handle);head.append(th);
  });
  thead.append(head);
  // Hàng đơn vị dưới tiêu đề, kiểu Auto Info.
  const unitRow=node('tr',undefined,'unit-row');
  cols.forEach(col=>{const th=node('th');if(unitTextOf(col.key))th.append(node('span',unitTextOf(col.key),'pill'));unitRow.append(th);});
  thead.append(unitRow);t.append(thead);
  // Nhãn "Tổng cộng" / tên nhóm đặt ở cột rộng nhất có sẵn (Tên, rồi Họ, rồi Loại) để không bị cắt.
  const labelKey=['instance','definition','entity'].find(k=>cols.some(c=>c.key===k));
  const labelIndex=Math.max(0,cols.findIndex(col=>col.key===labelKey));
  const tbody=node('tbody'),pids=pidMap();
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
        }else if(col.kind==='sum'){td.textContent=fmt(scaledValue(col.key,sumOf(section.rows,col.key)),digitsFor(col.key));td.className='num';}
        else if(col.kind==='calc'){td.textContent=calcText(section.rows);td.className='num';}
        head.append(td);
      });
      tbody.append(head);
      if(closed)return;
    }
    section.rows.forEach(row=>{
      pos++;
      const members=membersOf(row);
      const tr=node('tr');tr.dataset.index=String(row.index);tr.dataset.members=members.join(',');
      rowDrag(tr,row,section,pids,host);
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
        else if(col.kind==='image')imageCell(td,row);
        else if(col.kind==='image_location')imageCell(td,row,'location');
        else if(IMAGE_EXTRA_KINDS[col.kind])imageCell(td,row,IMAGE_EXTRA_KINDS[col.kind]);
        else if(NUMERIC.has(col.key)){td.textContent=fmt(scaledValue(col.key,row[col.key]),(col.key==='calc_qty'||col.key==='mat_qty')?(CALC_DIGITS[row.calc_method]||0):col.key==='mat_waste'?1:digitsFor(col.key));td.className='num';}
        else if(col.key==='url'){
          td.append(node('span',row.url,'cell-url'));
          if(row.url){const open=node('button','↗','cell-open');open.type='button';open.title='Mở link';open.setAttribute('aria-label','Mở link');open.onclick=e=>{e.stopPropagation();call('open_url',row.url);};open.ondblclick=e=>e.stopPropagation();td.append(open);}
        }
        else td.textContent=cellText(row,col.key);
        if(col.key==='front_state'&&row.front_note)td.title=row.front_note; // lý do tự động chọn mặt trước, để duyệt
        if(col.key==='vgd_id'&&row.vgd_id)td.title=row.vgd_id;
        if(col.key==='mat_cost'&&row.mat_note)td.title=exportText(row.mat_note);
        if(col.key.startsWith('calc_')&&row.calc_source)td.title=exportText(CALC_SOURCES[row.calc_source]||'')+(row.calc_note?' · '+exportText(row.calc_note):'')+(col.key==='calc_method'?'. '+exportText('Nhấp đúp để đổi cách tính của tag này.'):''); // vì sao ra cách tính này (dịch từng phần theo ngôn ngữ)
        tr.append(td);
      });
      rowGrip(tr,row,section,pids,host);
      tbody.append(tr);
    });
  });
  t.append(tbody);
  if(tableState.showTotals){
    const foot=node('tr');
    cols.forEach((col,i)=>{
      const td=node('td');
      if(i===labelIndex)td.textContent=`Tổng cộng · ${countOf(rows)} đối tượng`;
      else if(col.kind==='sum'){td.textContent=fmt(scaledValue(col.key,sumOf(rows,col.key)),digitsFor(col.key));td.className='num';}
      else if(col.kind==='calc'){td.textContent=calcText(rows);td.className='num';}
      foot.append(td);
    });
    const tfoot=node('tfoot');tfoot.append(foot);t.append(tfoot);
  }
  wrap.append(t);host.append(wrap);
  if(scroll){wrap.scrollTop=scroll.top;wrap.scrollLeft=scroll.left;}
  if(hadFocus)wrap.focus({preventScroll:true});
  if(!rows.length)host.append(node('p','Không có đối tượng nào khớp bộ lọc.','empty'));
  fillImages();
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
  const p=node('div',undefined,'popover right group-panel');
  p.append(node('div','Nhóm theo','pop-title'));
  const list=node('div',undefined,'pop-list');
  GROUP_OPTIONS.forEach(([value,label])=>list.append(button(label,()=>{tableState.groupBy=value;tableState.panel=null;tableView(tableState.data);},'pop-pick'+(value===tableState.groupBy?' primary':''))));
  const merge=node('label',undefined,'merge-opt');
  const box=node('input');box.type='checkbox';box.checked=tableState.merge;
  box.onchange=()=>{tableState.merge=box.checked;renderGrid($('grid-host'));};
  merge.append(box,document.createTextNode(' Gộp dòng giống nhau'));
  // Mở / thu gọn mọi nhóm một lượt, khỏi bấm từng nhóm khi có nhiều nhóm.
  const toggles=node('div');
  if(tableState.groupBy)toggles.append(button('Mở tất cả nhóm',()=>setAllGroupsClosed(false),'pop-pick'),button('Thu gọn tất cả',()=>setAllGroupsClosed(true),'pop-pick'));
  p.append(list,toggles,merge,node('p','Chỉ đổi cách hiển thị. Dòng gộp: Số lượng, diện tích, thể tích là tổng của các dòng gộp.','muted'));
  return p;
}
// Thay thế hàng loạt: chữ cần tìm là ô Tìm; áp cho các cột Tên, Mô tả, Xuất xứ, Quy cách đang hiện, trong các dòng đang lọc.
const REPLACE_COLUMNS={instance:'name',description:'description',owner:'owner',size:'size'};
const replaceFields=()=>orderedKeys().filter(k=>REPLACE_COLUMNS[k]).map(k=>REPLACE_COLUMNS[k]);
function replaceMatches(){
  const q=foldText(tableState.search.trim());if(!q)return 0;
  const fields=replaceFields();let count=0;
  filteredRows().forEach(r=>fields.forEach(f=>{if(foldText(r[f==='name'?'name':f]).includes(q))count++;}));
  return count;
}
function updateReplaceUi(){
  const box=$('replace-box'),go=$('replace-go');if(!box||!go)return;
  const q=tableState.search.trim(),n=replaceMatches();
  box.hidden=!q;go.textContent=`Thay thế (${n})`;go.disabled=!n;
  go.title=replaceFields().length?'Thay chữ đang tìm trong các cột Tên, Mô tả, Xuất xứ, Quy cách đang hiện (một bước hoàn tác)':'Hãy hiện ít nhất một cột Tên, Mô tả, Hãng hoặc Cỡ';
}
function runReplace(){
  const find=tableState.search.trim();
  if(!find)throw Error('Hãy nhập chữ cần tìm.');
  if(!replaceMatches())throw Error('Không có ô nào chứa chữ cần tìm.');
  call('table_replace',JSON.stringify({find,replace:tableState.replace,fields:replaceFields(),indexes:filteredRows().map(r=>r.index)}));
}
// Biểu tượng ảnh (vẽ bằng SVG để đúng màu theme).
function imageIcon(){
  const ns='http://www.w3.org/2000/svg',svg=document.createElementNS(ns,'svg');
  svg.setAttribute('viewBox','0 0 24 24');svg.setAttribute('width','18');svg.setAttribute('height','18');svg.setAttribute('fill','none');svg.setAttribute('stroke','currentColor');svg.setAttribute('stroke-width','2');svg.setAttribute('stroke-linecap','round');svg.setAttribute('stroke-linejoin','round');svg.setAttribute('aria-hidden','true');
  [['rect',{x:3,y:4,width:18,height:16,rx:2}],['circle',{cx:9,cy:10,r:1.6}],['path',{d:'M21 16l-5-5-8 8'}]].forEach(([tag,attrs])=>{const el=document.createElementNS(ns,tag);Object.entries(attrs).forEach(([k,v])=>el.setAttribute(k,v));svg.append(el);});
  return svg;
}
function toolbar(){
  const d=tableState.data;const bar=node('div',undefined,'toolbar');
  const cols=button('Chọn cột',toggleColumns,'primary');cols.id='cols-btn';
  cols.setAttribute('aria-expanded',String(tableState.panel==='columns'));
  const searchWrap=node('div',undefined,'search-wrap');
  const search=node('input');search.type='text';search.placeholder='Tìm kiếm...';search.value=tableState.search;search.setAttribute('aria-label','Tìm trong bảng');
  const clear=node('button','×','search-clear');clear.type='button';clear.title='Xóa chữ tìm';clear.setAttribute('aria-label','Xóa chữ tìm');clear.hidden=!tableState.search;
  clear.onclick=()=>{tableState.search='';search.value='';clear.hidden=true;glass.hidden=false;renderGrid($('grid-host'));updateReplaceUi();};
  search.oninput=()=>{tableState.search=search.value;clear.hidden=!search.value;glass.hidden=!!search.value;renderGrid($('grid-host'));updateReplaceUi();};
  const glass=node('span','⌕','search-icon');glass.setAttribute('aria-hidden','true');glass.hidden=!!tableState.search;
  clear.hidden=!tableState.search;
  searchWrap.append(search,glass,clear);
  const replaceBox=node('div',undefined,'replace-box');replaceBox.id='replace-box';replaceBox.hidden=true;
  const replace=node('input');replace.type='text';replace.placeholder='Thay bằng...';replace.value=tableState.replace;replace.maxLength=200;replace.setAttribute('aria-label','Thay bằng');
  const go=button('Thay thế',()=>runReplace());go.id='replace-go';
  replace.oninput=()=>{tableState.replace=replace.value;};
  replace.onkeydown=e=>{if(e.key==='Enter'){e.preventDefault();go.click();}};
  replaceBox.append(replace,go);
  const group=node('select');group.setAttribute('aria-label','Nhóm hạng mục');group.append(new Option('Tất cả hạng mục',''));(d.groups||[]).forEach(g=>group.append(new Option(g,g)));
  group.value=tableState.group;group.onchange=()=>{tableState.group=group.value;renderGrid($('grid-host'));persistView();updateReplaceUi();};
  const snap=button('',()=>{tableState.panel=tableState.panel==='capture'?null:'capture';tableView(tableState.data);},'icon-btn');
  snap.append(imageIcon());snap.id='cap-run';snap.title='Cập nhật ảnh';snap.setAttribute('aria-label','Cập nhật ảnh');snap.setAttribute('aria-expanded',String(tableState.panel==='capture'));
  const stop=button('Dừng',()=>call('images_cancel'));stop.id='cap-stop';stop.hidden=true;
  const progress=node('span',undefined,'muted');progress.id='cap-progress';
  const groupLabelText=(GROUP_OPTIONS.find(o=>o[0]===tableState.groupBy)||GROUP_OPTIONS[0])[1];
  const grouping=button(tableState.groupBy&&tableState.groupBy!==GROUP_OPTIONS[0][0]?`Nhóm: ${groupLabelText} ▾`:'Nhóm theo ▾',()=>{tableState.panel=tableState.panel==='group'?null:'group';tableView(tableState.data);});
  grouping.setAttribute('aria-expanded',String(tableState.panel==='group'));
  const groupAnchor=node('div',undefined,'pop-anchor');groupAnchor.append(grouping);
  if(tableState.panel==='group')groupAnchor.append(groupPanel());
  // Nút Loại trừ tag luôn hiện trên thanh (bấm để mở danh sách); đang loại trừ thì kèm số tag vì số đo đã khác. Mục trong menu Công cụ vẫn giữ.
  const excludeCount=excludedTags().size;
  const excludeChip=button(excludeCount?`Loại trừ ${excludeCount} tag`:'Loại trừ tag',toggleExclude,'chip');excludeChip.id='exclude-chip';excludeChip.title='Các tag này không tính vào Rộng / Dài / Cao. Bấm để xem hoặc đổi.';
  excludeChip.setAttribute('aria-expanded',String(tableState.panel==='exclude'));
  const own=new Set(pidMap().values()),placed=tableState.manual.some(pid=>own.has(pid));
  const unplace=button('Bỏ xếp tay',resetManualOrder);unplace.id='order-reset';unplace.title='Bỏ thứ tự bạn đã kéo, về thứ tự quét ban đầu';
  bar.append(cols,searchWrap,replaceBox,group,excludeChip,node('span',undefined,'grow'),snap,stop,progress);
  if(placed)bar.append(unplace);
  bar.append(groupAnchor);
  return bar;
}
// Thu gọn (closed = true) hoặc mở (false) mọi nhóm đang hiện. Chỉ đổi cách xem, không đổi dữ liệu.
function setAllGroupsClosed(closed){
  viewModel().sections.forEach(section=>{
    if(section.label===null)return;
    const key=`${tableState.groupBy}:${section.label}`;
    if(closed)tableState.collapsed.add(key);else tableState.collapsed.delete(key);
  });
  renderGrid($('grid-host'));
}
// Mặt trước: phát hiện tự động (tường + hình học), đặt tay theo hướng nhìn / xoay / đảo, xóa. Chỉ ghi dữ liệu, không đổi hình học.
tableState.frontOverwrite=false;
function frontTargets(){return tableState.sel.size?[...tableState.sel]:filteredRows().map(r=>r.index);}
function frontManualTargets(){
  if(!tableState.sel.size)throw Error('Hãy chọn đối tượng trong bảng trước.');
  return [...tableState.sel];
}
// Sửa trục theo mặt trước (đổi hình học): chỉ làm cho các dòng đang chọn, phải Xem trước rồi mới Áp dụng được.
tableState.alignPlan=null;
function alignLines(plan){
  const lines=[];
  if(!plan.fix)lines.push('Không có món nào cần sửa trục.');
  else{lines.push(`Sẽ sửa trục ${plan.fix} loại (${plan.instances} bản sao).`);if(plan.names&&plan.names.length)lines.push('Gồm: '+plan.names.join(', ')+(plan.fix>plan.names.length?'…':''));}
  if(plan.aligned)lines.push(`Đã có mặt trước -Y: ${plan.aligned} loại.`);
  (plan.reasons||[]).forEach(r=>lines.push(`Bỏ qua ${r.count} loại: ${r.reason}.`));
  return lines;
}
function alignSection(p,row){
  p.append(node('div','Sửa trục theo mặt trước','pop-title front-sub'));
  p.append(node('p','Xoay nội dung của món (bội của 90°) để mặt trước thành hướng -Y và bù cho mọi bản sao, nên hình trong model không đổi chỗ. Đây là thay đổi hình học; Ctrl+Z hoàn tác một lần. Chỉ áp dụng cho các dòng đang chọn.','muted'));
  const key=JSON.stringify([...tableState.sel].sort((a,b)=>a-b));
  const plan=tableState.alignPlan&&JSON.stringify(tableState.alignPlan.key)===key?tableState.alignPlan:null;
  if(plan){const box=node('div',undefined,'front-plan');alignLines(plan).forEach(line=>box.append(node('div',line)));p.append(box);}
  const preview=button('Xem trước sửa trục',()=>call('front_align_preview',JSON.stringify({indexes:frontManualTargets()})));preview.id='front-align-preview';
  // Sau khi bấm Áp dụng xóa ngay bản xem trước (vẽ lại bảng) để không bấm hai lần.
  const apply=button('Áp dụng sửa trục',()=>{call('front_align',JSON.stringify({indexes:frontManualTargets()}));tableState.alignPlan=null;tableView(tableState.data);},'primary');apply.id='front-align-apply';
  apply.disabled=!(plan&&plan.fix>0);
  p.append(row(preview,apply));
}
function frontPanel(){
  const p=node('div',undefined,'popover right front-panel');
  const chosen=tableState.sel.size>0,targets=frontTargets();
  p.append(node('div','Mặt trước','pop-title'));
  p.append(node('p','Mặt trước là hướng ra của món theo trục riêng của nó. Khi chọn món, mũi tên trong SketchUp chỉ hướng này.','muted'));
  p.append(node('p',chosen?`Áp dụng cho ${targets.length} đối tượng đang chọn.`:`Chưa chọn dòng nào: phát hiện tự động cho tất cả ${targets.length} đối tượng đang hiện.`,'rename-scope'));
  const over=node('input');over.type='checkbox';over.checked=tableState.frontOverwrite;over.id='front-overwrite';over.onchange=()=>{tableState.frontOverwrite=over.checked;};
  const overLabel=node('label',undefined,'merge-opt');overLabel.append(over,document.createTextNode(' Ghi đè cả món đã đặt tay'));
  const detect=button('Phát hiện tự động',()=>call('front_detect',JSON.stringify({indexes:chosen?targets:[],overwrite:tableState.frontOverwrite})),'primary');detect.id='front-detect';
  const row=(...buttons)=>{const r=node('div',undefined,'front-row');r.append(...buttons);return r;};
  const send=(mode,extra={})=>()=>call('front_set',JSON.stringify({indexes:frontManualTargets(),mode,...extra}));
  const camera=button('Theo hướng nhìn hiện tại',send('camera'));camera.id='front-camera';camera.title='Xoay camera nhìn thẳng vào mặt trước của món rồi bấm nút này';
  const turn=button('Xoay 90°',send('turn'));turn.id='front-turn';
  const flip=button('Đảo chiều',send('opposite'));flip.id='front-opposite';
  const clear=button('Xóa mặt trước',()=>call('front_clear',JSON.stringify({indexes:frontManualTargets()})));clear.id='front-clear';
  p.append(overLabel,row(detect),row(camera),row(turn,flip,clear));
  alignSection(p,row);
  p.append(node('p','Món tin cậy "Cần duyệt" nên được xem lại: chọn dòng, nhìn mũi tên trong SketchUp, đúng thì giữ, sai thì xoay hoặc đảo.','muted'));
  return p;
}
// Chụp ảnh: hỏi lại trước khi chụp nhiều đối tượng. Chỉ chụp khi bấm nút Chụp.
function captureTargets(){return tableState.sel.size?[...tableState.sel]:filteredRows().map(r=>r.index);}
// Đặt Mã đối tượng hàng loạt: tiền tố + số thứ tự theo thứ tự dòng đang hiện (chỉ các dòng đang chọn). Ruby kiểm tra lại và không để trùng mã.
function codesPanel(){
  const p=node('div',undefined,'popover right capture-panel codes-panel');
  const picked=tableState.displayed.filter(r=>r.members.some(m=>tableState.sel.has(m)));
  p.append(node('div','Đặt mã đối tượng','pop-title'));
  p.append(node('p',picked.length?`Đặt mã cho ${picked.length} dòng đang chọn, theo thứ tự trong bảng.`:'Hãy chọn các dòng cần đặt mã (Ctrl+A chọn hết các dòng đang hiện).','rename-scope'));
  const field=(label,value,type)=>{const wrap=node('label',undefined,'rename-field');const input=node('input');input.type=type||'text';input.value=value;input.setAttribute('aria-label',label);wrap.append(node('span',label),input);return {wrap,input};};
  const prefix=field('Tiền tố','D'),start=field('Số bắt đầu','1','number'),pad=field('Số chữ số','2','number');
  prefix.input.maxLength=20;
  const row=node('div',undefined,'rename-row');row.append(start.wrap,pad.wrap);
  const over=node('input');over.type='checkbox';const overLabel=node('label',undefined,'merge-opt');overLabel.append(over,document.createTextNode(' Đặt lại cả món đã có mã'));
  const preview=node('p',undefined,'muted');
  const sample=()=>{const n=Number(start.input.value),d=Number(pad.input.value);preview.textContent=Number.isInteger(n)&&Number.isInteger(d)&&d>=1&&d<=6?`Ví dụ: ${prefix.input.value.trim()}${String(n).padStart(d,'0')}, ${prefix.input.value.trim()}${String(n+1).padStart(d,'0')}...`:'';};
  [prefix,start,pad].forEach(f=>f.input.oninput=sample);sample();
  const apply=button('Áp dụng',()=>{
    if(!selectedIndexes().length)throw Error('Hãy chọn các dòng cần đặt mã.');
    call('table_assign_codes',JSON.stringify({indexes:selectedIndexes(),prefix:prefix.input.value,start:Number(start.input.value),pad:Number(pad.input.value),overwrite:over.checked}));
    tableState.panel=null;tableView(tableState.data);
  },'primary');
  const actions=node('div',undefined,'rename-actions');actions.append(apply,button('Đóng',()=>{tableState.panel=null;tableView(tableState.data);}));
  p.append(prefix.wrap,row,overLabel,preview,actions);
  return p;
}
// Thư viện vật liệu: lưu trên máy (dùng cho mọi model), nối với vật liệu SketchUp theo tên. Ruby kiểm tra lại mọi giá trị.
const MATERIAL_UNITS=[['m2','m²'],['m','m'],['m3','m³'],['pcs','cái'],['set','bộ'],['lot','lô'],['kg','kg'],['none','không']];
function materialsPanel(){
  const p=node('div',undefined,'popover right capture-panel materials-panel');
  const items=((tableState.data&&tableState.data.material_library)||[]).map(i=>({...i}));
  const names=(tableState.data&&tableState.data.sketchup_materials)||[];
  p.append(node('div','Thư viện vật liệu','pop-title'));
  p.append(node('p','Nối với vật liệu SketchUp theo tên. Khối lượng có hao hụt = khối lượng tính x (1 + hao hụt %). Thành tiền chỉ tính khi đơn vị vật liệu trùng đơn vị tính của dòng (m², m, m³, cái).','muted'));
  const save=()=>call('material_library_save',JSON.stringify({items}));
  const input=(item,key,label,type,width,place)=>{const i=node('input');i.type=type;i.value=item[key]??'';i.setAttribute('aria-label',label);i.title=label;if(place)i.placeholder=place;if(width)i.style.width=width;i.onchange=()=>{item[key]=type==='number'?(i.value===''?null:Number(i.value)):i.value;save();};return i;};
  items.forEach(item=>{
    const box=node('div',undefined,'mt-item');box.dataset.id=item.id;
    const top=node('div',undefined,'mt-top');
    const code=input(item,'code','Mã vật liệu','text','80px','Mã');code.maxLength=30;
    const name=input(item,'name','Tên vật liệu','text');name.className='mt-name';name.maxLength=80;
    const del=button('×',()=>{items.splice(items.indexOf(item),1);save();},'cs-del');del.title='Xóa vật liệu này khỏi thư viện';del.setAttribute('aria-label','Xóa vật liệu '+item.name);
    top.append(code,name,del);
    const mid=node('div',undefined,'mt-mid');
    const unit=node('select');unit.setAttribute('aria-label','Đơn vị vật liệu');MATERIAL_UNITS.forEach(([v,t])=>unit.append(new Option(t,v)));unit.value=item.unit||'m2';unit.onchange=()=>{item.unit=unit.value;save();};
    mid.append(miniField('Đơn vị',unit),miniField('Đơn giá',input(item,'price','Đơn giá','number',null)),miniField('Hao hụt %',input(item,'waste','Hao hụt (%)','number',null)),miniField('Dày mm',input(item,'thickness','Độ dày (mm)','number',null)));
    const link=node('select');link.setAttribute('aria-label','Vật liệu SketchUp được nối');link.append(new Option('(Chưa nối vật liệu SketchUp)',''));
    [...new Set([...names,item.sketchup_material].filter(Boolean))].forEach(n=>link.append(new Option(n,n)));link.value=item.sketchup_material||'';link.onchange=()=>{item.sketchup_material=link.value;save();};
    const more=node('div',undefined,'mt-more');
    more.append(input(item,'manufacturer','Hãng','text',null,'Hãng'),input(item,'product','Sản phẩm','text',null,'Sản phẩm'),input(item,'spec','Quy cách','text',null,'Quy cách'));
    box.append(top,mid,link,more);p.append(box);
  });
  if(!items.length)p.append(node('p','Chưa có vật liệu nào. Bấm Thêm vật liệu.','muted'));
  const add=button('+ Thêm vật liệu',()=>{items.push({name:`Vật liệu ${items.length+1}`,code:'',unit:'m2',waste:0,price:null,thickness:null,manufacturer:'',product:'',spec:'',sketchup_material:''});save();});add.id='mt-add';
  const actions=node('div',undefined,'rename-actions');actions.append(add,button('Đóng',()=>{tableState.panel=null;tableView(tableState.data);}));
  p.append(actions);
  return p;
}
// Quản lý phòng: dữ liệu phòng (tên, mã, tầng, chiều cao, hoàn thiện) và số đo tính từ viền (diện tích, chu vi, thể tích, tường, trần), lưu trong model.
// "Tạo phòng từ mặt đang chọn" chỉ ĐỌC viền của mặt sàn đang chọn trong SketchUp. Ruby kiểm tra lại mọi giá trị.
function roomsPanel(){
  const p=node('div',undefined,'popover right capture-panel rooms-panel');
  const rooms=((tableState.data&&tableState.data.rooms)||[]).map(r=>({...r}));
  const levels=(tableState.data&&tableState.data.levels)||[];
  p.append(node('div','Quản lý phòng','pop-title'));
  const save=()=>call('table_rooms',JSON.stringify({rooms:rooms.map(({metrics,...rest})=>rest)}));
  const fieldInput=(room,key,label,type,width)=>{const i=node('input');i.type=type;i.value=room[key]??'';i.setAttribute('aria-label',label);i.title=label;if(width)i.style.width=width;i.onchange=()=>{room[key]=type==='number'?Number(i.value):i.value;save();};return i;};
  // Tìm, lọc và thu gọn (đợt 1): trạng thái nhớ trong tableState.roomsView, dựng lại bảng vẫn giữ.
  const roomsView=tableState.roomsView||(tableState.roomsView={q:'',level:'',collapsed:new Set(),collapsedLevels:new Set(),group:false,picked:new Set()});
  const levelName=id=>{const l=levels.find(x=>x.id===id);return l?l.name:'Chưa có tầng';};
  // Nhóm theo tầng (đợt 2): phòng của tầng đã xóa hoặc chưa gán tầng nằm chung nhóm "Chưa có tầng".
  const groupKey=room=>levels.some(l=>l.id===room.level)?room.level:'';
  const setGroupCollapsed=(group,flag)=>{const body=group.querySelector('.rm-group-body');const gt=group.querySelector('.rm-group-head .rm-toggle');body.hidden=flag;gt.textContent=flag?'▸':'▾';gt.setAttribute('aria-expanded',String(!flag));flag?roomsView.collapsedLevels.add(group.dataset.key):roomsView.collapsedLevels.delete(group.dataset.key);};
  const allRoomBoxes=()=>[...p.querySelectorAll('.rm-item')];
  const setRoomCollapsed=(box,flag)=>{const body=box.querySelector('.rm-body');const toggle=box.querySelector('.rm-toggle');body.hidden=flag;toggle.textContent=flag?'▸':'▾';toggle.setAttribute('aria-expanded',String(!flag));flag?roomsView.collapsed.add(box.dataset.id):roomsView.collapsed.delete(box.dataset.id);};
  const search=node('input');search.type='search';search.placeholder='Tìm theo tên hoặc mã';search.value=roomsView.q;search.setAttribute('aria-label','Tìm phòng');search.oninput=()=>applyRoomsView();
  const levelFilter=node('select');levelFilter.setAttribute('aria-label','Lọc theo tầng');levelFilter.append(new Option('Tất cả tầng',''),new Option('Chưa có tầng','none'));levels.forEach(l=>levelFilter.append(new Option(l.name,l.id)));levelFilter.value=roomsView.level;levelFilter.onchange=()=>applyRoomsView();
  const countLine=node('p',undefined,'muted rm-count');
  const collapseAll=button(roomsView.collapsed.size?'Mở tất cả':'Thu gọn tất cả',()=>{const collapse=collapseAll.textContent==='Thu gọn tất cả';allRoomBoxes().forEach(box=>setRoomCollapsed(box,collapse));collapseAll.textContent=collapse?'Mở tất cả':'Thu gọn tất cả';});collapseAll.className='rm-collapse-all';
  const groupTick=node('input');groupTick.type='checkbox';groupTick.checked=!!roomsView.group;groupTick.onchange=()=>{roomsView.group=groupTick.checked;tableView(tableState.data);};
  const groupLabel=node('label',undefined,'rm-group-tick');groupLabel.append(groupTick,node('span','Nhóm theo tầng'));
  const viewRow=node('div',undefined,'rm-view');viewRow.append(search,levelFilter,collapseAll,groupLabel);
  p.append(viewRow,countLine);
  // Chọn nhiều phòng và đổi hàng loạt (đợt 3): mọi thay đổi gom vào rooms rồi gửi một lần, Ruby kiểm tra cả danh sách.
  const pickedCount=node('span',undefined,'rm-picked');
  const updatePicked=()=>{const n=rooms.filter(r=>roomsView.picked.has(r.id)).length;pickedCount.textContent=`Đã chọn ${n} phòng`;applyBulk.disabled=!n;};
  const pickShown=button('Chọn tất cả đang hiện',()=>{allRoomBoxes().filter(b=>!b.hidden).forEach(b=>{roomsView.picked.add(b.dataset.id);b.querySelector('.rm-pick input').checked=true;});updatePicked();});
  const clearPick=button('Bỏ chọn',()=>{roomsView.picked.clear();allRoomBoxes().forEach(b=>{b.querySelector('.rm-pick input').checked=false;});updatePicked();});clearPick.className='rm-bulk-clear';
  const levelPick=node('select');levelPick.className='rm-bulk-level';levelPick.setAttribute('aria-label','Tầng cho phòng đã chọn');levelPick.append(new Option('Giữ nguyên tầng','keep'),new Option('(Không có tầng)',''));levels.forEach(l=>levelPick.append(new Option(l.name,l.id)));
  const heightPick=node('input');heightPick.type='number';heightPick.min='1';heightPick.className='rm-bulk-height';heightPick.placeholder='Cao (mm)';heightPick.setAttribute('aria-label','Chiều cao cho phòng đã chọn (mm)');
  const finishKeys=['finish_floor','finish_wall','finish_ceiling'];
  const finishPicks=[['rm-bulk-finish-floor','Sàn'],['rm-bulk-finish-wall','Tường'],['rm-bulk-finish-ceiling','Trần']].map(([cls,t])=>{const i=node('input');i.type='text';i.maxLength=60;i.className=cls;i.placeholder=t+' (giữ nguyên)';i.setAttribute('aria-label','Hoàn thiện '+t.toLowerCase()+' cho phòng đã chọn');return i;});
  const applyBulk=button('Áp dụng cho phòng đã chọn',()=>{
    const targets=rooms.filter(r=>roomsView.picked.has(r.id));
    if(!targets.length)throw Error('Hãy chọn ít nhất một phòng.');
    targets.forEach(room=>{
      if(levelPick.value!=='keep'){room.level=levelPick.value;if(!room.level)room.elevation_source='manual';}
      if(heightPick.value!=='')room.height=Number(heightPick.value);
      finishPicks.forEach((input,i)=>{if(input.value!=='')room[finishKeys[i]]=input.value;});
    });
    save();
  });applyBulk.className='rm-bulk-apply';
  // Gợi ý mã (đợt 4): chỉ điền phòng đã chọn còn trống mã; mã dạng tiền tố-T<tầng>-số (tầng không có thì bỏ phần T), không trùng mã có sẵn.
  const codePrefix=node('input');codePrefix.type='text';codePrefix.maxLength=20;codePrefix.className='rm-code-prefix';codePrefix.placeholder='Tiền tố mã (vd WC)';codePrefix.setAttribute('aria-label','Tiền tố mã gợi ý');
  const suggestCodes=button('Gợi ý mã cho phòng đã chọn',()=>{
    const prefix=codePrefix.value.trim();
    if(!roomsView.picked.size)throw Error('Hãy chọn ít nhất một phòng.');
    if(!prefix)throw Error('Hãy nhập tiền tố mã (vd WC).');
    const targets=rooms.filter(r=>roomsView.picked.has(r.id)&&!String(r.number||'').trim());
    if(!targets.length)throw Error('Các phòng đã chọn đều đã có mã.');
    const taken=new Set(rooms.map(r=>String(r.number||'').trim().toLowerCase()).filter(Boolean));
    const nextSeq=new Map();
    targets.forEach(room=>{
      const level=levels.find(l=>l.id===room.level);
      const digits=level?(level.name.match(/\d+/)||[])[0]:undefined;
      const base=`${prefix}${level?`-T${digits||levels.indexOf(level)+1}`:''}`;
      let seq=nextSeq.get(base)||1,code;
      do{code=`${base}-${String(seq).padStart(2,'0')}`;seq++;}while(taken.has(code.toLowerCase()));
      nextSeq.set(base,seq);taken.add(code.toLowerCase());room.number=code;
    });
    save();
  });suggestCodes.className='rm-code-suggest';
  const bulkRow=node('div',undefined,'rm-bulk');bulkRow.append(pickedCount,pickShown,clearPick,levelPick,heightPick,...finishPicks,codePrefix,suggestCodes,applyBulk);
  p.append(bulkRow);
  updatePicked();
  // Cần kiểm tra (đợt 5): phòng thiếu tầng hoặc thiếu mã; bấm một dòng để mở đúng phòng. Phòng chưa dựng khối chỉ đếm, không liệt kê.
  const issues=rooms.flatMap(room=>{
    const list=[];
    if(!room.level)list.push('thiếu tầng');
    if(!String(room.number||'').trim())list.push('thiếu mã');
    return list.length?[{room,list}]:[];
  });
  const noVolume=rooms.filter(room=>!room.has_volume).length;
  if(issues.length||noVolume){
    const issueBox=node('div',undefined,'rm-issues');
    if(issues.length)issueBox.append(node('div',`Cần kiểm tra (${issues.length} phòng)`,'rm-issues-title'));
    issues.forEach(({room,list})=>{
      const item=button(`${room.name} — ${list.join(', ')}`,()=>goToRoom(room.id));item.className='rm-issue';
      issueBox.append(item);
    });
    if(noVolume)issueBox.append(node('p',`${noVolume} phòng chưa dựng khối 3D.`,'muted rm-issues-note'));
    p.append(issueBox);
  }
  const goToRoom=id=>{
    const box=allRoomBoxes().find(b=>b.dataset.id===id);
    if(!box)return;
    roomsView.q='';search.value='';roomsView.level='';levelFilter.value='';
    applyRoomsView();
    const group=box.closest('.rm-group');
    if(group&&group.querySelector('.rm-group-body').hidden)setGroupCollapsed(group,false);
    setRoomCollapsed(box,false);
    box.scrollIntoView({block:'center'});
    box.querySelector('.rm-name').focus();
  };
  const hosts=new Map();
  if(roomsView.group){
    [...levels.map(l=>({key:l.id,title:l.name})),{key:'',title:'Chưa có tầng'}].forEach(({key,title})=>{
      const count=rooms.filter(r=>groupKey(r)===key).length;
      if(!count)return;
      const group=node('div',undefined,'rm-group');group.dataset.key=key;
      const gt=button('▾',()=>setGroupCollapsed(group,!body.hidden));gt.className='rm-toggle';gt.setAttribute('aria-label','Mở hoặc thu gọn nhóm '+title);
      const head=node('div',undefined,'rm-group-head');head.append(gt,node('span',`${title} · ${count} phòng`,'rm-group-title'));
      const body=node('div',undefined,'rm-group-body');
      group.append(head,body);p.append(group);setGroupCollapsed(group,roomsView.collapsedLevels.has(key));
      hosts.set(key,body);
    });
  }
  const applyRoomsView=()=>{
    roomsView.q=search.value;roomsView.level=levelFilter.value;
    const q=foldText(search.value.trim());
    let shown=0;
    allRoomBoxes().forEach(box=>{
      const room=rooms.find(r=>r.id===box.dataset.id);
      const byText=!q||foldText(`${room.name} ${room.number||''}`).includes(q);
      const byLevel=!levelFilter.value||(levelFilter.value==='none'?!room.level:room.level===levelFilter.value);
      box.hidden=!(byText&&byLevel);
      if(!box.hidden)shown++;
    });
    p.querySelectorAll('.rm-group').forEach(group=>{group.hidden=![...group.querySelectorAll('.rm-item')].some(box=>!box.hidden);});
    countLine.textContent=`Hiển thị ${shown} / ${rooms.length} phòng.`;
  };
  rooms.forEach(room=>{
    const box=node('div',undefined,'rm-item');box.dataset.id=room.id;
    const top=node('div',undefined,'rm-top');
    const name=fieldInput(room,'name','Tên phòng','text');name.className='rm-name';name.maxLength=60;
    const number=fieldInput(room,'number','Mã phòng','text');number.className='rm-number';number.maxLength=60;number.placeholder='Mã';
    const del=button('×',()=>{rooms.splice(rooms.indexOf(room),1);save();},'cs-del');del.title='Xóa phòng này (món đã gán chỉ hiện "phòng đã xóa", không mất dữ liệu khác)';del.setAttribute('aria-label','Xóa phòng '+room.name);
    top.append(name,number,del);
    const mid=node('div',undefined,'rm-mid');
    const lv=node('select');lv.setAttribute('aria-label','Tầng của phòng');lv.append(new Option('(Không có tầng)',''));levels.forEach(l=>lv.append(new Option(l.name,l.id)));lv.value=room.level||'';
    // Cao độ sàn theo tầng của phòng; chỉ phòng hạ nền khác mới nhập tay. Phòng không có tầng thì phải nhập tay.
    const manual=room.elevation_source==='manual'||!room.level;
    const hand=node('input');hand.type='checkbox';hand.checked=manual;hand.disabled=!room.level;hand.setAttribute('aria-label','Hạ nền khác (nhập tay cao độ sàn)');
    hand.title=room.level?'Bật nếu phòng hạ nền khác với tầng: khi đó nhập cao độ sàn tay':'Phòng chưa có tầng: nhập cao độ sàn tay';
    hand.onchange=()=>{room.elevation_source=hand.checked?'manual':'level';elev.disabled=!hand.checked;save();}; // đổi ngay trên màn hình, không chờ Ruby
    lv.onchange=()=>{room.level=lv.value;if(!room.level){room.elevation_source='manual';hand.checked=true;hand.disabled=true;elev.disabled=false;}else{hand.disabled=false;}save();};
    const elev=fieldInput(room,'elevation','Cao độ sàn (mm)','number');elev.disabled=!manual;elev.title=manual?'Cao độ sàn nhập tay':'Theo cao độ của tầng; bật Hạ nền khác để nhập tay';
    const handLabel=node('label',undefined,'rm-hand');handLabel.append(hand,node('span','Hạ nền khác'));
    mid.append(miniField('Tầng',lv),miniField('Cao mm',fieldInput(room,'height','Chiều cao phòng (mm)','number')),miniField('Cao độ sàn',elev),handLabel);
    const fin=node('div',undefined,'rm-fin');
    [['finish_floor','Sàn'],['finish_wall','Tường'],['finish_ceiling','Trần']].forEach(([k,t])=>{const i=fieldInput(room,k,'Hoàn thiện '+t.toLowerCase(),'text');i.placeholder='Hoàn thiện '+t.toLowerCase();i.maxLength=60;fin.append(i);});
    const m=room.metrics||{};
    const build=button(room.has_volume?'Dựng lại khối':'Dựng khối',()=>call('table_room_build',JSON.stringify({id:room.id})));build.className='rm-build';
    build.title='Dựng (hoặc dựng lại) khối 3D của phòng: một khối trên tag VGD_ROOMS, một bước hoàn tác.';
    const upd=button('Cập nhật viền từ mặt đang chọn',()=>call('table_room_update_boundary',JSON.stringify({id:room.id})));upd.className='rm-update';
    upd.title='Thay viền phòng bằng đúng một mặt sàn đang chọn trong SketchUp. Tên, mã, tầng, chiều cao, hoàn thiện giữ nguyên; cao độ sàn chỉ đổi theo mặt với phòng hạ nền (nhập tay).';
    const body=node('div',undefined,'rm-body');body.append(top,mid,fin,node('p',`Sàn ${m.area} m² · Chu vi ${m.perimeter} m · Thể tích ${m.volume} m³ · Tường (chưa trừ cửa) ${m.wall_area} m² · Trần ${m.ceiling_area} m²`+(room.holes&&room.holes.length?` · ${room.holes.length} lỗ (cột, hộp kỹ thuật)`:''),'muted rm-metrics'),build,upd);
    const toggle=button('▾',()=>setRoomCollapsed(box,!body.hidden));toggle.className='rm-toggle';toggle.setAttribute('aria-label','Mở hoặc thu gọn phòng '+room.name);
    const pick=node('input');pick.type='checkbox';pick.checked=roomsView.picked.has(room.id);pick.setAttribute('aria-label','Chọn phòng '+room.name);
    pick.onchange=()=>{pick.checked?roomsView.picked.add(room.id):roomsView.picked.delete(room.id);updatePicked();};
    const pickWrap=node('label',undefined,'rm-pick');pickWrap.append(pick);
    const head=node('div',undefined,'rm-head');head.append(pickWrap,toggle,node('span',`${room.name} · ${room.number||'—'} · ${levelName(room.level)} · ${m.area??0} m²`,'rm-summary'));
    box.append(head,body);
    (hosts.get(groupKey(room))||p).append(box);
    setRoomCollapsed(box,roomsView.collapsed.has(room.id));
  });
  if(!rooms.length)p.append(node('p','Chưa có phòng nào. Chọn một hoặc nhiều mặt sàn trong SketchUp rồi bấm Tạo phòng từ các mặt đang chọn.','muted'));
  const newName=node('input');newName.type='text';newName.placeholder='Tên phòng mới (nhiều mặt: tiền tố, vd Phòng)';newName.maxLength=60;newName.setAttribute('aria-label','Tên phòng mới');
  const newNumber=node('input');newNumber.type='text';newNumber.placeholder='Mã';newNumber.maxLength=60;newNumber.setAttribute('aria-label','Mã phòng mới');
  const newLevel=node('select');newLevel.setAttribute('aria-label','Tầng của phòng mới');newLevel.append(new Option('(Không có tầng)',''));levels.forEach(l=>newLevel.append(new Option(l.name,l.id)));
  const create=node('div',undefined,'rm-new');create.append(newName,newNumber,newLevel);
  const make=button('Tạo phòng từ các mặt đang chọn',()=>call('table_room_from_selection',JSON.stringify({name:newName.value,number:newNumber.value,level:newLevel.value})),'primary');make.id='rm-make';
  make.title='Đọc viền (và các lỗ, vd cột) của các mặt sàn nằm ngang đang chọn trong SketchUp, mỗi mặt thành một phòng. Một mặt: tên và mã như đã nhập. Nhiều mặt: tên là tiền tố (Phòng 1, Phòng 2...), không đặt mã. Chỉ lưu dữ liệu, không dựng hình.';
  const picked=tableState.displayed.filter(r=>r.members.some(m=>tableState.sel.has(m)));
  const auto=button('Gán món vào phòng theo vị trí',()=>{
    if(!selectedIndexes().length)throw Error('Hãy chọn các dòng cần gán phòng (Ctrl+A chọn hết các dòng đang hiện).');
    call('table_assign_rooms_auto',JSON.stringify({indexes:selectedIndexes()}));
  });auto.id='rm-auto';auto.title='Mỗi món nhận phòng chứa tâm đáy của nó (trong viền và trong khoảng cao của phòng). Chỉ là nhãn, không dời hình.';
  const buildAll=button(`Dựng khối tất cả phòng${rooms.length?` (${rooms.length})`:''}`,()=>call('table_room_build_all',JSON.stringify({})));buildAll.id='rm-build-all';
  buildAll.disabled=!rooms.length;buildAll.title='Dựng (hoặc dựng lại) khối 3D của mọi phòng, một bước hoàn tác cho cả đợt.';
  const actions=node('div',undefined,'rename-actions');actions.append(make,buildAll,auto,button('Đóng',()=>{tableState.panel=null;tableView(tableState.data);}));
  p.append(create,node('p',picked.length?`${picked.length} dòng đang chọn.`:'Chọn dòng để gán phòng theo vị trí; hoặc nhấp đúp ô Phòng để gán tay.','muted'),actions);
  applyRoomsView();
  return p;
}
// Quản lý tầng: tên, cao độ sàn và chiều cao (mm) của từng tầng, lưu trong model (chỉ nhãn, không dời hình học); gán tầng theo cao độ cho các dòng đang chọn.
// Ô tầng trong bảng nhấp đúp để gán tay. Ruby kiểm tra lại mọi giá trị.
// Ô số có nhãn ngắn ở trên (thay cho placeholder bị cắt chữ trong ô hẹp).
const miniField=(text,input)=>{const box=node('label',undefined,'f-mini');box.append(node('span',text),input);return box;};
function levelsPanel(){
  const p=node('div',undefined,'popover right capture-panel levels-panel');
  const levels=(tableState.data&&tableState.data.levels)||[];
  p.append(node('div','Quản lý tầng','pop-title'));
  const rows=node('div',undefined,'lv-rows');
  const collect=()=>[...rows.querySelectorAll('.lv-row')].map(r=>{const o={name:r.querySelector('.lv-name').value,elevation:Number(r.querySelector('.lv-elev').value),height:Number(r.querySelector('.lv-height').value)};if(r.dataset.id)o.id=r.dataset.id;return o;});
  const save=()=>call('table_levels',JSON.stringify({levels:collect()}));
  const addRow=level=>{
    const r=node('div',undefined,'lv-row');if(level.id)r.dataset.id=level.id;
    const input=(cls,value,label,type)=>{const i=node('input',undefined,cls);i.type=type;i.value=value;i.setAttribute('aria-label',label);i.onchange=save;return i;};
    const name=input('lv-name',level.name,'Tên tầng','text');name.maxLength=60;
    const del=button('×',()=>{r.remove();save();},'cs-del');del.title='Xóa tầng này (món đã gán chỉ hiện "tầng đã xóa", không mất dữ liệu khác)';del.setAttribute('aria-label','Xóa tầng '+level.name);
    r.append(name,input('lv-elev',level.elevation,'Cao độ sàn (mm)','number'),input('lv-height',level.height,'Chiều cao tầng (mm)','number'),del);rows.append(r);
  };
  if(levels.length){const head=node('div',undefined,'lv-row lv-head');head.append(node('span','Tên'),node('span','Cao độ (mm)'),node('span','Cao (mm)'),node('span'));p.append(head);}
  levels.forEach(addRow);p.append(rows);
  if(!levels.length)p.append(node('p','Chưa có tầng nào. Bấm Thêm tầng.','muted'));
  const add=button('+ Thêm tầng',()=>{
    const last=levels[levels.length-1];
    const next={name:`Tầng ${levels.length+1}`,elevation:last?Math.round((last.elevation+last.height)*10)/10:0,height:last?last.height:3300};
    call('table_levels',JSON.stringify({levels:[...collect(),next]}));
  });add.id='lv-add';
  const picked=tableState.displayed.filter(r=>r.members.some(m=>tableState.sel.has(m)));
  const auto=button('Gán tầng theo cao độ cho món đang chọn',()=>{
    if(!selectedIndexes().length)throw Error('Hãy chọn các dòng cần gán tầng (Ctrl+A chọn hết các dòng đang hiện).');
    call('table_assign_levels_auto',JSON.stringify({indexes:selectedIndexes()}));
  },'primary');auto.id='lv-auto';auto.title='Mỗi món nhận tầng cao nhất có cao độ sàn bằng hoặc thấp hơn đáy món (dung sai 50 mm). Chỉ là nhãn, không dời hình.';
  const actions=node('div',undefined,'rename-actions');actions.append(add,auto,button('Đóng',()=>{tableState.panel=null;tableView(tableState.data);}));
  p.append(node('p',picked.length?`${picked.length} dòng đang chọn.`:'Chọn dòng để gán tầng theo cao độ; hoặc nhấp đúp ô Tầng để gán tay.','muted'),actions);
  return p;
}
const SNAPSHOT_FIELDS={name:'Tên',code:'Mã',level:'Tầng',room:'Phòng',material:'Vật liệu',lenX:'Rộng',lenY:'Sâu',lenZ:'Cao',calc_qty:'Khối lượng tính'};
function snapshotsPanel(){
  const p=node('div',undefined,'popover right capture-panel snapshots-panel');
  const list=tableState.snapshots||[];
  p.append(node('div','So sánh phiên bản','pop-title'),node('p','Chụp mốc để nhớ giá trị của các món ở thời điểm này, sau đó so với bảng hiện tại để biết món nào thêm, xóa hoặc đổi. Mốc lưu trong file SketchUp (tối đa 5 mốc), chỉ đọc bảng.','muted'));
  const name=node('input',undefined,'sn-name');name.type='text';name.maxLength=60;name.placeholder='Tên mốc (ví dụ Bản gửi khách 12/11)';name.setAttribute('aria-label','Tên mốc');
  const take=button('Chụp mốc hiện tại',()=>{if(!name.value.trim())throw Error('Hãy nhập tên mốc.');call('snapshot_save',JSON.stringify({name:name.value}));},'primary');take.id='sn-take';
  const bar=node('div',undefined,'sn-bar');bar.append(name,take);p.append(bar);
  const rows=node('div',undefined,'sn-list');
  list.forEach(snap=>{
    const r=node('div',undefined,'sn-item');
    const del=button('×',()=>call('snapshot_delete',JSON.stringify({id:snap.id})),'cs-del');del.title='Xóa mốc này';del.setAttribute('aria-label','Xóa mốc '+snap.name);
    r.append(node('span',snap.name,'sn-title'),node('span',`${String(snap.created||'').slice(0,16).replace('T',' ')} · ${snap.count} món`,'muted'),button('So sánh',()=>call('snapshot_compare',JSON.stringify({id:snap.id}))),del);
    rows.append(r);
  });
  p.append(rows);
  if(!list.length)p.append(node('p','Chưa có mốc nào. Nhập tên rồi bấm Chụp mốc hiện tại.','muted'));
  const diff=tableState.snapshotDiff;
  if(diff){
    const sum=node('p',`So với mốc ${diff.name}: ${diff.added.length} món mới, ${diff.removed.length} món không còn, ${diff.changed.length} món đổi, ${diff.unchanged} món giữ nguyên.`,'muted');sum.id='sn-summary';p.append(sum);
    const out=node('div',undefined,'sn-results');
    const line=(tag,label,text,index)=>{const row=node('div',undefined,'sn-result'+(index!==undefined?' clickable':''));row.append(node('span',tag,'badge '+(tag==='Mới'?'':tag==='Không còn'?'error':'warning')),node('span',label),node('span',text,'muted'));if(index!==undefined){row.tabIndex=0;row.onclick=()=>{tableState.sel=new Set([index]);call('table_select',JSON.stringify({indexes:[index],field:''}));};row.onkeydown=e=>{if(e.key==='Enter')row.click();};}out.append(row);};
    diff.added.forEach(a=>line('Mới',a.name,'',a.index));
    diff.changed.forEach(c=>line('Thay đổi',c.name,c.diffs.map(d=>`${SNAPSHOT_FIELDS[d.field]||d.field}: ${d.old===null||d.old===''?'—':d.old} → ${d.new===null||d.new===''?'—':d.new}`).join('; '),c.index));
    diff.removed.forEach(r=>line('Không còn',r.name,''));
    p.append(out);
  }
  p.append((()=>{const a=node('div',undefined,'rename-actions');a.append(button('Đóng',()=>{tableState.panel=null;tableView(tableState.data);}));return a;})());
  return p;
}
const CHECK_OPS=[['lt','nhỏ hơn'],['lte','nhỏ hơn hoặc bằng'],['gt','lớn hơn'],['gte','lớn hơn hoặc bằng'],['eq','bằng'],['neq','khác'],['contains','chứa'],['empty','để trống'],['not_empty','không để trống']];
const CHECK_SEVERITIES=[['INFO','Thông tin'],['WARNING','Cảnh báo'],['ERROR','Lỗi']];
function checksPanel(){
  const p=node('div',undefined,'popover right capture-panel checks-panel');
  const rules=(tableState.data&&tableState.data.check_rules)||[];
  const columns=((tableState.data&&tableState.data.columns)||[]).filter(c=>!['image','image_location','image_extra1','image_extra2'].includes(c.kind));
  p.append(node('div','Luật kiểm tra','pop-title'),node('p','Mỗi luật kiểm tra một cột của bảng (số đo tính bằng mm). Luật lưu trong file SketchUp, chỉ đọc bảng, không đổi gì trong model.','muted'));
  const rows=node('div',undefined,'ck-rows');
  const collect=()=>[...rows.querySelectorAll('.ck-item')].map(r=>{const o={name:r.querySelector('.ck-name').value,column:r.querySelector('.ck-col').value,op:r.querySelector('.ck-op').value,value:r.querySelector('.ck-val').value,group:r.querySelector('.ck-group').value,severity:r.querySelector('.ck-sev').value,message:r.querySelector('.ck-msg').value};if(r.dataset.id)o.id=r.dataset.id;return o;});
  const save=()=>call('check_rules_save',JSON.stringify({rules:collect()}));
  const select=(cls,options,value,label)=>{const s=node('select',undefined,cls);options.forEach(([v,t])=>s.append(new Option(t,v)));s.value=value;s.setAttribute('aria-label',label);s.onchange=save;return s;};
  const input=(cls,value,label,max)=>{const i=node('input',undefined,cls);i.type='text';i.value=value;i.maxLength=max;i.setAttribute('aria-label',label);i.onchange=save;return i;};
  const addRule=rule=>{
    const r=node('div',undefined,'ck-item');if(rule.id)r.dataset.id=rule.id;
    const val=input('ck-val',rule.value||'','Giá trị so sánh',80);
    const op=select('ck-op',CHECK_OPS,rule.op,'Phép so sánh');
    const sync=()=>{val.hidden=['empty','not_empty'].includes(op.value);};op.addEventListener('change',sync);sync();
    const del=button('×',()=>{r.remove();save();},'cs-del');del.title='Xóa luật này';del.setAttribute('aria-label','Xóa luật '+rule.name);
    const top=node('div',undefined,'ck-top');top.append(input('ck-name',rule.name,'Tên luật',60),del);
    const mid=node('div',undefined,'ck-mid');const group=select('ck-group',[['','Tất cả nhóm'],...(tableState.data.groups||[]).map(g=>[g,g])],rule.group||'','Nhóm hạng mục');mid.append(select('ck-col',columns.map(c=>[c.key,c.label]),rule.column,'Cột'),op,val,group);
    const low=node('div',undefined,'ck-low');low.append(select('ck-sev',CHECK_SEVERITIES,rule.severity,'Mức độ'),input('ck-msg',rule.message||'','Lời nhắn (để trống thì dùng tên luật)',120));
    r.append(top,mid,low);rows.append(r);
  };
  rules.forEach(addRule);p.append(rows);
  if(!rules.length)p.append(node('p','Chưa có luật nào. Bấm Thêm luật.','muted'));
  const add=button('+ Thêm luật',()=>{
    const first=columns.find(c=>c.kind==='number')||columns[0];
    if(!first)throw Error('Bảng chưa có cột nào để kiểm tra.');
    call('check_rules_save',JSON.stringify({rules:[...collect(),{name:`Luật ${rules.length+1}`,column:first.key,op:'lt',value:'0',group:'',severity:'WARNING',message:''}]}));
  });add.id='ck-add';
  const run=button('Chạy kiểm tra',()=>call('check_rules_run'),'primary');run.id='ck-run';
  const actions=node('div',undefined,'rename-actions');actions.append(add,run,button('Đóng',()=>{tableState.panel=null;tableView(tableState.data);}));
  p.append(actions);
  const result=tableState.checkResults;
  if(result){
    const found=result.results||[];
    const sum=node('p',found.length?`${found.length} vi phạm trên ${result.rows} dòng (${result.rules} luật).${result.truncated?' Chỉ hiện một phần.':''} Bấm vào dòng để chọn món trong bảng.`:`Không có vi phạm nào (${result.rows} dòng, ${result.rules} luật).`,'muted');sum.id='ck-summary';p.append(sum);
    const list=node('div',undefined,'ck-results');
    found.forEach(f=>{
      const row=node('div',undefined,'ck-result clickable');row.tabIndex=0;
      const who=(tableState.data.rows||[]).find(r=>r.index===f.index);
      row.append(badge(f.severity),node('span',f.message),node('span',who?(who.name||who.definition||''):'','muted'));
      row.onclick=()=>{tableState.sel=new Set([f.index]);call('table_select',JSON.stringify({indexes:[f.index],field:''}));};
      row.onkeydown=e=>{if(e.key==='Enter')row.click();};
      list.append(row);
    });
    p.append(list);
  }
  return p;
}
function capturePanel(){
  const p=node('div',undefined,'popover right capture-panel');
  const targets=captureTargets(),chosen=tableState.sel.size>0;
  p.append(node('div','Cập nhật ảnh','pop-title'));
  p.append(node('p',chosen?`Chụp ảnh cho ${targets.length} đối tượng đang chọn?`:`Chụp ảnh cho tất cả ${targets.length} đối tượng đang hiện?`,'rename-scope'));
  const only=node('input');only.type='checkbox';only.checked=imagesState.only;only.id='cap-only';only.onchange=()=>{imagesState.only=only.checked;};
  const onlyLabel=node('label',undefined,'merge-opt');onlyLabel.append(only,document.createTextNode(' Chỉ chụp đối tượng chưa có ảnh'));
  const s=workSettings();
  p.append(onlyLabel,node('p',`Cỡ ${s.image_width} x ${s.image_height}, ${VIEW_LABELS[s.image_view]||s.image_view}. Đổi trong bảng preset.`,'muted'));
  const actions=node('div',undefined,'rename-actions');
  const place=node('div',undefined,'cap-place');
  place.append(node('span','Ảnh vị trí','muted'),button('◣ Trái',()=>{tableState.panel=null;runCapture(targets,imagesState.only,'left','location');tableView(tableState.data);}),button('◢ Phải',()=>{tableState.panel=null;runCapture(targets,imagesState.only,'right','location');tableView(tableState.data);}),button('● Theo preset',()=>{tableState.panel=null;runCapture(targets,imagesState.only,undefined,'location');tableView(tableState.data);}),button('Xem trước',()=>{tableState.panel=null;tableView(tableState.data);runPreview(targets,imagesState.only,undefined,'location');}));
  place.title='Chụp cảnh quanh món (không cô lập), lưu vào cột Ảnh vị trí: Trái / Phải chụp Iso một lần từ bên đó, Theo preset chụp đúng thiết lập ảnh vị trí của preset (góc nhìn, góc lệch, cỡ ảnh...)';
  actions.append(button('Chụp',()=>{tableState.panel=null;runCapture(targets,imagesState.only);tableView(tableState.data);},'primary'),button('Xem trước',()=>{tableState.panel=null;tableView(tableState.data);runPreview(targets,imagesState.only);}),button('Hủy',()=>{tableState.panel=null;tableView(tableState.data);}));
  const extraRows=[['extra1','Ảnh 3'],['extra2','Ảnh 4']].map(([kind,label])=>{
    const row=node('div',undefined,'cap-place');
    row.append(node('span',label,'muted'),button('● Theo preset',()=>{tableState.panel=null;runCapture(targets,imagesState.only,undefined,kind);tableView(tableState.data);}),button('Xem trước',()=>{tableState.panel=null;tableView(tableState.data);runPreview(targets,imagesState.only,undefined,kind);}));
    row.title='Chụp thêm góc khác của món (cô lập như ảnh chính), lưu vào cột '+label+' theo thiết lập '+label+' của preset (góc nhìn, góc lệch, cỡ ảnh...)';
    return row;
  });
  // Ảnh vị trí, Ảnh 3, Ảnh 4 ít dùng hơn ảnh chính: gập sẵn trong "Ảnh khác", bấm để sổ ra (nhớ trạng thái trong phiên).
  const more=node('details',undefined,'cap-more');more.open=!!imagesState.moreOpen;
  more.addEventListener('toggle',()=>{imagesState.moreOpen=more.open;});
  more.append(node('summary','Ảnh khác (vị trí, ảnh 3, ảnh 4)'),place,...extraRows);
  p.append(actions,more);
  return p;
}
// ---- Ngăn Chọn cột: trượt ra bên trái và đẩy bảng sang phải (cột đầu không bị che), gọn theo kiểu Auto Info ----
const SIDE_MS=220;
// Sau khi đổi cột hiện / thứ tự: vẽ lại bảng (giữ vị trí cuộn), lưu, cập nhật số đếm; không dựng lại cả khung bảng.
function refreshColumns(){
  const host=$('grid-host');if(!host||!tableState.data)return;
  const old=host.querySelector('.grid-wrap');const scroll=old?{top:old.scrollTop,left:old.scrollLeft}:null;
  renderGrid(host);
  const wrap=host.querySelector('.grid-wrap');if(scroll&&wrap){wrap.scrollTop=scroll.top;wrap.scrollLeft=scroll.left;}
  syncCustomPreset();persistView();updateReplaceUi();updateColumnCounts();
}
function updateColumnCounts(){
  const side=$('col-side');if(!side)return;
  const total=tableState.data.columns.length,n=tableState.visible.size;
  const badge=side.querySelector('.badge'),all=side.querySelector('.cs-all input'),label=side.querySelector('.cs-all .cs-all-text');
  if(badge)badge.textContent=`${n} / ${total}`;
  if(all)all.checked=n===total;
  if(label)label.textContent=n===total?'Bỏ chọn tất cả':'Chọn tất cả';
}
// Hiệu ứng đổi chỗ (FLIP): ghi vị trí cũ, đổi DOM, rồi cho từng mục trượt từ vị trí cũ về vị trí mới.
function flipList(list,mutate){
  const before=new Map([...list.children].map(el=>[el,el.getBoundingClientRect().top]));
  mutate();
  [...list.children].forEach(el=>{
    const dy=before.get(el)-el.getBoundingClientRect().top;
    if(!dy)return;
    el.style.transition='none';el.style.transform=`translateY(${dy}px)`;
    void el.offsetHeight;
    el.style.transition=`transform ${SIDE_MS-70}ms ease`;el.style.transform='';
    const clean=()=>{el.style.transition='';el.removeEventListener('transitionend',clean);};
    el.addEventListener('transitionend',clean);
  });
}
// Đặt các khoá đang hiện (đã lọc) theo thứ tự mới vào đúng các vị trí chúng đang chiếm trong thứ tự đầy đủ.
function applyListOrder(keys){
  const slots=[];tableState.order.forEach((k,i)=>{if(keys.includes(k))slots.push(i);});
  const order=[...tableState.order];slots.forEach((slot,n)=>{order[slot]=keys[n];});
  tableState.order=order;
}
function sortableList(list){
  let dragging=null;
  list.querySelectorAll('.pop-col').forEach(item=>{
    item.draggable=true;
    item.ondragstart=e=>{dragging=item;item.classList.add('dragging');e.dataTransfer.effectAllowed='move';e.dataTransfer.setData('text/plain',item.dataset.key);};
    item.ondragend=()=>{
      item.classList.remove('dragging');dragging=null;
      const keys=[...list.children].map(el=>el.dataset.key);
      const before=tableState.order.filter(k=>keys.includes(k));
      if(keys.some((k,i)=>k!==before[i])){applyListOrder(keys);refreshColumns();}
    };
    item.ondragover=e=>{
      e.preventDefault();if(!dragging||dragging===item)return;
      const box=item.getBoundingClientRect(),after=e.clientY>box.top+box.height/2;
      const target=after?item.nextElementSibling:item;
      if(target===dragging||dragging.nextElementSibling===target)return;
      flipList(list,()=>list.insertBefore(dragging,target));
    };
  });
}
function renderColumnList(list){
  const q=foldText(tableState.colSearch.trim());
  list.replaceChildren();
  tableState.order.forEach(key=>{
    const col=colByKey(key);if(!col)return;
    // Danh sách chọn cột luôn ghi tên chuẩn của cột; tiêu đề riêng của preset (nếu có) chỉ ghi chú thêm, để hai cột không trông trùng tên.
    const standard=withUnit(col.label),custom=tableState.headers&&tableState.headers[col.key];
    const alias=custom&&custom!==standard?custom:'';
    if(q&&!foldText(`${standard} ${alias}`).includes(q))return;
    const item=node('div',undefined,'pop-col');item.dataset.key=key;
    const box=node('input',undefined,'cb');box.type='checkbox';box.checked=tableState.visible.has(key);
    box.onchange=()=>{if(box.checked)tableState.visible.add(key);else tableState.visible.delete(key);if(box.checked&&key==='areaProjected')ensureProjected();refreshColumns();};
    const label=node('label');label.append(box,node('span',standard,'cs-name'));
    if(alias)label.append(node('span',`hiện trong bảng: ${alias}`,'cs-alias'));
    const grip=node('span','⠿','drag');grip.setAttribute('aria-hidden','true');
    item.append(label);
    if(col.custom){ // cột thêm tay: xóa được (chỉ bỏ cột khỏi bảng, dữ liệu đã nhập trong các món vẫn còn)
      const del=button('×',()=>call('table_custom_column',JSON.stringify({action:'remove',key})),'cs-del');
      del.title='Xóa cột này (dữ liệu đã nhập trong các món vẫn còn)';del.setAttribute('aria-label','Xóa cột '+standard);item.append(del);
    }
    item.append(grip);list.append(item);
  });
  sortableList(list);
}
// Mép phải của ngăn bên: kéo để đổi độ rộng, dùng chung cho Chọn cột và Loại trừ tag, chỉ nhớ trong lúc ngăn còn mở (mở lại về 230 px).
const SIDE_MIN=180;
function sideGrip(side){
  const grip=node('div',undefined,'cs-grip');grip.title='Kéo để đổi độ rộng';
  grip.onmousedown=event=>{
    event.preventDefault();event.stopPropagation();
    const startX=event.clientX,startW=side.firstElementChild.offsetWidth,room=side.parentElement.clientWidth;
    const max=Math.max(SIDE_MIN,room-300); // chừa chỗ cho bảng
    side.classList.add('resizing');
    const move=e=>side.style.setProperty('--side-w',Math.round(Math.min(max,Math.max(SIDE_MIN,startW+e.clientX-startX)))+'px');
    const up=()=>{document.removeEventListener('mousemove',move);document.removeEventListener('mouseup',up);side.classList.remove('resizing');};
    document.addEventListener('mousemove',move);document.addEventListener('mouseup',up);
  };
  return grip;
}
// Form thêm cột thủ công (theo AutoInfo): kiểu cột, tên cột, và dictionary + tên thuộc tính khi đọc thuộc tính của món. Ruby kiểm tra lại mọi giá trị.
function customColumnForm(host){
  host.replaceChildren();
  const form=node('div',undefined,'cc-form');
  const kind=node('select');kind.setAttribute('aria-label','Kiểu cột');
  [['attribute','Thuộc tính tùy chọn'],['dynamic','Thuộc tính động (Dynamic Components)'],['text','Cột tự nhập']].forEach(([value,text])=>kind.append(new Option(text,value)));
  const field=(label,hint)=>{const wrap=node('label',undefined,'cc-field');const input=node('input');input.type='text';input.maxLength=80;input.placeholder=hint;input.setAttribute('aria-label',label);wrap.append(node('span',label),input);return {wrap,input};};
  const name=field('Tên cột','Ví dụ: Mã vật tư'),dict=field('Tên dictionary','Ví dụ: vgd'),attr=field('Tên thuộc tính','Ví dụ: ma_vat_tu');
  const sync=()=>{dict.wrap.hidden=kind.value!=='attribute';attr.wrap.hidden=kind.value==='text';attr.input.placeholder=kind.value==='dynamic'?'Ví dụ: price':'Ví dụ: ma_vat_tu';};
  kind.onchange=sync;sync();
  const need=(input,text)=>{if(!input.value.trim()){input.focus();throw Error(text);}};
  const submit=button('Thêm',()=>{
    need(name.input,'Hãy nhập tên cột.');
    if(kind.value==='attribute')need(dict.input,'Hãy nhập tên dictionary.');
    if(kind.value!=='text')need(attr.input,'Hãy nhập tên thuộc tính.');
    const column={kind:kind.value,label:name.input.value};
    if(kind.value!=='text')column.attribute=attr.input.value;
    if(kind.value==='attribute')column.dictionary=dict.input.value;
    call('table_custom_column',JSON.stringify({action:'add',column}));
    host.replaceChildren();
  },'primary');
  const cancel=button('Hủy',()=>host.replaceChildren());
  const actions=node('div',undefined,'cc-actions');actions.append(submit,cancel);
  form.onkeydown=e=>{if(e.key==='Enter'){e.preventDefault();submit.click();}else if(e.key==='Escape'){e.preventDefault();e.stopPropagation();host.replaceChildren();}};
  form.append(kind,name.wrap,dict.wrap,attr.wrap,actions);host.append(form);name.input.focus();
}
function buildColumnPanel(side){
  const inner=node('div',undefined,'col-side-in');
  const head=node('div',undefined,'cs-head');
  const search=node('input');search.type='search';search.placeholder='Tìm cột...';search.value=tableState.colSearch;search.className='pop-search';search.setAttribute('aria-label','Tìm cột');
  const close=button('×',closeColumns,'cs-close');close.title='Ẩn danh sách cột';close.setAttribute('aria-label','Ẩn danh sách cột');
  const formHost=node('div',undefined,'cs-form-host');
  const add=button('+',()=>{if(formHost.firstChild)formHost.replaceChildren();else customColumnForm(formHost);},'cs-add');
  add.title='Thêm cột mới: thuộc tính tùy chọn, thuộc tính động hoặc cột tự nhập';add.setAttribute('aria-label','Thêm cột');
  head.append(search,add,close);
  const bar=node('div',undefined,'cs-all');
  const allBox=node('input',undefined,'cb');allBox.type='checkbox';allBox.setAttribute('aria-label','Chọn tất cả cột');
  allBox.onchange=()=>{
    tableState.visible=allBox.checked?new Set(tableState.data.columns.map(c=>c.key)):new Set();ensureProjected();
    side.querySelectorAll('.pop-col input').forEach(b=>{b.checked=allBox.checked;});
    refreshColumns();
  };
  const allLabel=node('label');allLabel.append(allBox,node('span','Bỏ chọn tất cả','cs-all-text'));
  bar.append(allLabel,node('span',undefined,'badge'));
  const list=node('div',undefined,'pop-cols');
  search.oninput=()=>{tableState.colSearch=search.value;renderColumnList(list);};
  renderColumnList(list);
  const density=node('select');density.setAttribute('aria-label','Độ cao hàng');density.className='pop-density';
  [['','Hàng: Vừa'],['dense','Hàng: Gọn'],['roomy','Hàng: Thoáng']].forEach(([v,t])=>density.append(new Option(t,v)));
  density.value=tableState.density;density.onchange=()=>{tableState.density=density.value;tableState.rowHeight=0;renderGrid($('grid-host'));persistView();};
  density.title='Giữ Ctrl và lăn chuột giữa trên bảng để đổi độ cao hàng (ảnh to ra theo).'; // gợi ý, không chiếm chỗ của danh sách cột
  inner.append(head,formHost,bar,list,density,sideGrip(side));
  side.replaceChildren(inner);
  updateColumnCounts();
}
// ---- Ngăn Loại trừ tag: tick các tag không tính vào Rộng / Dài / Cao (cùng ngăn bên với Chọn cột) ----
tableState.excludeSearch='';tableState.excludeTags=null;tableState.excludePending=false;
const excludedTags=()=>tableState.excludeTags||new Set((config.app&&config.app.settings&&config.app.settings.exclude_tags)||[]);
const modelTags=()=>((tableState.data&&tableState.data.choices&&tableState.data.choices.model_tags)||[]);
let excludeTimer=null;
// Lưu sau một lúc không tick nữa: mỗi lần lưu là Ruby tính lại số đo cả bảng, nên không gửi sau từng cú tick.
function saveExcluded(){
  tableState.excludePending=true;clearTimeout(excludeTimer);
  excludeTimer=setTimeout(()=>{tableState.excludePending=false;call('settings_save',JSON.stringify({exclude_tags:[...excludedTags()]}));},500);
  updateExcludeCounts();persistView();
}
function excludeNames(){
  const q=foldText(tableState.excludeSearch.trim());
  const inModel=modelTags(),missing=[...excludedTags()].filter(name=>!inModel.includes(name)).sort((a,b)=>a.localeCompare(b,'vi'));
  return [...inModel.map(name=>({name,missing:false})),...missing.map(name=>({name,missing:true}))].filter(item=>!q||foldText(item.name).includes(q));
}
function renderExcludeList(list){
  list.replaceChildren();
  const items=excludeNames();
  if(!items.length)list.append(node('p',modelTags().length?'Không có tag nào khớp.':'Không có tag nào trong model.','muted pp-note'));
  items.forEach(({name,missing})=>{
    const item=node('div',undefined,'pop-col');item.dataset.key=name;
    const box=node('input',undefined,'cb');box.type='checkbox';box.checked=excludedTags().has(name);
    box.onchange=()=>{const set=new Set(excludedTags());if(box.checked)set.add(name);else set.delete(name);tableState.excludeTags=set;saveExcluded();};
    const label=node('label');label.append(box,node('span',name+(missing?' (không có trong model)':''),'cs-name'+(missing?' muted':'')));
    item.append(label);list.append(item);
  });
}
// Nút Loại trừ tag và (nếu đang mở) danh sách tag cập nhật theo cài đặt mới nhất từ Ruby.
function refreshExcludeUi(){
  const side=$('col-side');
  if(side&&side.dataset.kind==='exclude'&&side.querySelector('.pop-cols'))renderExcludeList(side.querySelector('.pop-cols'));
  updateExcludeCounts();
  showExcludeCount(excludedTags().size);
}
function updateExcludeCounts(){
  const side=$('col-side');if(!side||side.dataset.kind!=='exclude')return;
  const names=excludeNames(),set=excludedTags();
  const badge=side.querySelector('.badge'),all=side.querySelector('.cs-all input'),label=side.querySelector('.cs-all .cs-all-text');
  const on=names.filter(item=>set.has(item.name)).length;
  if(badge)badge.textContent=`${set.size} / ${modelTags().length}`;
  if(all){all.checked=names.length>0&&on===names.length;all.disabled=!names.length;}
  if(label)label.textContent=names.length&&on===names.length?'Bỏ chọn tất cả':'Chọn tất cả';
  showExcludeCount(set.size);
}
function buildExcludePanel(side){
  const inner=node('div',undefined,'col-side-in');
  const head=node('div',undefined,'cs-head');
  const search=node('input');search.type='search';search.placeholder='Tìm tag...';search.value=tableState.excludeSearch;search.className='pop-search';search.setAttribute('aria-label','Tìm tag');
  const close=button('×',()=>closeColumns(),'cs-close');close.title='Ẩn danh sách tag';close.setAttribute('aria-label','Ẩn danh sách tag');
  head.append(search,close);
  const note=node('p','Phần nằm trên tag được tick không tính vào Rộng / Dài / Cao của Bảng khối lượng.','muted pp-note');
  const bar=node('div',undefined,'cs-all');
  const allBox=node('input',undefined,'cb');allBox.type='checkbox';allBox.setAttribute('aria-label','Chọn tất cả tag');
  allBox.onchange=()=>{
    const set=new Set(excludedTags());
    excludeNames().filter(item=>!item.missing||allBox.checked===false).forEach(item=>{if(allBox.checked)set.add(item.name);else set.delete(item.name);});
    tableState.excludeTags=set;renderExcludeList(list);saveExcluded();
  };
  const allLabel=node('label');allLabel.append(allBox,node('span','Chọn tất cả','cs-all-text'));
  bar.append(allLabel,node('span',undefined,'badge'));
  const list=node('div',undefined,'pop-cols');
  search.oninput=()=>{tableState.excludeSearch=search.value;renderExcludeList(list);updateExcludeCounts();};
  renderExcludeList(list);
  inner.append(head,note,bar,list,sideGrip(side));
  side.replaceChildren(inner);side.dataset.kind='exclude';
  updateExcludeCounts();
}
// ---- Ngăn bên: Chọn cột hoặc Loại trừ tag ----
const sideKind=()=>tableState.panel==='columns'||tableState.panel==='exclude'?tableState.panel:null;
// Số tag đang loại trừ: trên chip của thanh công cụ (ẩn khi 0) và mục Loại trừ tag trong menu Công cụ (nếu đang mở).
function showExcludeCount(n){
  const chip=$('exclude-chip');if(chip)chip.textContent=n?`Loại trừ ${n} tag`:'Loại trừ tag';
  const item=$('exclude-btn'),text=item&&item.querySelector('.io-text');if(text)text.textContent=n?`Loại trừ tag (${n})`:'Loại trừ tag';
}
function markSideButtons(){
  const cols=$('cols-btn'),excl=$('exclude-btn');
  if(cols)cols.setAttribute('aria-expanded',String(tableState.panel==='columns'));
  if(excl)excl.setAttribute('aria-expanded',String(tableState.panel==='exclude'));
  const chip=$('exclude-chip');if(chip)chip.setAttribute('aria-expanded',String(tableState.panel==='exclude'));
}
function buildSide(kind,side){if(kind==='exclude')buildExcludePanel(side);else{buildColumnPanel(side);side.dataset.kind='columns';}}
function openSide(kind,animate=true){
  const side=$('col-side');if(!side)return;
  clearTimeout(side._closing);
  if(!side.classList.contains('open'))side.style.removeProperty('--side-w'); // mở lại từ đóng: về 230 px
  tableState.panel=kind;
  buildSide(kind,side);
  markSideButtons();
  if(!animate){side.classList.add('open');return;}
  requestAnimationFrame(()=>requestAnimationFrame(()=>side.classList.add('open'))); // hai khung hình để width 0 được vẽ trước khi trượt ra
}
function closeColumns(animate=true){
  const side=$('col-side');
  if(sideKind())tableState.panel=null;
  markSideButtons();
  if(!side)return;
  side.classList.remove('open');
  clearTimeout(side._closing);
  const empty=()=>{side.replaceChildren();delete side.dataset.kind;};
  if(animate)side._closing=setTimeout(empty,SIDE_MS+60);else empty();
}
// Bấm nút của ngăn: đang mở đúng ngăn đó thì đóng; đang mở ngăn kia thì đổi nội dung (không đóng rồi mở lại).
function toggleSide(kind){
  if(tableState.panel===kind){closeColumns();return;}
  const side=$('col-side');
  if(sideKind()&&side&&side.classList.contains('open')){tableState.panel=kind;buildSide(kind,side);markSideButtons();return;}
  const other=!!tableState.panel; // đang mở bảng khác (Đổi tên, Chụp ảnh...): đóng bảng đó khi mở ngăn này
  openSide(kind);if(other)tableView(tableState.data);
}
// Bấm ra ngoài thì đóng bảng đang mở (Đổi tên, Mặt trước, Cập nhật ảnh, Nhóm theo, Nhập/Xuất, ngăn Cột, ngăn Loại trừ).
// Không vẽ lại thanh công cụ (vẽ lại sẽ làm mất con trỏ ở ô tìm kiếm vừa bấm), chỉ gỡ bảng nổi và đặt lại nút.
function closeTablePanel(){
  if(!tableState.panel)return;
  if(sideKind()){closeColumns();return;}
  tableState.panel=null;
  document.querySelectorAll('.popover').forEach(p=>p.remove());
  document.querySelectorAll('button[aria-expanded="true"]').forEach(b=>{if(!b.closest('header'))b.setAttribute('aria-expanded','false');});
}
const PANELS_KEEP_ON_ROW_CLICK=['rename','bridge','front','capture','codes','levels','rooms','materials','checks','snapshots']; // ba bảng này dùng các dòng đang chọn: bấm chọn dòng không đóng
document.addEventListener('mousedown',e=>{
  if(!tableState.panel||!(e.target instanceof Element))return;
  const t=e.target;
  if(t.closest('.popover,.header-panel,.photo-pop,.preview-board,.cell-menu,dialog,.col-side'))return; // bên trong bảng nổi hoặc ngăn
  const toggle=t.closest('button[aria-expanded]');
  if(toggle&&!toggle.closest('header'))return; // nút mở bảng tự bật / tắt đúng bảng của nó
  if(PANELS_KEEP_ON_ROW_CLICK.includes(tableState.panel)&&t.closest('.grid'))return;
  closeTablePanel();
},true);
const toggleColumns=()=>toggleSide('columns');
const toggleExclude=()=>toggleSide('exclude');
// Nút gạt (công tắc) giống tab Quản lý của VGD Center: bấm vào nút hoặc chữ đều gạt.
function toggleButton(text,on,handler){
  const item=node('div',undefined,'sw-item');
  const sw=node('button',undefined,'sw');sw.type='button';sw.setAttribute('role','switch');sw.setAttribute('aria-checked',String(!!on));sw.setAttribute('aria-label',text);
  const label=node('span',text,'sw-label');
  sw.onclick=handler;label.onclick=handler;
  item.append(sw,label);return item;
}
// Xuất Excel / PDF: gửi cho Ruby đúng bảng đang hiện (cột, thứ tự, tiêu đề, đơn vị, dòng đã lọc / sắp xếp / nhóm, dòng tổng).
// Ô số gửi dạng số đã đổi sang đơn vị của preset, chưa làm tròn (Excel tự định dạng theo số lẻ của cột). Chữ dịch theo ngôn ngữ đang dùng.
const exportText=text=>VGD_I18N.language==='en'?VGD_I18N.translateText(text):text;
function exportColumn(col){
  const type=col.key==='ordinal'?'ordinal':isImageColumn(col)?'image':NUMERIC.has(col.key)?'number':col.key==='url'?'link':'text';
  const imageKind=col.kind==='image_location'?{image_kind:'location'}:IMAGE_EXTRA_KINDS[col.kind]?{image_kind:IMAGE_EXTRA_KINDS[col.kind]}:{};
  return {...imageKind,label:exportText(colLabel(col)),unit:exportText(unitTextOf(col.key)||''),type,digits:type==='number'?digitsFor(col.key):0,width:Math.min(2000,Math.max(20,Math.round(widthOf(col.key))))}; // độ rộng cột đang chỉnh trên màn hình, dùng làm tỉ lệ ban đầu của trang in
}
function exportCell(row,col,position){
  if(col.key==='ordinal')return position;
  if(isImageColumn(col))return null;
  if(NUMERIC.has(col.key)){const value=scaledValue(col.key,row[col.key]);return value==null||value===''?null:Number(value);}
  return String(cellText(row,col.key)||'');
}
// Xuất luôn đủ mọi món, kể cả nhóm đang thu gọn (thu gọn chỉ là cách xem trên màn hình).
function exportRows(model){
  const {cols,rows,sections,sumOf,countOf}=model;
  const labelKey=['instance','definition','entity'].find(k=>cols.some(c=>c.key===k));
  const labelIndex=Math.max(0,cols.findIndex(col=>col.key===labelKey));
  const summary=(list,text)=>cols.map((col,i)=>i===labelIndex?text:col.kind==='sum'?Number(scaledValue(col.key,sumOf(list,col.key))):null);
  const out=[];let position=0;
  sections.forEach(section=>{
    if(section.label!==null){
      out.push({kind:'group',cells:summary(section.rows,exportText(`${section.label} · ${countOf(section.rows)}`))});
    }
    section.rows.forEach(row=>{position++;out.push({kind:'row',pid:row.pid||null,cells:cols.map(col=>exportCell(row,col,position))});});
  });
  if(tableState.showTotals)out.push({kind:'total',cells:summary(rows,exportText(`Tổng cộng · ${countOf(rows)} đối tượng`))});
  return out;
}
// Xuất Excel / PDF: mỗi sheet là một worksheet (Excel) hoặc một phần của trang in (PDF), mỗi sheet đúng cột, sắp xếp, nhóm, bộ lọc của nó. Chỉ một sheet thì như trước.
// Số đo thân phụ thuộc tag loại trừ của từng sheet nên chuyển qua từng sheet (Ruby tính lại khi tag loại trừ khác) rồi trả về sheet đang mở.
const tableWaiters=[];
const nextTableEvent=(ms=window.tableWaitMs||20000)=>new Promise(resolve=>{let done=false;const finish=arrived=>{if(!done){done=true;resolve(arrived===true);}};tableWaiters.push(()=>finish(true));setTimeout(finish,ms);}); // true khi bảng mới tới, false khi hết thời gian chờ
function exportLabels(){return {model:exportText('Mô hình'),preset:'Preset',date:exportText('Ngày'),print:exportText('In / Lưu PDF'),reset:exportText('Đặt lại độ rộng cột'),hint:exportText('Kéo mép tiêu đề cột để chỉnh độ rộng.')};}
function exportSheetData(name){
  const model=viewModel(true);
  return {name,columns:model.cols.map(exportColumn),rows:exportRows(model),...(tableState.rowHeight>0?{row_height:tableState.rowHeight}:{})};
}
let exporting=false;
async function exportTable(format){
  if(exporting)return message('Đang chuẩn bị xuất, hãy đợi xong.',true);
  ensureSheets();stashSheet();
  const base={format,title:exportText('Bảng khối lượng'),preset:tableState.preset||'',decimal_separator:workSettings().decimal_separator,labels:exportLabels()};
  if(tableState.sheets.length<2){
    const one=exportSheetData(null);
    return call('table_export',JSON.stringify({...base,...(one.row_height?{row_height:one.row_height}:{}),columns:one.columns,rows:one.rows}));
  }
  exporting=true;
  const original=tableState.sheet,sheets=tableState.sheets.map(sheet=>({...sheet})),out=[];let failure='';
  try{
    message(`Đang chuẩn bị ${sheets.length} sheet để xuất…`);
    for(let i=0;i<sheets.length;i++){
      tableState.sheet=i;loadSheet(sheets[i]);
      const relocked=applyRowsLock(sheets[i].lock||null); // sheet khóa cần đúng các món đã khóa
      const needsProjected=tableState.visible.has('areaProjected')&&tableState.data.options&&!tableState.data.options.projected;
      const changed=applySheetExclude(sheets[i]);
      if(needsProjected)ensureProjected();
      if((changed||needsProjected||relocked)&&!(await nextTableEvent()))throw new Error(`Hết thời gian chờ tính lại số đo cho sheet “${sheets[i].name}”. Hãy thử xuất lại.`); // Ruby tính lại số đo / diện tích chiếu rồi gửi bảng mới
      out.push(exportSheetData(sheets[i].name));
    }
  }catch(error){
    failure=error.message;
    out.length=0;
  }finally{
    tableState.sheet=original;loadSheet(sheets[original]);
    const relocked=applyRowsLock(sheets[original].lock||null);
    const changed=applySheetExclude(sheets[original]);
    if(changed||relocked)await nextTableEvent();
    exporting=false;
    tableState.sheets=sheets;persistView();tableView(tableState.data);
  }
  if(failure)message(failure,true);
  if(out.length)call('table_export',JSON.stringify({...base,sheets:out}));
}
// Biểu tượng nhỏ cho menu (SVG, dùng màu chữ hiện tại).
function menuIcon(shapes){
  const ns='http://www.w3.org/2000/svg',svg=document.createElementNS(ns,'svg');
  svg.setAttribute('viewBox','0 0 24 24');svg.setAttribute('width','16');svg.setAttribute('height','16');svg.setAttribute('fill','none');svg.setAttribute('stroke','currentColor');svg.setAttribute('stroke-width','2');svg.setAttribute('stroke-linecap','round');svg.setAttribute('stroke-linejoin','round');svg.setAttribute('aria-hidden','true');
  shapes.forEach(([tag,attrs])=>{const el=document.createElementNS(ns,tag);Object.entries(attrs).forEach(([k,v])=>el.setAttribute(k,v));svg.append(el);});
  return svg;
}
const IO_ICONS={
  bridge:[['path',{d:'M21 12a9 9 0 0 0-15-6.7L3 8'}],['path',{d:'M3 3v5h5'}],['path',{d:'M3 12a9 9 0 0 0 15 6.7L21 16'}],['path',{d:'M16 16h5v5'}]],
  excel:[['path',{d:'M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z'}],['path',{d:'M14 3v6h6'}],['path',{d:'M9 13l4 5M13 13l-4 5'}]],
  pdf:[['path',{d:'M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z'}],['path',{d:'M14 3v6h6'}],['path',{d:'M8 13h8M8 17h5'}]],
  preset:[['path',{d:'M4 6h16M4 12h16M4 18h16'}]],
  id:[['rect',{x:3,y:5,width:18,height:14,rx:2}],['path',{d:'M7 10h4M7 14h2M14 10h3M14 14h3'}]],
  calc:[['rect',{x:5,y:3,width:14,height:18,rx:2}],['path',{d:'M8 7h8M8 12h2M12 12h2M8 16h2M12 16h2'}]]
};
// Cầu nối dữ liệu: nhập Excel / CSV vào dữ liệu chữ của món (xem docs/vgd_bim/BRIDGE.md, mẫu 5D Auto Info). Chọn file → chọn cột khớp và cột nhập → xem trước → áp dụng.
tableState.bridge={file:null,match_by:'vgd_id',match_column:'',mapping:{},preview:null,skip:new Set(),shown:200};
const BRIDGE_STATUS={unmatched:'Không có trong bảng',ambiguous:'Trùng khóa trong bảng, bỏ qua',file_duplicate:'Khóa lặp trong file, bỏ qua',locked:'Bị khóa, bỏ qua',unchanged:'Không đổi'};
function bridgeOptions(){const b=tableState.bridge;return {match_by:b.match_by,match_column:b.match_column,mapping:b.mapping};}
function bridgePreview(box,apply){
  const b=tableState.bridge,pv=b.preview;if(!pv)return;
  const c=pv.counts;
  box.append(node('p',`Sẽ nhập ${c.changes} giá trị cho ${c.ok} đối tượng · không đổi ${c.unchanged} · không khớp ${c.unmatched}`+(c.errors?` · giá trị sai ${c.errors}`:'')+(c.ambiguous?` · khóa trùng trong bảng ${c.ambiguous}`:'')+(c.file_duplicate?` · khóa lặp trong file ${c.file_duplicate}`:'')+(c.locked?` · bị khóa ${c.locked}`:'')+'. Chỉ đọc món đang có trong bảng; ô trống trong file nghĩa là không đổi.'));
  const table=node('table',undefined,'rename-table');
  const rows=pv.rows.filter(r=>r.status!=='blank'&&r.status!=='unchanged');
  rows.slice(0,b.shown).forEach(row=>{
    if(row.status!=='ok'){
      const tr=node('tr');tr.className='st-locked';const why=node('td',BRIDGE_STATUS[row.status]||row.status);why.colSpan=3;tr.append(node('td'),node('td',`Dòng ${row.row} · ${row.key||'(trống)'}`),why);table.append(tr);return;
    }
    row.changes.forEach((ch,i)=>{
      const tr=node('tr');if(ch.error)tr.className='st-locked';
      const id=`${row.row}|${ch.field}`;
      const box2=node('input');box2.type='checkbox';box2.checked=!ch.error&&!b.skip.has(id);box2.disabled=!!ch.error;
      box2.onchange=()=>{if(box2.checked)b.skip.delete(id);else b.skip.add(id);};
      const cell=node('td');cell.append(box2);
      tr.append(cell,node('td',i===0?`Dòng ${row.row} · ${row.name||row.key}`:''),node('td',ch.label),node('td',ch.old||'(trống)'),node('td',ch.error?ch.error:'→ '+ch.new));
      table.append(tr);
    });
  });
  box.append(table);
  if(rows.length>b.shown){const more=button(`Hiện thêm (${rows.length-b.shown} dòng nữa)`,()=>{b.shown+=200;tableView(tableState.data);});box.append(more);}
}
function bridgePanel(){
  const b=tableState.bridge,f=b.file;
  const p=node('div',undefined,'popover right rename bridge');
  p.append(node('div','Cầu nối dữ liệu · nhập từ Excel / CSV','pop-title'));
  p.append(node('p','Đọc file Excel (.xlsx, trang tính đầu) hoặc CSV rồi cập nhật dữ liệu chữ của các món đang có trong bảng (tên, mô tả, xuất xứ, liên kết, quy cách, đơn giá, cột chữ tự thêm). Không đổi tag, vật liệu, tầng, phòng. File Excel xuất từ BIM nhập lại được nếu có cột VGD ID hoặc Mã đối tượng.'));
  const box=node('div');
  const apply=button('Áp dụng',()=>{call('bridge_apply',JSON.stringify({...bridgeOptions(),skip:[...b.skip].map(id=>{const [row,field]=id.split('|');return [Number(row),field];})}));b.preview=null;tableState.panel=null;tableView(tableState.data);},'primary');
  apply.disabled=!(b.preview&&b.preview.counts.changes>0);
  const stale=()=>{b.preview=null;b.skip=new Set();b.shown=200;apply.disabled=true;box.replaceChildren();};
  const open=button(f?'Chọn file khác…':'Chọn file Excel / CSV…',()=>call('bridge_open'),f?'':'primary');
  p.append(open);
  if(f){
    p.append(node('p',`${f.name} · ${f.count} dòng dữ liệu`));
    const pick=(label,value,options,onchange)=>{
      const wrap=node('label',undefined,'rename-field');wrap.append(node('span',label));
      const select=node('select');options.forEach(([v,t])=>select.append(new Option(t,v)));select.value=value;select.onchange=()=>{onchange(select.value);stale();};
      wrap.append(select);return wrap;
    };
    const row=node('div',undefined,'rename-row');
    row.append(pick('Khớp theo',b.match_by,f.match.map(m=>[m.key,m.label]),v=>{b.match_by=v;}),
      pick('Cột của file dùng để khớp',b.match_column,[['','(chọn cột)'],...f.headers.filter(h=>h).map(h=>[h,h])],v=>{b.match_column=v;if(v)delete b.mapping[v];}));
    p.append(row);
    p.append(node('div','Cột của file → trường cần nhập (để trống = bỏ qua)','pop-title'));
    const list=node('div');
    f.headers.filter(h=>h&&h!==b.match_column).forEach(h=>{
      list.append(pick(h,b.mapping[h]||'',[['','(bỏ qua)'],...f.fields.map(x=>[x.key,x.label])],v=>{if(v)b.mapping[h]=v;else delete b.mapping[h];}));
    });
    p.append(list);
  }
  const actions=node('div',undefined,'rename-actions');
  actions.append(button('Xem trước',()=>{
    if(!b.match_column)return message('Hãy chọn cột của file dùng để khớp.',true);
    if(!Object.keys(b.mapping).length)return message('Hãy chọn ít nhất một cột để nhập.',true);
    call('bridge_preview',JSON.stringify(bridgeOptions()));
  },'primary'),apply,button('Đóng',()=>{tableState.panel=null;tableView(tableState.data);}));
  p.append(box,actions);
  if(f)bridgePreview(box,apply);
  return p;
}
// Menu Công cụ chia nhóm gập được để không dài quá cửa sổ: chỉ nhóm Xuất mở sẵn; nhóm đã mở / gập được nhớ trên máy này.
const IO_OPEN_KEY='vgd.bim.tools.open';
const ioOpen=(()=>{try{return JSON.parse(localStorage.getItem(IO_OPEN_KEY))||{export:true};}catch(_){return {export:true};}})();
function ioSection(id,title,items){
  const sec=node('details',undefined,'io-sec');sec.open=!!ioOpen[id];sec.dataset.sec=id;
  sec.addEventListener('toggle',()=>{ioOpen[id]=sec.open;try{localStorage.setItem(IO_OPEN_KEY,JSON.stringify(ioOpen));}catch(_){/* không lưu được thì thôi */}});
  sec.append(node('summary',title,'io-head'),...items);
  return sec;
}
function ioPanel(){
  const p=node('div',undefined,'popover right io-panel');
  const item=(icon,text,handler,disabledNote)=>{
    const b=node('button',undefined,'pop-pick io-item');b.type='button';
    b.append(menuIcon(IO_ICONS[icon]),node('span',text,'io-text'));
    if(disabledNote){b.disabled=true;b.append(node('span',disabledNote,'io-note'));}
    else b.onclick=()=>{tableState.panel=null;tableView(tableState.data);handler();};
    return b;
  };
  const exportItems=[item('bridge','Cầu nối dữ liệu',()=>{tableState.panel='bridge';tableView(tableState.data);}),item('excel','Xuất Excel',()=>exportTable('xlsx')),item('pdf','In PDF',()=>exportTable('pdf'))];
  // Công cụ của bảng (trước nằm trên thanh công cụ): loại trừ tag khỏi số đo, đổi tên hàng loạt, nhận mặt trước.
  const excludeCount=excludedTags().size;
  const exclude=item('preset',excludeCount?`Loại trừ tag (${excludeCount})`:'Loại trừ tag',toggleExclude);exclude.id='exclude-btn';exclude.title='Chọn các tag không tính vào Rộng / Dài / Cao';
  const rename=item('calc','Đổi tên...',()=>{tableState.panel='rename';tableView(tableState.data);});rename.id='rename-open';rename.title='Đổi tên hàng loạt các món trong bảng';
  const front=item('id','Mặt trước...',()=>{tableState.panel='front';tableView(tableState.data);});front.id='front-btn';front.title='Nhận và sửa mặt trước của món (dùng cho Rộng / Sâu và ảnh Chính diện)';
  // Ghi cách tính suy ra từ tag vào các món đang chọn (chỉ điền mục còn trống; một bước hoàn tác). Phải chọn dòng rõ ràng để không ghi hàng loạt nhầm.
  const calc=item('calc','Ghi cách tính vào món đang chọn',()=>{if(!tableState.sel.size)return message('Hãy chọn các dòng cần ghi cách tính (Ctrl+A chọn hết các dòng đang hiện).',true);call('table_commit_calc',JSON.stringify({indexes:[...tableState.sel]}));});
  calc.id='calc-commit';calc.title='Ghi hạng mục, cách tính và đơn vị suy ra từ tag vào các món đang chọn (chỉ điền mục còn trống, không ghi đè dữ liệu đã nhập; một bước hoàn tác)';
  // VGD ID: mã định danh ổn định của món (xem docs/vgd_bim/ROADMAP.md). Gán chỉ cho món chưa có ID và phải chọn dòng rõ ràng; sửa trùng áp cho cả bảng (món cũ nhất giữ ID).
  const assignIds=item('id','Gán VGD ID cho món đang chọn',()=>{if(!tableState.sel.size)return message('Hãy chọn các dòng cần gán VGD ID (Ctrl+A chọn hết các dòng đang hiện).',true);call('table_assign_ids',JSON.stringify({indexes:[...tableState.sel]}));});
  const codesBtn=item('id','Đặt mã đối tượng hàng loạt...',()=>{tableState.panel='codes';tableView(tableState.data);});
  codesBtn.id='codes-open';codesBtn.title='Đặt Mã đối tượng (D01, D02...) cho các món đang chọn theo thứ tự trong bảng';
  assignIds.id='ids-assign';assignIds.title='Gán mã định danh VGD ID cho các món đang chọn chưa có ID (món đã có ID giữ nguyên, món bị khóa bỏ qua; một bước hoàn tác)';
  const editSource=item('id','Sửa bằng plugin dựng hình',()=>{
    if(tableState.sel.size!==1)return message('Hãy chọn đúng một dòng (món do plugin dựng hình tạo ra) để sửa bằng plugin.',true);
    const index=[...tableState.sel][0],row=tableState.data.rows.find(r=>r.index===index);
    if(!row||!row.source_plugin)return message('Món này không do plugin dựng hình tạo ra nên không có gì để sửa bằng plugin.',true);
    call('table_edit_source',JSON.stringify({index}));
  });
  editSource.id='edit-source';editSource.title='Mở plugin đã dựng ra món đang chọn (ví dụ VGD Structure) ở đúng phần tử để sửa. VGD_BIM chỉ gọi plugin, không tự sửa hình của plugin khác';
  const fixIds=item('id','Sửa VGD ID trùng',()=>call('table_fix_duplicate_ids'));
  fixIds.id='ids-fix';fixIds.title='Các món do copy mà dùng chung VGD ID: món cũ nhất giữ ID, các món còn lại nhận ID mới (một bước hoàn tác)';
  const levelsBtn=item('id','Quản lý tầng...',()=>{tableState.panel='levels';tableView(tableState.data);});
  levelsBtn.id='levels-open';levelsBtn.title='Thêm / sửa tầng của công trình và gán tầng cho món (chỉ là nhãn, không dời hình)';
  const roomsBtn=item('id','Quản lý phòng...',()=>{tableState.panel='rooms';tableView(tableState.data);});
  roomsBtn.id='rooms-open';roomsBtn.title='Tạo phòng từ mặt sàn đang chọn, sửa tên / mã / tầng / chiều cao / hoàn thiện, xem diện tích, thể tích và gán món vào phòng (dữ liệu và khối 3D của phòng)';
  const materialsBtn=item('id','Thư viện vật liệu...',()=>{tableState.panel='materials';tableView(tableState.data);});
  materialsBtn.id='materials-open';materialsBtn.title='Thư viện vật liệu (mã, hãng, đơn giá, hao hụt...) nối với vật liệu SketchUp theo tên để tính khối lượng có hao hụt và thành tiền theo vật liệu';
  const checksBtn=item('id','Luật kiểm tra...',()=>{tableState.panel='checks';tableView(tableState.data);});
  checksBtn.id='checks-open';checksBtn.title='Đặt luật kiểm tra riêng cho bảng (ví dụ Rộng nhỏ hơn 700 thì cảnh báo, Tầng để trống thì thông tin) rồi chạy và bấm vào kết quả để chọn món';
  const snapBtn=item('id','So sánh phiên bản...',()=>{tableState.panel='snapshots';tableState.snapshotDiff=null;tableState.snapshots=null;call('snapshot_list');tableView(tableState.data);});
  snapBtn.id='snapshots-open';snapBtn.title='Chụp mốc giá trị các món rồi so với bảng hiện tại để biết món nào thêm, xóa hoặc đổi';
  p.append(ioSection('export','Xuất',exportItems),ioSection('table','Bảng',[exclude,rename,front]),
    ioSection('data','Mã và dữ liệu món',[calc,assignIds,fixIds,editSource,codesBtn]),
    ioSection('site','Công trình',[levelsBtn,roomsBtn]),ioSection('check','Vật liệu và kiểm tra',[materialsBtn,checksBtn,snapBtn]));
  return p;
}
// Các công tắc gom vào bảng "Tùy chọn" (thay cho hai hàng công tắc luôn hiện); bảng "Công cụ" là menu nhập / xuất và các hộp dữ liệu.
function optionsPanel(){
  const options=()=>tableState.data.options;
  const p=node('div',undefined,'popover right opts-panel');
  const switches=node('div',undefined,'switches');
  switches.append(node('div','Khi chọn dòng trong bảng','io-head'));
  switches.append(toggleButton('Thu phóng đối tượng',options().zoom,()=>call('table_option',JSON.stringify({zoom:!options().zoom}))));
  switches.append(toggleButton('Cô lập đối tượng chọn',options().isolate,()=>call('table_option',JSON.stringify({isolate:!options().isolate}))));
  switches.append(toggleButton('Chọn sâu bên trong',options().deep,()=>call('table_option',JSON.stringify({deep:!options().deep}))));
  switches.append(toggleButton('Bảng tên trên model',options().label!==false,()=>call('table_option',JSON.stringify({label:options().label===false}))));
  switches.append(node('div','Số đo','io-head'));
  switches.append(toggleButton('Diện tích chiếu',options().projected,()=>call('table_option',JSON.stringify({projected:!options().projected}))));
  switches.append(node('div','Dòng tính tổng','io-head'));
  switches.append(toggleButton('Hiển thị dòng tính tổng',tableState.showTotals,()=>{tableState.showTotals=!tableState.showTotals;tableView(tableState.data);}));
  switches.append(toggleButton('Tổng chỉ cấp cao nhất',tableState.onlyTop,()=>{tableState.onlyTop=!tableState.onlyTop;tableView(tableState.data);}));
  p.append(switches);
  return p;
}
function menuBar(){
  const bar=node('div',undefined,'menubar');
  const menu=node('div',undefined,'footer-menu');
  const opts=button('Tùy chọn ▾',()=>{tableState.panel=tableState.panel==='opts'?null:'opts';tableView(tableState.data);});opts.id='opts-btn';
  opts.title='Thu phóng, cô lập, chọn sâu, diện tích chiếu, bảng tên trên model, dòng tính tổng';
  opts.setAttribute('aria-expanded',String(tableState.panel==='opts'));
  const io=button('Công cụ ▾',()=>{tableState.panel=tableState.panel==='io'?null:'io';tableView(tableState.data);});io.id='tools-btn';
  io.title='Xuất Excel / PDF, mã và VGD ID, tầng, phòng, vật liệu, luật kiểm tra, so sánh phiên bản';
  io.setAttribute('aria-expanded',String(tableState.panel==='io'));
  menu.append(opts,io);
  if(tableState.panel==='opts')menu.append(optionsPanel());
  if(tableState.panel==='io')menu.append(ioPanel());
  bar.append(menu);
  return bar;
}
// Khu menu Tùy chọn / Công cụ cuối thanh trên. Đã có thì chỉ đổi trạng thái tại chỗ (công tắc trượt mượt, không bị dựng lại giữa chừng):
// nút giữ nguyên, công tắc đổi aria-checked, bảng Công cụ vẽ lại. Trả về khu menu (mới hoặc cũ).
function syncMenuBar(view){
  const fresh=menuBar(),old=view.querySelector('.menubar');
  if(!old)return fresh;
  const oldMenu=old.querySelector('.footer-menu'),freshMenu=fresh.querySelector('.footer-menu');
  const freshButtons=freshMenu.querySelectorAll(':scope>button');
  oldMenu.querySelectorAll(':scope>button').forEach((b,i)=>b.setAttribute('aria-expanded',freshButtons[i].getAttribute('aria-expanded')));
  const oldOpts=oldMenu.querySelector('.opts-panel'),freshOpts=freshMenu.querySelector('.opts-panel');
  if(oldOpts&&freshOpts){
    const current=oldOpts.querySelectorAll('.sw');
    freshOpts.querySelectorAll('.sw').forEach((sw,i)=>{if(current[i]&&current[i].getAttribute('aria-checked')!==sw.getAttribute('aria-checked'))current[i].setAttribute('aria-checked',sw.getAttribute('aria-checked'));});
  }else if(oldOpts)oldOpts.remove();
  else if(freshOpts)oldMenu.append(freshOpts);
  const oldIo=oldMenu.querySelector('.io-panel'),freshIo=freshMenu.querySelector('.io-panel');
  if(freshIo){if(oldIo)oldIo.replaceWith(freshIo);else oldMenu.append(freshIo);}
  else if(oldIo)oldIo.remove();
  return old;
}
function tableView(data){
  const knownKeys=tableState.data?new Set(tableState.data.columns.map(c=>c.key)):null; // để nhận ra cột thêm tay vừa tạo
  tableState.data=data;
  document.body.classList.add('table-mode');updateSelInfo(); // bảng chiếm hết chiều cao cửa sổ: tiêu đề cột và chân trang cố định, chỉ cuộn các hàng
  const restored=!tableState.restored&&restoreView(data);
  if(!restored&&!tableState.order.length)applyPreset(tableState.preset);
  if(!(data.presets||[]).some(p=>p.name===tableState.preset))applyPreset((data.presets||[])[0].name);
  const keys=new Set(data.columns.map(c=>c.key)); // cột thêm tay đã xóa thì bỏ khỏi thứ tự / cột đang hiện; cột mới tạo thì hiện luôn, ở cuối
  tableState.order=tableState.order.filter(k=>keys.has(k));[...tableState.visible].forEach(k=>{if(!keys.has(k))tableState.visible.delete(k);});
  const added=knownKeys?data.columns.filter(c=>c.custom&&!knownKeys.has(c.key)):[];
  added.forEach(c=>{tableState.visible.add(c.key);if(!tableState.order.includes(c.key))tableState.order.push(c.key);});
  if(added.length)syncCustomPreset();
  if(!tableState.projectedChecked){tableState.projectedChecked=true;ensureProjected();} // preset đã lưu có cột Diện tích chiếu: bật công tắc một lần khi bảng nạp xong
  ensureSheets();
  const content=$('content');
  let view=content.querySelector('.table-view');
  const fresh=!view;
  if(fresh){ // khung bảng dựng một lần; các lần sau chỉ làm mới từng phần để ngăn Chọn cột và công tắc giữ nguyên hiệu ứng
    content.replaceChildren();
    view=node('div',undefined,'table-view');content.append(view);
    const split=node('div',undefined,'tv-split'),side=node('aside',undefined,'col-side');side.id='col-side';
    const host=node('div');host.id='grid-host';split.append(side,host);
    view.append(node('div',undefined,'toolbar-wrap'),split);
  }
  const hint=view.querySelector(':scope>.hint');
  if(data.hint){if(hint)hint.textContent=data.hint;else view.prepend(node('p',data.hint,'hint'));}else if(hint)hint.remove();
  // Thanh trên: thanh công cụ (dựng lại) + khu menu Tùy chọn / Công cụ (giữ nguyên chỗ, không gỡ khỏi trang) + ngăn đang mở.
  const bar=view.querySelector('.toolbar-wrap');
  const roomsScroll=bar.querySelector('.rooms-panel')?.scrollTop||0;
  [...bar.children].forEach(el=>{if(!el.classList.contains('menubar'))el.remove();});
  bar.prepend(toolbar());
  const menu=syncMenuBar(view);if(!menu.parentNode)bar.append(menu);
  if(tableState.panel==='capture')bar.append(capturePanel());
  if(tableState.panel==='codes')bar.append(codesPanel());
  if(tableState.panel==='levels')bar.append(levelsPanel());
  if(tableState.panel==='rooms'){const panel=roomsPanel();bar.append(panel);panel.scrollTop=roomsScroll;}
  if(tableState.panel==='materials')bar.append(materialsPanel());
  if(tableState.panel==='checks')bar.append(checksPanel());
  if(tableState.panel==='snapshots')bar.append(snapshotsPanel());
  if(tableState.panel==='front')bar.append(frontPanel());
  if(tableState.panel==='rename')bar.append(renamePanel());
  if(tableState.panel==='bridge')bar.append(bridgePanel());
  const side=$('col-side'),host=$('grid-host');
  const kind=sideKind();
  if(kind){
    if(fresh||!side.classList.contains('open')&&!side.firstChild)openSide(kind,!fresh);
    else if(side.dataset.kind!==kind){buildSide(kind,side);markSideButtons();}
    else if(kind==='columns'){renderColumnList(side.querySelector('.pop-cols'));updateColumnCounts();}
    else{renderExcludeList(side.querySelector('.pop-cols'));updateExcludeCounts();}
  }else if(side.classList.contains('open'))closeColumns();
  const old=host.querySelector('.grid-wrap');const scroll=old?{top:old.scrollTop,left:old.scrollLeft}:null;
  renderGrid(host);
  if(scroll){const wrap=host.querySelector('.grid-wrap');if(wrap){wrap.scrollTop=scroll.top;wrap.scrollLeft=scroll.left;}}
  syncSheetBar(view);
  persistView();updatePresetButton();updateReplaceUi();syncBusy();
  $('primary-actions').replaceChildren(); // bỏ chọn bằng cách bấm vùng trống trong SketchUp hoặc nhấn Esc trong bảng
}
// Phần nằm chung trong một tab.
const TAB_OF={rules:'mapping',validate_model:'mapping',validate_selection:'mapping',export:'scan',convert_selection:'information'};
window.VGD={receive(event,data){
  if(event==='config'){syncFile(data);document.body.classList.remove('table-mode');updateSelInfo();if(appliedLanguage&&data.language&&appliedLanguage!==data.language){location.reload();return;}appliedLanguage=data.language||'vi';VGD_I18N.setLanguage(appliedLanguage,data.vi_en);config=data;if(config.table&&!tableState.restored)restoreView({view:config.table.view,columns:config.table.columns,presets:config.table.presets});updatePresetButton();locale=data.locale||locale;$('subtitle').textContent=TAB_OF[data.mode]?`${data.version} · ${translated('modes',data.mode)}`:data.version;document.querySelectorAll('[data-mode]').forEach(b=>{const active=b.dataset.mode===(TAB_OF[data.mode]||data.mode);b.classList.toggle('active',active);b.setAttribute('aria-selected',String(active));});$('preview').close();$('content').replaceChildren();$('primary-actions').replaceChildren();document.querySelector('main').scrollTop=0;message('Đang đọc dữ liệu…');}
  if(event==='table'){tableState.manual=Array.isArray(data.row_order)?data.row_order:[];tableState.rename.preview=null;tableState.sel=new Set(Array.isArray(data.selected)?data.selected:[]);if(!tableState.sel.has(tableState.anchor))tableState.anchor=null;} // bảng đổi thì bản xem trước đổi tên cũ không còn đúng
  const renderers={information,scan,scan_pending:scanPending,mapping,validation,rules,tags:tagEditor,table:tableView};if(renderers[event]){renderers[event](data);message('Sẵn sàng.');}
  if(event==='snapshots'){tableState.snapshots=data;if(tableState.panel==='snapshots'&&tableState.data)tableView(tableState.data);}
  if(event==='snapshot_diff'){tableState.snapshotDiff=data;tableState.panel='snapshots';if(tableState.data)tableView(tableState.data);}
  if(event==='check_results'){tableState.checkResults=data;tableState.panel='checks';if(tableState.data)tableView(tableState.data);}
  if(event==='highlight')highlightRows(data.indexes);
  if(event==='sheet_lock'){const s=tableState.sheets&&tableState.sheets[tableState.sheet];if(s&&data&&data.lock){s.lock=data.lock;tableState.lockKey=lockKeyOf(data.lock);persistView();if(tableState.data)tableView(tableState.data);}}
  if(event==='options'&&tableState.data){tableState.data.options=data;tableView(tableState.data);}
  if(event==='presets'){
    if(config.table)config.table.presets=data;
    if(tableState.data){tableState.data.presets=data;if(config.mode==='table')tableView(tableState.data);}
    updatePresetButton();if(openPanel==='preset-panel')presetPanel($('preset-panel'));
  }
  if(event==='settings'){config.app=data;if(!tableState.excludePending){tableState.excludeTags=null;refreshExcludeUi();}if(openPanel==='preset-panel')presetPanel($('preset-panel'));if(openPanel==='gear-panel')languagePanel($('gear-panel'));}
  if(event==='front_align_plan'){tableState.alignPlan=data&&!data.cleared?data:null;if(tableState.panel==='front'&&tableState.data)tableView(tableState.data);return;}
  if(event==='bridge_file'){const b=tableState.bridge;b.file=data;b.match_by=data.suggest.match_by;b.match_column=data.suggest.match_column||'';b.mapping={...data.suggest.mapping};b.preview=null;b.skip=new Set();b.shown=200;if(tableState.panel==='bridge'&&tableState.data)tableView(tableState.data);}
  if(event==='bridge_preview'){const b=tableState.bridge;b.preview=data;b.skip=new Set();b.shown=200;if(tableState.panel==='bridge'&&tableState.data)tableView(tableState.data);}
  if(event==='rename_preview'){tableState.rename.preview=data;if(tableState.panel==='rename'&&tableState.data)tableView(tableState.data);}
  if(event==='table'){tableWaiters.splice(0).forEach(done=>done());}
  if(event==='images_progress')imagesProgress(data);
  if(event==='images_done')imagesDone(data);
  if(event==='images_changed')imagesChanged(data.items);
  if(event==='photo_settings')receivePhotoSettings(data);
  if(event==='image_preview')receivePreviewFrame(data);
  if(event==='preview_progress')receivePreviewProgress(data);
  if(event==='preview_done')receivePreviewDone(data);
  if(event==='image_data')receiveImageData(data);
  if(event==='tag_rules')receiveTagRules(data);
  if(event==='tag_auto_plan')receiveTagAutoPlan(data);
  if(event==='tag_tree')receiveTagTree(data);
  if(event==='tag_sample')receiveTagSample(data);
  if(event==='tag_paint')receiveTagPaint(data);
  if(event==='tag_excel')receiveTagExcel(data);
  if(event==='tag_delete_preview')receiveTagDeletePreview(data);
  if(event==='folder_rules')receiveFolderRules(data);
  if(event==='folder_auto_plan')receiveFolderAutoPlan(data);
  if(event==='progress')message(`Đang quét… ${number(data.count,0)} đối tượng hình học.`);
  if(event==='message')message(data.error||data.text,!!data.error);
  if(event==='preview')preview(data);
  if(event==='export_done')showExportDone(data);
  if(event==='selection'){const text=$('tag-selection-text'),go=$('tag-assign');if(text)text.textContent=`Đang chọn ${data.count} đối tượng hoặc mặt trong SketchUp.`;if(go){go.dataset.count=String(data.count);go.disabled=!data.count;}}
}};
$('export-done-close').onclick=()=>$('export-done').close();$('export-done-open').onclick=()=>{$('export-done').close();call('export_open')};$('export-done-folder').onclick=()=>{$('export-done').close();call('export_open_folder')};
$('cancel-preview').onclick=()=>$('preview').close();$('confirm-preview').onclick=()=>{$('confirm-preview').disabled=true;$('preview').close();call('confirm_convert')};document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>call('open_panel',b.dataset.mode));
document.addEventListener('vgdtheme',e=>{const dark=e.detail.theme==='dark';document.body.classList.toggle('dark',dark);document.body.classList.toggle('light',!dark);$('brand-logo').src=dark?'../assets/icons/vgd_primary_dark.svg':'../assets/icons/vgd_primary_light.svg';});
VGDTheme.start({key:'VGD_BIM_theme',button:$('theme')});
document.addEventListener('DOMContentLoaded',()=>call('ready'));
