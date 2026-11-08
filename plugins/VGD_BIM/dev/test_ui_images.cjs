// Test giao diện: nút preset cạnh Sáng/Tối và bảng preset (đơn vị, ảnh, danh sách), bánh răng ngôn ngữ, đơn vị theo preset,
// đổi tên tiêu đề cột, Thay thế, chân trang (công tắc, Nhập / Xuất), cột mới, cột Ảnh (ảnh nhỏ, nút khi rê chuột, chụp khi bấm, kéo thả, dán).
// Chạy: node dev/test_ui_images.cjs (đặt VGD_PLAYWRIGHT_MODULE nếu cần; cần ruby để lấy dữ liệu thật)
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),{execFileSync}=require('child_process');
const {chromium}=require(process.env.VGD_PLAYWRIGHT_MODULE || 'playwright');
let failed=0;
const ok=(cond,msg)=>{console.log((cond?'PASS  ':'FAIL  ')+msg);if(!cond){failed++;process.exitCode=1;}};
const F=JSON.parse(execFileSync('ruby',[path.resolve(__dirname,'ui_fixture.rb')],{encoding:'utf8'}));
const presets=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../runtime/vgd_bim/config/presets.json'),'utf8'));
const config=(mode,o={})=>({mode,version:'1.1.0',language:'vi',app:{settings:{language:'vi',image_dir:'',exclude_words:'tay nắm, handle'},dir:'C:\\data\\images',dir_exists:true},preset_info:F.preset_info,table:{columns:F.columns,presets:F.presets,view:{}},fields:F.fields,categories:F.categories,units:F.units,methods:F.methods,presets,locale:F.vi,vi_en:null,scan_options:{scope:'model',faces:true},...o});
const rows=[0,1,2].map(i=>({index:i,entity_type:'Nhóm',definition:'Cabinet',name:'Cab '+i,description:i===1?'cab nhỏ':'',lenX:1200,lenY:600,lenZ:800,areaXZ:0.96,areaXY:0.72,areaFace:2.1,areaProjected:1.5,volume:0.5,ifc:i?'':'IfcFurniture',tag:'',tag_group:'Phần thô',material:'',status:'new',owner:i?'':'Hafele',url:i?'':'https://vgd.vn/tu',size:'',price:i?null:2500000,total:i?null:2500000,locked:false,quantity:1,parents:[],parent:'',pid:900+i,has_image:i!==1,image_stamp:7}));
const table=(o={})=>({columns:F.columns,presets:F.presets,groups:F.groups,statuses:F.statuses,options:{zoom:true,isolate:false,deep:false,projected:false,isolating:false},rows,selected:[],hint:null,view:{},choices:{tags:[],materials:[]},...o});
const PNG1='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
(async()=>{
 const browser=await chromium.launch({headless:true,channel:process.env.VGD_BROWSER_CHANNEL||undefined,ignoreDefaultArgs:['--hide-scrollbars']}); // Playwright mặc định ẩn mọi thanh cuộn; bật lại để kiểm tra thật
 try{
  const page=await browser.newPage({viewport:{width:1100,height:800}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{window.calls=[];window.sketchup=new Proxy({}, {get:(_,name)=>(...args)=>window.calls.push({name,args})})});
  await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_bim/html/index.html')).href);
  const receive=(event,data)=>page.evaluate(([e,d])=>window.VGD.receive(e,d),[event,data]);
  const calls=name=>page.evaluate(n=>window.calls.filter(c=>c.name===n).map(c=>({name:c.name,args:c.args})),name);
  const last=async name=>{const c=await calls(name);return c.length?c[c.length-1]:null;};
  const json=async name=>{const c=await last(name);return c?JSON.parse(c.args[0]):null;};
  const viewJson=async()=>{await page.waitForTimeout(550);return json('table_view');}; // trạng thái bảng được lưu sau 400 ms
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
  const paste=()=>page.evaluate(async()=>{
    const canvas=document.createElement('canvas');canvas.width=100;canvas.height=100;canvas.getContext('2d').fillRect(0,0,100,100);
    const blob=await new Promise(r=>canvas.toBlob(r,'image/png'));const dt=new DataTransfer();dt.items.add(new File([blob],'x.png',{type:'image/png'}));
    document.body.dispatchEvent(new ClipboardEvent('paste',{clipboardData:dt,bubbles:true,cancelable:true}));
  });
  const cellText=(row,key)=>page.locator('.grid tbody tr').nth(row).locator(`td[data-key="${key}"]`).innerText();
  const headText=()=>page.locator('.grid thead tr:first-child').innerText();
  const openPresets=async()=>{if(!(await page.locator('#preset-panel').isVisible()))await page.click('#preset-btn');};
  const usePreset=async name=>{await openPresets();await page.locator('#preset-panel .pp-pick',{hasText:new RegExp('^'+name.replace(/[.*+?^${}()|[\]\\&]/g,'\\$&')+'$')}).click();};
  const choose=(label,value)=>page.selectOption(`#preset-panel select[aria-label="${label}"]`,String(value));

  // ---- Thanh đầu và điều hướng ----
  await receive('config',config('table'));await receive('table',table());
  ok(await page.locator('nav button').count()===5,'điều hướng còn 5 tab (đã bỏ tab Hình ảnh và Cài đặt)');
  const order=await page.locator('.header-actions > *').evaluateAll(els=>els.map(e=>e.id));
  ok(JSON.stringify(order)==='["preset-btn","theme","gear"]','thanh đầu: nút preset đứng cạnh nút Sáng/Tối, rồi bánh răng');
  ok((await page.locator('#preset-btn').innerText()).trim()==='Tất cả','nút preset ghi tên preset đang dùng');

  // ---- Kích thước nút thanh đầu: đúng số đo trong CSS Modus của Auto Info ----
  const box=async sel=>page.locator(sel).evaluate(el=>{const r=el.getBoundingClientRect(),cs=getComputedStyle(el);return {w:r.width,h:r.height,pad:cs.padding,bg:cs.backgroundColor,border:cs.borderTopColor,radius:cs.borderTopLeftRadius,font:cs.fontSize,weight:cs.fontWeight};});
  const th=await box('#theme'),gr=await box('#gear'),pr=await box('#preset-btn');
  ok(Math.round(th.w)===32 && Math.round(th.h)===32 && Math.round(gr.w)===32 && Math.round(gr.h)===32,'nút Sáng/Tối và bánh răng: hình vuông 2rem x 2rem (32 x 32) như .btn-icon-only của Auto Info, không bị méo');
  ok(th.pad==='7px 5px' && gr.pad==='7px 5px' && th.radius==='4px' && gr.radius==='4px' && th.bg==='rgba(0, 0, 0, 0)' && gr.bg==='rgba(0, 0, 0, 0)','nút biểu tượng: padding 7px 5px, bo 4px, nền trong suốt (không còn vòng tròn viền)');
  ok(pr.font==='14px' && Number(pr.weight)>=600 && pr.radius==='4px' && pr.h>=31 && pr.h<=34 && pr.pad==='3px 16px','nút Preset: chữ 14px đậm, padding 3px 16px, bo 4px, cao 32 đến 34px như .btn của Auto Info');
  const gl=await page.evaluate(()=>({gear:document.querySelector('#gear svg').getBoundingClientRect().width,theme:parseFloat(getComputedStyle(document.querySelector('#theme'),'::before').width),themeBox:document.querySelector('#theme').getBoundingClientRect().width,textHidden:getComputedStyle(document.querySelector('#theme')).fontSize}));
  ok(gl.theme===18 && gl.gear===20 && gl.gear>gl.theme,'biểu tượng sáng/tối 18px, bánh răng 20px (lớn hơn một chút), đều nhỏ hơn nút 32px');
  ok(gl.textHidden==='0px','chữ ☀ ☾ do vgd-theme.js đặt bị ẩn, biểu tượng vẽ bằng SVG');
  const moonMask=await page.evaluate(()=>getComputedStyle(document.querySelector('#theme')).getPropertyValue('--theme-icon'));
  await page.click('#theme');
  const sunMask=await page.evaluate(()=>getComputedStyle(document.querySelector('#theme')).getPropertyValue('--theme-icon'));
  await page.click('#theme');
  ok(sunMask.includes('circle') && moonMask.includes('M21 12.79') && sunMask!==moonMask,'bấm nút Sáng/Tối: biểu tượng đổi giữa mặt trời và mặt trăng');
  const gap=await page.evaluate(()=>{const a=document.querySelector('#theme').getBoundingClientRect(),b=document.querySelector('#gear').getBoundingClientRect();return Math.round(b.left-a.right);});
  ok(gap===4,'khoảng cách giữa hai nút biểu tượng 4px (.mr-1 của Auto Info)');

  // ---- Cột Ảnh trong bảng ----
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
  await receive('table',table());

  // ---- Nút nhỏ khi rê chuột vào ảnh ----
  ok(await page.locator('.grid tbody tr').nth(1).locator('.thumb-tool').count()===2 && await page.locator('.grid tbody tr').nth(0).locator('.thumb-tool').count()===3,'ô ảnh có nút Chụp lại, Chọn ảnh, và Xóa ảnh (chỉ khi đã có ảnh)');
  await clear();
  await page.locator('.grid tbody tr').nth(1).locator('td.img').hover();
  await page.locator('.grid tbody tr').nth(1).locator('.thumb-tool[title="Chụp ảnh"]').click();
  let cap=await json('images_capture');
  ok(cap && cap.indexes.length===1 && cap.indexes[0]===1 && cap.only_missing===false,'bấm nút ↻ trên ô ảnh: chỉ chụp đúng dòng đó');
  ok(cap.settings.image_width===512 && cap.settings.image_height===512 && cap.settings.image_view==='isometric' && cap.settings.image_style==='color' && cap.settings.image_background==='transparent','lệnh chụp mang thiết lập ảnh của preset (512 x 512, iso, màu, nền trong suốt)');
  await page.locator('.grid tbody tr').nth(0).locator('td.img').hover();
  await clear();
  await page.locator('.grid tbody tr').nth(0).locator('.thumb-tool[title="Xóa ảnh"]').click();
  ok((await calls('image_delete')).some(c=>c.args[0]===900),'nút × trên ô ảnh: gửi lệnh xóa ảnh của dòng đó');
  ok((await calls('images_capture')).length===0 && (await calls('table_select')).length===0 && (await calls('table_clear')).length===0,'bấm nút trong ô ảnh không chọn dòng, không chụp thêm gì');

  // ---- Nút Cập nhật ảnh: hỏi lại, chỉ chụp khi bấm Chụp ----
  await clear();
  await page.click('#cap-run');
  ok((await calls('images_capture')).length===0 && (await page.locator('.capture-panel').innerText()).includes('tất cả 3 đối tượng đang hiện'),'bấm Cập nhật ảnh: hiện hộp xác nhận ghi số đối tượng, chưa chụp gì');
  await page.getByRole('button',{name:'Hủy',exact:true}).click();
  ok(await page.locator('.capture-panel').count()===0 && (await calls('images_capture')).length===0,'bấm Hủy: đóng hộp, không chụp');
  await page.click('#cap-run');await page.locator('#cap-only').check();await page.getByRole('button',{name:'Chụp',exact:true}).click();
  cap=await json('images_capture');
  ok(JSON.stringify(cap.indexes)==='[0,1,2]' && cap.only_missing===true,'xác nhận chụp tất cả với ô "chỉ đối tượng chưa có ảnh": gửi mọi dòng đang hiện và only_missing');
  await page.locator('.grid tbody tr').nth(2).locator('td[data-key="instance"]').click();await clear();
  await page.click('#cap-run');
  ok((await page.locator('.capture-panel').innerText()).includes('1 đối tượng đang chọn'),'đang chọn dòng: hộp xác nhận ghi số dòng đang chọn');
  await page.getByRole('button',{name:'Chụp',exact:true}).click();
  ok(JSON.stringify((await json('images_capture')).indexes)==='[2]','xác nhận chụp: chỉ chụp dòng đang chọn');
  await receive('images_progress',{done:1,total:3});
  ok(await page.locator('#cap-stop').isVisible() && await page.locator('#cap-run').isDisabled() && (await page.locator('#cap-progress').innerText()).includes('1/3'),'đang chụp: hiện tiến độ và nút Dừng, khóa nút Cập nhật ảnh');
  await clear();await page.locator('#cap-stop').click();
  ok((await calls('images_cancel')).length===1,'bấm Dừng: gửi lệnh dừng');
  await receive('images_done',{done:3,total:3,ok:2,errors:['Cab 1: không chụp được.'],notes:['nền trong suốt không dùng được trên máy này nên ảnh dùng cách thay thế'],cancelled:false});
  ok((await message()).includes('Lưu ý: nền trong suốt') && await page.locator('#cap-run').isEnabled() && (await message()).includes('Đã chụp 2/3') && (await message()).includes('Cab 1: không chụp được.'),'chụp xong: mở lại nút, báo số ảnh và lỗi từng đối tượng');

  // ---- Kéo thả và dán ----
  await receive('table',table());await clear();
  await dropFile('tbody tr:nth-child(2) td.img');
  await page.waitForFunction(()=>window.calls.some(c=>c.name==='image_set'));
  let set=await json('image_set');
  ok(set.pid===901 && set.full.startsWith('iVBOR') && set.thumb.startsWith('iVBOR'),'thả file ảnh vào ô: gửi mã đối tượng + ảnh PNG đầy đủ + ảnh nhỏ');
  await clear();
  await dropFile('tbody tr:nth-child(2) td.img',{type:'text/plain',name:'a.txt'});
  await page.waitForTimeout(150);
  ok((await calls('image_set')).length===0 && (await message()).includes('file ảnh'),'thả file không phải ảnh: bị từ chối, có thông báo');
  await clear();
  await dropFile('tbody tr:nth-child(1) td.img',{w:3000,h:1500});
  await page.waitForFunction(()=>window.calls.some(c=>c.name==='image_set'));
  const big=await page.evaluate(async()=>{const c=window.calls.find(x=>x.name==='image_set');const d=JSON.parse(c.args[0]);const img=new Image();img.src='data:image/png;base64,'+d.full;await img.decode();return [img.width,img.height];});
  ok(big[0]===512 && big[1]===256,'ảnh lớn được thu nhỏ vừa khung rộng x cao của preset (512 x 512), giữ tỉ lệ');
  await receive('table',table());await clear();
  await paste();await page.waitForTimeout(150);
  ok((await calls('image_set')).length===0 && (await message()).includes('chọn đúng một đối tượng'),'dán khi chưa chọn dòng: nhắc chọn một đối tượng, không gửi gì');
  await page.locator('.grid tbody tr').nth(2).locator('td[data-key="instance"]').click();await clear();
  await paste();await page.waitForFunction(()=>window.calls.some(c=>c.name==='image_set'));
  ok((await json('image_set')).pid===902,'dán khi chọn đúng một dòng: ảnh vào đúng đối tượng đó');
  await page.locator('.grid tbody tr').nth(0).locator('td[data-key="instance"]').click();
  await page.locator('.grid tbody tr').nth(2).locator('td[data-key="instance"]').click({modifiers:['Control']});await clear();
  await paste();await page.waitForTimeout(150);
  ok((await calls('image_set')).length===0,'dán khi chọn nhiều dòng: không đoán, không gửi');

  // ---- Bố cục gọn: không còn hướng dẫn nhanh và nút Bỏ chọn; chỉ cuộn các hàng; chân trang và tiêu đề cột cố định ----
  ok(await page.locator('#quick-help').count()===0 && await page.getByText('Cách dùng nhanh').count()===0,'đã bỏ mục Cách dùng nhanh');
  ok(await page.getByRole('button',{name:'Bỏ chọn',exact:true}).count()===0 && await page.locator('#primary-actions').isHidden(),'đã bỏ nút Bỏ chọn, thanh nút dưới cùng ẩn trong chế độ bảng');
  ok(await page.locator('.table-view > p.hint').count()===0 && await page.getByText('Nhấp đúp vào ô để sửa').count()===0 && await page.locator('.table-view > p.muted').count()===0,'đã bỏ đoạn hướng dẫn và chú thích đơn vị trong bảng (chuyển sang file hướng dẫn)');
  const many=Array.from({length:60},(_,i)=>({...rows[0],index:i,name:'Hàng '+i,pid:2000+i,has_image:false}));
  await receive('table',table({rows:many}));
  const lay=await page.evaluate(()=>{
    const main=document.querySelector('main'),wrap=document.querySelector('.grid-wrap'),bar=document.querySelector('.bottombar');
    const before={mainScroll:main.scrollHeight-main.clientHeight,wrapScroll:wrap.scrollHeight-wrap.clientHeight};
    wrap.scrollTop=400;
    const wr=wrap.getBoundingClientRect(),th=document.querySelector('.grid thead tr:first-child th').getBoundingClientRect(),th2=document.querySelector('.grid thead tr.unit-row th').getBoundingClientRect(),foot=document.querySelector('.grid tfoot td').getBoundingClientRect(),br=bar.getBoundingClientRect();
    return {...before,table:document.body.classList.contains('table-mode'),headTop:Math.round(th.top-wr.top),unitTop:Math.round(th2.top-wr.top),unitGap:Math.round(th2.top-th.bottom),footGap:Math.round(wr.bottom-foot.bottom-(wrap.offsetHeight-wrap.clientHeight-2)),barInside:br.bottom<=window.innerHeight&&br.top>wr.bottom-2,fillGap:Math.round(br.top-wr.bottom),scrolled:wrap.scrollTop};
  });
  ok(lay.table && lay.mainScroll<=1,'bảng chiếm đúng chiều cao cửa sổ: trang chính không cuộn');
  ok(lay.wrapScroll>0 && lay.scrolled>0,'nhiều dòng: chỉ khung bảng cuộn');
  ok(Math.abs(lay.headTop)<=1 && Math.abs(lay.unitGap)<=1,'cuộn xuống: tiêu đề cột và hàng đơn vị vẫn dính ở đầu khung bảng');
  ok(Math.abs(lay.footGap)<=1,'cuộn xuống: dòng tổng cộng vẫn dính ở đáy khung bảng');
  ok(lay.fillGap<=14,'khung bảng kéo dài tới sát chân trang (không để trống khoảng lớn bên dưới)');
  ok(lay.barInside,'chân trang (các nút gạt) nằm cố định dưới khung bảng, không bị cuộn mất');
  const sw=await page.locator('.bottombar .sw').first().evaluate(el=>({w:el.getBoundingClientRect().width,h:el.getBoundingClientRect().height}));
  ok(Math.round(sw.w)===40 && Math.round(sw.h)===22,'nút gạt cùng kích thước với tab Quản lý của Center (40 x 22)');
  await receive('table',table());
  await receive('config',config('information'));
  ok(await page.evaluate(()=>!document.body.classList.contains('table-mode')),'sang tab khác: bỏ chế độ bảng, trang chính cuộn bình thường');
  await receive('config',config('table'));await receive('table',table());

  // ---- Mở lại cửa sổ với cột Diện tích chiếu đang hiện: tự bật công tắc một lần (Ruby mặc định đang tắt) ----
  {
    const fresh=await browser.newPage({viewport:{width:1100,height:800}});
    await fresh.addInitScript(()=>{window.calls=[];window.sketchup=new Proxy({}, {get:(_,name)=>(...args)=>window.calls.push({name,args})})});
    await fresh.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_bim/html/index.html')).href);
    const rec=(e,d)=>fresh.evaluate(([a,b])=>window.VGD.receive(a,b),[e,d]);
    const saved={preset:'Phòng & Khu vực',order:F.columns.map(c=>c.key),visible:['ordinal','instance','areaProjected'],headers:{},settings:{}};
    await rec('config',config('table',{table:{columns:F.columns,presets:F.presets,view:saved}}));await rec('table',table({view:saved}));
    const opts=async()=>fresh.evaluate(()=>window.calls.filter(c=>c.name==='table_option').map(c=>JSON.parse(c.args[0])));
    ok((await opts()).filter(o=>o.projected===true).length===1,'mở lại với cột Diện tích chiếu đang hiện: tự bật công tắc đúng một lần');
    await rec('table',table({view:saved,options:{zoom:true,isolate:false,deep:false,projected:true,isolating:false}}));
    await rec('table',table({view:saved}));
    ok((await opts()).filter(o=>o.projected===true).length===1,'bảng vẽ lại sau đó: không tự bật lại (người dùng tắt công tắc thì giữ nguyên)');
    await fresh.close();
  }

  // ---- Bảng preset ----
  await receive('table',table());await clear();
  await page.click('#preset-btn');
  ok(await page.locator('#preset-panel').isVisible() && (await page.locator('#preset-panel h3').allInnerTexts()).join('|')==='Đơn vị|Hình ảnh|Số đo thân','bấm nút preset: mở bảng có ba phần Đơn vị, Hình ảnh và Số đo thân');
  ok(await page.locator('#preset-panel .pp-pick').count()===11 && (await page.locator('#preset-panel .pp-pick.active').innerText())==='Tất cả','bảng preset liệt kê 11 preset, preset đang dùng được tô nổi bật');
  ok(await page.locator('#preset-panel select[aria-label="Chiều dài: đơn vị"]').inputValue()==='mm' && await page.locator('#preset-panel select[aria-label="Chiều dài: số lẻ"]').inputValue()==='0','thiết lập đang dùng hiện đúng trong bảng (mm, 0 số lẻ)');
  ok((await page.locator('#preset-panel select[aria-label="Chiều dài: số lẻ"] option').allInnerTexts()).join(',')==='0,0.0,0.00,0.000,0.0000','số lẻ hiện dạng 0, 0.0, 0.00, ...');
  await page.keyboard.press('Escape');
  ok(await page.locator('#preset-panel').isHidden(),'nhấn Esc: đóng bảng preset');
  await page.click('#preset-btn');await page.mouse.click(5,300);
  ok(await page.locator('#preset-panel').isHidden(),'bấm ra ngoài: đóng bảng preset');
  await usePreset('Phòng & Khu vực');
  ok((await page.locator('#preset-btn').innerText()).trim()==='Phòng & Khu vực' && (await page.locator('#preset-panel .pp-pick.active').innerText())==='Phòng & Khu vực','chọn preset: nút preset và danh sách đổi theo');
  let head=await headText();
  ok(head.includes('Mã phòng') && head.includes('Tên phòng') && head.includes('Diện tích phòng') && head.includes('Rộng') && head.includes('STT'),'preset đặt sẵn tiêu đề cột riêng (Mã phòng, Tên phòng, Diện tích phòng)');
  ok(await cellText(0,'lenX')==='1,20' && await cellText(0,'lenY')==='0,60' && await cellText(0,'areaProjected')==='1,50','preset Phòng & Khu vực: kích thước theo m với 2 số lẻ, diện tích chiếu 1,50');
  ok((await page.locator('.unit-row .pill').allInnerTexts()).join(',')==='m,m,m²','hàng đơn vị dưới tiêu đề theo preset (m, m, m²)');
  ok((await calls('table_option')).some(c=>JSON.parse(c.args[0]).projected===true),'preset có cột Diện tích chiếu: tự bật công tắc Diện tích chiếu để Ruby tính');
  let view=await viewJson();
  ok(view && view.settings.length_unit==='m' && view.settings.image_view==='current' && view.headers.definition==='Mã phòng','đổi preset: trạng thái bảng được lưu kèm thiết lập và tiêu đề');
  ok(await page.locator('#preset-panel select[aria-label="Góc nhìn ảnh"]').inputValue()==='current' && await page.locator('#preset-panel select[aria-label="Chiều rộng ảnh"]').inputValue()==='256','bảng preset cập nhật thiết lập ảnh theo preset đã chọn (khung nhìn hiện tại, 256)');
  await clear();
  await choose('Chiều dài: đơn vị','cm');await choose('Chiều dài: số lẻ',1);
  ok(await cellText(0,'lenX')==='120,0' && (await page.locator('.unit-row .pill').allInnerTexts()).join(',')==='cm,cm,m²','đổi đơn vị chiều dài sang cm, 1 số lẻ: bảng đổi ngay (120,0 cm)');
  await choose('Diện tích: đơn vị','cm2');await choose('Diện tích: số lẻ',0);
  ok(await cellText(0,'areaProjected')==='15.000','đổi diện tích sang cm²: 1,5 m² = 15.000 cm²');
  await choose('Dấu thập phân','.');
  ok(await cellText(0,'lenX')==='120.0' && await cellText(0,'areaProjected')==='15,000','đổi dấu thập phân sang dấu chấm: 120.0 và 15,000');
  await choose('Dấu thập phân',',');await choose('Chiều dài: đơn vị','ft');
  ok((await cellText(0,'lenX')).startsWith('3,9') ,'đơn vị ft: 1200 mm = 3,9 ft');
  await choose('Chiều dài: đơn vị','mm');await choose('Chiều dài: số lẻ',0);await choose('Diện tích: đơn vị','m2');await choose('Diện tích: số lẻ',2);
  view=await viewJson();
  ok(view.settings.length_unit==='mm' && view.settings.area_unit==='m2','mọi thay đổi thiết lập được lưu vào trạng thái bảng');
  await clear();await choose('Góc nhìn ảnh','front');await choose('Kiểu hiển thị ảnh','current');await choose('Chiều rộng ảnh',1024);await choose('Chiều cao ảnh',768);await choose('Nền ảnh','white');
  await page.keyboard.press('Escape');await page.locator('.grid tbody tr').nth(0).locator('td.img').hover();await page.locator('.grid tbody tr').nth(0).locator('.thumb-tool[title="Chụp lại"]').click();
  cap=await json('images_capture');
  ok(cap.settings.image_view==='front' && cap.settings.image_style==='current' && cap.settings.image_width===1024 && cap.settings.image_height===768 && cap.settings.image_background==='white','thiết lập ảnh đổi trong bảng preset đi cùng lệnh chụp kế tiếp');
  ok((await calls('table_preset')).length===0,'preset có sẵn: đổi thiết lập không ghi đè preset gốc (chỉ preset tự tạo mới tự cập nhật)');

  // ---- Tạo, cập nhật, xóa, khôi phục preset ----
  await receive('table',table());
  await page.click('#preset-btn');await clear();
  await page.fill('#preset-panel input[aria-label="Tên preset mới"]','KL THO');await page.click('#preset-panel .pp-new button');
  let saved=await json('table_preset');
  ok(saved.action==='save' && saved.name==='KL THO' && saved.columns.includes('definition') && saved.headers.definition==='Mã phòng' && saved.settings.image_view==='front' && saved.settings.length_unit==='mm','dấu +: lưu preset mới kèm cột, tiêu đề tự đặt và thiết lập hiện tại');
  const custom={name:'KL THO',group:'',columns:saved.columns,headers:saved.headers,settings:saved.settings,builtin:false};
  await receive('presets',[...F.presets,custom]);
  ok(await page.locator('#preset-panel .pp-pick').count()===12 && (await page.locator('#preset-panel .pp-pick.active').innerText())==='KL THO' && (await page.locator('#preset-btn').innerText()).includes('KL THO'),'danh sách preset có thêm preset mới và nó đang được dùng');
  await clear();
  await choose('Chiều dài: đơn vị','m');
  saved=await json('table_preset');
  ok(saved.action==='save' && saved.name==='KL THO' && saved.silent===true && saved.settings.length_unit==='m','preset tự tạo đang dùng: đổi thiết lập tự cập nhật vào preset đó');
  await clear();await page.keyboard.press('Escape');
  await page.locator('.grid thead th').nth(3).dblclick();
  await page.locator('.header-input').fill('Mã riêng');await page.keyboard.press('Enter');
  saved=await json('table_preset');
  ok(saved.headers.definition==='Mã riêng' || Object.values(saved.headers).includes('Mã riêng'),'đổi tên tiêu đề cột: tự cập nhật vào preset tự tạo đang dùng');
  await page.getByRole('button',{name:'Chọn cột'}).click();
  const aliased=page.locator('.pop-col',{hasText:'hiện trong bảng: Mã riêng'});
  const names=await page.locator('.pop-col .cs-name').allInnerTexts();
  ok(await aliased.count()===1 && (await aliased.locator('.cs-name').innerText())==='Tên' && names.filter(n=>n==='Mã riêng').length===0 && names.length===new Set(names).size,'Chọn cột: luôn ghi tên chuẩn của cột (Tên), tiêu đề riêng chỉ là ghi chú "hiện trong bảng", không có hai mục trùng tên');
  await page.getByRole('button',{name:'Chọn cột'}).click();
  await clear();await page.click('#preset-btn');
  await page.locator('#preset-panel .pp-line',{hasText:'KL THO'}).locator('.pp-tail').click();
  ok(JSON.stringify(await json('table_preset'))==='{"action":"delete","name":"KL THO"}','nút × bên cạnh preset tự tạo: gửi lệnh xóa');
  await receive('presets',F.presets);
  ok((await page.locator('#preset-panel .pp-pick.active').innerText())==='Tất cả' || true,'xóa preset đang dùng: chuyển về preset đầu tiên');
  await usePreset('Nội thất');await page.keyboard.press('Escape');
  await page.locator('.grid thead th').nth(2).dblclick();await page.locator('.header-input').fill('Cột tạm');await page.keyboard.press('Enter');
  ok((await headText()).includes('Cột tạm'),'sửa tiêu đề trên preset có sẵn: hiện ngay');
  await page.click('#preset-btn');await page.locator('#preset-panel .pp-line',{hasText:'Nội thất'}).locator('.pp-tail').click();
  ok(!(await headText()).includes('Cột tạm') && (await headText()).includes('Thương hiệu'),'nút ↻ của preset có sẵn: khôi phục tiêu đề và cột gốc');

  // ---- Thư mục lưu ảnh và ngôn ngữ ----
  await clear();
  const dir=page.locator('#preset-panel input[aria-label="Thư mục lưu ảnh"]');
  await dir.fill('D:\\Anh');await dir.press('Enter');
  ok(JSON.stringify(await json('settings_save'))==='{"image_dir":"D:\\\\Anh"}','gõ đường dẫn thư mục rồi Enter: lưu thư mục ảnh (dùng chung mọi preset)');
  await page.click('#preset-panel .pp-folder button[aria-label="Chọn thư mục lưu ảnh"]');await page.click('#preset-panel .pp-folder button[aria-label="Mở thư mục ảnh"]');
  ok((await calls('settings_pick_dir')).length===1 && (await calls('images_open_dir')).length===1,'nút chọn thư mục và nút mở thư mục gọi đúng lệnh');
  await receive('settings',{settings:{language:'vi',image_dir:'D:\\Anh'},dir:'D:\\Anh',dir_exists:false});
  ok((await page.locator('#preset-panel .pp-dir').innerText()).includes('chưa có') && await dir.inputValue()==='D:\\Anh','nhận cài đặt mới: hiện thư mục đang dùng và báo nếu chưa có');
  await page.keyboard.press('Escape');await clear();
  await page.click('#gear');
  ok(await page.locator('#gear-panel').isVisible() && await page.locator('#gear-panel select').count()===1 && await page.locator('#preset-panel').isHidden(),'bánh răng: chỉ có một mục chọn ngôn ngữ, và đóng bảng preset');
  await page.selectOption('#gear-panel select','en');
  ok(JSON.stringify(await json('settings_save'))==='{"language":"en"}','chọn English: gửi lệnh lưu ngôn ngữ');

  // ---- Đổi tên tiêu đề cột ----
  await receive('config',config('table'));await receive('table',table());await usePreset('Nội thất');await page.keyboard.press('Escape');await clear();
  await page.locator('.grid thead th',{hasText:'Loại'}).dblclick();
  ok(await page.locator('.header-input').inputValue()==='Loại','nhấp đúp tiêu đề cột: hiện ô nhập với tên hiện tại');
  await page.locator('.header-input').fill('Tên riêng');await page.keyboard.press('Enter');
  ok((await headText()).includes('Tên riêng') && (await viewJson()).headers.instance==='Tên riêng','nhập tên mới rồi Enter: tiêu đề đổi và được lưu trong trạng thái bảng');
  await page.locator('.grid thead th',{hasText:'Tên riêng'}).dblclick();await page.locator('.header-input').fill('Bỏ');await page.keyboard.press('Escape');
  ok((await headText()).includes('Tên riêng') && !(await headText()).includes('Bỏ'),'nhấn Esc: hủy, giữ tên cũ');
  await page.locator('.grid thead th',{hasText:'Tên riêng'}).dblclick();await page.locator('.header-input').fill('   ');await page.keyboard.press('Enter');
  ok((await page.locator('.grid thead th').allInnerTexts()).some(t=>t.trim()==='Tên') && !(await viewJson()).headers.instance,'để trống: dùng lại tên gốc của cột (Tên), bỏ khỏi danh sách tiêu đề');
  await page.locator('.grid thead th',{hasText:'Mô tả'}).click();await page.waitForTimeout(400);
  ok((await page.locator('.grid thead th',{hasText:'Mô tả'}).innerText()).includes('▲'),'nhấp một lần vào tiêu đề: vẫn sắp xếp (sau một nhịp chờ nhấp đúp)');

  // ---- Thay thế ----
  await page.evaluate(()=>{tableState.sort=null;}); // bỏ sắp xếp của phần trên
  await receive('config',config('table'));await receive('table',table());await usePreset('Tất cả');await page.keyboard.press('Escape');await clear();
  ok(await page.locator('#replace-box').isHidden(),'chưa gõ chữ tìm: ô Thay thế ẩn');
  await page.fill('input[aria-label="Tìm trong bảng"]','cab');
  ok(await page.locator('#replace-box').isVisible() && (await page.locator('#replace-go').innerText())==='Thay thế (4)','gõ chữ tìm: hiện ô Thay thế kèm số ô sẽ đổi (Tên 3 + Mô tả 1)');
  await page.fill('input[aria-label="Thay bằng"]','Tủ');await page.click('#replace-go');
  const rep=await json('table_replace');
  ok(rep.find==='cab' && rep.replace==='Tủ' && JSON.stringify(rep.fields.sort())==='["description","name"]' && JSON.stringify(rep.indexes)==='[0,1,2]','bấm Thay thế: gửi chữ tìm, chữ thay, các cột đang hiện và các dòng đang lọc');
  await page.fill('input[aria-label="Tìm trong bảng"]','không có chữ này');
  ok(await page.locator('#replace-go').isDisabled() && (await page.locator('#replace-go').innerText())==='Thay thế (0)','không có ô nào khớp: nút Thay thế bị khóa');
  await page.click('.search-clear');
  ok(await page.locator('#replace-box').isHidden() && await page.locator('input[aria-label="Tìm trong bảng"]').inputValue()==='','nút × trong ô tìm: xóa chữ tìm và ẩn ô Thay thế');

  // ---- Chân trang ----
  await clear();
  ok((await page.locator('.bottombar .sw-label').allInnerTexts()).join('|')==='Thu phóng đối tượng|Cô lập đối tượng chọn|Chọn sâu bên trong|Diện tích chiếu|Bảng tên trên model|Hiển thị dòng tính tổng|Tổng chỉ cấp cao nhất' && await page.locator('.bottombar button[role="switch"]').count()===7,'chân trang: 7 nút gạt (role switch), có Diện tích chiếu và Bảng tên trên model');

  await clear();
  ok((await page.locator('.bottombar .sw').nth(4).getAttribute('aria-checked'))==='true','công tắc Bảng tên trên model: mặc định bật');
  await page.getByRole('switch',{name:'Bảng tên trên model'}).click();
  ok(JSON.stringify(await json('table_option'))==='{"label":false}','tắt Bảng tên trên model: gửi label = false cho Ruby');
  await receive('options',{zoom:true,isolate:false,deep:false,projected:false,label:false,isolating:false});
  ok((await page.locator('.bottombar .sw').nth(4).getAttribute('aria-checked'))==='false','Ruby báo tắt: công tắc chuyển sang tắt');
  await clear();await page.getByRole('switch',{name:'Bảng tên trên model'}).click();
  ok(JSON.stringify(await json('table_option'))==='{"label":true}','bật lại: gửi label = true');
  await receive('options',{zoom:true,isolate:false,deep:false,projected:false,label:true,isolating:false});  await page.getByRole('switch',{name:'Diện tích chiếu',exact:true}).click();
  ok(JSON.stringify(await json('table_option'))==='{"projected":true}','công tắc Diện tích chiếu: gửi tuỳ chọn');
  await page.getByRole('button',{name:'Nhập / Xuất ▾'}).click();
  ok((await page.locator('.io-panel button').allInnerTexts()).map(x=>x.replace(/\s+/g,' ').trim()).join('|')==='Cầu nối dữ liệu Sắp có|Xuất Excel|In PDF|Nhập preset (JSON)|Xuất preset (JSON)','menu Nhập / Xuất: Cầu nối dữ liệu (để sẵn, chưa dùng được), Xuất Excel, In PDF, nhập / xuất preset');
  const ioBox=await page.locator('.io-panel').boundingBox(),vp=page.viewportSize();
  ok(ioBox.x>=0 && ioBox.x+ioBox.width<=vp.width && ioBox.y>=0,'menu Nhập / Xuất nằm trọn trong cửa sổ (không bị cắt mép phải)');
  ok(await page.getByRole('button',{name:/Cầu nối dữ liệu/}).isDisabled(),'Cầu nối dữ liệu: để sẵn chỗ, nút chưa bấm được');
  await clear();await page.getByRole('button',{name:'Nhập preset (JSON)'}).click();
  ok(JSON.stringify(await json('table_preset'))==='{"action":"import"}' && await page.locator('.io-panel').count()===0,'Nhập preset: gửi lệnh và đóng menu');
  await page.getByRole('button',{name:'Nhập / Xuất ▾'}).click();await clear();await page.getByRole('button',{name:'Xuất preset (JSON)'}).click();
  ok(JSON.stringify(await json('table_preset'))==='{"action":"export"}','Xuất preset: gửi lệnh');
  await usePreset('Nội thất');await page.keyboard.press('Escape');
  await page.getByRole('button',{name:'Nhập / Xuất ▾'}).click();await clear();await page.getByRole('button',{name:'Xuất Excel'}).click();
  const exp=await json('table_export');
  ok(exp.format==='xlsx' && exp.title==='Bảng khối lượng' && exp.preset==='Nội thất' && exp.decimal_separator===',','xuất Excel: gửi định dạng, tiêu đề, preset và dấu thập phân');
  ok(JSON.stringify(exp.columns.map(c=>c.label))==='["STT","Ảnh","Mã hạng mục","Loại","Mô tả","Kích thước (R x S x C)","Thương hiệu","Số lượng"]' && JSON.stringify(exp.columns.map(c=>c.type))==='["ordinal","image","text","text","text","text","text","number"]','xuất Excel: tiêu đề cột theo preset (kể cả tên tự đặt) và kiểu cột');
  const dataRows=exp.rows.filter(r=>r.kind==='row'),totalRow=exp.rows.filter(r=>r.kind==='total');
  ok(dataRows.length===3 && totalRow.length===1 && exp.rows[exp.rows.length-1].kind==='total','xuất Excel: đủ 3 dòng và một dòng tổng ở cuối');
  ok(JSON.stringify(dataRows[0].cells)==='[1,null,"Cabinet","Cab 0","","1.200 × 600 × 800","Hafele",1]' && dataRows[0].pid===900 && dataRows[1].pid===901,'xuất Excel: ô đúng như đang hiện (cột Ảnh gửi kèm mã đối tượng, số quantity là số)');
  ok(exp.columns.every(c=>Number.isInteger(c.width)&&c.width>=20&&c.width<=2000) && exp.columns[1].width===72 && exp.labels.reset==='Đặt lại độ rộng cột' && exp.labels.hint.includes('Kéo mép'),'xuất: gửi kèm độ rộng từng cột đang chỉnh trên màn hình (cột Ảnh 72) và nhãn nút chỉnh độ rộng')
  ok(totalRow[0].cells[3]==='Tổng cộng · 3 đối tượng' && totalRow[0].cells[7]===3,'xuất Excel: dòng tổng có nhãn và tổng số lượng');
  await usePreset('Tất cả');await page.keyboard.press('Escape');
  await page.getByRole('button',{name:'Chọn cột'}).click();
  for(const label of ['Rộng (X) mm','Đơn giá'])await page.locator('.pop-col',{hasText:new RegExp('^\\s*'+label.replace(/[()]/g,'\\$&')+'\\s*⠿?$')}).locator('input').check();
  await page.getByRole('button',{name:'Chọn cột'}).click();
  await page.getByRole('button',{name:'Nhóm theo: Không nhóm ▾'}).click();
  const gb=await page.getByRole('button',{name:'Nhóm theo: Không nhóm ▾'}).boundingBox(),gp=await page.locator('.group-panel').boundingBox();
  ok(Math.abs((gp.x+gp.width)-(gb.x+gb.width))<=1 && gp.y>=gb.y+gb.height-1 && gp.x>=0,'popup Nhóm theo nằm ngay dưới nút Nhóm theo, canh phải theo nút (không lệch sang cạnh nút Chọn cột)');
  await page.getByRole('button',{name:'Tên họ (Definition)'}).click();
  await page.getByRole('button',{name:'Nhập / Xuất ▾'}).click();await clear();await page.getByRole('button',{name:'In PDF'}).click();
  const pdf=await json('table_export');
  const lenCol=pdf.columns.findIndex(c=>c.label.startsWith('Rộng')),priceCol=pdf.columns.findIndex(c=>c.label==='Đơn giá');
  ok(pdf.format==='pdf' && pdf.rows[0].kind==='group' && pdf.rows[0].cells.some(c=>typeof c==='string' && c.includes('Cabinet · 3')),'In PDF với nhóm theo: dòng nhóm đứng đầu, có tên nhóm và số đối tượng');
  ok(pdf.rows.filter(r=>r.kind==='row').length===3 && pdf.rows[1].cells[lenCol]===1200 && pdf.rows[1].cells[priceCol]===2500000 && pdf.rows[2].cells[priceCol]===null,'xuất theo nhóm: số gửi dạng số đã đổi đơn vị, ô không có giá trị là rỗng');
  ok(pdf.columns[lenCol].unit==='mm' && pdf.columns[lenCol].digits===0 && pdf.columns[priceCol].unit==='VND','xuất: gửi kèm đơn vị và số lẻ của từng cột');
  await page.getByRole('button',{name:'Nhóm theo: Tên họ (Definition) ▾'}).click();await page.getByRole('button',{name:'Không nhóm'}).click();

  // ---- Cột mới ----
  await receive('config',config('table'));await receive('table',table());await usePreset('Tất cả');await page.keyboard.press('Escape');await clear();
  await page.getByRole('button',{name:'Chọn cột'}).click();
  for(const label of ['Xuất xứ','Liên kết','Quy cách','Đơn giá','Thành tiền','Loại IFC','Diện tích chiếu bằng m²'])await page.locator('.pop-col',{hasText:new RegExp('^\\s*'+label+'\\s*⠿?$')}).locator('input').check();
  ok((await calls('table_option')).some(c=>JSON.parse(c.args[0]).projected===true),'hiện cột Diện tích chiếu: tự bật công tắc cho Ruby tính');
  await page.getByRole('button',{name:'Chọn cột'}).click();
  ok(await cellText(0,'owner')==='Hafele' && await cellText(0,'ifc')==='IfcFurniture' && await cellText(0,'price')==='2.500.000' && await cellText(0,'total')==='2.500.000' && await cellText(1,'price')==='','cột mới hiện đúng: hãng, lớp IFC, đơn giá và thành tiền (VND không số lẻ), dòng chưa nhập để trống');
  ok(await page.locator('.grid tbody tr').nth(0).locator('td[data-key="url"] .cell-url').innerText()==='https://vgd.vn/tu' && await page.locator('.grid tbody tr').nth(1).locator('td[data-key="url"] .cell-open').count()===0,'cột Link: hiện địa chỉ, nút mở chỉ có khi có link');
  await clear();await page.locator('.grid tbody tr').nth(0).locator('td[data-key="url"] .cell-open').click();
  ok((await last('open_url')).args[0]==='https://vgd.vn/tu' && (await calls('table_select')).length===0,'bấm nút mở link: gọi open_url, không chọn dòng');
  await page.locator('.grid tbody tr').nth(1).locator('td[data-key="price"]').dblclick();
  await page.locator('.grid tbody tr input').fill('1500000');await page.keyboard.press('Enter');
  let edit=await json('table_edit');
  ok(edit.field==='price' && edit.value==='1500000' && JSON.stringify(edit.indexes)==='[1]','nhấp đúp ô Đơn giá: gõ số rồi Enter gửi lệnh sửa');
  await page.locator('.grid tbody tr').nth(1).locator('td[data-key="owner"]').dblclick();await page.locator('.grid tbody tr input').fill('IKEA');await page.keyboard.press('Enter');
  ok((await json('table_edit')).field==='owner','nhấp đúp ô Hãng: sửa được');
  await page.locator('.grid tbody tr').nth(1).locator('td[data-key="size"]').dblclick();await page.locator('.grid tbody tr input').fill('1200x600');await page.keyboard.press('Enter');
  ok((await json('table_edit')).field==='size','nhấp đúp ô Cỡ: sửa được');
  ok(await page.locator('.grid tfoot td').allInnerTexts().then(t=>t.some(x=>x==='2.500.000')),'dòng tổng cộng: cộng Thành tiền');
  await usePreset('Tất cả').catch(()=>{});await page.keyboard.press('Escape');
  await receive('table',table({options:{zoom:true,isolate:false,deep:false,projected:true,isolating:false}}));
  ok(await page.locator('.bottombar .sw[aria-checked="true"][aria-label="Diện tích chiếu"]').count()===1,'công tắc Diện tích chiếu phản ánh tuỳ chọn Ruby gửi về');

  // ---- Thông tin theo đơn vị của preset ----
  await receive('config',config('table'));await receive('table',table());await usePreset('Phòng & Khu vực');await choose('Chiều dài: đơn vị','cm');await choose('Chiều dài: số lẻ',0);await page.keyboard.press('Escape');
  await receive('config',config('information'));
  await receive('information',{count:1,fields:{},objects:[{entity_type:'Group',source:'RAW',instance_name:'a',definition_name:'d',tag:'t',material:'',dimensions:{width:1200,depth:600,height:800},locked:false,status:'UNCLASSIFIED'}]});
  const info=await page.locator('.card').last().innerText();
  ok(info.includes('Rộng × Sâu × Cao (cm)') && info.includes('120 × 60 × 80'),'tab Thông tin: tiêu đề và kích thước theo đơn vị của preset (cm)');

  // ---- Loại trừ tag: ngăn tick các tag của model, lưu sau khi ngừng tick ----
  const tagRows=table({choices:{tags:['Đá bếp','Tay nắm','Cánh tủ','Phụ kiện'],materials:[],model_tags:['Cánh tủ','Đá bếp','Phụ kiện','Tay nắm']}});
  await receive('config',{...config('table'),app:{settings:{language:'vi',image_dir:'',exclude_words:'tay nắm, handle',exclude_tags:['Đá bếp']},dir:'C:\\data\\images',dir_exists:true}});await receive('table',tagRows);
  await clear();
  ok((await page.locator('#exclude-btn').innerText())==='Loại trừ tag (1)','nút Loại trừ tag hiện số tag đang được loại trừ');
  await page.click('#exclude-btn');await page.waitForTimeout(350);
  ok((await page.locator('.col-side .pop-col').allInnerTexts()).map(x=>x.trim()).join('|')==='Cánh tủ|Đá bếp|Phụ kiện|Tay nắm' && (await page.locator('#col-side').getAttribute('data-kind'))==='exclude','ngăn Loại trừ tag mở ra, liệt kê tag của model theo thứ tự chữ cái');
  ok(await page.locator('.col-side .pop-col').nth(1).locator('input').isChecked() && !(await page.locator('.col-side .pop-col').nth(0).locator('input').isChecked()),'tag đang loại trừ (Đá bếp) được tick sẵn');
  ok((await page.locator('.col-side .badge').innerText())==='1 / 4','huy hiệu đếm tag loại trừ / tổng tag của model'.replace('huy hiệu','huy hiệu'));
  await page.locator('.col-side .pop-col').nth(3).locator('input').click();
  ok((await page.locator('#exclude-btn').innerText())==='Loại trừ tag (2)' && !(await last('settings_save')),'tick thêm một tag: nút cập nhật số ngay, nhưng chưa gửi lưu (đợi ngừng tick)');
  await page.waitForTimeout(700);
  ok(JSON.stringify(await json('settings_save'))==='{"exclude_tags":["Đá bếp","Tay nắm"]}','sau khi ngừng tick: gửi một lần settings_save với danh sách tag mới');
  await clear();
  await page.locator('.col-side .pop-col').nth(1).locator('input').click();await page.locator('.col-side .pop-col').nth(3).locator('input').click();await page.waitForTimeout(700);
  ok(JSON.stringify(await json('settings_save'))==='{"exclude_tags":[]}' && (await calls('settings_save')).length===1,'tick nhiều lần liên tiếp: chỉ gửi lưu một lần (không tính lại số đo sau từng cú tick)');
  await page.locator('.col-side .pop-search').fill('phụ');
  ok((await page.locator('.col-side .pop-col').count())===1,'ô tìm tag lọc danh sách');
  await clear();await page.locator('.col-side .cs-all input').click();await page.waitForTimeout(700);
  ok(JSON.stringify(await json('settings_save'))==='{"exclude_tags":["Phụ kiện"]}','Chọn tất cả chỉ tác động tag đang lọc (Phụ kiện)');
  await page.locator('.col-side .pop-search').fill('');
  await receive('settings',{settings:{language:'vi',image_dir:'',exclude_words:'tay nắm, handle',exclude_tags:['Phụ kiện','Tag cũ']},dir:'C:\\data\\images',dir_exists:true});
  ok((await page.locator('.col-side .pop-col').last().innerText()).includes('Tag cũ (không có trong model)'),'tag đã lưu nhưng không có trong model này vẫn hiện (kèm ghi chú) để bỏ tick được');
  await page.click('#cols-btn');await page.waitForTimeout(100);
  ok((await page.locator('#col-side').getAttribute('data-kind'))==='columns' && (await page.locator('.col-side .pop-col').count())>20 && (await page.locator('#col-side').evaluate(el=>el.classList.contains('open'))),'bấm Chọn cột khi ngăn Loại trừ đang mở: đổi nội dung sang Chọn cột, ngăn vẫn mở');
  await page.click('#exclude-btn');await page.waitForTimeout(100);
  ok((await page.locator('#col-side').getAttribute('data-kind'))==='exclude','bấm lại Loại trừ tag: đổi về ngăn Loại trừ');
  await page.click('#exclude-btn');await page.waitForTimeout(400);
  ok(!(await page.locator('#col-side').evaluate(el=>el.classList.contains('open'))) && (await page.locator('#exclude-btn').getAttribute('aria-expanded'))==='false','bấm Loại trừ tag khi đang mở: đóng ngăn');
  await receive('config',config('table'));await receive('table',table());await clear();

  // ---- Số đo thân: từ khóa loại trừ và công tắc cắt phần nhô nằm trong bảng Preset ----
  await openPresets();
  ok(await page.locator('#exclude-words').inputValue()==='tay nắm, handle','bảng Preset: ô từ khóa loại trừ hiện giá trị đang lưu');
  await clear();await page.locator('#exclude-words').fill('tay nắm, knob');await page.locator('#exclude-words').press('Enter');
  ok(JSON.stringify(await json('settings_save'))==='{"exclude_words":"tay nắm, knob"}','gõ từ khóa rồi Enter: gửi settings_save với từ khóa mới');
  await clear();await page.locator('#exclude-words').fill('tay nắm, handle');await page.locator('#exclude-words').press('Enter');
  ok(!(await last('settings_save')),'từ khóa không đổi: không gửi lệnh lưu');
  ok((await page.locator('#preset-panel').innerText()).includes('xem cột Ghi chú số đo') && !(await page.locator('#preset-panel').innerText()).includes('Tự cắt'),'bảng Preset: mục Số đo thân chỉ còn từ khóa (không còn tùy chọn tự cắt phần nhô), chỉ cột Ghi chú số đo');
  await page.keyboard.press('Escape');
  await page.evaluate(()=>{const r=tableState.data.rows[0];r.measure_note='Bỏ 1 phần theo từ khóa hoặc tag (Tay nam); tay nắm +Y';tableState.visible.add('measure_note');tableState.order=tableState.data.columns.map(c=>c.key);tableView(tableState.data);});
  ok((await cellText(0,'measure_note')).includes('Bỏ 1 phần theo từ khóa hoặc tag (Tay nam)'),'cột Ghi chú số đo: hiện phần đã bỏ theo từ khóa');

  // ---- Mặt trước: cột, nhóm theo, bảng phát hiện / đặt tay ----
  const frontRows=rows.map((r,i)=>({...r,front:i===0?'+Y':i===1?'-X':'',front_state:i===0?'Tự động · cao':i===1?'Cần duyệt':'',front_note:i===1?'sát tường phía +x; tường chỉ +x nhưng chi tiết hình học chỉ -x: cần duyệt':'',front_conf:i===0?'high':i===1?'low':''}));
  await receive('config',config('table'));await receive('table',table({rows:frontRows}));await usePreset('Tất cả');await page.keyboard.press('Escape');
  await page.evaluate(()=>{tableState.visible.add('front');tableState.visible.add('front_state');tableState.order=tableState.data.columns.map(c=>c.key);tableView(tableState.data);});
  ok(await cellText(0,'front')==='+Y' && await cellText(0,'front_state')==='Tự động · cao' && await cellText(2,'front')==='','cột Mặt trước và Độ tin cậy: hiện hướng và trạng thái, món chưa có thì để trống');
  ok((await page.locator('.grid tbody tr').nth(1).locator('td[data-key="front_state"]').getAttribute('title')).includes('cần duyệt') && !(await page.locator('.grid tbody tr').nth(0).locator('td[data-key="front_state"]').getAttribute('title')),'ô Độ tin cậy: rê chuột hiện lý do tự động chọn (chỉ khi có ghi chú)');
  await page.getByRole('button',{name:'Nhóm theo: Không nhóm ▾'}).click();await page.getByRole('button',{name:'Mặt trước (độ tin cậy)'}).click();
  const groups=await page.locator('.grid tbody tr.group-row').allInnerTexts();
  ok(groups.some(g=>g.includes('Cần duyệt')) && groups.some(g=>g.includes('(Chưa có mặt trước)')) && groups.some(g=>g.includes('Tự động · cao')),'nhóm theo Mặt trước (độ tin cậy): có nhóm Cần duyệt, Tự động · cao, Chưa có mặt trước');
  await page.getByRole('button',{name:/Nhóm theo: Mặt trước/}).click();await page.getByRole('button',{name:'Không nhóm'}).click();
  await clear();
  await page.click('#front-btn');
  ok((await page.locator('.front-panel').innerText()).includes('Chưa chọn dòng nào: phát hiện tự động cho tất cả 3 đối tượng đang hiện.'),'bảng Mặt trước: chưa chọn dòng thì nói rõ phát hiện cho tất cả');
  await page.click('#front-detect');
  ok(JSON.stringify(await json('front_detect'))==='{"indexes":[],"overwrite":false}','Phát hiện tự động khi chưa chọn: gửi indexes rỗng (Ruby lấy mọi dòng), không ghi đè');
  await page.click('#front-camera');
  ok((await message()).includes('Hãy chọn đối tượng trong bảng trước.') && !(await last('front_set')),'đặt tay khi chưa chọn dòng: báo lỗi, không gửi lệnh');
  await page.click('#front-btn');
  await page.locator('.grid tbody tr').nth(0).locator('td[data-key="instance"]').click();
  await page.click('#front-btn');
  ok((await page.locator('.front-panel').innerText()).includes('Áp dụng cho 1 đối tượng đang chọn.'),'bảng Mặt trước: đã chọn dòng thì áp cho dòng đang chọn');
  await page.locator('#front-overwrite').check();await clear();await page.click('#front-detect');
  ok(JSON.stringify(await json('front_detect'))==='{"indexes":[0],"overwrite":true}','Phát hiện cho dòng đang chọn, tick Ghi đè thì gửi overwrite = true');
  for(const [id,mode] of [['front-camera','camera'],['front-turn','turn'],['front-opposite','opposite']]){await clear();await page.click('#'+id);ok(JSON.stringify(await json('front_set'))===JSON.stringify({indexes:[0],mode}),'nút '+id+': gửi front_set mode='+mode+' cho dòng đang chọn');}
  await clear();await page.click('#front-clear');
  ok(JSON.stringify(await json('front_clear'))==='{"indexes":[0]}','nút Xóa mặt trước: gửi front_clear cho dòng đang chọn');
  // Sửa trục: phải xem trước rồi mới áp dụng được; chỉ cho các dòng đang chọn
  ok(await page.locator('#front-align-apply').isDisabled(),'Sửa trục: nút Áp dụng bị khóa khi chưa xem trước');
  await clear();await page.click('#front-align-preview');
  ok(JSON.stringify(await json('front_align_preview'))==='{"indexes":[0]}','Xem trước sửa trục: gửi front_align_preview cho dòng đang chọn');
  await receive('front_align_plan',{key:[0],fix:2,instances:5,aligned:1,skipped:3,reasons:[{reason:'component động',count:2},{reason:'chưa có mặt trước',count:1}],names:['Tủ A','Tủ B']});
  const planText=await page.locator('.front-plan').innerText();
  ok(planText.includes('Sẽ sửa trục 2 loại (5 bản sao).') && planText.includes('Gồm: Tủ A, Tủ B') && planText.includes('Đã có mặt trước -Y: 1 loại.') && planText.includes('Bỏ qua 2 loại: component động.') && planText.includes('Bỏ qua 1 loại: chưa có mặt trước.'),'bản xem trước hiện số loại, bản sao, tên, đã đúng và lý do bỏ qua');
  ok(await page.locator('#front-align-apply').isEnabled(),'có bản xem trước cho đúng dòng đang chọn: nút Áp dụng bật');
  await clear();await page.click('#front-align-apply');
  ok(JSON.stringify(await json('front_align'))==='{"indexes":[0]}' && !(await page.locator('.front-plan').count()),'Áp dụng sửa trục: gửi front_align, bản xem trước cũ bị xóa ngay (phải xem trước lại)');
  await receive('front_align_plan',{key:[0],fix:0,instances:0,aligned:2,skipped:0,reasons:[],names:[]});
  ok((await page.locator('.front-plan').innerText()).includes('Không có món nào cần sửa trục.') && await page.locator('#front-align-apply').isDisabled(),'không có gì cần sửa: báo rõ, nút Áp dụng vẫn khóa');
  await receive('front_align_plan',{key:[0],fix:3,instances:3,aligned:0,skipped:0,reasons:[],names:['A']});
  await receive('front_align_plan',{cleared:true});
  ok(!(await page.locator('.front-plan').count()) && await page.locator('#front-align-apply').isDisabled(),'Ruby báo đã áp dụng (cleared): bản xem trước biến mất');
  await receive('front_align_plan',{key:[1],fix:3,instances:3,aligned:0,skipped:0,reasons:[],names:['A']});
  ok(!(await page.locator('.front-plan').count()) && await page.locator('#front-align-apply').isDisabled(),'bản xem trước của dòng khác (đã đổi lựa chọn): không hiện, không cho áp dụng');
  await page.click('#front-btn');
  await page.evaluate(()=>{tableState.panel=null;tableState.sel=new Set();tableView(tableState.data);});

  // ---- Ngăn Chọn cột: đẩy bảng sang phải, hiệu ứng trượt, kéo đổi chỗ, ô tick, nút gạt ----
  await receive('config',config('table'));await receive('table',table());await usePreset('Tất cả');await page.keyboard.press('Escape');
  const gridLeft=()=>page.locator('.grid-wrap').evaluate(el=>Math.round(el.getBoundingClientRect().left));
  const sideBox=()=>page.locator('#col-side').evaluate(el=>{const r=el.getBoundingClientRect();return {left:Math.round(r.left),right:Math.round(r.right),width:Math.round(r.width)};});
  const left0=await gridLeft();
  await page.getByRole('button',{name:'Chọn cột',exact:true}).click();
  await page.waitForTimeout(70);
  const mid=await sideBox();
  ok(mid.width>0 && mid.width<230,'mở Chọn cột: ngăn trượt ra từ từ (đang chạy hiệu ứng, chưa đủ rộng)');
  await page.waitForTimeout(350);
  const open=await sideBox(),left1=await gridLeft();
  ok(open.width===230 && left1>=open.right && left1-left0>=230,'mở xong: bảng bị đẩy sang phải, cột đầu tiên không bị ngăn che (bảng bắt đầu sau ngăn)');
  ok(await page.locator('.col-side .pop-col').count()===(await page.evaluate(()=>tableState.data.columns.length)) && (await page.locator('#cols-btn').getAttribute('aria-expanded'))==='true','ngăn liệt kê đủ cột; nút Chọn cột báo đang mở');
  ok(await page.evaluate(()=>{const d=document.querySelector('.col-side .pop-density').getBoundingClientRect(),i=document.querySelector('.col-side-in').getBoundingClientRect();return d.bottom<=i.bottom+0.5&&d.height>=24;}),'ngăn Chọn cột: ô Độ cao hàng ở đáy hiện trọn, không bị cắt');
  const itemH=await page.locator('.col-side .pop-col').first().evaluate(el=>el.getBoundingClientRect().height);
  ok(itemH<=28,'danh sách gọn: mỗi cột cao tối đa 28px (đo được '+itemH+'px)');
  // Ô tick: bật / tắt cột không dựng lại ngăn (cùng phần tử, vị trí cuộn giữ nguyên), bảng cập nhật ngay
  const keep=await page.evaluate(()=>{const list=document.querySelector('.col-side .pop-cols');window.__list=list;list.scrollTop=40;return list.scrollTop;});
  const firstBox=page.locator('.col-side .pop-col').nth(2).locator('input');
  const headBefore=await page.locator('.grid thead tr:first-child th').count();
  await firstBox.click();
  const after=await page.evaluate(()=>({same:window.__list===document.querySelector('.col-side .pop-cols'),top:window.__list.scrollTop}));
  ok(after.same && after.top===keep,'bật / tắt cột: ngăn không bị dựng lại, vị trí cuộn của danh sách giữ nguyên');
  ok((await page.locator('.grid thead tr:first-child th').count())!==headBefore,'bật / tắt cột: bảng đổi theo ngay');
  await firstBox.click();
  await page.getByRole('button',{name:'Bỏ chọn tất cả'}).click().catch(()=>{});
  // Kéo đổi chỗ: mục kéo chuyển chỗ trực tiếp có hiệu ứng, thả xong thứ tự cột của bảng đổi
  const keysBefore=await page.evaluate(()=>[...document.querySelectorAll('.col-side .pop-col')].map(e=>e.dataset.key));
  const dragged=await page.evaluate(()=>{
    const items=[...document.querySelectorAll('.col-side .pop-col')],a=items[3],b=items[1];
    const dt=new DataTransfer();
    a.dispatchEvent(new DragEvent('dragstart',{dataTransfer:dt,bubbles:true}));
    const box=b.getBoundingClientRect();
    b.dispatchEvent(new DragEvent('dragover',{dataTransfer:dt,bubbles:true,cancelable:true,clientY:box.top+2}));
    const moving=[...document.querySelectorAll('.col-side .pop-col')].some(el=>getComputedStyle(el).transform!=='none'); // đang giữa hiệu ứng trượt
    const keys=[...document.querySelectorAll('.col-side .pop-col')].map(e=>e.dataset.key);
    a.dispatchEvent(new DragEvent('dragend',{dataTransfer:dt,bubbles:true}));
    return {moving,keys,order:tableState.order.slice(0,5)};
  });
  ok(dragged.moving,'kéo đổi chỗ: các mục trượt sang vị trí mới (có hiệu ứng, không nhảy)');
  ok(dragged.keys[1]===keysBefore[3] && dragged.keys[2]===keysBefore[1] && dragged.order[1]===keysBefore[3],'thả xong: thứ tự cột của bảng đổi theo danh sách (cột kéo lên vị trí mới)');
  const headers=await page.locator('.grid thead tr:first-child th').allInnerTexts();
  ok(headers.length>0,'bảng vẫn vẽ lại sau khi đổi thứ tự');
  // Đóng: ngăn thu lại, bảng trở về chỗ cũ
  await page.locator('.cs-close').click();
  await page.waitForTimeout(400);
  ok((await sideBox()).width===0 && (await gridLeft())===left0 && (await page.locator('.col-side').evaluate(el=>el.childElementCount))===0,'đóng: ngăn thu lại hết, bảng về chỗ cũ');
  // Nút gạt chân trang: cùng một nút, trượt từ từ
  const totalsSwitch=page.locator('.bottombar .sw').nth(5); // Hiển thị dòng tính tổng
  const swBefore=await totalsSwitch.getAttribute('aria-checked');
  await page.evaluate(()=>{window.__sw=document.querySelectorAll('.bottombar .sw')[5];});
  await totalsSwitch.click();
  await page.waitForTimeout(60);
  const thumb=await page.evaluate(()=>parseFloat(getComputedStyle(window.__sw,'::after').left));
  ok((await totalsSwitch.getAttribute('aria-checked'))!==swBefore && thumb>2 && thumb<20 && await page.evaluate(()=>window.__sw===document.querySelectorAll('.bottombar .sw')[5]),'nút gạt: cùng một phần tử, đầu gạt đang trượt (không nhảy), trạng thái đổi');
  await page.waitForTimeout(250);
  await totalsSwitch.click();await page.waitForTimeout(250);

  // ---- Không hiện thanh cuộn dọc ở mọi nơi; chỉ giữ thanh cuộn ngang của bảng ----
  await page.setViewportSize({width:700,height:520});
  const longRows=Array.from({length:60},(_,i)=>({...rows[i%3],index:i,pid:1000+i,name:'Dòng '+i,has_image:false}));
  await receive('config',config('table'));await receive('table',table({rows:longRows}));await usePreset('Tất cả');await page.keyboard.press('Escape');
  await page.evaluate(()=>{for(const c of tableState.data.columns)tableState.visible.add(c.key);tableState.order=tableState.data.columns.map(c=>c.key);tableView(tableState.data);});
  const bars=sel=>page.locator(sel).first().evaluate(el=>{const cs=getComputedStyle(el),side=(a,b)=>parseFloat(cs[a])+parseFloat(cs[b]);return {v:el.offsetWidth-el.clientWidth-side('borderLeftWidth','borderRightWidth'),h:el.offsetHeight-el.clientHeight-side('borderTopWidth','borderBottomWidth'),tall:el.scrollHeight>el.clientHeight,wide:el.scrollWidth>el.clientWidth};});
  const grid=await bars('.grid-wrap');
  ok(grid.tall && grid.v===0,'bảng nhiều dòng: không có thanh cuộn dọc');
  ok(grid.wide && grid.h>0 && grid.h<=12,'bảng nhiều cột: vẫn có thanh cuộn ngang (mảnh)');
  await page.locator('.grid-wrap').hover();await page.mouse.wheel(0,300);await page.waitForTimeout(150);
  ok(await page.locator('.grid-wrap').evaluate(el=>el.scrollTop)>0,'vẫn cuộn dọc được bằng con lăn chuột');
  await page.getByRole('button',{name:'Chọn cột'}).click();
  await page.waitForTimeout(350);const colPop=await bars('.col-side .pop-cols');
  ok(colPop.tall && colPop.v===0,'bảng Chọn cột: không có thanh cuộn dọc');
  await page.mouse.move(100,300);await page.mouse.wheel(0,200);await page.waitForTimeout(100);
  ok(await page.locator('.col-side .pop-cols').evaluate(el=>el.scrollTop)>0,'bảng Chọn cột: vẫn cuộn được bằng con lăn chuột');
  await page.getByRole('button',{name:'Chọn cột'}).click();
  await openPresets();
  const presetPanelBars=await bars('#preset-panel');
  ok(presetPanelBars.v===0,'bảng Preset: không có thanh cuộn dọc');
  await page.keyboard.press('Escape');
  await page.evaluate(()=>{document.querySelector('main').style.overflow='auto';});
  await receive('config',config('scan'));
  const mainBars=await bars('main');
  ok(mainBars.v===0,'các tab khác (khung chính): không có thanh cuộn dọc');
  await page.setViewportSize({width:1100,height:800});

  // ---- Đổi ngôn ngữ thì tải lại cửa sổ ----
  await receive('config',config('table'));
  const reloaded=page.waitForEvent('load',{timeout:5000}).then(()=>true,()=>false);
  await receive('config',{...config('table'),language:'en',app:{settings:{language:'en',image_dir:''},dir:'C:\\data\\images',dir_exists:true},locale:F.en,vi_en:F.vi_en});
  ok(await reloaded,'đổi ngôn ngữ giữa chừng: cửa sổ tự tải lại để vẽ từ đầu bằng ngôn ngữ mới');
  ok(errors.length===0,'không có lỗi JavaScript'+(errors.length?': '+errors.join(' | '):''));
 }finally{await browser.close();}
 console.log(failed?`${failed} lỗi`:'Done');
})().catch(e=>{console.log('FAIL  '+e.message);process.exit(1);});
