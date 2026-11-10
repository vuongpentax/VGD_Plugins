// Kiểm tra bản dịch tiếng Anh của giao diện VGD_BIM: mọi tab, mọi bảng chọn, thông báo phải hết chữ có dấu tiếng Việt.
// Dùng dữ liệu thật do Ruby sinh ra (dev/ui_fixture.rb). Chạy: node dev/test_ui_en.cjs (đặt VGD_PLAYWRIGHT_MODULE nếu cần)
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),{execFileSync}=require('child_process');
const {chromium}=require(process.env.VGD_PLAYWRIGHT_MODULE || 'playwright');
const fail=m=>{console.log('FAIL  '+m);process.exitCode=1;},pass=m=>console.log('PASS  '+m);
const F=JSON.parse(execFileSync('ruby',[path.resolve(__dirname,'ui_fixture.rb')],{encoding:'utf8'}));
const presets=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../runtime/vgd_bim/config/presets.json'),'utf8'));
const VIET=/[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]/i;
// Chữ tiếng Việt được phép còn lại: mã mẫu đổi tên (là cú pháp), tên ngôn ngữ, ví dụ tên cột trong thông báo nhập tag.
const ALLOWED=new Set(['{tên}','{họ}','{phân loại}','{nhóm}','{số}','Tiếng Việt']);
const config=(lang,mode)=>({mode,version:'1.1.0',language:lang,app:{settings:{language:lang,image_dir:'',exclude_words:'tay nam, handle'},dir:'C:\\data\\images',dir_exists:false},preset_info:F.preset_info,table:{columns:F.columns,presets:F.presets,view:{}},fields:F.fields,categories:F.categories,units:F.units,methods:F.methods,presets,locale:lang==='en'?F.en:F.vi,vi_en:lang==='en'?F.vi_en:null,scan_options:{scope:'model',faces:true}});
const rows=[0,1,2].map(i=>({index:i,entity_type:i?'Thành phần':'Nhóm',definition:'Cabinet',name:'Cab '+i,description:'Oak',lenX:1200,lenY:600,lenZ:800,areaXZ:0.96,areaXY:0.72,areaFace:2.1,volume:0.5,tag:'Tag'+i,tag_group:'Phần thô',material:'Oak',status:['new','existing','reuse'][i],locked:i===2,quantity:1,parents:[],parent:i?'Parent A':'',pid:900+i,has_image:i===0,image_stamp:5,areaProjected:1.5,ifc:'IfcWall',owner:'Hafele',url:'https://a.vn',size:'1x2',price:1000,total:1000}));
(async()=>{
 const browser=await chromium.launch({headless:true,channel:process.env.VGD_BROWSER_CHANNEL||undefined});
 try{
  const lang=process.argv[2]||'en';
  const page=await browser.newPage({viewport:{width:1100,height:800}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{window.calls=[];window.sketchup=new Proxy({}, {get:(_,name)=>(...args)=>window.calls.push({name,args})})});
  await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_bim/html/index.html')).href);
  const receive=(event,data)=>page.evaluate(([e,d])=>window.VGD.receive(e,d),[event,data]);
  const found=new Map();
  const scan=async label=>{
    await page.waitForTimeout(30);
    const texts=await page.evaluate(()=>{
      const out=[];const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);
      while(walker.nextNode()){const n=walker.currentNode;if(n.parentElement.closest('script,style,textarea'))continue;out.push(n.nodeValue.trim());}
      document.querySelectorAll('[placeholder],[title],[aria-label],[alt]').forEach(el=>['placeholder','title','aria-label','alt'].forEach(a=>{if(el.hasAttribute(a))out.push(el.getAttribute(a));}));
      return out;
    });
    texts.filter(t=>t&&VIET.test(t)&&!ALLOWED.has(t)).forEach(t=>{if(!found.has(t))found.set(t,label);});
  };
  const messages=async list=>{for(const text of list){await receive('message',{text});await scan('message');await receive('message',{error:text});await scan('message');}};

  await receive('config',config(lang,'information'));
  await receive('information',{count:2,fields:{category:null,item_type:'socket',description:null,unit:'pcs',quantity_method:'count',include_boq:true},objects:[{entity_type:'Group',source:'RAW',instance_name:'',definition_name:'Def',tag:'ELEC',material:'',dimensions:{width:120,depth:50,height:80},locked:false,status:'UNCLASSIFIED'}]});
  await scan('Thông tin');
  await receive('information',{count:0,fields:{},objects:[]});await scan('Thông tin (trống)');
  await receive('config',config(lang,'scan'));
  await receive('scan',{summary:{groups:2,components:3,definitions:4,materials:1,tags:2,vgd_objects:1,unclassified:5,coverage:20,raw_faces:99},components:[{definition_name:'',names:['A'],instances:3,tags:['T'],material:'',dimensions:{width:100,depth:50,height:30},dimension_variants:3}],materials:[{material:'(Unpainted)',area:1.5,back_area:0,faces:4}],export:{objects:12,faces:340}});await scan('Quét & xuất');
  await page.evaluate(()=>{config.scan_options.faces=false;scanOptionsBar($('content'));});await scan('Quét (tắt mặt)');
  await receive('config',config(lang,'mapping'));
  const map={index:0,source_type:'definition_name',source_value:'O_CAM',kind:'object',instances:28,eligible:28,protected:2,suggestion:{data:{category:'electrical',item_type:'socket',unit:'pcs',quantity_method:'count'},confidence:'HIGH',source:'HEURISTIC'},status:'READY'};
  await receive('mapping',[map,{...map,index:1,kind:'material',source_value:''}]);await scan('Phân loại');
  await page.getByRole('button',{name:/Chỉnh thông tin|Edit information/}).first().click();await scan('Phân loại (sửa)');
  await receive('preview',{objects:28,occurrences:30,skipped:2,data:map.suggestion.data,rule:true,shared:true,material:true});await scan('Xem trước');
  await receive('config',config(lang,'validate_model'));
  const vf=F.vi.fields,m=F.vi.quantity_method,u=F.vi.unit;
  await receive('validation',[{index:0,status:'ERROR',instance_name:'',definition_name:'D',issues:[
    {severity:'ERROR',message:`Thiếu ${vf.description.toLowerCase()}`},{severity:'ERROR',message:`${vf.code} phải là văn bản`},{severity:'ERROR',message:`${vf.unit} không hợp lệ`},
    {severity:'ERROR',message:`${m.count} cần đơn vị ${u.pcs} / ${u.set}`},{severity:'WARNING',message:'Chưa nhập mã hạng mục'},{severity:'WARNING',message:'Chưa gán khu vực / phòng'},{severity:'INFO',message:'Chưa phân loại'}]}]);await scan('Kiểm tra');
  await receive('config',config(lang,'rules'));
  await receive('rules',[{source_type:'definition_name',source_value:'X',data:{category:'electrical',item_type:'socket'}}]);await scan('Quy tắc');
  await page.getByRole('button',{name:/Thêm quy tắc|Add rule/}).first().click();await scan('Quy tắc (thêm)');
  await receive('config',config(lang,'tags'));
  await receive('tags',{groups:F.groups.slice(0,5),tags:[{name:'A',group:F.groups[0],in_model:true,visible:false},{name:'B',group:F.groups[1],in_model:false},{name:'C',group:F.groups[1],in_model:true,visible:true}],selection:3,rules:[{tag:'Tường',keywords:'tường, wall'},{tag:'Cửa',keywords:'cửa, door'}],catalog:[{group:'A. ARCHITECTURAL',label_vi:'Kiến trúc',count:15,tags:['A. CHIMNEY','A. WALL']},{group:'F. FIRE PROTECTION',label_vi:'Phòng cháy chữa cháy',count:1,tags:['F. FIRE SUPPRESSION']}]});await scan('Soạn tag');
  await receive('tag_tree',{supported:true,isolated:{kind:'tag',id:12,name:'A. DOOR'},folders:[{id:1,name:'A. ARCHITECTURAL',visible:true,parent_id:null},{id:2,name:'S. STRUCTURAL',visible:false,parent_id:null}],layers:[{id:10,name:'A. WALL',visible:true,folder_id:1},{id:11,name:'A. WINDOW',visible:false,folder_id:1},{id:12,name:'A. DOOR',visible:true,folder_id:null}]});
  await scan('Soạn tag (trong model)');
  await page.locator('.tm-row[data-kind=folder]').first().locator('.tm-caret').click();await scan('Soạn tag (trong model, mở thư mục)');
  await receive('tag_tree',{supported:true,styles_supported:true,line_styles:['Solid Line'],color_by_tag:true,isolated:null,pinned:['A. WALL','X. OLD'],recent:['A. DOOR','A. WALL'],folders:[],layers:[{id:10,name:'A. WALL',visible:true,folder_id:null,color:'#c0392b',line_style:''}]});await scan('Soạn tag (trong model, màu và nét)');
  await receive('tag_delete_preview',{id:10,name:'A. WALL',count:4});await scan('Soạn tag (xóa tag)');
  await page.locator('#tag-tree-delete').getByRole('button').last().click();
  await receive('tag_excel',{file:'tags.xlsx',styles_supported:true,folders_supported:true,more_warnings:3,warnings:['Dòng 4: thiếu tên tag, bỏ qua.','Dòng 5: tên tag quá dài (tối đa 60 ký tự), bỏ qua.','Dòng 6: Untagged là tag mặc định của SketchUp, bỏ qua.','Dòng 7: tag "A. WALL" bị trùng, bỏ qua.','Dòng 8: màu "xanh" không đọc được, bỏ qua màu.','Dòng 9: tên thư mục không hợp lệ, bỏ thư mục.'],rows:[{name:'A. WALL',color:'#ff0000',style:'Dash',folder:'A. ARCHITECTURAL',exists:false},{name:'A. DOOR',color:null,style:'',folder:'',exists:true}]});await scan('Soạn tag (nhập Excel)');
  await page.locator('#tag-excel-actions').getByRole('button').last().click();
  await page.locator('#tag-pane-model input[type=search]').fill('wall');await scan('Soạn tag (trong model, tìm)');await page.locator('#tag-pane-model input[type=search]').fill('zzz');await scan('Soạn tag (trong model, không khớp)');
  await receive('tag_tree',{supported:false,isolated:null,folders:[],layers:[]});await scan('Soạn tag (trong model, SketchUp cũ)');
  await page.click('#tag-tab-set');
  await page.locator('.tag-group summary').first().click();await scan('Soạn tag (mở nhóm)');
  await page.locator('#tag-pane-set input[type=search]').fill('wall');await scan('Soạn tag (tìm)');await page.locator('#tag-pane-set input[type=search]').fill('');
  await page.click('#tag-tab-lib');await scan('Soạn tag (thư viện)');
  await page.getByLabel('A. ARCHITECTURAL',{exact:true}).check();await scan('Soạn tag (đã tick cụm)');await page.getByLabel('A. ARCHITECTURAL',{exact:true}).uncheck();
  await page.click('#tag-tab-auto');await scan('Soạn tag (tự động, gập)');await page.locator('.rule-fold>summary').first().click();await page.locator('.rule-fold>summary').nth(1).click();await scan('Soạn tag (tự động, mở bảng luật)');
  await receive('tag_auto_plan',{total:5,assign:2,same:1,kept:1,unmatched:1,locked:1,rules:[{tag:'Wall',count:1,samples:['Wall 1']},{tag:'Door',count:4,samples:['Door_900','Door_2','Door_3']}]});await scan('Soạn tag (xem trước gắn tự động)');
  await receive('tag_auto_plan',{total:5,assign:0,same:5,kept:0,unmatched:0,locked:0,rules:[]});await scan('Soạn tag (không cần gắn)');
  await receive('folder_rules',{rules:[{folder:'A. ARCHITECTURAL',keywords:'A.'},{folder:'# BASIC',keywords:'#, edge'}]});await scan('Soạn tag (thư mục)');
  await receive('folder_auto_plan',{total:7,assign:3,same:1,kept:2,unmatched:1,rules:[{tag:'A. ARCHITECTURAL',count:3,samples:['A. WALL','A. DOOR']},{tag:'# BASIC',count:1,samples:['Edge']}]});await scan('Soạn tag (xem trước thư mục)');
  await receive('folder_auto_plan',{total:7,assign:0,same:7,kept:0,unmatched:0,rules:[]});await scan('Soạn tag (không cần xếp thư mục)');
  const table=cfg=>({columns:F.columns,presets:F.presets,groups:F.groups,statuses:F.statuses,options:{zoom:true,isolate:false,deep:false,projected:false,isolating:false},rows,selected:[],hint:null,view:{},choices:{tags:['Tag0','Tag1'],materials:['Oak']},...cfg});
  await receive('config',config(lang,'table'));
  const ids=rows.map(r=>r.pid).filter(Number.isInteger);
  await receive('table',table({selected:[0],row_order:ids.slice(0,2).reverse()}));await scan('Bảng');
  if(!(ids.length>1&&await page.locator('#order-reset').count()===1&&await page.locator('.row-grip').count()>0))throw Error('Manual row order controls (grip, clear button) did not show in the table fixture');
  await page.evaluate(()=>{for(const p of ['columns','presets','group','rename']){tableState.panel=p;tableView(tableState.data);}});
  for(const p of ['columns','presets','group','rename']){await page.evaluate(p=>{tableState.panel=p;tableView(tableState.data);},p);await scan('Bảng ('+p+')');}
  // Khung thông số ảnh riêng của một món (nút ⚙): ảnh chính và ảnh vị trí
  await page.evaluate(()=>{tableState.panel=null;tableView(tableState.data);});
  for(const [column,label] of [['image','Khung thông số ảnh chính'],['image_location','Khung thông số ảnh vị trí']]){
    const opened=await page.evaluate(column=>{const td=document.querySelector(`.grid tbody tr td[data-key="${column}"]`);if(!td)return false;const gear=[...td.querySelectorAll('.cell-tool')].find(b=>b.textContent==='⚙');if(!gear)return false;gear.click();return !!document.querySelector('.photo-pop');},column);
    if(opened){await scan(label);await page.keyboard.press('Escape');}
    else if(column==='image')throw Error('Photo settings gear (⚙) did not open the panel in the table fixture');
  }
  await page.evaluate(()=>{tableState.rename.preview={counts:{ok:2,same:1,locked:1,empty:1,long:1,duplicate:1},rows:[{old:'a',new:'b',status:'ok',duplicate:true},{old:'',new:'',status:'empty'},{old:'x',new:'x',status:'same'},{old:'y',new:'y',status:'locked'},{old:'z',new:'z',status:'long'}]};tableState.panel='rename';tableView(tableState.data);});await scan('Bảng (xem trước đổi tên)');
  await page.evaluate(()=>{tableState.panel=null;tableState.groupBy='parent';tableState.merge=true;tableView(tableState.data);});await scan('Bảng (nhóm)');
  for(const g of ['entity','definition','instance','material','tag','tag_group','status']){await page.evaluate(g=>{tableState.groupBy=g;tableView(tableState.data);},g);await scan('Bảng (nhóm '+g+')');}
  await page.evaluate(()=>{tableState.groupBy='';tableState.merge=false;tableState.visible=new Set(tableState.data.columns.map(c=>c.key));tableState.order=tableState.data.columns.map(c=>c.key);tableView(tableState.data);});await scan('Bảng (mọi cột)');
  await page.locator('.grid tbody tr').nth(1).locator('td[data-key="tag"]').dblclick();await scan('Bảng (menu tag)');
  await page.keyboard.press('Escape');
  await page.evaluate(()=>{message('x');});
  // Thanh đầu: bảng preset, bánh răng, hộp xác nhận chụp ảnh, menu Nhập / Xuất, Thay thế
  await receive('config',config(lang,'table'));await receive('table',table());
  await page.click('#preset-btn');await scan('Bảng preset');
  await page.locator('#preset-panel .pp-pick').nth(5).click();await scan('Bảng preset (Phòng & Khu vực)');
  await page.keyboard.press('Escape');await scan('Bảng (preset Phòng & Khu vực)');
  await page.click('#gear');await scan('Bánh răng');await page.keyboard.press('Escape');
  await page.evaluate(()=>{tableState.panel='capture';tableView(tableState.data);});await scan('Hộp xác nhận chụp ảnh');
  await page.evaluate(()=>{tableState.panel='io';tableView(tableState.data);});await scan('Menu Nhập / Xuất');
  await page.evaluate(()=>{tableState.panel=null;tableView(tableState.data);});
  await page.evaluate(()=>{window.calls.length=0;exportTable('xlsx');});
  const exported=await page.evaluate(()=>JSON.parse(window.calls.filter(c=>c.name==='table_export').pop().args[0]));
  const english=lang==='en';
  if(exported.title===(english?'Quantity table':'Bảng khối lượng') && exported.labels.model===(english?'Model':'Mô hình') && exported.labels.print===(english?'Print / Save PDF':'In / Lưu PDF') && exported.rows[exported.rows.length-1].cells.some(c=>c===(english?'Total · 3 objects':'Tổng cộng · 3 đối tượng')) && (!english||!exported.columns.some(c=>VIET.test(c.label)&&!ALLOWED.has(c.label))))pass('Dữ liệu xuất Excel / PDF theo ngôn ngữ đang dùng (tiêu đề, nhãn, dòng tổng, tiêu đề cột)');
  else fail('Dữ liệu xuất sai ngôn ngữ: '+JSON.stringify({t:exported.title,l:exported.labels,total:exported.rows[exported.rows.length-1].cells,cols:exported.columns.map(c=>c.label)}));
  await page.fill('.search-wrap input','cab');await scan('Thay thế');
  await page.fill('.search-wrap input','');
  await page.evaluate(()=>{captureState.busy=true;captureState.done=1;captureState.total=3;syncBusy();});await scan('Đang chụp');
  await page.evaluate(()=>{captureState.busy=false;syncBusy();});
  await receive('images_progress',{done:1,total:3});await scan('Đang chụp (tiến độ)');
  await receive('images_done',{done:3,total:3,ok:2,errors:['Cab 1: lỗi NoMethodError: undefined method `bounds` for nil (chi tiết trong capture.log)'],notes:['nền trong suốt không dùng được trên máy này nên ảnh dùng cách thay thế','khử răng cưa không dùng được trên máy này nên ảnh dùng cách thay thế'],cancelled:false});await scan('Chụp xong');
  await receive('images_done',{done:1,total:3,ok:1,errors:[],cancelled:true});await scan('Chụp dừng');
  await page.evaluate(()=>{tableState.data.rows.forEach((r,i)=>{r.measure_note=['Left out','Bỏ 2 phần theo từ khóa hoặc tag (Tay nam, Handle_128)','Bỏ 1 phần theo từ khóa hoặc tag (knob)'][i%3]==='Left out'?'':['','Bỏ 2 phần theo từ khóa hoặc tag (Handle_128, knob)','Bỏ 1 phần theo từ khóa hoặc tag (knob)'][i%3];});});
  await page.evaluate(()=>{tableState.data.rows.forEach((r,i)=>{r.front=['+Y','-X','+X'][i%3];r.front_state=['Tự động · cao','Cần duyệt','Thủ công'][i%3];r.front_note=['sát tường phía -y; mặt có nhiều chi tiết nhất','ở góc tường (hai mặt kề sát tường); chưa đủ bằng chứng, cần duyệt','món lệch góc so với trục, mặt trước chỉ gần đúng; chỉ đọc 4000 mặt đầu tiên của món (lấy mẫu)'][i%3];});tableState.panel='front';tableState.sel=new Set();tableView(tableState.data);});await scan('Bảng Mặt trước');
  await page.evaluate(()=>{tableState.panel=null;tableState.sel=new Set([0]);tableView(tableState.data);tableState.panel='front';tableView(tableState.data);});await scan('Bảng Mặt trước (đã chọn dòng)');
  await page.evaluate(()=>{tableState.panel='front';tableState.sel=new Set([0]);tableState.alignPlan={key:[0],fix:2,instances:5,aligned:1,skipped:3,reasons:[{reason:'component động',count:2},{reason:'chưa có mặt trước',count:1},{reason:'có bản sao bị khóa',count:1},{reason:'có bản sao bị lật gương',count:1},{reason:'là ảnh',count:1},{reason:'không có hình bên trong',count:1},{reason:'không có bản sao nào trong model',count:1},{reason:'nằm trong đối tượng bị khóa',count:1}],names:['Cabinet A','Cabinet B']};tableView(tableState.data);});await scan('Sửa trục (xem trước)');
  await page.evaluate(()=>{tableState.alignPlan={key:[0],fix:0,instances:0,aligned:0,skipped:0,reasons:[],names:[]};tableView(tableState.data);});await scan('Sửa trục (không có gì)');
  await page.evaluate(()=>{tableState.alignPlan=null;tableState.panel=null;tableState.sel=new Set();tableView(tableState.data);});
  await page.evaluate(()=>{tableState.data.choices={tags:[],materials:[],model_tags:['Door','Counter','Handle']};config.app.settings.exclude_tags=['Counter','Old tag'];tableState.excludeTags=null;tableState.panel='exclude';tableView(tableState.data);});await scan('Ngăn Loại trừ tag');
  await page.evaluate(()=>{const s=document.querySelector('.col-side .pop-search');s.value='zzz';s.dispatchEvent(new Event('input'));});await scan('Loại trừ tag (không khớp)');
  await page.evaluate(()=>{tableState.excludeSearch='';tableState.panel=null;tableView(tableState.data);});
  await page.evaluate(()=>{tableState.panel=null;tableState.sel=new Set();tableState.groupBy='front_state';tableView(tableState.data);});await scan('Nhóm theo Mặt trước');
  await page.evaluate(()=>{tableState.groupBy='';tableView(tableState.data);});
  await page.evaluate(()=>{for(const k of tableState.data.columns.map(c=>c.key))tableState.visible.add(k);tableState.order=tableState.data.columns.map(c=>c.key);tableView(tableState.data);});await scan('Bảng (mọi cột mới)');
  await page.locator('.grid tbody tr').nth(0).locator('td[data-key="price"]').hover();
  await messages([
    'Đã lưu cài đặt.','Đang chụp ảnh. Hãy đợi xong hoặc bấm Dừng.','Không có đối tượng nào cần chụp.','Mỗi lần chỉ chụp tối đa 200 đối tượng. Hãy chọn ít hơn.','Ngôn ngữ không hợp lệ.',
    'Cỡ ảnh phải từ 128 đến 4096 điểm ảnh.','Thư mục ảnh phải là đường dẫn đầy đủ (ví dụ C:\\Anh\\NoiThat).','Ảnh quá lớn (tối đa 8 MB).','Dữ liệu không phải ảnh PNG.','Không đọc được ảnh.',
    'Đã thay chữ trong 3 ô của 2 đối tượng. Bỏ qua 1 đối tượng bị khóa.','Chữ cần tìm hoặc chữ thay thế quá dài (tối đa 200 ký tự).','Hãy chọn cột cần thay: chỉ có Tên, Mô tả, Xuất xứ, Quy cách.','Không có ô nào chứa chữ cần tìm.','Hãy nhập chữ cần tìm.','Link phải bắt đầu bằng http:// hoặc https://, không có khoảng trắng, tối đa 500 ký tự.','Cỡ tối đa 100 ký tự.','Đơn giá phải là số không âm, ví dụ 1250000 hoặc 12,5 (không dùng dấu chấm ngăn cách hàng nghìn).','Link không hợp lệ.','Không ghi được vào thư mục ảnh C:\\Anh. Hãy chọn thư mục khác trong bảng Preset.','SketchUp không chụp được ảnh (đã thử 3 cách). File: C:\\Anh\\1.tmp.png, cỡ 512 x 512. Kiểm tra thư mục lưu ảnh và quyền ghi.',
    'Đã nhập 3 preset.','Đã xác định mặt trước cho 5 loại: tin cậy cao 2, trung bình 2, cần duyệt 1. Chưa xác định được 2 loại (cần đặt tay). Bỏ qua 1 đối tượng đã đặt tay. Bỏ qua 3 đối tượng bị khóa. (12 đối tượng được xem xét)','Đã xác định mặt trước cho 1 loại: tin cậy cao 1, trung bình 0, cần duyệt 0.','Đã đặt mặt trước cho 4 loại (thủ công). Bỏ qua 1 đối tượng chưa có mặt trước. Bỏ qua 2 đối tượng bị khóa.','Đã xóa mặt trước của 3 loại.','Mỗi lần phát hiện tối đa 500 đối tượng. Hãy chọn ít hơn.','Cách đặt mặt trước không hợp lệ.','Hướng mặt trước không hợp lệ.','Đối tượng đang bị khóa nên không đặt được mặt trước.','Đối tượng đang bị khóa nên không xóa được mặt trước.','Các bản sao của cùng một component đang cho hướng khác nhau. Hãy chọn từng bản sao.','Không xác định được hướng nhìn ngang của camera. Hãy xoay camera nhìn vào mặt trước của món (không nhìn thẳng từ trên xuống).','Chưa có mặt trước để xoay / đảo. Hãy phát hiện hoặc đặt tay trước.','Chưa có đối tượng nào trong bảng.','Danh sách tag loại trừ không hợp lệ.','Tối đa 300 tag loại trừ, mỗi tên không quá 100 ký tự.','Bỏ 2 phần theo từ khóa hoặc tag (Counter, knob)','Danh sách từ khóa tối đa 200 ký tự.','Tối đa 12 từ khóa, mỗi từ không quá 40 ký tự.','Đã sửa trục cho 3 loại (7 bản sao): mặt trước giờ là -Y, hình trong model không đổi chỗ.','Đã sửa trục cho 1 loại (2 bản sao): mặt trước giờ là -Y, hình trong model không đổi chỗ. Bỏ qua 4 loại.','Hãy chọn các món cần sửa trục trong bảng.','Không có món nào cần sửa trục. Bấm Xem trước để biết lý do.','Mỗi lần sửa trục tối đa 500 đối tượng. Hãy chọn ít hơn.','Đã xuất 2 preset: C:\\a.json','File preset quá lớn.','File không phải JSON hợp lệ.','Thiết lập của preset không hợp lệ.','Đơn vị diện tích không hợp lệ.','Đơn vị thể tích không hợp lệ.','Dấu thập phân không hợp lệ.','Tiền tệ không hợp lệ.','Góc nhìn của ảnh không hợp lệ.','Kiểu hiển thị của ảnh không hợp lệ.','Số chữ số lẻ phải từ 0 đến 4.','Tiêu đề cột không hợp lệ.','Tiêu đề cột phải là chữ.','Tiêu đề cột tối đa 60 ký tự.','Tệp preset không đúng định dạng.','Phiên bản tệp preset chưa được hỗ trợ.','Quá nhiều preset (tối đa 100).','Tệp không có preset hợp lệ nào.','Chưa có preset tự tạo để xuất. Bấm + trong bảng preset để lưu một preset.','Bảng quá lớn để xuất.','Dữ liệu bảng không hợp lệ.','Thiết lập của preset không hợp lệ.','Tên preset quá dài (tối đa 40 ký tự).','Đã cập nhật 3 đối tượng; bỏ qua 1 đối tượng bị khóa.','Đã sửa tên cho 2 đối tượng. Bỏ qua 1 đối tượng bị khóa.','Đã đổi tên 5 đối tượng. Bỏ qua 1 đối tượng bị khóa. Có 2 dòng trùng tên.',
    'Đã gán tag "Door" cho 4 đối tượng. Bỏ qua 1 đối tượng bị khóa. Tag này đang tắt hiển thị nên các đối tượng gán vào sẽ bị ẩn.','Đã lưu preset "Cab".','Đã xuất 5 tag: C:\\a.csv','Đã nhập 4 tag. Bộ tag hiện có 9 tag.',
    'Đã chuyển đổi 7 đối tượng. Đã lưu quy tắc phân loại.','Đã xuất 12 dòng và 5 ảnh ra Excel: C:\\a.xlsx','Đã xuất 1 dòng ra Excel: C:\\a.xlsx','Đã tạo trang báo cáo 12 dòng và mở trong trình duyệt. Khi cần in, bấm nút In / Lưu PDF trên trang rồi chọn Lưu thành PDF.','Định dạng xuất không hợp lệ.','Dữ liệu bảng không hợp lệ.','Bảng chưa có dòng nào. Hãy chọn group hoặc component trong SketchUp.','Dòng 3: Nhóm không hợp lệ: Zzz','Tên tag quá dài (tối đa 60 ký tự): abc','Tên tag bị trùng: abc',
    'Mô hình đã thay đổi. Hãy làm mới trước khi tiếp tục.','Bảng đã cũ. Hãy làm mới bảng.','Số bắt đầu phải là số nguyên từ 0 đến 99999.','Chỉ số dòng không hợp lệ.','Không ghi được tệp. Kiểm tra vị trí lưu và đóng tệp nếu đang mở trong Excel.',
    'Các dòng nằm ở cấp lồng khác nhau nên SketchUp chỉ chọn dòng cuối. Đổi tên vẫn áp dụng cho mọi dòng đã chọn trong bảng.','Hãy đánh dấu ít nhất một trường cần cập nhật.','Đối tượng đang bị khóa nên không sửa được.',
    'Đối tượng nằm trong thành phần dùng chung nhiều nơi nên không cô lập được.','Quy tắc phải là một danh sách.','Mục đưa vào bảng khối lượng phải là Có hoặc Không.','Đã ẩn 4 đối tượng thuộc tag loại trừ.',
    'Đã lưu bộ luật gắn tag tự động làm mặc định.','Đã nhập 16 tag từ 2 cụm vào bộ tag (15 tag mới tạo trong model).','Hãy tick ít nhất một cụm.','Cụm không hợp lệ: X. OTHER','Lề ảnh phải từ 0 đến 100 (%).','Bên của góc Iso không hợp lệ.','Hãy chọn bên Iso là trái hoặc phải.','Đã đặt lại bộ luật về mặc định.','Đã xuất 9 luật: C:\\a.json','Đã nhập 9 luật từ file. Bộ luật chưa lưu làm mặc định.',
    'Đã gắn tag tự động cho 5 đối tượng (2 tag). Đã đúng tag sẵn: 1. Giữ nguyên 2 đối tượng đã có tag khác. Bỏ qua 3 đối tượng bị khóa. Tag đang tắt hiển thị nên đối tượng gắn vào sẽ bị ẩn: Door.',
    'Chưa có luật nào. Hãy thêm ít nhất một luật.','Hãy chọn group hoặc component trong SketchUp trước, hoặc bật "Cả model".','Quá nhiều đối tượng (tối đa 20000). Hãy chọn ít hơn.','Không có đối tượng nào cần gắn tag. Bấm Xem trước để biết lý do.',
    'Tùy chọn "Dựa theo" không hợp lệ.','Tùy chọn "Phạm vi" không hợp lệ.','Danh sách luật phải là một danh sách.','Tối đa 100 luật.','Dòng 2: Mỗi luật phải là một mục hợp lệ.','Dòng 1: Cần ít nhất một từ khóa.','Dòng 3: Từ khóa phải có ít nhất 2 ký tự.','Dòng 1: Mỗi luật tối đa 30 từ khóa, mỗi từ khóa không quá 40 ký tự.','File luật không đúng định dạng.','File không có luật nào.']);
  await messages(['Đã lấy tag "A. WALL". Chọn đối tượng rồi bấm Gán tag để gán.','Không bấm trúng đối tượng nào.','Đối tượng này chưa có tag (Untagged).','Bấm vào một đối tượng trong view để lấy tag của nó (Esc để hủy).','Đã xóa tag "A. WALL".','Đã xóa tag "A. WALL". Đã chuyển 4 đối tượng sang tag "A. DOOR".','Đã xóa tag "A. WALL". Các đối tượng đang dùng tag này đã về Untagged.','Mã tag nhận không hợp lệ.','Không tìm thấy tag nhận. Hãy làm mới danh sách.','Tag nhận phải khác tag cần xóa.','Tag Untagged không xóa được.']);
  await messages(['Đã chuyển tag "A. WALL" vào thư mục "S. STRUCTURAL".','Đã chuyển tag "A. WALL" ra ngoài thư mục.','Tag đã nằm sẵn ở đó.','Tag Untagged không xếp vào thư mục được.','Mã thư mục không hợp lệ.']);
  await messages(['Lưu ý: SketchUp báo vị trí group đang mở khác với vị trí tính từ các group cha. VGD_BIM dùng vị trí tính từ các group cha.','Màu không hợp lệ.','Kiểu nét không có trong model.','Phiên bản SketchUp này chưa có kiểu nét cho tag (cần SketchUp 2021 trở lên).','Giá trị không hợp lệ.']);
  await messages(['Hãy chọn file Excel đuôi .xlsx.','Chưa chọn tag nào để nhập.','File Excel quá lớn (tối đa 5 MB).','File không phải Excel (.xlsx) hợp lệ.','File Excel có quá nhiều phần.','File Excel có mã hóa, chưa đọc được.','File Excel có phần quá lớn.','File Excel dùng kiểu nén chưa hỗ trợ.','File Excel bị hỏng (không giải nén được).','Không đọc được trang tính đầu tiên.','File Excel không có dữ liệu.','Không tìm thấy dòng tiêu đề. Dòng đầu của bảng cần có cột "Name" (hoặc "Tên tag").','File không có tag nào để nhập.','Danh sách tag không hợp lệ.','Tên tag không được để trống.','File Excel có quá nhiều dòng (tối đa 5000).','Quá nhiều tag (tối đa 2000).','Tên tag không hợp lệ: X','Màu của tag "X" không hợp lệ.','Kiểu nét của tag "X" không hợp lệ.','Tên thư mục của tag "X" không hợp lệ.','Đã nhập 5 tag từ Excel (3 mới tạo, 2 cập nhật). Bỏ qua 1 tag đã có trong model. Đã tạo 2 thư mục tag. Kiểu nét không nhận ra, đã bỏ qua: Zigzag.','Đã nhập 1 tag từ Excel (1 mới tạo, 0 cập nhật).']);
  await messages(['Đã cô lập tag "A. WALL" (ẩn 3 tag khác). Bấm lại để khôi phục hiển thị.','Đã cô lập thư mục "A. ARCHITECTURAL" (ẩn 1 tag khác). Bấm lại để khôi phục hiển thị.','Đã khôi phục hiển thị tag như trước khi cô lập.','Giá trị hiển thị không hợp lệ.','Không tìm thấy tag hoặc thư mục này. Hãy làm mới danh sách.','Không tìm thấy tag này. Hãy làm mới danh sách.','Không tìm thấy thư mục này. Hãy làm mới danh sách.','Chưa cô lập gì để khôi phục.','Mã tag hoặc thư mục không hợp lệ.','Loại mục không hợp lệ.']);
  await messages(['Đã lưu bộ luật xếp thư mục làm mặc định.','Đã đặt lại bộ luật xếp thư mục về mặc định.','Đã xuất 18 luật: C:\\a.json','Đã nhập 18 luật từ file. Bộ luật chưa lưu làm mặc định.',
    'Đã xếp 12 tag vào 4 thư mục (3 thư mục mới tạo). Đã đúng thư mục sẵn: 2. Giữ nguyên 5 tag đã nằm trong thư mục khác.','Đã xếp 1 tag vào 1 thư mục (0 thư mục mới tạo).',
    'Phiên bản SketchUp này chưa có thư mục tag (cần SketchUp 2021 trở lên).','Chưa có tag nào trong model ngoài Untagged. Hãy nhập tag mẫu hoặc gán tag trước.','Không có tag nào cần xếp vào thư mục. Bấm Xem trước để biết lý do.',
    'Dòng 2: Hãy nhập tên thư mục.','Dòng 3: Tên thư mục không hợp lệ.','Dòng 1: Tên thư mục quá dài (tối đa 60 ký tự): X','Dòng 4: Cần ít nhất một từ khóa.','File JSON không đúng định dạng.']);
  if(errors.length)fail('Lỗi JavaScript: '+errors.join(' | '));
  if(lang==='en'){
    if(found.size)fail(`Còn ${found.size} chuỗi tiếng Việt chưa dịch:\n`+[...found].map(([t,l])=>`   [${l}] ${t}`).join('\n'));
    else pass('Giao diện tiếng Anh: mọi tab, bảng chọn và thông báo đã dịch hết');
    // Chuyển về tiếng Việt: nạp lại, không còn tiếng Anh dịch sót (nav tĩnh trong index.html)
    await receive('config',config('vi','table'));
  }else{
    if(await page.locator('nav').innerText().then(t=>/Quantity|Settings/.test(t)))fail('Tiếng Việt bị dịch nhầm');else pass('Giao diện tiếng Việt giữ nguyên, không bị dịch');
  }
 }finally{await browser.close();}
})().catch(e=>{console.log('FAIL  '+e.message);process.exit(1);});
