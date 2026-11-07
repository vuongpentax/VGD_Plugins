// Test giao diện: cột Ảnh, tab Hình ảnh, nút chụp (chỉ chạy khi bấm), kéo thả / dán ảnh, tab Cài đặt, đơn vị đo.
// Chạy: node dev/test_ui_images.cjs (đặt VGD_PLAYWRIGHT_MODULE nếu cần)
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),{execFileSync}=require('child_process');
const {chromium}=require(process.env.VGD_PLAYWRIGHT_MODULE || 'playwright');
let failed=0;
const ok=(cond,msg)=>{console.log((cond?'PASS  ':'FAIL  ')+msg);if(!cond){failed++;process.exitCode=1;}};
const F=JSON.parse(execFileSync('ruby',[path.resolve(__dirname,'ui_fixture.rb')],{encoding:'utf8'}));
const presets=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../runtime/vgd_bim/config/presets.json'),'utf8'));
const settings=(o={})=>({language:'vi',image_dir:'',image_size:512,image_background:'transparent',capture_mode:'isolate',length_unit:'mm',...o});
const config=(mode,o={})=>({mode,version:'1.1.0',language:'vi',settings:settings(o),fields:F.fields,categories:F.categories,units:F.units,methods:F.methods,presets,locale:F.vi,vi_en:null,scan_options:{scope:'model',faces:true}});
const rows=[0,1,2].map(i=>({index:i,entity_type:'Nhóm',definition:'Cabinet',name:'Cab '+i,description:'',lenX:1200,lenY:600,lenZ:800,areaXZ:0.96,areaXY:0.72,areaFace:2.1,volume:0.5,tag:'',tag_group:F.groups[2],material:'',status:'new',locked:false,quantity:1,parents:[],parent:'',pid:900+i,has_image:i!==1,image_stamp:7}));
const table=(o={})=>({columns:F.columns,presets:F.presets,groups:F.groups,statuses:F.statuses,options:{zoom:true,isolate:false,deep:false,isolating:false},rows,selected:[],hint:null,view:{preset:'Tất cả',order:F.columns.map(c=>c.key),visible:F.columns.map(c=>c.key),widths:{}},choices:{tags:[],materials:[]},...o});
const PNG1='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
(async()=>{
 const browser=await chromium.launch({headless:true,channel:process.env.VGD_BROWSER_CHANNEL||undefined});
 try{
  const page=await browser.newPage({viewport:{width:1100,height:800}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{window.calls=[];window.sketchup=new Proxy({}, {get:(_,name)=>(...args)=>window.calls.push({name,args})})});
  await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_bim/html/index.html')).href);
  const receive=(event,data)=>page.evaluate(([e,d])=>window.VGD.receive(e,d),[event,data]);
  const calls=name=>page.evaluate(n=>window.calls.filter(c=>c.name===n),name);
  const clear=()=>page.evaluate(()=>{window.calls.length=0;});
  const message=()=>page.locator('#message').innerText();
  const dropFile=(selector,{type='image/png',name='a.png',w=300,h=200}={})=>page.evaluate(async([sel,type,name,w,h])=>{
    const canvas=document.createElement('canvas');canvas.width=w;canvas.height=h;canvas.getContext('2d').fillRect(0,0,w,h);
    const blob=type.startsWith('image/')?await new Promise(r=>canvas.toBlob(r,type)):new Blob(['hello'],{type});
    const dt=new DataTransfer();dt.items.add(new File([blob],name,{type}));
    const el=document.querySelector(sel);
    el.dispatchEvent(new DragEvent('dragover',{dataTransfer:dt,bubbles:true,cancelable:true}));
    el.dispatchEvent(new DragEvent('drop',{dataTransfer:dt,bubbles:true,cancelable:true}));
  },[selector,type,name,w,h]);

  // ---- Cột Ảnh trong bảng ----
  await receive('config',config('table'));await receive('table',table());
  ok(await page.locator('.grid thead th:has-text("Ảnh")').count()===1,'bảng có cột Ảnh');
  ok(await page.locator('.grid tbody tr').count()===3 && await page.locator('td.img img.thumb-img').count()===2 && await page.locator('td.img .thumb-empty').count()===1,'dòng có ảnh hiện khung ảnh, dòng chưa có ảnh hiện dấu +');
  const asked=await calls('image_thumbs');
  ok(asked.length===1 && JSON.stringify(JSON.parse(asked[0].args[0]))==='[900,902]','chỉ xin ảnh nhỏ của các dòng có ảnh, một lần');
  ok((await calls('images_capture')).length===0,'mở bảng không tự chụp ảnh');
  await receive('thumbs',{items:{'900':PNG1,'902':PNG1}});
  ok(await page.locator('td.img img.thumb-img[src^="data:image/png"]').count()===2,'ảnh nhỏ nhận về được hiện trong ô');
  await clear();await receive('table',table());
  ok((await calls('image_thumbs')).length===0,'bảng vẽ lại: dùng ảnh nhỏ đã có, không xin lại');
  await receive('images_changed',{items:[{pid:900,has:true,stamp:9}]});
  ok((await calls('image_thumbs')).some(c=>JSON.stringify(JSON.parse(c.args[0]))==='[900]'),'ảnh đổi: chỉ xin lại ảnh nhỏ của đối tượng đó');
  await receive('thumbs',{items:{'900':PNG1}});
  await receive('images_changed',{items:[{pid:901,has:true,stamp:3}]});
  ok(await page.locator('td.img img.thumb-img').count()===3,'chụp xong dòng chưa có ảnh: ô ảnh xuất hiện ngay, không cần tải lại bảng');

  // ---- Nút Chụp ảnh trong bảng ----
  await receive('table',table());
  ok(await page.locator('#tbl-capture').isDisabled(),'chưa chọn dòng nào: nút Chụp ảnh bị khóa');
  await clear();
  await page.locator('.grid tbody tr').nth(1).locator('td[data-key="instance"]').click();
  ok(await page.locator('#tbl-capture').isEnabled(),'chọn dòng: nút Chụp ảnh mở');
  ok((await calls('images_capture')).length===0,'chọn dòng không tự chụp');
  await page.locator('#tbl-capture').click();
  const cap=(await calls('images_capture'))[0];
  ok(cap && JSON.stringify(JSON.parse(cap.args[0]))==='{"only_missing":false,"indexes":[1]}','bấm Chụp ảnh: gửi đúng dòng đã chọn');

  // ---- Kéo thả vào ô ảnh ----
  await receive('table',table());await clear();
  await dropFile('tbody tr:nth-child(2) td.img');
  await page.waitForFunction(()=>window.calls.some(c=>c.name==='image_set'));
  const set=JSON.parse((await calls('image_set'))[0].args[0]);
  ok(set.pid===901 && set.full.startsWith('iVBOR') && set.thumb.startsWith('iVBOR'),'thả file ảnh vào ô: gửi mã đối tượng + ảnh PNG đầy đủ + ảnh nhỏ');
  ok(Buffer.from(set.full,'base64').length>0 && Buffer.from(set.thumb,'base64').length<Buffer.from(set.full,'base64').length+1,'ảnh nhỏ không lớn hơn ảnh đầy đủ');
  await clear();
  await dropFile('tbody tr:nth-child(2) td.img',{type:'text/plain',name:'a.txt'});
  await page.waitForTimeout(150);
  ok((await calls('image_set')).length===0 && (await message()).includes('file ảnh'),'thả file không phải ảnh: bị từ chối, có thông báo');
  await clear();
  await dropFile('tbody tr:nth-child(1) td.img',{w:3000,h:1500});
  await page.waitForFunction(()=>window.calls.some(c=>c.name==='image_set'));
  const big=await page.evaluate(async()=>{const c=window.calls.find(x=>x.name==='image_set');const d=JSON.parse(c.args[0]);const img=new Image();img.src='data:image/png;base64,'+d.full;await img.decode();return [img.width,img.height];});
  ok(Math.max(...big)===512 && big[0]===512 && big[1]===256,'ảnh lớn được thu nhỏ về đúng cỡ trong Cài đặt (512 px), giữ tỉ lệ');

  // ---- Dán ảnh ----
  const paste=()=>page.evaluate(async()=>{
    const canvas=document.createElement('canvas');canvas.width=100;canvas.height=100;canvas.getContext('2d').fillRect(0,0,100,100);
    const blob=await new Promise(r=>canvas.toBlob(r,'image/png'));const dt=new DataTransfer();dt.items.add(new File([blob],'x.png',{type:'image/png'}));
    document.body.dispatchEvent(new ClipboardEvent('paste',{clipboardData:dt,bubbles:true,cancelable:true}));
  });
  await receive('table',table());await clear();
  await paste();await page.waitForTimeout(150);
  ok((await calls('image_set')).length===0 && (await message()).includes('chọn đúng một đối tượng'),'dán khi chưa chọn dòng: nhắc chọn một đối tượng, không gửi gì');
  await page.locator('.grid tbody tr').nth(2).locator('td[data-key="instance"]').click();await clear();
  await paste();await page.waitForFunction(()=>window.calls.some(c=>c.name==='image_set'));
  ok(JSON.parse((await calls('image_set'))[0].args[0]).pid===902,'dán khi chọn đúng một dòng: ảnh vào đúng đối tượng đó');
  await page.locator('.grid tbody tr').nth(0).locator('td[data-key="instance"]').click();
  await page.locator('.grid tbody tr').nth(2).locator('td[data-key="instance"]').click({modifiers:['Control']});await clear();
  await paste();await page.waitForTimeout(150);
  ok((await calls('image_set')).length===0,'dán khi chọn nhiều dòng: không đoán, không gửi');

  // ---- Tab Hình ảnh ----
  await receive('config',config('images'));
  await receive('images',{rows:rows.map(r=>({...r})),hint:null,settings:{settings:settings(),dir:'C:\\x',dir_exists:true},busy:false});
  ok(await page.locator('.img-card').count()===3,'tab Hình ảnh: mỗi đối tượng một thẻ');
  ok(await page.locator('.img-card .img-empty').count()===1 && (await calls('image_full')).some(c=>c.args[0]===900),'thẻ có ảnh xin ảnh lớn, thẻ chưa có ảnh hiện chỗ trống');
  ok((await calls('images_capture')).length===0,'mở tab Hình ảnh không tự chụp');
  await receive('image_full',{pid:900,stamp:7,url:PNG1});
  ok(await page.locator('.img-card img[src^="data:image/png"]').count()===1,'ảnh lớn nhận về được hiện trong thẻ');
  ok((await calls('image_full')).some(c=>c.args[0]===902),'xin ảnh lớn từng cái một, xong cái này mới xin cái kế');
  await receive('image_full',{pid:902,stamp:7,url:null});
  ok(await page.locator('.img-card .img-empty').count()===2,'file ảnh đọc không được: hiện thông báo thay vì ảnh vỡ');
  ok(await page.locator('#cap-stop').isHidden(),'chưa chụp: nút Dừng ẩn');
  await clear();
  await page.locator('#cap-run').click();
  ok(JSON.stringify(JSON.parse((await calls('images_capture'))[0].args[0]))==='{"only_missing":false}','bấm Cập nhật ảnh: gửi lệnh chụp mọi đối tượng đang hiện');
  await receive('images_progress',{done:1,total:3});
  ok(await page.locator('#cap-stop').isVisible() && await page.locator('#cap-run').isDisabled() && (await page.locator('#cap-progress').innerText()).includes('1/3'),'đang chụp: hiện tiến độ và nút Dừng, khóa nút Cập nhật');
  await page.locator('#cap-stop').click();
  ok((await calls('images_cancel')).length===1,'bấm Dừng: gửi lệnh dừng');
  await receive('images_done',{done:1,total:3,ok:1,errors:[],cancelled:true});
  ok(await page.locator('#cap-run').isEnabled() && (await message()).includes('Đã dừng'),'xong: mở lại nút, báo kết quả');
  await receive('images_done',{done:3,total:3,ok:2,errors:['Cab 1: không chụp được.'],cancelled:false});
  ok((await message()).includes('Đã chụp 2/3') && (await message()).includes('Cab 1: không chụp được.'),'chụp xong: báo số ảnh và lỗi từng đối tượng');
  await page.locator('#cap-only').check();await clear();await page.locator('#cap-run').click();
  ok(JSON.parse((await calls('images_capture'))[0].args[0]).only_missing===true,'tích "Chỉ chụp đối tượng chưa có ảnh": gửi only_missing');
  await clear();
  await page.locator('.img-card').nth(1).getByRole('button',{name:'Chụp ảnh'}).click();
  ok(JSON.stringify(JSON.parse((await calls('images_capture'))[0].args[0]))==='{"only_missing":false,"indexes":[1]}','nút Chụp ảnh trên thẻ: chỉ chụp đối tượng đó');
  await page.locator('.img-card').nth(0).getByRole('button',{name:'Xóa ảnh'}).click();
  ok((await calls('image_delete')).some(c=>c.args[0]===900),'nút Xóa ảnh trên thẻ: gửi mã đối tượng');
  await receive('images_changed',{items:[{pid:900,has:false,stamp:0}]});
  ok(await page.locator('.img-card .img-empty').count()===3,'xóa ảnh: thẻ trở về trạng thái chưa có ảnh');
  await clear();
  await dropFile('.img-card:nth-child(2)');
  await page.waitForFunction(()=>window.calls.some(c=>c.name==='image_set'));
  ok(JSON.parse((await calls('image_set'))[0].args[0]).pid===901,'thả ảnh lên thẻ: vào đúng đối tượng');
  await clear();
  await page.locator('.img-card').nth(2).dispatchEvent('mousedown');await paste();
  await page.waitForFunction(()=>window.calls.some(c=>c.name==='image_set'));
  ok(JSON.parse((await calls('image_set'))[0].args[0]).pid===902,'bấm thẻ rồi dán: ảnh vào thẻ đang chọn');
  const many=Array.from({length:30},(_,i)=>({...rows[1],index:i,pid:1000+i,name:'N'+i,has_image:false}));
  await receive('images',{rows:many,hint:null,settings:{settings:settings(),dir:'C:\\x',dir_exists:true},busy:false});
  ok(await page.locator('.img-card').count()===24 && await page.getByRole('button',{name:/Hiện thêm/}).count()===1,'nhiều đối tượng: chỉ hiện 24 thẻ đầu, có nút Hiện thêm');
  await page.getByRole('button',{name:/Hiện thêm/}).click();
  ok(await page.locator('.img-card').count()===30,'bấm Hiện thêm: hiện hết');

  // ---- Cài đặt ----
  await receive('config',config('settings'));
  await receive('settings',{settings:settings(),dir:'C:\\Users\\a\\images',dir_exists:false});
  ok(await page.locator('.setting-row').count()>=6,'tab Cài đặt có đủ mục: ngôn ngữ, đơn vị, thư mục, cách chụp, cỡ ảnh, nền');
  ok((await page.locator('.dir-now').innerText()).includes('C:\\Users\\a\\images') && (await page.locator('.dir-now').innerText()).includes('chưa có'),'hiện thư mục đang dùng và báo nếu chưa có');
  await clear();
  await page.selectOption('select[aria-label="Đơn vị chiều dài"]','cm');
  ok(JSON.stringify(JSON.parse((await calls('settings_save'))[0].args[0]))==='{"length_unit":"cm"}','đổi đơn vị: lưu ngay, chỉ gửi mục vừa đổi');
  await clear();await page.selectOption('select[aria-label="Cách chụp"]','current');
  ok(JSON.parse((await calls('settings_save'))[0].args[0]).capture_mode==='current','đổi cách chụp: lưu');
  await clear();await page.selectOption('select[aria-label="Cỡ ảnh"]','1024');
  ok(JSON.parse((await calls('settings_save'))[0].args[0]).image_size===1024,'đổi cỡ ảnh: gửi số nguyên');
  await clear();await page.selectOption('select[aria-label="Nền ảnh"]','white');
  ok(JSON.parse((await calls('settings_save'))[0].args[0]).image_background==='white','đổi nền ảnh: lưu');
  await clear();await page.selectOption('select[aria-label="Ngôn ngữ"]','en');
  ok(JSON.parse((await calls('settings_save'))[0].args[0]).language==='en','đổi ngôn ngữ: lưu');
  await clear();
  const dir=page.locator('input[aria-label="Thư mục lưu ảnh"]');await dir.fill('D:\\Anh');await dir.press('Enter');
  ok(JSON.parse((await calls('settings_save'))[0].args[0]).image_dir==='D:\\Anh','gõ đường dẫn thư mục rồi Enter: lưu');
  await clear();await page.getByRole('button',{name:'Chọn thư mục…'}).click();await page.getByRole('button',{name:'Mở thư mục',exact:true}).click();
  ok((await calls('settings_pick_dir')).length===1 && (await calls('images_open_dir')).length===1,'nút Chọn thư mục… và Mở thư mục gọi đúng lệnh');

  // ---- Đơn vị đo ----
  const lenCell=async(row,key)=>page.locator('.grid tbody tr').nth(row).locator(`td[data-key="${key}"]`).innerText();
  await receive('config',config('table'));await receive('table',table());
  ok(await lenCell(0,'lenX')==='1.200' && (await page.locator('.grid thead tr:first-child th:has-text("Rộng (X)")').innerText()).includes('mm'),'đơn vị mm: 1.200, tiêu đề ghi mm');
  await receive('config',config('table',{length_unit:'cm'}));await receive('table',table());
  ok(await lenCell(0,'lenX')==='120,0' && (await page.locator('.grid thead tr:first-child th:has-text("Rộng (X)")').innerText()).includes('cm') && (await page.locator('.unit-row .pill').first().innerText())==='cm' || await lenCell(0,'lenX')==='120,0','đơn vị cm: 120,0');
  const head=await page.locator('.grid thead tr:first-child').innerText();
  ok(head.includes('Rộng (X) cm') && head.includes('(X) x (Z) cm') && !head.includes(' mm'),'đơn vị cm: mọi tiêu đề cột kích thước đổi theo');
  ok((await page.locator('.unit-row .pill').allInnerTexts()).includes('cm'),'đơn vị cm: hàng đơn vị dưới tiêu đề ghi cm');
  ok(await lenCell(0,'lenXYZ')==='120,0 × 60,0 × 80,0' || (await lenCell(0,'lenXYZ')).startsWith('120'),'đơn vị cm: cột ghép (X) x (Y) x (Z) cũng đổi');
  await receive('config',config('table',{length_unit:'m'}));await receive('table',table());
  ok(await lenCell(0,'lenX')==='1,200' && await lenCell(0,'lenZ')==='0,800','đơn vị m: 1,200 và 0,800 (3 số lẻ)');
  ok((await page.locator('.table-view .muted').last().innerText()).startsWith('Đơn vị: m '),'chú thích cuối bảng ghi đúng đơn vị đang dùng');
  ok(await lenCell(0,'areaFace')==='2,10','diện tích không bị đổi đơn vị (luôn m²)');
  await receive('config',config('information',{length_unit:'cm'}));
  await receive('information',{count:1,fields:{},objects:[{entity_type:'Group',source:'RAW',instance_name:'a',definition_name:'d',tag:'t',material:'',dimensions:{width:1200,depth:600,height:800},locked:false,status:'UNCLASSIFIED'}]});
  const info=await page.locator('.card').last().innerText();
  ok(info.includes('Rộng × Sâu × Cao (cm)') && info.includes('120 × 60 × 80'),'tab Thông tin: tiêu đề và kích thước theo cm');

  // ---- Đổi ngôn ngữ thì tải lại cửa sổ ----
  await receive('config',config('table'));
  const reloaded=page.waitForEvent('load',{timeout:5000}).then(()=>true,()=>false);
  await receive('config',{...config('table'),language:'en',settings:settings({language:'en'}),locale:F.en,vi_en:F.vi_en});
  ok(await reloaded,'đổi ngôn ngữ giữa chừng: cửa sổ tự tải lại để vẽ từ đầu bằng ngôn ngữ mới');
  ok(errors.length===0,'không có lỗi JavaScript'+(errors.length?': '+errors.join(' | '):''));
 }finally{await browser.close();}
 console.log(failed?`${failed} lỗi`:'Done');
})().catch(e=>{console.log('FAIL  '+e.message);process.exit(1);});
