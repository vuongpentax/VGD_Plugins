// Test giao diện: sheet của bảng khối lượng (như Excel: nằm dưới chân trang, cột / sắp xếp / bộ lọc / tag loại trừ riêng mỗi sheet)
// và gợi ý nhập kiểu Excel (chữ mờ điền sẵn, Enter / Tab nhận) trong ô chữ của bảng.
// Chạy: node dev/test_ui_sheets.cjs (đặt VGD_PLAYWRIGHT_MODULE nếu cần; cần ruby để lấy dữ liệu thật)
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),{execFileSync}=require('child_process');
const {chromium}=require(process.env.VGD_PLAYWRIGHT_MODULE || 'playwright');
let failed=0;
const ok=(cond,msg)=>{console.log((cond?'PASS  ':'FAIL  ')+msg);if(!cond){failed++;process.exitCode=1;}};
const F=JSON.parse(execFileSync('ruby',[path.resolve(__dirname,'ui_fixture.rb')],{encoding:'utf8'}));
const presets=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../runtime/vgd_bim/config/presets.json'),'utf8'));
const NAMES=['Tủ bếp dưới','Tủ bếp trên','Bàn ăn'];
const config=(mode,o={},excluded=[],file='C:\\data\\a_VGD_BIM')=>({mode,version:'1.1.0',language:'vi',file,app:{settings:{language:'vi',exclude_words:'tay nắm, handle',exclude_tags:excluded},dir:file,dir_exists:true,saved:true},preset_info:F.preset_info,table:{columns:F.columns,presets:F.presets,view:{}},fields:F.fields,categories:F.categories,units:F.units,methods:F.methods,presets,locale:F.vi,vi_en:null,scan_options:{scope:'model',faces:true},...o});
const rows=()=>NAMES.map((n,i)=>({index:i,entity_type:'Nhóm',definition:'Cabinet',name:n,description:i===0?'Mô tả cũ':'',lenX:1200,lenY:600,lenZ:800,areaXZ:0.96,areaXY:0.72,areaFace:2.1,areaProjected:1.5,volume:0.5,ifc:'',tag:'',tag_group:'Phần thô',material:'',status:'new',owner:'',url:'',size:'',price:null,total:null,locked:false,quantity:1,parents:[],parent:'',pid:900+i,has_image:false,image_stamp:0,image_url:null}));
const table=(o={})=>({columns:F.columns,presets:F.presets,groups:F.groups,statuses:F.statuses,options:{zoom:true,isolate:false,deep:false,projected:false,isolating:false},rows:rows(),selected:[],hint:null,view:{},choices:{tags:[],materials:[],model_tags:['Cửa','Tường','Rèm'],suggest:{name:['Tủ bếp dưới','Bàn ăn đôi'],description:['Giao tuần sau']}},...o});
(async()=>{
 const browser=await chromium.launch({headless:true,channel:process.env.VGD_BROWSER_CHANNEL||undefined,ignoreDefaultArgs:['--hide-scrollbars']});
 try{
  const page=await browser.newPage({viewport:{width:1100,height:800}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{try{localStorage.setItem('vgd.bim.tools.open',JSON.stringify({export:true,table:true,data:true,site:true,check:true}));}catch(_){}/* mọi nhóm menu Công cụ mở sẵn để test bấm thẳng; mặc định gập kiểm riêng */window.calls=[];window.sketchup=new Proxy({}, {get:(_,name)=>(...args)=>window.calls.push({name,args})})});
  await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_bim/html/index.html')).href);
  const receive=(event,data)=>page.evaluate(([e,d])=>window.VGD.receive(e,d),[event,data]);
  const calls=name=>page.evaluate(n=>window.calls.filter(c=>c.name===n).map(c=>({name:c.name,args:c.args})),name);
  const last=async name=>{const c=await calls(name);return c.length?c[c.length-1]:null;};
  const json=async name=>{const c=await last(name);return c?JSON.parse(c.args[0]):null;};
  const clear=()=>page.evaluate(()=>{window.calls.length=0;});
  const message=()=>page.locator('#message').innerText();
  const tabs=()=>page.locator('.sheetbar .sheet-tab').allInnerTexts();
  const activeTab=()=>page.locator('.sheetbar .sheet-tab[aria-selected=true]').innerText();
  const heads=()=>page.locator('.grid thead tr:first-child').innerText();
  const openColumns=async()=>{if(!(await page.locator('#col-side.open').count()))await page.click('#cols-btn');await page.waitForTimeout(350);};
  const toggleColumn=async label=>{await openColumns();await page.locator('.col-side .pop-col',{hasText:label}).first().locator('input').click();};
  const settle=ms=>page.waitForTimeout(ms||150);

  await receive('config',config('table'));await receive('table',table());

  // ---- Sheet: thanh dưới chân trang ----
  ok(JSON.stringify(await tabs())==='["Sheet1"]' && await page.locator('.sheetbar .sheet-add').count()===1,'mới mở: có một sheet "Sheet1" và nút + thêm sheet');
  ok((await activeTab())==='Sheet1','sheet đầu tiên đang mở');
  const box=await page.evaluate(()=>{const b=document.querySelector('.tv-split').getBoundingClientRect(),s=document.querySelector('.sheetbar').getBoundingClientRect(),f=document.querySelector('footer.status-bar,.status-bar').getBoundingClientRect();return {bottombar:b.bottom,sheet:s.top,sheetBottom:s.bottom,status:f.top};});
  ok(box.sheet>=box.bottombar-1 && box.sheetBottom<=box.status+1,'thanh sheet nằm dưới khung bảng, ngay trên thanh trạng thái (chân trang)');

  // ---- Cột riêng từng sheet ----
  ok((await heads()).includes('Mô tả'),'Sheet1 đang hiện cột Mô tả');
  await toggleColumn('Mô tả');await settle();
  ok(!(await heads()).includes('Mô tả'),'bỏ tick Mô tả: Sheet1 ẩn cột');
  await page.click('.sheetbar .sheet-add');await settle(300);
  ok(JSON.stringify(await tabs())==='["Sheet1","Sheet2"]' && (await activeTab())==='Sheet2','bấm +: có Sheet2 và chuyển sang Sheet2');
  ok(!(await heads()).includes('Mô tả'),'sheet mới sao chép cài đặt của sheet đang mở (cũng ẩn Mô tả)');
  await toggleColumn('Mô tả');await settle();
  ok((await heads()).includes('Mô tả'),'Sheet2 tick lại Mô tả: hiện');
  await page.locator('.sheetbar .sheet-tab',{hasText:'Sheet1'}).click();await settle(300);
  ok((await activeTab())==='Sheet1' && !(await heads()).includes('Mô tả'),'quay về Sheet1: vẫn ẩn Mô tả (cột riêng từng sheet)');
  await page.locator('.sheetbar .sheet-tab',{hasText:'Sheet2'}).click();await settle(300);
  ok((await heads()).includes('Mô tả'),'sang Sheet2: vẫn hiện Mô tả');

  // ---- Tìm kiếm / nhóm theo riêng từng sheet ----
  await page.fill('input[placeholder^="Tìm kiếm"]','Bàn');await settle(300);
  ok((await page.locator('.grid tbody tr').count())===1,'Sheet2: gõ tìm "Bàn" còn 1 dòng');
  await page.locator('.sheetbar .sheet-tab',{hasText:'Sheet1'}).click();await settle(300);
  ok((await page.locator('.grid tbody tr').count())===3 && (await page.inputValue('input[placeholder^="Tìm kiếm"]'))==='','Sheet1: không bị ảnh hưởng bởi tìm kiếm của Sheet2 (đủ 3 dòng, ô tìm rỗng)');
  await page.locator('.sheetbar .sheet-tab',{hasText:'Sheet2'}).click();await settle(300);
  ok((await page.inputValue('input[placeholder^="Tìm kiếm"]'))==='Bàn' && (await page.locator('.grid tbody tr').count())===1,'quay lại Sheet2: tìm kiếm còn nguyên');

  // ---- Tag loại trừ riêng từng sheet ----
  await page.locator('.sheetbar .sheet-tab',{hasText:'Sheet1'}).click();await settle(300);
  await clear();
  await page.click('#tools-btn');await page.click('#exclude-btn');await page.waitForTimeout(350); // Loại trừ tag nằm trong menu Công cụ
  await page.locator('.col-side .pop-col',{hasText:'Tường'}).locator('input').click();await page.waitForTimeout(700);
  ok(JSON.stringify(await json('settings_save'))==='{"exclude_tags":["Tường"]}','Sheet1: tick Tường gửi lưu settings_save');
  await receive('config',config('table',{},['Tường']));await receive('table',table());await settle(300);
  await clear();
  await page.locator('.sheetbar .sheet-tab',{hasText:'Sheet2'}).click();await settle(300);
  ok(JSON.stringify(await json('settings_save'))==='{"exclude_tags":[]}','sang Sheet2 (chưa loại trừ gì): gửi lại tag loại trừ rỗng để Ruby tính lại số đo');
  ok((await message()).includes('tính lại số đo'),'có thông báo đang tính lại số đo theo sheet');
  await receive('config',config('table',{},[]));await receive('table',table());await settle(300);
  await clear();
  await page.locator('.sheetbar .sheet-tab',{hasText:'Sheet1'}).click();await settle(300);
  ok(JSON.stringify(await json('settings_save'))==='{"exclude_tags":["Tường"]}','về Sheet1: gửi lại ["Tường"] (tag loại trừ riêng Sheet1)');
  await receive('config',config('table',{},['Tường']));await receive('table',table());await settle(300);
  await clear();
  await page.locator('.sheetbar .sheet-tab',{hasText:'Sheet1'}).click();await settle(200);
  ok((await calls('settings_save')).length===0,'bấm lại sheet đang mở: không gửi gì');
  // hai sheet cùng tag loại trừ thì chuyển không phải tính lại
  await page.click('.sheetbar .sheet-add');await settle(300);
  ok((await activeTab())==='Sheet3' && (await calls('settings_save')).length===0,'sheet mới sao chép cả tag loại trừ: không tính lại số đo');

  // ---- Lưu trạng thái ----
  await page.waitForTimeout(600);
  const saved=await json('table_view');
  ok(saved && saved.sheets.length===3 && saved.sheet===2 && saved.sheets[0].name==='Sheet1' && JSON.stringify(saved.sheets[0].exclude_tags)==='["Tường"]' && JSON.stringify(saved.sheets[1].exclude_tags)==='[]','trạng thái lưu gồm các sheet, sheet đang mở và tag loại trừ riêng từng sheet');
  ok(saved.sheets[1].search==='Bàn' && saved.sheets[0].search==='' && !saved.sheets[0].visible.includes('description') && saved.sheets[1].visible.includes('description'),'lưu cả bộ lọc và cột riêng từng sheet');

  // ---- Đổi tên, nhân đôi, xóa ----
  await page.locator('.sheetbar .sheet-tab',{hasText:'Sheet3'}).dblclick();
  await page.locator('.sheet-rename').fill('Tủ bếp');await page.keyboard.press('Enter');await settle();
  ok(JSON.stringify(await tabs())==='["Sheet1","Sheet2","Tủ bếp"]','bấm đúp tên sheet: đổi tên bằng ô nhập, Enter xác nhận');
  await page.locator('.sheetbar .sheet-tab',{hasText:'Tủ bếp'}).dblclick();
  await page.locator('.sheet-rename').fill('sheet1');await page.keyboard.press('Enter');await settle();
  ok((await message()).includes('Đã có sheet tên này') && (await tabs()).includes('Tủ bếp'),'đặt trùng tên sheet khác (không phân biệt hoa thường): từ chối, giữ tên cũ');
  await page.locator('.sheetbar .sheet-tab',{hasText:'Tủ bếp'}).dblclick();
  await page.locator('.sheet-rename').fill('Bỏ');await page.keyboard.press('Escape');await settle();
  ok((await tabs()).includes('Tủ bếp') && !(await tabs()).includes('Bỏ'),'Esc khi đổi tên: hủy');
  await page.locator('.sheetbar .sheet-tab',{hasText:'Tủ bếp'}).focus();await page.keyboard.press('F2');
  ok(await page.locator('.sheet-rename').count()===1,'F2 trên tab sheet cũng mở ô đổi tên');await page.keyboard.press('Escape');await settle();
  await page.locator('.sheetbar .sheet-tab',{hasText:'Sheet2'}).click({button:'right'});
  ok(await page.locator('.sheet-menu button').allInnerTexts().then(t=>t.join('|')==='Đổi tên|Nhân đôi|Xóa sheet'),'bấm phải vào tab: menu Đổi tên / Nhân đôi / Xóa sheet');
  const delContrast=()=>page.evaluate(()=>{const b=[...document.querySelectorAll('.sheet-menu button')].find(x=>/Xóa sheet|Bấm lần nữa/.test(x.textContent)),cs=getComputedStyle(b);const rgb=c=>(c.match(/[\d.]+/g)||[]).slice(0,4).map(Number);const lum=([r,g,bl])=>{const f=v=>{v/=255;return v<=0.03928?v/12.92:Math.pow((v+0.055)/1.055,2.4)};return 0.2126*f(r)+0.7152*f(g)+0.0722*f(bl)};let bg=rgb(cs.backgroundColor);if(bg.length===4&&bg[3]===0){let n=b.parentElement;while(n&&(()=>{const q=rgb(getComputedStyle(n).backgroundColor);return q.length===4&&q[3]===0;})())n=n.parentElement;bg=rgb(getComputedStyle(n||document.body).backgroundColor);}const fg=rgb(cs.color);const a=lum(fg),c=lum(bg);return (Math.max(a,c)+0.05)/(Math.min(a,c)+0.05);});
  ok(await delContrast()>=3,'nút Xóa sheet: chữ đọc được (tương phản chữ / nền đủ lớn)');
  await page.locator('.sheet-menu button',{hasText:'Nhân đôi'}).click();await settle(300);
  ok((await tabs()).join('|')==='Sheet1|Sheet2|Tủ bếp|Sheet2 (2)' && (await activeTab())==='Sheet2 (2)','Nhân đôi: thêm "Sheet2 (2)" và mở sheet đó');
  ok((await page.inputValue('input[placeholder^="Tìm kiếm"]'))==='Bàn','sheet nhân đôi giữ bộ lọc của sheet gốc');
  await page.locator('.sheetbar .sheet-tab',{hasText:'Sheet2 (2)'}).click({button:'right'});
  await page.locator('.sheet-menu button',{hasText:'Xóa sheet'}).click();
  ok((await tabs()).includes('Sheet2 (2)') && await page.locator('.sheet-menu button',{hasText:'Bấm lần nữa để xóa'}).count()===1,'Xóa sheet cần bấm hai lần (lần đầu chỉ hỏi lại)');
  await settle(400);
  ok(await delContrast()>=3,'nút Xóa sheet sau lần bấm đầu (đỏ đặc): chữ đọc được');
  await page.locator('.sheet-menu button',{hasText:'Bấm lần nữa để xóa'}).click();await settle(300);
  ok((await tabs()).join('|')==='Sheet1|Sheet2|Tủ bếp' && (await message()).includes('Đã xóa sheet'),'bấm lần hai: xóa sheet');
  ok((await activeTab())==='Tủ bếp','xóa sheet đang mở (cuối danh sách): chuyển sang sheet kề bên');
  for(const name of ['Tủ bếp','Sheet2']){await page.locator('.sheetbar .sheet-tab',{hasText:name}).click({button:'right'});await page.locator('.sheet-menu button',{hasText:'Xóa sheet'}).click();await page.locator('.sheet-menu button',{hasText:'Bấm lần nữa để xóa'}).click();await settle(300);}
  ok((await tabs()).join('|')==='Sheet1','xóa dần: luôn còn lại một sheet');
  await page.locator('.sheetbar .sheet-tab').click({button:'right'});
  ok(await page.locator('.sheet-menu button',{hasText:'Xóa sheet'}).isDisabled(),'chỉ còn một sheet: nút Xóa sheet bị khóa');
  await page.keyboard.press('Escape');await page.mouse.click(5,5);

  // ---- Tối đa 20 sheet ----
  for(let i=0;i<25;i++)await page.click('.sheetbar .sheet-add').catch(()=>{});
  await settle(300);
  ok((await tabs()).length===20 && (await message()).includes('Tối đa 20 sheet'),'tối đa 20 sheet, quá thì báo');

  // ---- Mở lại: khôi phục sheet từ file ----
  await clear();
  await page.reload();
  const view={preset:'Tất cả',order:F.columns.map(c=>c.key),visible:F.columns.slice(0,6).map(c=>c.key),sheet:1,sheets:[{name:'Tủ',visible:F.columns.slice(0,4).map(c=>c.key),exclude_tags:[]},{name:'Rời',visible:F.columns.slice(0,6).map(c=>c.key),search:'Bàn',exclude_tags:['Cửa']}]};
  await receive('config',config('table',{table:{columns:F.columns,presets:F.presets,view}},['Cửa']));await receive('table',table({view}));await settle(400);
  ok(JSON.stringify(await tabs())==='["Tủ","Rời"]' && (await activeTab())==='Rời','mở lại từ file: có đủ sheet và mở đúng sheet đã lưu');
  ok((await page.inputValue('input[placeholder^="Tìm kiếm"]'))==='Bàn' && (await calls('settings_save')).length===0,'sheet khôi phục giữ bộ lọc; tag loại trừ đã khớp thì không tính lại');
  await page.locator('.sheetbar .sheet-tab',{hasText:'Tủ'}).click();await settle(300);
  ok((await heads()).split('\t').length<=5 && (await last('settings_save')) && JSON.stringify(await json('settings_save'))==='{"exclude_tags":[]}','sang sheet "Tủ": ít cột hơn và gửi tag loại trừ rỗng');
  // trạng thái cũ (chưa có sheet) vẫn mở được
  await page.reload();await receive('config',config('table'));await receive('table',table({view:{preset:'Tất cả',order:F.columns.map(c=>c.key),visible:F.columns.slice(0,5).map(c=>c.key)}}));await settle(300);
  ok(JSON.stringify(await tabs())==='["Sheet1"]','file cũ chưa có sheet: tự tạo "Sheet1" từ cột đang dùng');

  // ---- Mỗi file SketchUp một cài đặt: sang file khác thì nạp lại (file mới về mặc định) ----
  const FILE_B='C:\\data\\b_VGD_BIM';
  await receive('config',config('table'));await receive('table',table());await settle(300);
  await page.click('.sheetbar .sheet-add');await settle(300);
  await toggleColumn('Mô tả');await settle(200);
  await page.fill('input[placeholder^="Tìm kiếm"]','Bàn');await settle(300);
  ok((await tabs()).length===2 && !(await heads()).includes('Mô tả'),'chuẩn bị: file A có 2 sheet, ẩn cột Mô tả, đang tìm "Bàn"');
  await receive('config',config('table',{},['Tường']));await receive('table',table());await settle(300);
  ok((await tabs()).length===2 && !(await heads()).includes('Mô tả'),'gửi lại cấu hình của CÙNG file (đổi tab, làm mới): giữ nguyên sheet và cột');
  await openColumns();await page.locator('.col-side .pop-col',{hasText:'Vật liệu'}).first().locator('input').click();
  await clear(); // từ đây: thay đổi vừa bấm của file A đang chờ lưu (400 ms); đổi file ngay thì không được ghi
  await receive('config',config('table',{},[],FILE_B));await receive('table',table());await page.waitForTimeout(800);
  ok(JSON.stringify(await tabs())==='["Sheet1"]' && (await heads()).includes('Mô tả') && (await page.inputValue('input[placeholder^="Tìm kiếm"]'))==='','sang file B (chưa có cài đặt): về mặc định — một sheet, cột Mô tả hiện, ô tìm kiếm trống');
  ok((await calls('table_view')).every(c=>JSON.parse(c.args[0]).file===FILE_B),'thay đổi chưa kịp lưu của file A không bị ghi nhầm cho file B (mọi lần lưu đều mang mã file B)');
  ok((await calls('settings_save')).length===0,'sang file mới không tự gửi lưu tag loại trừ (đọc từ cài đặt của file)');
  const bView={preset:'Tất cả',order:F.columns.map(c=>c.key),visible:F.columns.slice(0,3).map(c=>c.key),sheet:0,sheets:[{name:'Tủ bếp B',visible:F.columns.slice(0,3).map(c=>c.key),exclude_tags:['Cửa']}]};
  await receive('config',config('table',{table:{columns:F.columns,presets:F.presets,view:bView}},['Cửa'],'C:\\data\\c_VGD_BIM'));await receive('table',table({view:bView}));await settle(300);
  ok(JSON.stringify(await tabs())==='["Tủ bếp B"]' && (await heads()).split('\t').length<=4,'sang file C đã có cài đặt riêng: nạp đúng sheet và cột của file đó');
  await page.click('.sheetbar .sheet-add');await settle(300);
  await page.waitForTimeout(600);
  const savedC=await json('table_view');
  ok(savedC.file==='C:\\data\\c_VGD_BIM' && savedC.sheets.length===2,'lưu trạng thái của file C kèm mã file C');

  // ---- Xuất Excel / PDF: mọi sheet, mỗi sheet đúng cột và tag loại trừ của nó ----
  await receive('config',config('table'));await receive('table',table());await settle(300);
  ok(JSON.stringify(await tabs())==='["Sheet1"]','chuẩn bị xuất: một sheet');
  await clear();
  await page.evaluate(()=>{window.__exp=exportTable('xlsx');});
  const one=await json('table_export');
  ok(one && !('sheets' in one) && one.columns.length>3 && one.rows.length>0 && one.format==='xlsx','một sheet: xuất như trước (columns / rows, không có sheets)');
  await page.click('.sheetbar .sheet-add');await settle(300);
  await toggleColumn('Mô tả');await settle(200);
  await page.locator('.sheetbar .sheet-tab',{hasText:'Sheet2'}).dblclick();await page.locator('.sheet-rename').fill('Tủ bếp');await page.keyboard.press('Enter');await settle();
  await page.locator('.sheetbar .sheet-tab',{hasText:'Sheet1'}).click();await settle(300);
  await page.evaluate(()=>{tableState.sheets[1].exclude_tags=['Tường'];}); // sheet Tủ bếp loại trừ tag Tường, sheet 1 thì không
  await receive('config',config('table'));await receive('table',table());await settle(200); // Ruby tính lại theo tag loại trừ của Sheet1 (rỗng)
  await clear();
  await page.evaluate(()=>{window.__exp=exportTable('pdf');});
  await page.waitForFunction(()=>window.calls.some(c=>c.name==='settings_save'),null,{timeout:5000});
  ok(JSON.stringify(await json('settings_save'))==='{"exclude_tags":["Tường"]}' && (await calls('table_export')).length===0,'xuất nhiều sheet: chuyển sang sheet 2, gửi tag loại trừ của sheet đó cho Ruby và ĐỢI tính lại (chưa xuất)');
  ok((await message()).includes('Đang '),'có thông báo đang chuẩn bị / tính lại');
  await receive('config',config('table',{},['Tường']));await receive('table',table());
  await page.waitForFunction(()=>window.calls.filter(c=>c.name==='settings_save').length===2,null,{timeout:5000});
  ok(JSON.stringify(await json('settings_save'))==='{"exclude_tags":[]}' && (await calls('table_export')).length===0,'xong sheet 2: trả về sheet đang mở, gửi lại tag loại trừ rỗng của sheet 1 và đợi tính lại');
  await receive('config',config('table',{},[]));await receive('table',table());
  await page.evaluate(()=>window.__exp);
  const multi=await json('table_export');
  ok(multi && multi.format==='pdf' && Array.isArray(multi.sheets) && multi.sheets.length===2 && multi.sheets[0].name==='Sheet1' && multi.sheets[1].name==='Tủ bếp' && !('columns' in multi),'xuất xong: một lệnh table_export có 2 sheet theo đúng tên, không còn columns / rows ở ngoài');
  const lab=sh=>sh.columns.map(c=>c.label);
  ok(lab(multi.sheets[0]).includes('Mô tả') && !lab(multi.sheets[1]).includes('Mô tả'),'mỗi sheet xuất đúng cột của nó (sheet Tủ bếp đã ẩn Mô tả)');
  ok(multi.sheets.every(sh=>sh.rows.some(r=>r.kind==='row')&&sh.rows.every(r=>r.cells.length===sh.columns.length)),'mỗi sheet có dòng dữ liệu, số ô khớp số cột');
  ok((await activeTab())==='Sheet1' && !(await page.evaluate(()=>exporting)) && (await heads()).includes('Mô tả'),'sau khi xuất: về lại Sheet1, cột như cũ, hết trạng thái đang xuất');
  const stateAfter=await page.evaluate(()=>({sheet:tableState.sheet,names:tableState.sheets.map(s=>s.name),ex:tableState.sheets.map(s=>s.exclude_tags)}));
  ok(stateAfter.sheet===0 && JSON.stringify(stateAfter.names)==='["Sheet1","Tủ bếp"]' && JSON.stringify(stateAfter.ex)==='[[],["Tường"]]','sheet và tag loại trừ riêng của từng sheet không bị đổi sau khi xuất');
  // hết thời gian chờ Ruby: không xuất nửa chừng, trả về sheet cũ
  await clear();
  await page.evaluate(()=>{window.tableWaitMs=300;tableState.sheets[1].exclude_tags=['Tường'];window.__exp=exportTable('xlsx');});
  await page.evaluate(()=>window.__exp);
  ok((await calls('table_export')).length===0 && (await message()).includes('Hết thời gian chờ') && (await activeTab())==='Sheet1','Ruby không trả bảng mới kịp: báo lỗi, không xuất, về lại sheet đang mở');
  await page.evaluate(()=>{window.tableWaitMs=0;});
  await receive('config',config('table'));await receive('table',table());await settle(200);

  // ---- Cầu nối dữ liệu: nhập Excel / CSV ----
  await receive('config',config('table'));await receive('table',table());await settle(200);await clear();
  await page.getByRole('button',{name:'Công cụ ▾'}).click();
  await page.getByRole('button',{name:/Cầu nối dữ liệu/}).click();
  ok(await page.locator('.popover.bridge').count()===1 && (await page.locator('.popover.bridge').innerText()).includes('Chọn file Excel / CSV'),'Cầu nối: hộp mở, chưa có file thì chỉ có nút chọn file');
  await page.getByRole('button',{name:'Chọn file Excel / CSV…'}).click();
  ok((await calls('bridge_open')).length===1,'bấm chọn file: gọi Ruby mở hộp chọn file (không đọc file trong giao diện)');
  await receive('bridge_file',{name:'a.xlsx',headers:['VGD ID','Tên','Đơn giá','Cột lạ'],count:3,sample:[],fields:[{key:'name',label:'Tên'},{key:'price',label:'Đơn giá'},{key:'description',label:'Mô tả'}],match:[{key:'vgd_id',label:'VGD ID'},{key:'code',label:'Mã đối tượng'}],suggest:{match_by:'vgd_id',match_column:'VGD ID',mapping:{'Tên':'name','Đơn giá':'price'}}});
  await settle(150);
  const bridgeText=await page.locator('.popover.bridge').innerText();
  ok(bridgeText.includes('a.xlsx · 3 dòng dữ liệu') && (await page.locator('.popover.bridge select').count())===5,'có file: hiện tên, số dòng, 2 ô khớp và 3 ô ánh xạ (trừ cột khớp)');
  await page.getByRole('button',{name:'Xem trước',exact:true}).click();
  const bp=await json('bridge_preview');
  ok(bp && bp.match_by==='vgd_id' && bp.match_column==='VGD ID' && JSON.stringify(bp.mapping)==='{"Tên":"name","Đơn giá":"price"}','xem trước: gửi khóa khớp và ánh xạ gợi ý');
  await clear();
  await receive('bridge_preview',{counts:{rows:4,ok:2,unchanged:0,unmatched:1,ambiguous:0,file_duplicate:0,locked:0,blank:0,changes:2,errors:1},rows:[
    {row:2,key:'vgd-a',index:0,name:'Tủ',status:'ok',changes:[{field:'name',label:'Tên',old:'Tủ',new:'Tủ mới'},{field:'price',label:'Đơn giá',old:'',new:'',error:'Đơn giá phải là số không âm'}]},
    {row:3,key:'vgd-b',index:1,name:'Bàn',status:'ok',changes:[{field:'price',label:'Đơn giá',old:'',new:'900000'}]},
    {row:4,key:'zzz',index:null,name:'',status:'unmatched',changes:[]}]});
  await settle(150);
  const boxes=page.locator('.popover.bridge .rename-table input[type=checkbox]');
  ok((await boxes.count())===3 && (await boxes.nth(1).isDisabled()) && (await boxes.nth(0).isChecked()) && (await page.locator('.popover.bridge').innerText()).includes('Không có trong bảng'),'xem trước: mỗi giá trị một ô tick, giá trị sai bị khóa không tick được, dòng không khớp hiện lý do');
  await boxes.nth(2).uncheck();
  await page.getByRole('button',{name:'Áp dụng',exact:true}).click();
  const ap=await json('bridge_apply');
  ok(ap && JSON.stringify(ap.skip)==='[[3,"price"]]' && ap.match_column==='VGD ID' && !(await page.locator('.popover.bridge').count()),'áp dụng: gửi cấu hình và các giá trị đã bỏ tick (dòng, trường); hộp đóng lại');
  // đổi cấu hình thì bản xem trước cũ mất (không áp dụng nhầm)
  await page.getByRole('button',{name:'Công cụ ▾'}).click();await page.getByRole('button',{name:/Cầu nối dữ liệu/}).click();
  await receive('bridge_file',{name:'a.xlsx',headers:['VGD ID','Tên'],count:1,sample:[],fields:[{key:'name',label:'Tên'}],match:[{key:'vgd_id',label:'VGD ID'}],suggest:{match_by:'vgd_id',match_column:'VGD ID',mapping:{'Tên':'name'}}});
  await receive('bridge_preview',{counts:{rows:1,ok:1,unchanged:0,unmatched:0,ambiguous:0,file_duplicate:0,locked:0,blank:0,changes:1,errors:0},rows:[{row:2,key:'a',index:0,name:'Tủ',status:'ok',changes:[{field:'name',label:'Tên',old:'Tủ',new:'X'}]}]});
  await settle(150);
  ok(await page.getByRole('button',{name:'Áp dụng',exact:true}).isEnabled(),'có thay đổi: nút Áp dụng bật');
  await page.locator('.popover.bridge select').nth(1).selectOption('');
  ok(await page.getByRole('button',{name:'Áp dụng',exact:true}).isDisabled() && (await page.locator('.popover.bridge .rename-table').count())===0,'đổi cột khớp: xem trước cũ biến mất, Áp dụng tắt');
  await page.getByRole('button',{name:'Xem trước',exact:true}).click();
  ok((await message()).includes('chọn cột của file dùng để khớp'),'chưa chọn cột khớp: báo lỗi, không gửi Ruby');
  await page.getByRole('button',{name:'Đóng',exact:true}).click();
  await clear();

  // ---- Gợi ý nhập kiểu Excel ----
  const cell=(row,key)=>page.locator('.grid tbody tr').nth(row).locator(`td[data-key="${key}"]`);
  const ghost=()=>page.locator('.ac-rest').innerText().catch(()=>'');
  const editInput=()=>page.locator('.grid tbody tr input');
  await receive('config',config('table'));await receive('table',table());await settle(300);
  await clear();
  await cell(2,'instance').dblclick();await page.keyboard.type('Tủ b');
  ok((await ghost())==='ếp dưới','gõ "Tủ b": hiện chữ mờ "ếp dưới" (gợi ý "Tủ bếp dưới" từ lịch sử)');
  await page.keyboard.press('Enter');
  const e1=await json('table_edit');
  ok(e1&&e1.field==='name'&&e1.value==='Tủ bếp dưới'&&JSON.stringify(e1.indexes)==='[2]','Enter nhận gợi ý và lưu trọn "Tủ bếp dưới"');
  await clear();
  await cell(2,'instance').dblclick();await page.keyboard.type('tủ bếp t');
  ok((await ghost())==='rên','gợi ý không phân biệt hoa thường và lấy cả tên đang có trong bảng ("Tủ bếp trên")');
  await page.keyboard.press('Tab');
  ok((await editInput().count())===0 && (await json('table_edit')).value==='Tủ bếp trên','Tab cũng nhận gợi ý và xác nhận');
  await clear();
  await cell(2,'instance').dblclick();await page.keyboard.type('Bàn');
  ok((await ghost())===' ăn đôi','gợi ý từ lịch sử đã lưu trong file (đối tượng không còn trong vùng chọn)');
  await page.keyboard.press('ArrowRight');
  ok((await editInput().inputValue())==='Bàn ăn đôi' && (await calls('table_edit')).length===0,'mũi tên phải ở cuối ô: nhận gợi ý nhưng chưa xác nhận');
  await page.keyboard.press('Escape');
  ok((await calls('table_edit')).length===0 && (await editInput().count())===0,'Esc: hủy, không gửi lệnh sửa');
  await cell(2,'instance').dblclick();await page.keyboard.type('Zebra');
  ok((await ghost())==='','chữ không khớp gợi ý nào: không hiện chữ mờ');
  await page.keyboard.press('Enter');
  ok((await json('table_edit')).value==='Zebra','Enter khi không có gợi ý: lưu đúng chữ đã gõ');
  await clear();
  await cell(2,'instance').dblclick();await page.keyboard.type('Tủ b');await page.keyboard.press('Backspace');
  ok((await ghost())==='','xóa lùi sau khi gõ: không tự gợi lại (như Excel)');
  await page.keyboard.press('Escape');
  await cell(1,'description').dblclick();await page.keyboard.type('Gi');
  ok((await ghost())==='ao tuần sau','cột Mô tả có gợi ý riêng của cột đó');
  await page.keyboard.press('Escape');
  await cell(1,'description').dblclick();await page.keyboard.type('Tủ');
  ok((await ghost())==='','gợi ý của cột Tên không lẫn sang cột Mô tả');
  await page.keyboard.press('Escape');
  await toggleColumn('Đơn giá');await settle(200);
  await cell(1,'price').dblclick();await page.keyboard.type('15');
  ok((await page.locator('.ac-wrap').count())===0 && (await ghost())==='','cột Đơn giá (số): không có gợi ý');
  await page.keyboard.press('Escape');
  await cell(2,'instance').dblclick();
  await page.evaluate(()=>{const i=document.querySelector('.grid tbody tr input');i.setSelectionRange(0,0);});
  await page.keyboard.type('Tủ');await page.evaluate(()=>{const i=document.querySelector('.grid tbody tr input');i.setSelectionRange(1,1);});
  await page.keyboard.press('Escape');
  await receive('table',table({choices:{tags:[],materials:[],model_tags:[],suggest:{}}}));await settle(200);
  await cell(0,'instance').dblclick();await page.keyboard.type('Tủ b');
  ok((await ghost())==='ếp dưới','không có lịch sử: vẫn gợi ý từ tên đang có trong bảng');
  await page.keyboard.press('Escape');
  // ---- Kéo đổi chỗ sheet: đổi chỗ khi kéo, tab khác trượt (FLIP), giữ sheet đang mở, lưu thứ tự ----
  while((await tabs()).length<3){await page.locator('.sheetbar .sheet-add').click();await settle(50);}
  await page.locator('.sheetbar .sheet-tab').nth(0).click();await settle(50);
  const before=await tabs(),first=before[0];
  await clear();
  await page.evaluate(()=>{const tabs=[...document.querySelectorAll('.sheetbar .sheet-tab')];window.draggedTab=tabs[0];const dt=new DataTransfer();tabs[0].dispatchEvent(new DragEvent('dragstart',{bubbles:true,dataTransfer:dt}));tabs[2].dispatchEvent(new DragEvent('dragover',{bubbles:true,cancelable:true,dataTransfer:dt}));});
  const moving=await page.evaluate(()=>[...document.querySelectorAll('.sheetbar .sheet-tab')].some(t=>getComputedStyle(t).transform!=='none'));
  await page.evaluate(()=>window.draggedTab.dispatchEvent(new DragEvent('dragend',{bubbles:true})));
  await settle(500);
  const after=await tabs();
  ok(moving,'kéo: các tab khác đang trượt bằng hiệu ứng (chưa về vị trí cuối)');
  ok(JSON.stringify(after)===JSON.stringify([before[1],before[2],first]),'thả: tab kéo xuống vị trí đích, các tab còn lại giữ thứ tự');
  ok((await activeTab())===first,'sheet đang mở vẫn là sheet vừa kéo, không đổi sang sheet khác');
  ok(await page.evaluate(()=>[...document.querySelectorAll('.sheetbar .sheet-tab')].every(t=>getComputedStyle(t).transform==='none')),'sau khi trượt xong: không còn lệch vị trí');
  const viewSaved=await json('table_view');
  ok(viewSaved && viewSaved.sheets.map(x=>x.name).join('|')===after.join('|'),'thứ tự sheet mới được lưu (table_view)');
  await page.locator('.sheetbar .sheet-tab').nth(0).click();await settle(50);
  ok((await activeTab())===after[0],'bấm tab sau khi kéo: mở đúng sheet tại vị trí mới');
  // ---- Khóa sheet: sheet khóa giữ các món đã khóa, không đổi theo lựa chọn; sheet thường theo lựa chọn ----
  const lockBtn=()=>page.locator('.sheetbar .sheet-lock');
  const activeIndex=()=>page.locator('.sheetbar .sheet-tab[aria-selected=true]').evaluate(el=>Number(el.dataset.index));
  const beforeLock=await tabs();
  await clear();
  await lockBtn().click();
  ok(JSON.stringify(await json('table_lock'))==='{"action":"on"}','nút Khóa sheet này: gửi lệnh khóa cho Ruby');
  await receive('sheet_lock',{lock:{items:[['11','21'],['12']]}});
  await settle(500);
  const locked=await activeIndex();
  ok((await lockBtn().getAttribute('aria-pressed'))==='true' && (await page.locator('.sheetbar .sheet-tab').nth(locked).getAttribute('class')).includes('locked'),'Ruby xác nhận khóa: nút bật, tab đang mở có dấu khóa');
  ok(JSON.stringify(await tabs())===JSON.stringify(beforeLock),'dấu khóa không làm đổi tên tab');
  const viewLocked=await json('table_view');
  ok(viewLocked.sheets[locked].lock && viewLocked.sheets[locked].lock.items.length===2,'sheet khóa được lưu cùng file (table_view)');
  const other=locked===0?1:0;
  await clear();
  await page.locator('.sheetbar .sheet-tab').nth(other).click();await settle(50);
  ok(JSON.stringify(await json('table_lock_apply'))==='{"lock":null}' && (await lockBtn().getAttribute('aria-pressed'))==='false','chuyển sang sheet thường: bảng theo lựa chọn (gửi lệnh bỏ khóa), nút tắt');
  await clear();
  await page.locator('.sheetbar .sheet-tab').nth(locked).click();await settle(50);
  const back=await json('table_lock_apply');
  ok(back && back.lock && back.lock.items.length===2,'quay lại sheet khóa: Ruby nhận đúng các món đã khóa');
  await clear();
  await lockBtn().click();
  ok(JSON.stringify(await json('table_lock_apply'))==='{"lock":null}' && (await lockBtn().getAttribute('aria-pressed'))==='false','bấm nút đang khóa: mở khóa, gửi lệnh bỏ khóa');
  await lockBtn().click();
  await receive('sheet_lock',{lock:{items:[['11','21']]}});
  await clear();
  await page.locator('.sheetbar .sheet-add').click();await settle(50);
  ok((await lockBtn().getAttribute('aria-pressed'))==='false','thêm sheet khi đang khóa: sheet mới không kế thừa khóa');
  await settle(500);
  const viewAdded=await json('table_view');
  ok(!viewAdded.sheets[viewAdded.sheet].lock,'sheet mới không có khóa trong table_view');
  // ---- Xuất nhiều sheet có sheet khóa: Ruby dựng lại đúng các món của sheet khóa rồi trả về sheet đang mở (mô phỏng Ruby trả bảng) ----
  await page.evaluate(d=>{
    window.__tableReply=d;
    window.sketchup=new Proxy({},{get:(_,name)=>(...args)=>{window.calls.push({name,args});if(name==='table_lock_apply'||name==='settings_save')setTimeout(()=>window.VGD.receive('table',window.__tableReply),0);}});
  },table());
  await clear();
  const sheetTotal=(await tabs()).length;
  await page.evaluate(()=>exportTable('xlsx'));
  await page.waitForFunction(()=>window.calls.some(c=>c.name==='table_export'),null,{timeout:60000});
  const exported=await json('table_export');
  const applied=(await calls('table_lock_apply')).map(c=>JSON.parse(c.args[0]).lock);
  const lockedApplied=applied.find(l=>l&&l.items);
  ok(exported.sheets && exported.sheets.length===sheetTotal,'xuất nhiều sheet: đủ mọi sheet trong file xuất');
  ok(!!lockedApplied && lockedApplied.items.length===1 && applied.some(l=>l===null),'sheet khóa được dựng lại đúng món của nó khi xuất, rồi trả về sheet đang mở');
  ok(errors.length===0,'không có lỗi JavaScript'+(errors.length?': '+errors.join(' | '):''));
 }finally{await browser.close();}
 console.log(failed?`${failed} lỗi`:'Done');
})().catch(e=>{console.log('FAIL  '+e.message);process.exit(1);});
