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
const settings=lang=>({language:lang,image_dir:'',image_size:512,image_background:'transparent',capture_mode:'isolate',length_unit:'mm'});
const config=(lang,mode)=>({mode,version:'1.1.0',language:lang,settings:settings(lang),fields:F.fields,categories:F.categories,units:F.units,methods:F.methods,presets,locale:lang==='en'?F.en:F.vi,vi_en:lang==='en'?F.vi_en:null,scan_options:{scope:'model',faces:true}});
const rows=[0,1,2].map(i=>({index:i,entity_type:i?'Thành phần':'Nhóm',definition:'Cabinet',name:'Cab '+i,description:'Oak',lenX:1200,lenY:600,lenZ:800,areaXZ:0.96,areaXY:0.72,areaFace:2.1,volume:0.5,tag:'Tag'+i,tag_group:F.groups[i%3],material:'Oak',status:['new','existing','reuse'][i],locked:i===2,quantity:1,parents:[],parent:i?'Parent A':'',pid:900+i,has_image:i===0,image_stamp:5}));
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
  await receive('tags',{groups:F.groups.slice(0,5),tags:[{name:'A',group:F.groups[0],in_model:true,visible:false},{name:'B',group:F.groups[1],in_model:false},{name:'C',group:F.groups[1],in_model:true,visible:true}],selection:3});await scan('Soạn tag');
  const table=cfg=>({columns:F.columns,presets:F.presets,groups:F.groups,statuses:F.statuses,options:{zoom:true,isolate:false,deep:false,isolating:false},rows,selected:[],hint:null,view:{},choices:{tags:['Tag0','Tag1'],materials:['Oak']},...cfg});
  await receive('config',config(lang,'table'));
  await receive('table',table({selected:[0]}));await scan('Bảng');
  await page.evaluate(()=>{for(const p of ['columns','presets','group','rename']){tableState.panel=p;tableView(tableState.data);}});
  for(const p of ['columns','presets','group','rename']){await page.evaluate(p=>{tableState.panel=p;tableView(tableState.data);},p);await scan('Bảng ('+p+')');}
  await page.evaluate(()=>{tableState.rename.preview={counts:{ok:2,same:1,locked:1,empty:1,long:1,duplicate:1},rows:[{old:'a',new:'b',status:'ok',duplicate:true},{old:'',new:'',status:'empty'},{old:'x',new:'x',status:'same'},{old:'y',new:'y',status:'locked'},{old:'z',new:'z',status:'long'}]};tableState.panel='rename';tableView(tableState.data);});await scan('Bảng (xem trước đổi tên)');
  await page.evaluate(()=>{tableState.panel=null;tableState.groupBy='parent';tableState.merge=true;tableView(tableState.data);});await scan('Bảng (nhóm)');
  for(const g of ['entity','definition','instance','material','tag','tag_group','status']){await page.evaluate(g=>{tableState.groupBy=g;tableView(tableState.data);},g);await scan('Bảng (nhóm '+g+')');}
  await page.evaluate(()=>{tableState.groupBy='';tableState.merge=false;tableState.visible=new Set(tableState.data.columns.map(c=>c.key));tableState.order=tableState.data.columns.map(c=>c.key);tableView(tableState.data);});await scan('Bảng (mọi cột)');
  await page.locator('.grid tbody tr').nth(1).locator('td[data-key="tag"]').dblclick();await scan('Bảng (menu tag)');
  await page.keyboard.press('Escape');
  await page.evaluate(()=>{message('x');});
  await receive('config',config(lang,'images'));
  await receive('images',{rows:rows.map(r=>({...r})),hint:null,settings:{settings:settings(lang),dir:'C:\\x',dir_exists:false},busy:false});await scan('Hình ảnh');
  await receive('images_progress',{done:1,total:3});await scan('Hình ảnh (đang chụp)');
  await receive('images_done',{done:3,total:3,ok:2,errors:['Cab 1: không chụp được.'],cancelled:false});await scan('Hình ảnh (xong)');
  await receive('images_done',{done:1,total:3,ok:1,errors:[],cancelled:true});await scan('Hình ảnh (dừng)');
  await receive('images',{rows:[],hint:'Chưa chọn đối tượng nào. Chọn group hoặc component trong SketchUp để xem và chụp ảnh.',settings:{settings:settings(lang),dir:'C:\\x',dir_exists:true},busy:false});await scan('Hình ảnh (trống)');
  await receive('config',config(lang,'settings'));
  await receive('settings',{settings:settings(lang),dir:'C:\\x',dir_exists:false});await scan('Cài đặt');
  await receive('settings',{settings:settings(lang),dir:'C:\\x',dir_exists:true});await scan('Cài đặt (có thư mục)');
  await messages([
    'Đã lưu cài đặt.','Đang chụp ảnh. Hãy đợi xong hoặc bấm Dừng.','Không có đối tượng nào cần chụp.','Mỗi lần chỉ chụp tối đa 200 đối tượng. Hãy chọn ít hơn.','Ngôn ngữ không hợp lệ.',
    'Cỡ ảnh phải từ 128 đến 4096 điểm ảnh.','Thư mục ảnh phải là đường dẫn đầy đủ (ví dụ C:\\Anh\\NoiThat).','Ảnh quá lớn (tối đa 8 MB).','Dữ liệu không phải ảnh PNG.','Không đọc được ảnh.',
    'Đã cập nhật 3 đối tượng; bỏ qua 1 đối tượng bị khóa.','Đã sửa tên cho 2 đối tượng. Bỏ qua 1 đối tượng bị khóa.','Đã đổi tên 5 đối tượng. Bỏ qua 1 đối tượng bị khóa. Có 2 dòng trùng tên.',
    'Đã gán tag "Door" cho 4 đối tượng. Bỏ qua 1 đối tượng bị khóa. Tag này đang tắt hiển thị nên các đối tượng gán vào sẽ bị ẩn.','Đã lưu preset "Cab".','Đã xuất 5 tag: C:\\a.csv','Đã nhập 4 tag. Bộ tag hiện có 9 tag.',
    'Đã chuyển đổi 7 đối tượng. Đã lưu quy tắc phân loại.','Đã xuất 12 dòng. Mở bằng Excel: C:\\a.csv','Dòng 3: Nhóm không hợp lệ: Zzz','Tên tag quá dài (tối đa 60 ký tự): abc','Tên tag bị trùng: abc',
    'Mô hình đã thay đổi. Hãy làm mới trước khi tiếp tục.','Bảng đã cũ. Hãy làm mới bảng.','Số bắt đầu phải là số nguyên từ 0 đến 99999.','Chỉ số dòng không hợp lệ.','Không ghi được tệp. Kiểm tra vị trí lưu và đóng tệp nếu đang mở trong Excel.',
    'Các dòng nằm ở cấp lồng khác nhau nên SketchUp chỉ chọn dòng cuối. Đổi tên vẫn áp dụng cho mọi dòng đã chọn trong bảng.','Hãy đánh dấu ít nhất một trường cần cập nhật.','Đối tượng đang bị khóa nên không sửa được.',
    'Đối tượng nằm trong thành phần dùng chung nhiều nơi nên không cô lập được.','Quy tắc phải là một danh sách.','Mục đưa vào bảng khối lượng phải là Có hoặc Không.']);
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
