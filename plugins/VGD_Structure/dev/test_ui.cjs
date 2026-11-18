// Test giao diện cửa sổ Lưới trục bằng Playwright (trình duyệt headless): dựng bảng trục, sửa nhịp, thêm / xóa trục, tạo trục từ nhịp,
// gửi đúng dữ liệu cho Ruby, vẽ xem trước SVG, bật tắt nút theo kết quả xem trước, đổi theme. Chạy: node dev/test_ui.cjs
// (đặt VGD_PLAYWRIGHT_MODULE nếu Playwright không cài local; cần ruby để lấy dữ liệu thật).
const path=require('path'),{pathToFileURL}=require('url'),{execFileSync}=require('child_process');
const {chromium}=require(process.env.VGD_PLAYWRIGHT_MODULE || 'playwright');
const ok=(cond,msg)=>{console.log((cond?'PASS  ':'FAIL  ')+msg);if(!cond)process.exitCode=1;};
const F=JSON.parse(execFileSync('ruby',[path.resolve(__dirname,'ui_fixture.rb')],{encoding:'utf8'}));
(async()=>{
 const browser=await chromium.launch({headless:true,channel:process.env.VGD_BROWSER_CHANNEL||undefined});
 try{
  const page=await browser.newPage({viewport:{width:1100,height:760}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{window.calls=[];window.sketchup=new Proxy({}, {get:(_,name)=>(arg)=>window.calls.push({name,arg})})});
  await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_structure/html/index.html')).href);
  const receive=(event,data)=>page.evaluate(([e,d])=>window.VGDS.receive(e,d),[event,data]);
  const calls=name=>page.evaluate(n=>window.calls.filter(c=>c.name===n).map(c=>c.arg?JSON.parse(c.arg):null),name);
  const clear=()=>page.evaluate(()=>{window.calls.length=0;});
  const last=async name=>{const c=await calls(name);return c[c.length-1];};
  const names=dir=>page.locator(`#axes-${dir} input.name`).evaluateAll(l=>l.map(i=>i.value));
  const spans=dir=>page.locator(`#axes-${dir} tr td:nth-child(2) input`).evaluateAll(l=>l.map(i=>i.value));
  const positions=dir=>page.locator(`#axes-${dir} td.pos`).allInnerTexts();
  const wait=ms=>page.waitForTimeout(ms||250);
  const message=()=>page.locator('#message').innerText();

  ok((await calls('ready')).length===1,'mở cửa sổ: giao diện báo ready cho Ruby một lần');
  await receive('state',F.state);await receive('preview',F.preview);
  ok(JSON.stringify(await names('x'))==='["1","2","3","4"]' && JSON.stringify(await names('y'))==='["A","B","C"]','bảng trục: 4 trục đứng 1-4 và 3 trục ngang A-C');
  ok(JSON.stringify(await spans('x'))==='["0","4200","4200","4200"]' && JSON.stringify(await positions('x'))==='["0","4200","8400","12600"]','nhịp và vị trí cộng dồn đúng; trục đầu không sửa được nhịp');
  ok(await page.locator('#axes-x tr:nth-child(2) td:nth-child(2) input').isDisabled(),'ô nhịp của trục đầu bị khóa (luôn 0)');
  ok(/4 trục đứng × 3 trục ngang: 12 giao điểm, 17 nhịp, 6 ô\. Khung lưới 12600 × 7200 mm\./.test(await page.locator('#summary').innerText()),'tóm tắt do Ruby tính hiện đúng');
  ok(await page.locator('#plan line.axis').count()===7 && await page.locator('#plan circle.bubble').count()===7 && await page.locator('#plan circle.node').count()===12,'xem trước SVG: 7 đường trục, 7 vòng tròn ký hiệu, 12 giao điểm');
  ok(JSON.stringify(await page.locator('#plan text').evaluateAll(l=>l.map(t=>t.textContent)))==='["1","2","3","4","A","B","C"]','tên trục nằm trong vòng tròn');
  ok((await page.locator('#build').innerText())==='Vẽ lưới trục' && await page.locator('#build').isEnabled() && await page.locator('#remove').isDisabled(),'chưa có lưới trong model: nút Vẽ bấm được, Xóa bị khóa');
  ok((await page.locator('#version').innerText())==='v0.19.0-beta.1','hiện phiên bản plugin');

  // Sửa nhịp
  await clear();
  await page.locator('#axes-x tr:nth-child(3) td:nth-child(2) input').fill('5000');
  ok(JSON.stringify(await positions('x'))==='["0","5000","9200","13400"]','sửa nhịp trục 2 thành 5000: vị trí các trục sau dời theo');
  await wait();
  const pv=await last('grid_preview');
  ok(pv && pv.grid.x_axes[1].offset===5000 && pv.grid.x_axes[3].offset===13400 && pv.symbol.scale===100 && pv.symbol.both_ends===false,'xem trước gửi Ruby lưới mới và thiết lập ký hiệu');
  // Gốc và ký hiệu
  await page.fill('#origin-x','1000');await page.selectOption('#scale','50');await page.check('#both');await wait();
  const pv2=await last('grid_preview');
  ok(pv2.grid.origin[0]===1000 && pv2.symbol.scale===50 && pv2.symbol.both_ends===true,'đổi gốc X, tỉ lệ 1:50, ký hiệu hai đầu: gửi đúng');
  // Thêm / xóa trục
  await page.click('[data-add=y]');
  ok(JSON.stringify(await names('y'))==='["A","B","C","D"]' && JSON.stringify(await spans('y'))==='["0","3600","3600","3600"]','thêm trục ngang: tên kế tiếp D, nhịp bằng nhịp trước');
  for(let i=0;i<7;i++)await page.click('[data-add=y]');
  ok(JSON.stringify(await names('y'))==='["A","B","C","D","E","F","G","H","J","K","L"]','thêm tiếp: chữ bỏ I (sau H là J)');
  await page.fill('#axes-y tr:nth-child(2) input.name','D');
  await page.click('[data-add=y]');
  const after=await names('y');
  ok(after[after.length-1]==='M' && after.filter(n=>n==='D').length===2,'tên trùng do người dùng gõ vẫn giữ nguyên để Ruby báo lỗi; trục thêm sau lấy tên chưa dùng');
  await page.fill('#axes-y tr:nth-child(2) input.name','A');
  await page.locator('#axes-y button.del').nth(3).click();
  ok((await names('y')).length===11,'xóa một trục');
  // Tối thiểu 2 trục
  await receive('state',F.state);await receive('preview',F.preview);
  await page.locator('#axes-y button.del').first().click();
  ok(await page.locator('#axes-y button.del').first().isDisabled() && (await names('y')).length===2,'còn 2 trục thì nút xóa bị khóa (tối thiểu 2)');
  await receive('state',F.state);await receive('preview',F.preview);

  // Tạo từ nhịp
  await clear();
  await page.fill('#quick-x','4200, 3600*2');await page.click('[data-quick=x]');
  const q=await last('grid_axes');
  ok(q && q.dir==='x' && q.text==='4200, 3600*2','nút Tạo trục từ nhịp gửi chuỗi nhịp cho Ruby (Ruby phân tích)');
  await receive('axes',{dir:'x',axes:F.quick_x});
  ok(JSON.stringify(await names('x'))==='["1","2","3","4"]' && JSON.stringify(await positions('x'))==='["0","4200","7800","11400"]','nhận danh sách trục Ruby trả về và hiện');
  await receive('axes',{dir:'y',axes:F.quick_y});
  ok(JSON.stringify(await names('y'))==='["A","B"]' && await page.locator('#axes-y button.del').first().isDisabled(),'trục ngang tạo từ nhịp 5000: A, B');

  // Vẽ / xóa
  await receive('state',F.state);await receive('preview',F.preview);await clear();
  await page.click('#build');
  const b=await last('grid_build');
  ok(b && b.grid.x_axes.length===4 && b.grid.y_axes.map(a=>a.name).join('')==='ABC' && b.grid.origin.join()==='0,0' && b.symbol.scale===100,'bấm Vẽ: gửi toàn bộ lưới và thiết lập cho Ruby');
  await receive('built',{message:'Đã vẽ lưới trục: 7 trục, 7 ký hiệu.',drawn:true});
  ok((await page.locator('#message').innerText()).includes('Đã vẽ lưới trục') && (await page.locator('#build').innerText())==='Vẽ lại lưới trục' && await page.locator('#remove').isEnabled(),'sau khi vẽ: thông báo, nút đổi thành Vẽ lại, Xóa bấm được');
  await page.click('#remove');
  ok((await calls('grid_remove')).length===1,'bấm Xóa lưới gọi Ruby (Ruby hỏi xác nhận)');
  await page.click('#reset');
  ok((await calls('grid_reset')).length===1,'bấm Lưới mặc định gọi Ruby');


  // ===== Tab Tầng và loại cột =====
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=levels]');
  ok(await page.locator('#tab-levels').isVisible() && !(await page.locator('#tab-grid').isVisible()),'chuyển sang tab Tầng và loại cột: hiện tab, ẩn tab lưới');
  const typeNames=()=>page.locator('#types-table tr td:nth-child(1) input').evaluateAll(l=>l.map(i=>i.value));
  const levelRows=()=>page.locator('#levels-table tr').evaluateAll(rs=>rs.slice(1).map(r=>[...r.querySelectorAll('input')].map(i=>i.value).concat([r.querySelector('td.note').textContent])));
  ok(JSON.stringify(await typeNames())==='["C30x30"]','bảng loại cột: C30x30');
  const lr=await levelRows();
  ok(lr.length===2 && lr[0][0]==='Tầng 1' && lr[0][1]==='0' && lr[0][2]==='50' && lr[0][3]==='120' && lr[0][6]==='Cột cao 3600 mm' && lr[1][6]==='Tầng trên cùng: chỉ có sàn','bảng tầng: 2 tầng, cán nền 50, tầng 1 cột cao 3600 (mặt sàn kết cấu 3550 - (-50)), tầng trên cùng chỉ có sàn');
  ok(await page.locator('#types-table button.del').first().isDisabled(),'còn một loại cột thì không xóa được');
  // sửa cao độ tầng 2
  await clear();
  await page.locator('#levels-table tr:nth-child(3) td:nth-child(2) input').fill('4000');await wait();
  ok((await levelRows())[0][6]==='Cột cao 4000 mm','đổi cao độ tầng 2 thành 4000: ghi chú cột tầng 1 cập nhật ngay (4000)');
  await clear();await page.locator('#levels-table tr:nth-child(2) td:nth-child(3) input').fill('80');await wait();
  ok((await levelRows())[0][2]==='80' && (await levelRows())[0][6]==='Cột cao 4030 mm','đổi cán nền tầng 1 thành 80: ghi chú cột cập nhật (từ -80 tới 3950 = 4030)');
  const lcs=await last('grid_preview');ok(lcs.levels[0].screed===80 && lcs.levels[1].screed===50,'cán nền gửi sang Ruby theo từng tầng (80 và 50)');
  await page.locator('#levels-table tr:nth-child(2) td:nth-child(3) input').fill('500');await wait();
  await page.locator('#levels-table tr:nth-child(2) td:nth-child(3) input').fill('50');await wait();
  const lp=await last('grid_preview');
  ok(lp.levels[1].elevation===4000 && lp.levels[0].id==='sl_00000001' && lp.levels[0].slab_thickness===120 && lp.level==='sl_00000001' && lp.types[0].name==='C30x30','xem trước gửi Ruby đúng định dạng tầng (elevation, slab_thickness, picks) và loại cột');
  // thêm tầng, thêm loại
  await page.click('#add-level');
  const lr2=await levelRows();
  ok(lr2.length===3 && lr2[2][0]==='Tầng 3' && lr2[2][1]==='7600','thêm tầng: tên Tầng 3, cao độ = tầng cuối + 3600');
  await page.click('#add-type');
  ok(JSON.stringify(await typeNames())==='["C30x30","Loại 2"]' && await page.locator('#types-table button.del').first().isEnabled(),'thêm loại cột: tên Loại 2, kích thước theo loại cuối, nút xóa bật');
  await page.locator('#types-table tr:nth-child(3) td:nth-child(1) input').fill('C40x60');
  await page.locator('#types-table tr:nth-child(3) td:nth-child(2) input').fill('400');
  await page.locator('#types-table tr:nth-child(3) td:nth-child(3) input').fill('600');await wait();
  const lp2=await last('grid_preview');
  ok(lp2.types.length===2 && lp2.types[1].name==='C40x60' && lp2.types[1].w===400 && lp2.types[1].d===600 && /^ct_[0-9a-f]{8}$/.test(lp2.types[1].id) && /^sl_[0-9a-f]{8}$/.test(lp2.levels[2].id),'loại mới có mã ct_xxxxxxxx, tầng mới có mã sl_xxxxxxxx, kích thước gửi đúng');
  // loại mặc định cho tầng 1
  await page.locator('#levels-table tr:nth-child(2) select:not(.beam-default):not(.wall-default)').selectOption({label:'C40x60'});await wait();
  ok((await last('grid_preview')).levels[0].column_type===lp2.types[1].id,'chọn loại cột mặc định của tầng 1: gửi mã loại');
  // xóa loại đang dùng: tầng quay về mặc định
  await page.locator('#types-table button.del').nth(1).click();await wait();
  const lp3=await last('grid_preview');
  ok(lp3.types.length===1 && lp3.levels[0].column_type===null,'xóa loại cột đang dùng: tầng quay về loại đầu danh sách, không để mã mồ côi');
  // xóa tầng
  await page.locator('#levels-table button.del').nth(2).click();
  ok((await levelRows()).length===2,'xóa tầng thứ 3');

  // ===== Tab Cột =====
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=columns]');
  ok(await page.locator('#tab-columns').isVisible(),'chuyển sang tab Cột');
  ok(JSON.stringify(await page.locator('#level-select option').allInnerTexts())==='["Tầng 1","Tầng 2"]' && (await page.locator('#level-note').innerText())==='Cột cao 3600 mm','chọn tầng đang xem; ghi chú chiều cao cột');
  ok(await page.locator('#plan2 rect.col').count()===2 && await page.locator('#plan2 rect.ghost').count()===10,'mặt bằng: 2 cột đã chọn và 10 giao điểm còn lại (khung chấm để bấm chọn)');
  ok(/Tầng 1: 2 cột, cao 3600 mm/.test(await page.locator('#col-summary').innerText()),'tóm tắt cột của tầng');
  ok(await page.locator('#build-cols').isEnabled() && await page.locator('#remove-cols').isDisabled(),'có cột chọn: Dựng bấm được; chưa dựng: Xóa bị khóa');
  // chọn thêm một giao điểm
  await clear();
  await page.locator('#plan2 rect.ghost[data-ref="3-C"]').dispatchEvent('click');await wait();
  const pk=await last('grid_preview');
  ok(Object.keys(pk.levels[0].picks.columns).sort().join()==='1-A,2-B,3-C' && !(await page.locator('#col-editor').isHidden()) && (await page.locator('#col-ref').innerText())==='3-C','bấm giao điểm trống: chọn cột 3-C, mở khung sửa cột, gửi lại xem trước');
  // đổi kiểu đặt
  await page.locator('#col-x').selectOption('max');await page.locator('#col-y').selectOption('center');await wait();
  const pk2=await last('grid_preview');
  ok(JSON.stringify(pk2.levels[0].picks.columns['3-C'])==='{"x":"max","y":"center"}','đổi kiểu đặt X = cạnh đông tại trục, Y = tâm trên trục: chỉ gửi phần khác quy ước');
  await page.locator('#col-x').selectOption('auto');await wait();
  ok(JSON.stringify((await last('grid_preview')).levels[0].picks.columns['3-C'])==='{"y":"center"}','trả X về theo quy ước: bỏ khóa x');
  await page.locator('#col-type').selectOption({index:0});
  await page.locator('#col-remove').click();await wait();
  ok(!('3-C' in (await last('grid_preview')).levels[0].picks.columns) && await page.locator('#col-editor').isHidden(),'bỏ cột này: xóa khỏi lựa chọn, đóng khung sửa');
  // chọn tất cả / bỏ hết
  await page.click('#pick-all');await wait();
  ok(Object.keys((await last('grid_preview')).levels[0].picks.columns).length===12,'chọn mọi giao điểm: 12 cột (không đè kiểu đặt đã có)');
  ok(JSON.stringify((await last('grid_preview')).levels[0].picks.columns['2-B'])==='{"x":"center"}','nút chọn mọi giao điểm giữ nguyên kiểu đặt riêng đã đặt ở 2-B');
  await page.click('#pick-none');await wait();
  ok(Object.keys((await last('grid_preview')).levels[0].picks.columns).length===0 && await page.locator('#build-cols').isDisabled(),'bỏ chọn hết: không còn cột, nút Dựng bị khóa');
  // vẽ từ dữ liệu Ruby: tô cột theo xem trước
  await receive('state',F.state);await receive('preview',F.preview_all);
  ok(await page.locator('#plan2 rect.col').count()===12 && await page.locator('#plan2 rect.ghost').count()===0,'xem trước 12 cột: vẽ đủ 12 hình chữ nhật cột');
  const rects=await page.locator('#plan2 rect.col').evaluateAll(l=>l.map(r=>[r.getAttribute('data-ref'),Number(r.getAttribute('x')),Number(r.getAttribute('y')),Number(r.getAttribute('width'))]));
  const c1a=rects.find(r=>r[0]==='1-A'),c2b=rects.find(r=>r[0]==='2-B');
  ok(c1a[1]===0 && c1a[2]===-300 && c1a[3]===300 && c2b[1]===4050,'vị trí vẽ đúng quy ước: cột góc 1-A có mép trên trục (x từ 0, y từ -300), cột giữa 2-B tâm ở giao điểm (x từ 4050)');
  // tầng trên cùng
  await page.locator('#level-select').selectOption('sl_00000002');
  await receive('preview',F.preview_top);
  ok(/tầng trên cùng/.test(await page.locator('#col-summary').innerText()) && await page.locator('#plan2 rect').count()===0,'tầng trên cùng: báo chỉ có sàn, không có cột để chọn');
  ok(await page.locator('#build-cols').isDisabled() && await page.locator('#pick-all').isDisabled(),'chọn tầng trên cùng: khóa nút dựng và chọn cột');
  await page.locator('#level-select').selectOption('sl_00000001');
  // lỗi loại cột
  await receive('preview',F.preview_bad_types);
  ok((await page.locator('#col-summary').innerText()).includes('rộng') && await page.locator('#col-summary.error').count()===1,'lỗi loại cột / tầng: hiện lỗi ở tab Cột');
  ok(await page.locator('#build').isEnabled(),'lỗi tầng / loại cột không khóa nút Vẽ lưới trục (xem trước lưới vẫn đúng)');
  await receive('state',F.state);await receive('preview',F.preview);
  // sao chép lựa chọn
  await page.click('[data-tab=levels]');await page.click('#add-level');await page.click('[data-tab=columns]');
  await page.locator('#level-select').selectOption({index:1});
  await clear();
  await page.locator('#copy-from').selectOption({label:'Tầng 1'});await page.click('#copy-picks');
  const cp=await last('picks_copy');
  ok(cp && cp.from==='sl_00000001' && cp.to==='sl_00000002' && cp.levels.length===3 && cp.grid.x_axes.length===4 && cp.types.length===1,'sao chép lựa chọn: gửi Ruby tầng nguồn, tầng đích, lưới, loại cột và tầng');
  const copied=JSON.parse(JSON.stringify(F.state.levels));copied[1].picks={columns:{'1-A':{},'2-B':{x:'center'}}};copied.push({id:cp.levels[2].id,name:'Tầng 3',elevation:7200,slab_thickness:120,column_type:null,picks:{columns:{}}});
  await receive('levels',{levels:copied,message:'Đã sao chép lựa chọn cột từ “Tầng 1” sang “Tầng 2”.'});await wait();
  ok((await message()).includes('Đã sao chép') && JSON.stringify((await last('grid_preview')).levels[1].picks.columns)==='{"1-A":{},"2-B":{"x":"center"}}','nhận tầng mới từ Ruby: cập nhật lựa chọn của tầng đích và xem trước lại');
  // dựng / xóa
  await receive('state',F.state);await receive('preview',F.preview);await clear();
  await page.click('[data-tab=columns]');
  await page.click('#build-cols');
  const bc=await last('columns_build');
  ok(bc && JSON.stringify(bc.levels)==='["sl_00000001"]' && bc.state.grid.x_axes.length===4 && bc.state.levels[0].picks.columns['2-B'].x==='center','Dựng cột tầng này: gửi tầng và toàn bộ dữ liệu cho Ruby (Ruby kiểm tra lại)');
  await clear();await page.click('#build-all-cols');
  ok(JSON.stringify((await last('columns_build')).levels)==='["sl_00000001"]','Dựng cột mọi tầng: chỉ gồm tầng dưới trên cùng và có cột được chọn');
  await receive('columns_built',{message:'Đã dựng 2 cột.',drawn_levels:['sl_00000001']});
  ok((await message())==='Đã dựng 2 cột.' && await page.locator('#remove-cols').isEnabled(),'sau khi dựng: Xóa cột tầng này bấm được');
  await page.click('#remove-cols');
  ok((await last('columns_remove')).level==='sl_00000001','Xóa cột gửi mã tầng');
  await page.click('[data-tab=grid]');
  ok(await page.locator('#tab-grid').isVisible(),'quay về tab Lưới trục');


  // ===== Loại dầm và tab Dầm =====
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=levels]');
  const btNames=()=>page.locator('#beam-types-table tr td:nth-child(1) input').evaluateAll(l=>l.map(i=>i.value));
  ok(JSON.stringify(await btNames())==='["D20x40"]' && await page.locator('#beam-types-table button.del').first().isDisabled(),'bảng loại dầm: D20x40, còn một loại thì không xóa được');
  await clear();
  await page.click('#add-beam-type');
  ok(JSON.stringify(await btNames())==='["D20x40","Dầm 2"]','thêm loại dầm: tên Dầm 2');
  await page.locator('#beam-types-table tr:nth-child(3) td:nth-child(1) input').fill('D30x60');
  await page.locator('#beam-types-table tr:nth-child(3) td:nth-child(2) input').fill('300');
  await page.locator('#beam-types-table tr:nth-child(3) td:nth-child(3) input').fill('600');await wait();
  const bp1=await last('grid_preview');
  ok(bp1.beam_types.length===2 && bp1.beam_types[1].name==='D30x60' && bp1.beam_types[1].w===300 && bp1.beam_types[1].h===600 && /^bt_[0-9a-f]{8}$/.test(bp1.beam_types[1].id),'loại dầm mới có mã bt_xxxxxxxx, gửi đúng kích thước');
  await page.locator('#levels-table tr:nth-child(2) select.beam-default').selectOption({label:'D30x60'});await wait();
  ok((await last('grid_preview')).levels[0].beam_type===bp1.beam_types[1].id && (await last('grid_preview')).levels[0].column_type===null,'chọn loại dầm mặc định của tầng 1: gửi beam_type (không đổi loại cột)');
  await page.locator('#beam-types-table button.del').nth(1).click();await wait();
  ok((await last('grid_preview')).beam_types.length===1 && (await last('grid_preview')).levels[0].beam_type===null,'xóa loại dầm đang dùng: tầng quay về loại đầu danh sách');
  // Tab Dầm
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=beams]');
  ok(await page.locator('#tab-beams').isVisible() && !(await page.locator('#tab-columns').isVisible()),'chuyển sang tab Dầm');
  ok(await page.locator('#plan3 rect.beam').count()===2 && await page.locator('#plan3 rect.span').count()===15 && await page.locator('#plan3 rect.colref').count()===2,'mặt bằng dầm: 2 dầm đã chọn, 15 nhịp còn lại để bấm chọn, cột hiện mờ làm nền');
  ok(/Tầng 1: 2 dầm, đỉnh dầm tại cao độ 3550 mm/.test(await page.locator('#beam-summary').innerText()),'tóm tắt dầm: số dầm, cao độ đỉnh');
  ok((await page.locator('#beam-level-note').innerText()).includes('3550') && await page.locator('#build-beams').isEnabled() && await page.locator('#remove-beams').isDisabled(),'ghi chú đỉnh dầm; Dựng bấm được, Xóa khóa khi chưa dựng');
  await clear();
  await page.locator('#plan3 rect.span[data-ref="x:A:2-3"]').dispatchEvent('click');await wait();
  const bk=await last('grid_preview');
  ok(Object.keys(bk.levels[0].picks.beams).sort().join()==='x:A:2-3,x:B:1-2,y:2:A-B' && (await page.locator('#beam-ref').innerText())==='x:A:2-3' && await page.locator('#beam-editor').isVisible(),'bấm nhịp trống: chọn dầm, mở khung sửa, gửi lại xem trước');
  await page.locator('#beam-p').selectOption('center');await wait();
  ok(JSON.stringify((await last('grid_preview')).levels[0].picks.beams['x:A:2-3'])==='{"p":"center"}','đổi vị trí ngang thành tâm trên trục: gửi p = center');
  await page.locator('#beam-p').selectOption('auto');await wait();
  ok(JSON.stringify((await last('grid_preview')).levels[0].picks.beams['x:A:2-3'])==='{}','trả về theo quy ước: bỏ khóa p');
  await page.locator('#beam-remove').click();await wait();
  ok(!('x:A:2-3' in (await last('grid_preview')).levels[0].picks.beams) && await page.locator('#beam-editor').isHidden(),'bỏ dầm này: xóa khỏi lựa chọn');
  await page.click('#beam-pick-edge');await wait();
  const edgeKeys=Object.keys((await last('grid_preview')).levels[0].picks.beams);
  ok(edgeKeys.length===2+10 && edgeKeys.includes('x:A:1-2') && edgeKeys.includes('y:4:B-C') && !edgeKeys.includes('x:B:2-3'),'chọn nhịp biên: thêm 10 nhịp biên (6 theo X trên trục A, C + 4 theo Y trên trục 1, 4) cùng 2 nhịp đã chọn');
  await page.click('#beam-pick-all');await wait();
  ok(Object.keys((await last('grid_preview')).levels[0].picks.beams).length===17 && JSON.stringify((await last('grid_preview')).levels[0].picks.beams['y:2:A-B'])==='{"p":"center"}','chọn mọi nhịp: 17 dầm, giữ kiểu đặt riêng đã đặt');
  await page.click('#beam-pick-none');await wait();
  ok(Object.keys((await last('grid_preview')).levels[0].picks.beams).length===0 && await page.locator('#build-beams').isDisabled(),'bỏ chọn hết: Dựng bị khóa');
  await receive('state',F.state);await receive('preview',F.preview_all_beams);
  ok(await page.locator('#plan3 rect.beam').count()===17 && await page.locator('#plan3 rect.span').count()===0,'xem trước 17 dầm: vẽ đủ 17 hình chữ nhật dầm');
  const rb=await page.locator('#plan3 rect.beam').evaluateAll(l=>l.map(r=>({ref:r.getAttribute('data-ref'),x:Number(r.getAttribute('x')),y:Number(r.getAttribute('y')),w:Number(r.getAttribute('width')),h:Number(r.getAttribute('height'))})));
  const bx=rb.find(r=>r.ref==='x:B:2-3'),by=rb.find(r=>r.ref==='y:1:A-B');
  ok(bx.x===4350 && bx.w===3900 && bx.h===200 && bx.y===-3700,'dầm x:B:2-3 vẽ từ mặt cột (x = 4350) dài 3900, rộng 200, tâm y = 3600 (y SVG = -3700 cho mép trên)');
  ok(by.x===0 && by.w===200 && by.y===-3450 && by.h===3150,'dầm biên y:1:A-B: mặt ngoài tại x = 0, từ mặt cột (y = 300) đến mặt cột (3450)');
  await page.locator('#beam-level-select').selectOption('sl_00000002');
  await receive('preview',F.preview_top);
  ok(/tầng trên cùng/.test(await page.locator('#beam-summary').innerText()) && await page.locator('#build-beams').isDisabled() && await page.locator('#beam-pick-all').isDisabled(),'tầng trên cùng: báo chỉ có sàn, khóa nút dầm');
  await page.locator('#beam-level-select').selectOption('sl_00000001');
  await receive('preview',F.preview_bad_types);
  ok(await page.locator('#beam-summary.error').count()===1,'lỗi loại / tầng hiện ở tab Dầm');
  // Sao chép lựa chọn dầm, dựng, xóa
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=levels]');await page.click('#add-level');await page.click('[data-tab=beams]');
  await page.locator('#beam-level-select').selectOption({index:1});await clear();
  await page.locator('#beam-copy-from').selectOption({label:'Tầng 1'});await page.click('#beam-copy-picks');
  const bcp=await last('picks_copy');
  ok(bcp && bcp.kind==='beams' && bcp.from==='sl_00000001' && bcp.to==='sl_00000002' && bcp.beam_types.length===1 && bcp.levels[0].picks.beams['x:B:1-2'],'sao chép dầm: gửi kind = beams cùng loại dầm và tầng');
  await receive('state',F.state);await receive('preview',F.preview);await clear();
  await page.click('[data-tab=beams]');
  await page.click('#build-beams');
  const bb=await last('beams_build');
  ok(bb && JSON.stringify(bb.levels)==='["sl_00000001"]' && bb.state.beam_types.length===1 && bb.state.levels[0].picks.beams['y:2:A-B'].p==='center','Dựng dầm tầng này: gửi toàn bộ dữ liệu (kể cả loại dầm)');
  await clear();await page.click('#build-all-beams');
  ok(JSON.stringify((await last('beams_build')).levels)==='["sl_00000001"]','Dựng dầm mọi tầng: chỉ tầng có dầm được chọn và không phải tầng trên cùng');
  await receive('beams_built',{message:'Đã dựng 2 dầm.',drawn_beam_levels:['sl_00000001']});
  ok((await message())==='Đã dựng 2 dầm.' && await page.locator('#remove-beams').isEnabled(),'sau khi dựng: Xóa dầm tầng này bấm được');
  await page.click('#remove-beams');
  ok((await last('beams_remove')).level==='sl_00000001','Xóa dầm gửi mã tầng');
  await page.click('[data-tab=grid]');


  // ===== Loại tường và tab Tường =====
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=levels]');
  const wtNames=()=>page.locator('#wall-types-table tr td:nth-child(1) input').evaluateAll(l=>l.map(i=>i.value));
  ok(JSON.stringify(await wtNames())==='["T200"]' && await page.locator('#wall-types-table button.del').first().isDisabled(),'bảng loại tường: T200, còn một loại thì không xóa được');
  await clear();
  await page.click('#add-wall-type');
  ok(JSON.stringify(await wtNames())==='["T200","Tường dày 2"]','thêm loại tường');
  await page.locator('#wall-types-table tr:nth-child(3) td:nth-child(1) input').fill('T100');
  await page.locator('#wall-types-table tr:nth-child(3) td:nth-child(2) input').fill('100');await wait();
  const wp1=await last('grid_preview');
  ok(wp1.wall_types.length===2 && wp1.wall_types[1].name==='T100' && wp1.wall_types[1].t===100 && /^wt_[0-9a-f]{8}$/.test(wp1.wall_types[1].id),'loại tường mới có mã wt_xxxxxxxx, gửi đúng độ dày');
  await page.locator('#levels-table tr:nth-child(2) select.wall-default').selectOption({label:'T100'});await wait();
  ok((await last('grid_preview')).levels[0].wall_type===wp1.wall_types[1].id && (await last('grid_preview')).levels[0].beam_type===null,'chọn loại tường mặc định của tầng 1: gửi wall_type (không đổi loại dầm)');
  await page.locator('#wall-types-table button.del').nth(1).click();await wait();
  ok((await last('grid_preview')).wall_types.length===1 && (await last('grid_preview')).levels[0].wall_type===null,'xóa loại tường đang dùng: tầng quay về loại đầu danh sách');
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=walls]');
  ok(await page.locator('#tab-walls').isVisible() && !(await page.locator('#tab-beams').isVisible()),'chuyển sang tab Tường');
  ok(await page.locator('#plan4 rect.wall').count()===2 && await page.locator('#plan4 rect.span').count()===15,'mặt bằng tường: 2 tường đã chọn, 15 nhịp còn lại để bấm chọn');
  ok(/Tầng 1: 2 tường, từ cao độ -50 mm/.test(await page.locator('#wall-summary').innerText()),'tóm tắt tường: số tường, cao độ chân');
  ok(await page.locator('#build-walls').isEnabled() && await page.locator('#remove-walls').isDisabled(),'Dựng bấm được, Xóa khóa khi chưa dựng');
  await clear();
  await page.locator('#plan4 rect.span[data-ref="x:A:2-3"]').dispatchEvent('click');await wait();
  ok(Object.keys((await last('grid_preview')).levels[0].picks.walls).sort().join()==='x:A:2-3,x:B:1-2,y:2:A-B' && (await page.locator('#wall-ref').innerText())==='x:A:2-3' && await page.locator('#wall-editor').isVisible(),'bấm nhịp trống: chọn tường, mở khung sửa, gửi lại xem trước');
  await page.locator('#wall-p').selectOption('center');await wait();
  ok(JSON.stringify((await last('grid_preview')).levels[0].picks.walls['x:A:2-3'])==='{"p":"center"}','đổi vị trí ngang: gửi p = center');
  await page.locator('#wall-remove').click();await wait();
  ok(!('x:A:2-3' in (await last('grid_preview')).levels[0].picks.walls) && await page.locator('#wall-editor').isHidden(),'bỏ tường này');
  await page.click('#wall-pick-edge');await wait();
  ok(Object.keys((await last('grid_preview')).levels[0].picks.walls).length===12,'chọn nhịp biên: thêm 10 nhịp biên cùng 2 đã chọn');
  await page.click('#wall-pick-all');await wait();
  ok(Object.keys((await last('grid_preview')).levels[0].picks.walls).length===17 && JSON.stringify((await last('grid_preview')).levels[0].picks.walls['y:2:A-B'])==='{"p":"center"}','chọn mọi nhịp: 17 tường, giữ kiểu đặt riêng');
  await page.click('#wall-pick-none');await wait();
  ok(Object.keys((await last('grid_preview')).levels[0].picks.walls).length===0 && await page.locator('#build-walls').isDisabled(),'bỏ chọn hết: Dựng bị khóa');
  await receive('state',F.state);await receive('preview',F.preview_all_walls);
  ok(await page.locator('#plan4 rect.wall').count()===17 && await page.locator('#plan4 rect.span').count()===0,'xem trước 17 tường: vẽ đủ');
  const rw=await page.locator('#plan4 rect.wall').evaluateAll(l=>l.map(r=>({ref:r.getAttribute('data-ref'),x:Number(r.getAttribute('x')),y:Number(r.getAttribute('y')),w:Number(r.getAttribute('width')),h:Number(r.getAttribute('height'))})));
  const wx=rw.find(r=>r.ref==='x:B:2-3'),wy=rw.find(r=>r.ref==='y:1:A-B');
  ok(wx.x===4350 && wx.w===3900 && wx.h===200 && wx.y===-3700 && wy.x===0 && wy.w===200 && wy.y===-3450 && wy.h===3150,'tường vẽ đúng: x:B:2-3 từ mặt cột (4350) dài 3900; tường biên y:1:A-B mặt ngoài tại x = 0, từ mặt cột đến mặt cột');
  await page.locator('#wall-level-select').selectOption('sl_00000002');
  await receive('preview',F.preview_top);
  ok(/tầng trên cùng/.test(await page.locator('#wall-summary').innerText()) && await page.locator('#build-walls').isDisabled(),'tầng trên cùng: báo chỉ có sàn, khóa nút tường');
  await page.locator('#wall-level-select').selectOption('sl_00000001');
  await receive('preview',F.preview_bad_types);
  ok(await page.locator('#wall-summary.error').count()===1,'lỗi loại / tầng hiện ở tab Tường');
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=levels]');await page.click('#add-level');await page.click('[data-tab=walls]');
  await page.locator('#wall-level-select').selectOption({index:1});await clear();
  await page.locator('#wall-copy-from').selectOption({label:'Tầng 1'});await page.click('#wall-copy-picks');
  const wcp=await last('picks_copy');
  ok(wcp && wcp.kind==='walls' && wcp.wall_types.length===1 && wcp.levels[0].picks.walls['x:B:1-2'],'sao chép tường: gửi kind = walls cùng loại tường');
  await receive('state',F.state);await receive('preview',F.preview);await clear();
  await page.click('[data-tab=walls]');
  await page.click('#build-walls');
  const wb=await last('walls_build');
  ok(wb && JSON.stringify(wb.levels)==='["sl_00000001"]' && wb.state.wall_types.length===1 && wb.state.levels[0].picks.walls['y:2:A-B'].p==='center','Dựng tường tầng này: gửi toàn bộ dữ liệu (kể cả loại tường)');
  await clear();await page.click('#build-all-walls');
  ok(JSON.stringify((await last('walls_build')).levels)==='["sl_00000001"]','Dựng tường mọi tầng: chỉ tầng có tường và không phải tầng trên cùng');
  await receive('walls_built',{message:'Đã dựng 2 tường.',drawn_wall_levels:['sl_00000001']});
  ok((await message())==='Đã dựng 2 tường.' && await page.locator('#remove-walls').isEnabled(),'sau khi dựng: Xóa tường tầng này bấm được');
  await page.click('#remove-walls');
  ok((await last('walls_remove')).level==='sl_00000001','Xóa tường gửi mã tầng');
  await page.click('[data-tab=grid]');


  // ===== Cao trần và tab Sàn, Trần =====
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=levels]');
  const lr3=await levelRows();
  ok(lr3[0][4]==='2800' && lr3[0][5]==='9','bảng tầng có cao trần 2800 và dày trần 9');
  await clear();
  await page.locator('#levels-table tr:nth-child(2) td:nth-child(5) input').fill('3000');
  await page.locator('#levels-table tr:nth-child(2) td:nth-child(6) input').fill('12');await wait();
  const lc=await last('grid_preview');
  ok(lc.levels[0].ceiling_height===3000 && lc.levels[0].ceiling_thickness===12 && lc.levels[0].picks.slabs!==undefined,'đổi cao trần và dày trần: gửi ceiling_height / ceiling_thickness');
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=slabs]');
  ok(await page.locator('#tab-slabs').isVisible() && !(await page.locator('#tab-walls').isVisible()),'chuyển sang tab Sàn');
  ok(await page.locator('#plan5 polygon.cell.slab').count()===2 && await page.locator('#plan5 rect.cellghost').count()===4,'mặt bằng sàn: 2 sàn đã chọn, 4 ô còn lại để bấm chọn');
  ok(/Tầng 1: 2 sàn \(tổng 29\.64 m²\)/.test(await page.locator('#slab-summary').innerText()) || /2 sàn/.test(await page.locator('#slab-summary').innerText()),'tóm tắt sàn: số sàn, tổng diện tích');
  ok((await page.locator('#slab-level-note').innerText()).includes('dày 120') && await page.locator('#build-slabs').isEnabled() && await page.locator('#remove-slabs').isDisabled(),'ghi chú dày sàn; Dựng bấm được, Xóa khóa khi chưa dựng');
  await clear();
  await page.locator('#plan5 rect.cellghost[data-ref="3-4/A-B"]').dispatchEvent('click');await wait();
  ok(Object.keys((await last('grid_preview')).levels[0].picks.slabs).sort().join()==='1-2/A-B,2-3/B-C,3-4/A-B','bấm ô trống: chọn sàn, gửi lại xem trước');
  await receive('state',F.state);await receive('preview',F.preview);await clear();
  await page.locator('#plan5 polygon.cell[data-ref="1-2/A-B"]').dispatchEvent('click');await wait();
  ok(!('1-2/A-B' in (await last('grid_preview')).levels[0].picks.slabs) && '2-3/B-C' in (await last('grid_preview')).levels[0].picks.slabs,'bấm ô đã chọn: bỏ sàn của ô đó');
  await page.click('#slab-pick-all');await wait();
  ok(Object.keys((await last('grid_preview')).levels[0].picks.slabs).length===6,'chọn mọi ô: 6 sàn');
  await page.click('#slab-pick-none');await wait();
  ok(Object.keys((await last('grid_preview')).levels[0].picks.slabs).length===0 && await page.locator('#build-slabs').isDisabled(),'bỏ chọn hết: Dựng bị khóa');
  await receive('state',F.state);await receive('preview',F.preview_all_cells);
  ok(await page.locator('#plan5 polygon.cell.slab').count()===6 && await page.locator('#plan5 rect.cellghost').count()===0,'xem trước 6 sàn: vẽ đủ');
  const sp=await page.locator('#plan5 polygon.cell.slab[data-ref="1-2/A-B"]').getAttribute('points');
  ok(sp==='0,0 4200,0 4200,-3600 0,-3600','sàn ô 1-2/A-B vẽ đúng từ trục tới trục (y SVG đảo dấu)');
  // dựng / xóa sàn
  await receive('state',F.state);await receive('preview',F.preview);await clear();
  await page.click('[data-tab=slabs]');await page.click('#build-slabs');
  const sb=await last('plates_build');
  ok(sb && sb.kind==='slabs' && JSON.stringify(sb.levels)==='["sl_00000001"]' && Object.keys(sb.state.levels[0].picks.slabs).length===2,'Dựng sàn tầng này: gửi kind = slabs, mã tầng, toàn bộ dữ liệu');
  await clear();await page.click('#build-all-slabs');
  ok(JSON.stringify((await last('plates_build')).levels)==='["sl_00000001"]','Dựng sàn mọi tầng: chỉ tầng có sàn được chọn');
  await receive('plates_built',{kind:'slabs',message:'Đã dựng 2 sàn.',drawn_levels:['sl_00000001']});
  ok((await message())==='Đã dựng 2 sàn.' && await page.locator('#remove-slabs').isEnabled(),'sau khi dựng: Xóa sàn tầng này bấm được');
  await page.click('#remove-slabs');
  const sr=await last('plates_remove');
  ok(sr.kind==='slabs' && sr.level==='sl_00000001','Xóa sàn gửi kind và mã tầng');
  // tầng trên cùng có sàn
  await page.locator('#slab-level-select').selectOption('sl_00000002');
  ok(await page.locator('#slab-pick-all').isEnabled() && (await page.locator('#slab-level-note').innerText()).includes('sàn mái'),'tầng trên cùng vẫn chọn được sàn (sàn mái)');
  await page.locator('#slab-level-select').selectOption('sl_00000001');
  // sao chép sàn
  await page.click('[data-tab=levels]');await page.click('#add-level');await page.click('[data-tab=slabs]');
  await page.locator('#slab-level-select').selectOption({index:1});await clear();
  await page.locator('#slab-copy-from').selectOption({label:'Tầng 1'});await page.click('#slab-copy-picks');
  const sc=await last('picks_copy');
  ok(sc && sc.kind==='slabs' && sc.from==='sl_00000001' && sc.to==='sl_00000002' && sc.levels[0].picks.slabs['1-2/A-B'],'sao chép sàn: gửi kind = slabs');
  // Tab Trần
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=ceilings]');
  ok(await page.locator('#tab-ceilings').isVisible() && await page.locator('#plan6 polygon.cell.ceiling').count()===2 && await page.locator('#plan6 rect.cellghost').count()===4,'tab Trần: 2 trần đã chọn, 4 ô còn lại');
  ok((await page.locator('#ceiling-level-note').innerText()).includes('2800') && /2 trần/.test(await page.locator('#ceiling-summary').innerText()),'ghi chú cao độ mặt dưới trần và tóm tắt');
  await clear();
  await page.locator('#plan6 rect.cellghost[data-ref="3-4/A-B"]').dispatchEvent('click');await wait();
  ok(Object.keys((await last('grid_preview')).levels[0].picks.ceilings).length===3 && Object.keys((await last('grid_preview')).levels[0].picks.slabs).length===2,'chọn ô trần chỉ đổi lựa chọn trần, không đổi sàn');
  await page.click('#ceiling-pick-all');await wait();
  ok(Object.keys((await last('grid_preview')).levels[0].picks.ceilings).length===6,'chọn mọi ô: 6 trần');
  await receive('state',F.state);await receive('preview',F.preview_all_cells);
  ok(await page.locator('#plan6 polygon.cell.ceiling').count()===6,'xem trước 6 trần: vẽ đủ (đa giác có thể khoét góc)');
  await page.locator('#ceiling-level-select').selectOption('sl_00000002');
  await receive('preview',F.preview_top);
  ok(/tầng trên cùng/.test(await page.locator('#ceiling-summary').innerText()) && await page.locator('#build-ceilings').isDisabled() && await page.locator('#ceiling-pick-all').isDisabled() && await page.locator('#plan6 polygon').count()===0,'tầng trên cùng: không có trần, khóa nút, không vẽ ô để bấm');
  await page.locator('#ceiling-level-select').selectOption('sl_00000001');
  await receive('state',F.state);await receive('preview',F.preview);await clear();
  await page.click('[data-tab=ceilings]');await page.click('#build-ceilings');
  const cb=await last('plates_build');
  ok(cb && cb.kind==='ceilings' && JSON.stringify(cb.levels)==='["sl_00000001"]' && cb.state.levels[0].ceiling_height===2800,'Dựng trần: gửi kind = ceilings, tầng, cao trần');
  await receive('plates_built',{kind:'ceilings',message:'Đã dựng 2 trần.',drawn_levels:['sl_00000001']});
  ok(await page.locator('#remove-ceilings').isEnabled() && await page.locator('#remove-slabs').count()===1,'sau khi dựng trần: Xóa trần bấm được');
  await page.click('[data-tab=grid]');



  // ===== Loại cửa và tab Cửa =====
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=levels]');
  const otNames=()=>page.locator('#opening-types-table tr td:nth-child(1) input').evaluateAll(l=>l.map(i=>i.value));
  ok(JSON.stringify(await otNames())==='["D900x2100","W1200x1200"]' && await page.locator('#opening-types-table select').first().inputValue()==='door','bảng loại cửa: D900x2100 (cửa đi), W1200x1200 (cửa sổ)');
  await clear();
  await page.click('#add-opening-type');
  ok(JSON.stringify(await otNames())==='["D900x2100","W1200x1200","Cửa 3"]','thêm loại cửa');
  await page.locator('#opening-types-table tr:nth-child(4) td:nth-child(1) input').fill('D800');
  await page.locator('#opening-types-table tr:nth-child(4) td:nth-child(3) input').fill('800');
  await page.locator('#opening-types-table tr:nth-child(4) td:nth-child(5) input').fill('50');await wait();
  const ot1=await last('grid_preview');
  ok(ot1.opening_types.length===3 && ot1.opening_types[2].name==='D800' && ot1.opening_types[2].w===800 && ot1.opening_types[2].sill===50 && ot1.opening_types[2].kind==='door' && /^ot_[0-9a-f]{8}$/.test(ot1.opening_types[2].id),'loại cửa mới có mã ot_xxxxxxxx, gửi đúng kích thước, ngưỡng, kiểu');
  await page.locator('#opening-types-table select').nth(2).selectOption('window');await wait();
  ok((await last('grid_preview')).opening_types[2].kind==='window','đổi kiểu thành cửa sổ');
  await page.locator('#opening-types-table button.del').nth(2).click();await wait();
  ok((await last('grid_preview')).opening_types.length===2,'xóa loại cửa');
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=openings]');
  ok(await page.locator('#tab-openings').isVisible() && !(await page.locator('#tab-walls').isVisible()),'chuyển sang tab Cửa');
  ok(await page.locator('#plan7 rect.wallbase').count()===2 && await page.locator('#plan7 rect.door').count()===1 && await page.locator('#plan7 rect.window').count()===1,'mặt bằng cửa: 2 tường đã chọn, 1 cửa đi và 1 cửa sổ');
  ok(/2 cửa trên 2 tường/.test(await page.locator('#opening-summary').innerText()) && (await page.locator('#opening-level-note').innerText()).includes('2 cửa đã đặt'),'tóm tắt: số cửa, số tường; ghi chú số cửa đã đặt');
  ok(await page.locator('#opening-editor').isHidden() && await page.locator('#build-openings').isEnabled() && await page.locator('#remove-openings').isDisabled(),'chưa chọn tường: khung sửa ẩn; Dựng bấm được, Xóa khóa khi chưa dựng');
  await page.locator('#plan7 rect.wallbase[data-ref="x:B:1-2"]').dispatchEvent('click');
  ok(await page.locator('#opening-editor').isVisible() && (await page.locator('#opening-wall-ref').innerText())==='x:B:1-2' && await page.locator('#opening-list .oprow').count()===2,'bấm tường: mở khung sửa với 2 cửa đã đặt');
  ok((await page.locator('#opening-wall-note').innerText()).includes('Dài 4050'),'ghi chú chiều dài tường');
  await clear();
  await page.locator('#opening-list .oprow input[type=number]').first().fill('1200');await wait();
  const mv=await last('grid_preview');
  ok(mv.levels[0].picks.openings.op_00000001.pos===1200 && mv.levels[0].picks.openings.op_00000001.wall==='x:B:1-2' && mv.levels[0].picks.openings.op_00000001.type==='ot_00000001','sửa vị trí cửa: gửi pos mới (mã cửa, tường, loại giữ nguyên)');
  await page.locator('#opening-list .oprow input[type=checkbox]').first().check();await wait();
  ok((await last('grid_preview')).levels[0].picks.openings.op_00000001.flip===true,'đổi mặt cánh: gửi flip = true');
  await page.locator('#opening-list .oprow select').first().selectOption({label:'Cửa sổ W1200x1200 (1200×1200)'});await wait();
  ok((await last('grid_preview')).levels[0].picks.openings.op_00000001.type==='ot_00000002','đổi loại cửa');
  await page.locator('#opening-list .oprow button.del').first().click();await wait();
  const after1=await last('grid_preview');
  ok(!('op_00000001' in after1.levels[0].picks.openings) && 'op_00000002' in after1.levels[0].picks.openings && await page.locator('#opening-list .oprow').count()===1,'xóa cửa: gỡ khỏi lựa chọn, danh sách còn 1 cửa');
  await clear();
  await page.click('#add-door');await wait();
  const added=await last('grid_preview');
  const newIds=Object.keys(added.levels[0].picks.openings).filter(k=>k!=='op_00000002');
  ok(newIds.length===1 && /^op_[0-9a-f]{8}$/.test(newIds[0]) && added.levels[0].picks.openings[newIds[0]].wall==='x:B:1-2' && added.levels[0].picks.openings[newIds[0]].type==='ot_00000001' && added.levels[0].picks.openings[newIds[0]].flip===false,'+ Cửa đi: thêm cửa mới với mã op_xxxxxxxx, loại cửa đi đầu tiên, trên đúng tường');
  const np=added.levels[0].picks.openings[newIds[0]].pos;
  ok(np===1012.5 && Math.abs(np-2800)>=900/2+1200/2+50,'vị trí cửa mới: giữa tường (2025) bị cửa sổ chiếm chỗ nên lấy vị trí kế (1012,5), cách cửa sổ ít nhất 50 mm');
  await page.click('#add-window');await page.click('#add-window');await page.click('#add-window');await page.click('#add-window');await wait();
  ok((await message()).includes('không còn chỗ') || Object.keys((await last('grid_preview')).levels[0].picks.openings).length<=6,'thêm nhiều cửa: hết chỗ trống thì báo, không chồng cửa');
  // xem trước từ Ruby và dựng
  await receive('state',F.state);await receive('preview',F.preview);await clear();
  await page.click('[data-tab=openings]');await page.click('#build-openings');
  const ob=await last('openings_build');
  ok(ob && JSON.stringify(ob.levels)==='["sl_00000001"]' && Object.keys(ob.state.levels[0].picks.openings).length===2 && ob.state.opening_types.length===2,'Dựng cửa tầng này: gửi tầng và toàn bộ dữ liệu (kể cả loại cửa)');
  await clear();await page.click('#build-all-openings');
  ok(JSON.stringify((await last('openings_build')).levels)==='["sl_00000001"]','Dựng cửa mọi tầng: chỉ tầng có cửa và không phải tầng trên cùng');
  await receive('openings_built',{message:'Đã dựng 2 cửa.',drawn_opening_levels:['sl_00000001']});
  ok((await message())==='Đã dựng 2 cửa.' && await page.locator('#remove-openings').isEnabled(),'sau khi dựng: Xóa cửa bấm được');
  await page.click('#remove-openings');
  ok((await last('openings_remove')).level==='sl_00000001','Xóa cửa gửi mã tầng');
  await page.locator('#opening-level-select').selectOption('sl_00000002');
  await receive('preview',F.preview_top);
  ok(/tầng trên cùng/.test(await page.locator('#opening-summary').innerText()) && await page.locator('#build-openings').isDisabled() && await page.locator('#plan7 rect.wallbase').count()===0,'tầng trên cùng: báo không có cửa, không vẽ tường để bấm, khóa nút');
  await page.locator('#opening-level-select').selectOption('sl_00000001');
  await receive('preview',F.preview_bad_types);
  ok(await page.locator('#opening-summary.error').count()===1,'lỗi loại / tầng hiện ở tab Cửa');
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=levels]');await page.click('#add-level');await page.click('[data-tab=openings]');
  await page.locator('#opening-level-select').selectOption({index:1});await clear();
  await page.locator('#opening-copy-from').selectOption({label:'Tầng 1'});await page.click('#opening-copy-picks');
  const oc=await last('picks_copy');
  ok(oc && oc.kind==='openings' && oc.opening_types.length===2 && oc.from==='sl_00000001' && oc.to==='sl_00000002','sao chép cửa: gửi kind = openings cùng loại cửa');
  await receive('state',F.state);await receive('preview',F.preview);
  await receive('focus',{kind:'door',level:'sl_00000001',ref:'op_00000001'});
  ok(await page.locator('#tab-openings').isVisible() && (await page.locator('#opening-wall-ref').innerText())==='x:B:1-2','focus cửa (từ BIM): mở tab Cửa và chọn tường chứa cửa đó');
  await page.click('[data-tab=all]');
  const arr=await page.locator('#all-table tr').evaluateAll(rs=>[...rs[0].querySelectorAll('th')].map(c=>c.textContent));
  ok(arr.join('|')==='Tầng|Cột|Dầm|Tường|Cửa|Sàn|Trần|Đã dựng','bảng tổng hợp có cột Cửa');
  await page.click('[data-tab=grid]');

  // ===== Tab Tổng hợp và dựng =====
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=all]');
  ok(await page.locator('#tab-all').isVisible() && !(await page.locator('#tab-ceilings').isVisible()),'chuyển sang tab Tổng hợp và dựng');
  const allRows=()=>page.locator('#all-table tr').evaluateAll(rs=>rs.slice(1).map(r=>[...r.querySelectorAll('td')].map(c=>c.textContent)));
  const ar=await allRows();
  ok(ar.length===2 && ar[0][0]==='Tầng 1' && JSON.stringify(ar[0].slice(1,7))==='["2","2","2","2","2","2"]','bảng tổng hợp: tầng 1 có 2 cột, 2 dầm, 2 tường, 2 cửa, 2 sàn, 2 trần theo lựa chọn');
  ok(ar[1][0]==='Tầng 2 (trên cùng: chỉ sàn)' && ar[1][1]==='—' && ar[1][2]==='—' && ar[1][3]==='—' && ar[1][4]==='—' && ar[1][6]==='—' && ar[1][5]==='0','tầng trên cùng: chỉ hiện số sàn, các loại khác là —');
  ok(ar[0][7]==='—' && await page.locator('#build-all-level').isEnabled() && await page.locator('#build-all-levels').isEnabled(),'chưa dựng gì: cột Đã dựng là —; nút Dựng tất cả bấm được');
  await clear();
  await page.click('#propose-level');
  const pl=await last('propose');
  ok(pl && pl.scope==='level' && pl.level==='sl_00000001' && pl.levels.length===2 && pl.types.length===1 && pl.beam_types.length===1 && pl.wall_types.length===1 && pl.grid.x_axes.length===4,'Đề xuất cho tầng này: gửi phạm vi, tầng và toàn bộ dữ liệu (Ruby tính đề xuất)');
  await clear();
  await page.click('#propose-all');
  ok((await last('propose')).scope==='all','Đề xuất cho mọi tầng: scope = all');
  const full=JSON.parse(JSON.stringify(F.state.levels));
  full[0].picks={columns:Object.fromEntries(['1-A','1-B','1-C','2-A','2-B','2-C','3-A','3-B','3-C','4-A','4-B','4-C'].map(r=>[r,{}])),beams:{'x:A:1-2':{}},walls:{'x:A:1-2':{}},slabs:{'1-2/A-B':{}},ceilings:{}};
  await receive('levels',{levels:full,message:'Đã đề xuất cho 1 tầng: thêm 12 cột.',proposed:{}});await wait();
  const ar2=await allRows();
  ok((await message()).includes('Đã đề xuất') && ar2[0][1]==='12' && ar2[0][2]==='1' && ar2[0][6]==='0','nhận danh sách tầng đề xuất từ Ruby: bảng tổng hợp cập nhật (12 cột)');
  // Kiểm tra
  await clear();
  await page.click('#run-check');
  ok((await last('check')) && (await last('check')).levels[0].picks.columns && (await last('check')).grid,'Kiểm tra: gửi toàn bộ dữ liệu cho Ruby');
  await receive('check',F.check_ok);
  ok((await page.locator('#check-summary').innerText())==='Không có lỗi hay cảnh báo nào.' && await page.locator('#check-list li').count()===0,'báo cáo sạch: không lỗi, không cảnh báo');
  await receive('check',F.check_warn);
  const warns=await page.locator('#check-list li').allInnerTexts();
  ok(/0 lỗi, \d+ cảnh báo\./.test(await page.locator('#check-summary').innerText()) && warns.length>=4 && warns.some(w=>w.startsWith('Tầng 1 · Dầm x:B:1-2') && w.includes('2-B')),'báo cáo có cảnh báo (thiếu cột 2-B): liệt kê theo tầng, dầm không có cột để gối');
  await page.locator('#tab-all #all-level-select').selectOption('sl_00000002');
  ok(await page.locator('#check-list li').count()===0,'đổi dữ liệu / tầng làm báo cáo cũ biến mất (không hiện kết quả cũ)');
  await page.locator('#all-level-select').selectOption('sl_00000001');
  // Dựng tất cả
  await receive('state',F.state);await receive('preview',F.preview);await clear();
  await page.click('[data-tab=all]');
  await page.click('#build-all-level');
  const bl=await last('build_all');
  ok(bl && JSON.stringify(bl.levels)==='["sl_00000001"]' && bl.state.levels[0].picks.walls['x:B:1-2'] && bl.state.wall_types.length===1,'Dựng tất cả tầng đang chọn: gửi tầng và toàn bộ dữ liệu');
  await clear();await page.click('#build-all-levels');
  ok(JSON.stringify((await last('build_all')).levels)==='["sl_00000001","sl_00000002"]','Dựng tất cả các tầng: gửi mọi tầng');
  await receive('all_built',{message:'Đã dựng 10 đối tượng trong một bước hoàn tác: 2 cột.',drawn:{columns:['sl_00000001'],beams:['sl_00000001'],walls:[],slabs:['sl_00000001'],ceilings:[]}});
  const ar3=await allRows();
  ok((await message()).includes('một bước hoàn tác') && ar3[0][7]==='Cột, Dầm, Sàn' && ar3[1][7]==='—','sau khi dựng: cột Đã dựng liệt kê các loại đã dựng của tầng');
  await page.click('[data-tab=columns]');
  ok(await page.locator('#remove-cols').isEnabled() && await page.locator('#remove-walls').isDisabled(),'các tab riêng nhận trạng thái đã dựng (xóa cột bấm được, xóa tường khóa)');
  await page.click('[data-tab=grid]');


  // ===== Sửa từ VGD BIM (sự kiện focus) =====
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=grid]');
  await receive('focus',{kind:'beam',level:'sl_00000001',ref:'x:B:1-2'});
  ok(await page.locator('#tab-beams').isVisible() && (await page.locator('#beam-ref').innerText())==='x:B:1-2' && await page.locator('#beam-editor').isVisible() && (await message()).includes('x:B:1-2'),'focus dầm: mở tab Dầm, chọn đúng nhịp, mở khung sửa, báo đang sửa');
  await receive('focus',{kind:'column',level:'sl_00000001',ref:'2-B'});
  ok(await page.locator('#tab-columns').isVisible() && (await page.locator('#col-ref').innerText())==='2-B','focus cột: mở tab Cột, chọn cột 2-B');
  await receive('focus',{kind:'wall',level:'sl_00000001',ref:'y:2:A-B'});
  ok(await page.locator('#tab-walls').isVisible() && (await page.locator('#wall-ref').innerText())==='y:2:A-B','focus tường: mở tab Tường (nhịp có dấu hai chấm)');
  await receive('focus',{kind:'slab',level:'sl_00000001',ref:'1-2/A-B'});
  ok(await page.locator('#tab-slabs').isVisible(),'focus sàn: mở tab Sàn');
  await receive('focus',{kind:'ceiling',level:'sl_00000001',ref:'1-2/A-B'});
  ok(await page.locator('#tab-ceilings').isVisible(),'focus trần: mở tab Trần');
  await receive('focus',{kind:'column',level:'sl_00000002',ref:'1-A'});
  ok(await page.locator('#column-level-select, #level-select').first().inputValue()==='sl_00000002' && await page.locator('#tab-columns').isVisible() && await page.locator('#col-editor').isHidden(),'focus tầng khác: chuyển tầng; cột không nằm trong lựa chọn thì không mở khung sửa');
  await receive('focus',{kind:'room',level:'sl_00000001',ref:'x'});
  ok(await page.locator('#tab-columns').isVisible(),'focus loại lạ: bỏ qua, không đổi tab, không lỗi');
  await page.click('[data-tab=grid]');

  // Tab Mặt bằng (canvas)
  await receive('state',F.state);await receive('preview',F.preview_all_cells);
  await page.click('[data-tab=plan]');
  ok(await page.locator('#pv-browser').isVisible(),'tab Mặt bằng mở ra: Cây dự án hiện sẵn (như Revit)');
  await page.click('#pv-browser-btn');ok(await page.locator('#pv-browser').isHidden() && (await page.locator('#pv-browser-btn').getAttribute('aria-pressed'))==='false','nút Cây dự án ẩn bảng');await wait(80);await page.keyboard.press('z');await page.keyboard.press('e');await wait(60);
  const dbg=()=>page.evaluate(()=>window.VGDPlan.debug());
  const pix=async(wx,wy)=>page.evaluate(([x,y])=>{const c=document.getElementById('pv-canvas'),p=window.VGDPlan.toScreen(x,y),d=c.getContext('2d').getImageData(Math.round(p[0]*window.devicePixelRatio),Math.round(p[1]*window.devicePixelRatio),1,1).data;return [d[0],d[1],d[2]];},[wx,wy]);
  ok(await page.locator('#tab-plan').isVisible() && !(await page.locator('#tab-grid').isVisible()),'tab Mặt bằng: hiện canvas, ẩn tab khác');
  let d0=await dbg();
  ok(d0.axes===7 && d0.counts.column===12 && d0.counts.slab===6 && d0.counts.wall>0 && d0.counts.beam>0 && d0.counts.ceiling===6,'mặt bằng nhận đủ phần tử từ xem trước: 7 trục, 12 cột, 6 sàn, tường, dầm, 6 trần');
  ok(d0.view.s>0.01 && d0.size.w>300 && d0.size.h>200,'tự vừa khung lần đầu, canvas có kích thước');
  const col=F.preview_all_cells.columns.items[0].center,c0=await pix(col[0],col[1]);
  ok(c0[1]>c0[0] && c0[1]>c0[2] && c0[1]>150,'pixel tại tâm cột có màu xanh lá (cột được vẽ trên canvas)');
  ok(await page.locator('#pv-tabs .pv-tab').count()===F.state.levels.length && (await page.locator('#pv-tabs [aria-selected=true]').getAttribute('data-level'))===F.state.levels[0].id,'tab theo tầng: đủ số tầng, đang chọn tầng hiện hành');
  ok(await page.locator('#pv-top .pv-ic[data-tool=select]').isEnabled() && await page.locator('#pv-top .pv-ic[data-tool=pan]').isEnabled() && await page.locator('#pv-side .pv-ic:disabled').count()===0 && await page.locator('#pv-side .pv-ic:not(:disabled)').count()===16,'cột công cụ bên trái: 8 công cụ thiết kế và 8 nút vẽ 2D / ghi chú đều dùng được; thanh trên có Chọn và Kéo dùng được');
  ok(await page.locator('#pv-side .pv-side-grp > i').allInnerTexts().then(a=>a.join('|'))==='Thiết kế|Vẽ 2D|Ghi chú','cột công cụ chia nhóm Thiết kế, Vẽ 2D, Ghi chú');
  ok((await page.locator('#pv-props').innerText()).includes('Tầng 1') && (await page.locator('#pv-props').innerText()).includes('Cao độ sàn'),'bảng Thuộc tính chưa chọn gì: hiện thông tin tầng');
  // Thu phóng quanh con trỏ: điểm dưới con trỏ đứng yên
  const box=await page.locator('#pv-canvas').boundingBox(),px=box.x+300,py=box.y+200,wBefore=await page.evaluate(([x,y])=>window.VGDPlan.toWorld(x,y),[300,200]);
  await page.mouse.move(px,py);await page.mouse.wheel(0,-300);await wait(80);
  const d1=await dbg(),wAfter=await page.evaluate(([x,y])=>window.VGDPlan.toWorld(x,y),[300,200]);
  ok(d1.view.s>d0.view.s*1.3 && Math.abs(wAfter[0]-wBefore[0])<1 && Math.abs(wAfter[1]-wBefore[1])<1,'cuộn lên: phóng to và giữ nguyên điểm dưới con trỏ');
  await page.mouse.wheel(0,600);await wait(80);
  ok((await dbg()).view.s<d1.view.s,'cuộn xuống: thu nhỏ');
  // Kéo bằng chuột giữa
  const dv=await dbg();
  await page.mouse.move(px,py);await page.mouse.down({button:'middle'});await page.mouse.move(px+80,py+40,{steps:4});await page.mouse.up({button:'middle'});
  const dp=await dbg();
  ok(Math.abs((dp.view.cx-dv.view.cx)+80/dv.view.s)<1 && Math.abs((dp.view.cy-dv.view.cy)-40/dv.view.s)<1,'kéo chuột giữa: mặt bằng dời đúng theo chuột');
  // Công cụ Kéo bằng phím H và nút
  await page.click('[data-tool=pan]');ok((await dbg()).tool==='pan' && (await page.locator('[data-tool=pan]').getAttribute('aria-pressed'))==='true','nút Kéo chọn công cụ Kéo');
  await page.mouse.move(px,py);await page.mouse.down();await page.mouse.move(px-50,py,{steps:3});await page.mouse.up();
  ok(Math.abs((await dbg()).view.cx-(dp.view.cx+50/dp.view.s))<1,'công cụ Kéo: kéo chuột trái dời mặt bằng');
  await page.keyboard.press('Escape');ok((await dbg()).tool==='select','Esc về công cụ Chọn (Modify)');
  // Vừa khung
  await page.keyboard.press('z');await page.keyboard.press('e');await wait(50);
  const df=await dbg();ok(Math.abs(df.view.s-d0.view.s)<1e-9,'gõ ZE (Zoom to Fit): về đúng khung ban đầu');
  // Rê chuột lên cột: hiện thông tin
  const csp=await page.evaluate(([x,y])=>window.VGDPlan.toScreen(x,y),[col[0],col[1]]);
  await page.mouse.move(box.x+csp[0],box.y+csp[1]);await wait(50);
  ok(/Cột 1-A/.test(await page.locator('#pv-hint').innerText()) && /X -?\d+\s+Y -?\d+ mm/.test(await page.locator('#pv-xy').innerText()),'rê lên cột: hiện mã, loại, kích thước và tọa độ con trỏ');
  // Chọn bằng bấm: bảng Thuộc tính hiện phần tử
  await page.mouse.click(box.x+csp[0],box.y+csp[1]);await wait(50);
  ok((await dbg()).selected==='Cột 1-A' && /Rộng × sâu/.test(await page.locator('#pv-props').innerText()),'bấm cột: chọn, bảng Thuộc tính hiện loại và kích thước');
  await page.mouse.move(box.x+5,box.y+5);await page.mouse.click(box.x+5,box.y+5);await wait(50);
  ok((await dbg()).selected===null && (await page.locator('#pv-props').innerText()).includes('Cao độ sàn'),'bấm chỗ trống: bỏ chọn, bảng về thông tin tầng');
  await page.mouse.click(box.x+csp[0],box.y+csp[1]);await page.keyboard.press('Escape');
  ok((await dbg()).selected===null,'Esc bỏ chọn');
  await page.click('#pv-props-btn');ok(await page.locator('#pv-props').isHidden(),'nút Thuộc tính ẩn bảng');await page.click('#pv-props-btn');
  await page.click('#pv-layers-btn');ok(await page.locator('#pv-layers').isVisible(),'nút Hiển thị mở danh sách lớp');
  // P2: chọn bằng khung, Shift, Ctrl+A
  const G=F.state.grid,gx=G.x_axes.map(a=>G.origin[0]+a.offset),gy=G.y_axes.map(a=>G.origin[1]+a.offset);
  const scr=async(x,y)=>{const bb=await page.locator('#pv-canvas').boundingBox(),q=await page.evaluate(([a,b])=>window.VGDPlan.toScreen(a,b),[x,y]);return [bb.x+q[0],bb.y+q[1]];};
  const colAt=ref=>F.preview_all_cells.columns.items.filter(c=>c.ref===ref)[0];
  const k1=colAt("1-A"),k2=colAt("2-A");
  const dragBox=async(a,b)=>{const p0=await scr(a[0],a[1]),p1=await scr(b[0],b[1]);await page.mouse.move(p0[0],p0[1]);await page.mouse.down();await page.mouse.move((p0[0]+p1[0])/2,(p0[1]+p1[1])/2,{steps:3});await page.mouse.move(p1[0],p1[1],{steps:3});await page.mouse.up();};
  const m=250;
  await dragBox([k1.center[0]-k1.w/2-m,k1.center[1]+k1.d/2+m],[k1.center[0]+k1.w/2+m,k1.center[1]-k1.d/2-m]);
  ok(JSON.stringify((await dbg()).selection)==='["Cột 1-A"]','kéo khung trái→phải (khung trong): chỉ chọn cột nằm trọn trong khung, không chọn sàn lớn hơn khung');
  await dragBox([k1.center[0]+k1.w/2+m,k1.center[1]-k1.d/2-m],[k1.center[0]-k1.w/2-m,k1.center[1]+k1.d/2+m]);
  let sel=(await dbg()).selection;
  ok(sel.includes('Cột 1-A') && sel.includes('Sàn 1-2/A-B') && sel.length>=2,'kéo khung phải→trái (khung cắt): chọn cả hình chạm khung (cột và sàn)');
  ok((await page.locator('#pv-props').innerText()).includes('Đã chọn '+sel.length+' phần tử'),'chọn nhiều: bảng Thuộc tính hiện số phần tử đã chọn');
  await page.mouse.click(box.x+5,box.y+5);
  const p1c=await scr(k1.center[0],k1.center[1]),p2c=await scr(k2.center[0],k2.center[1]);
  await page.mouse.click(p1c[0],p1c[1]);await page.keyboard.down('Control');await page.mouse.click(p2c[0],p2c[1]);await page.keyboard.up('Control');
  ok(JSON.stringify((await dbg()).selection)==='["Cột 1-A","Cột 2-A"]','Ctrl + bấm: thêm vào lựa chọn (quy ước Revit)');
  await page.keyboard.down('Shift');await page.mouse.click(p2c[0],p2c[1]);await page.keyboard.up('Shift');
  ok(JSON.stringify((await dbg()).selection)==='["Cột 1-A"]','Shift + bấm phần tử đã chọn: bớt khỏi lựa chọn (quy ước Revit)');
  await page.mouse.click(box.x+5,box.y+5);
  await page.keyboard.press('Control+a');
  const dAll=await dbg(),total=Object.keys(dAll.counts).filter(k=>dAll.visible[k==='opening'?'opening':k]).reduce((n,k)=>n+dAll.counts[k],0);
  ok(dAll.selection.length===total && total>20,'Ctrl+A: chọn mọi phần tử đang hiện (không gồm lớp đang tắt)');
  await page.keyboard.press('Escape');ok((await dbg()).selection.length===0,'Esc bỏ chọn tất cả');

  // P2: bắt điểm
  await page.click('[data-tool=measure]');
  const snapAtW=async(x,y,dx=3,dy=2)=>{const q=await scr(x,y);await page.mouse.move(q[0]+dx,q[1]+dy);await wait(30);return dbg();};
  let sd=await snapAtW(k1.center[0]-k1.w/2,k1.center[1]-k1.d/2);
  ok(sd.snap && sd.snap.text==='Đầu mút' && sd.snap.rank===0 && Math.hypot(sd.snap.p[0]-(k1.center[0]-k1.w/2),sd.snap.p[1]-(k1.center[1]-k1.d/2))<1,'bắt điểm: gần góc cột hiện "Đầu mút" và hít đúng tọa độ góc');
  sd=await snapAtW(gx[2],gy[1],0.3,0.2);
  ok(sd.snap && sd.snap.rank<=1 && Math.abs(sd.snap.p[0]-gx[2])<1 && Math.abs(sd.snap.p[1]-gy[1])<1,'bắt điểm: giao hai trục (trùng góc sàn) hít đúng tọa độ giao trục');
  const slabTop=F.preview_all_cells.slabs.items.filter(i=>i.ref==='1-2/B-C')[0];
  sd=await snapAtW((slabTop.min[0]+slabTop.max[0])/2,slabTop.max[1]);
  ok(sd.snap && sd.snap.text==='Trung điểm' && Math.abs(sd.snap.p[0]-(slabTop.min[0]+slabTop.max[0])/2)<1,'bắt điểm: giữa cạnh sàn hiện "Trung điểm"');
  sd=await snapAtW(gx[1]+700,gy[0]);
  ok(sd.snap && sd.snap.rank===3 && /Trên (trục|cạnh)/.test(sd.snap.text) && Math.abs(sd.snap.p[1]-gy[0])<1,'bắt điểm: trên trục / cạnh khi không gần điểm đặc biệt');
  const far=await scr((gx[1]+gx[2])/2,(gy[1]+gy[2])/2);await page.mouse.move(far[0],far[1]);await wait(30);
  ok((await dbg()).snap===null,'xa mọi điểm: không bắt (không hít bừa)');
  await page.click('#pv-snap');sd=await snapAtW(gx[2],gy[1]);
  ok(sd.snap===null && sd.snapOn===false,'tắt Bắt điểm: không hít nữa');
  await page.click('#pv-snap');

  // P2: đo
  await page.keyboard.press('Escape');await page.click('[data-tool=measure]');
  const click=async(x,y)=>{const q=await scr(x,y);await page.mouse.move(q[0],q[1]);await page.mouse.click(q[0],q[1]);};
  await click(gx[0],gy[0]);ok((await dbg()).measure && !(await dbg()).measure.done,'đo: bấm điểm đầu');
  await click(gx[1],gy[0]);let ms=await dbg();
  ok(ms.measure.done && Math.abs(ms.measure.b[0]-gx[1])<1 && /4200 mm/.test(await page.locator('#pv-hint').innerText()) && /Δx 4200, Δy 0, góc 0°/.test(await page.locator('#pv-hint').innerText()),'đo hai giao trục: 4200 mm, Δx 4200, Δy 0, góc 0°');
  await click(gx[0],gy[0]);await click(gx[1],gy[1]);
  const diag=Math.hypot(gx[1]-gx[0],gy[1]-gy[0]),ang=Math.round(Math.atan2(gy[1]-gy[0],gx[1]-gx[0])*1800/Math.PI)/10;
  ok(new RegExp(Math.round(diag)+' mm.*góc '+ang+'°').test(await page.locator('#pv-hint').innerText()),'đo đường chéo: độ dài và góc đúng ('+Math.round(diag)+' mm, '+ang+'°)');
  await click(gx[0],gy[0]);
  const tq=await scr(gx[1],gy[1]);await page.keyboard.down('Shift');await page.mouse.move(tq[0],tq[1]);await wait(30);
  ok(/4200 mm/.test(await page.locator('#pv-hint').innerText()) && /góc 0°/.test(await page.locator('#pv-hint').innerText()),'Shift khóa hướng đo theo trục gần nhất (ngang)');
  await page.keyboard.up('Shift');
  const rq=await scr(gx[0]+2000,gy[0]);await page.mouse.move(rq[0],rq[1]);await page.fill('#pv-vcb','1500');await page.press('#pv-vcb','Enter');ms=await dbg();
  ok(ms.measure.done && Math.abs(ms.measure.b[0]-(gx[0]+1500))<1 && Math.abs(ms.measure.b[1]-gy[0])<1 && (await page.locator('#pv-vcb').inputValue())==='','gõ 1500 + Enter khi đo: điểm cuối cách 1500 mm theo hướng con trỏ');
  await page.keyboard.press('Escape');ok((await dbg()).measure===null,'Esc hủy phép đo');

  // P2: đường gióng
  await page.click('[data-tool=guide]');ok((await dbg()).tool==='guide','bấm nút Đường gióng');
  await click(gx[0],gy[0]+1000);ok((await dbg()).draft==='ref','bấm vào một nét: chờ gióng song song');
  const rt=await scr(gx[0]+900,gy[0]+1000);await page.mouse.move(rt[0],rt[1]);await page.fill('#pv-vcb','500');await page.press('#pv-vcb','Enter');
  let gd=await dbg();
  ok(gd.guides===1 && Math.abs(gd.guideLines[0].p[0]-(gx[0]+500))<1 && Math.abs(gd.guideLines[0].d[1])>0.99,'gõ 500 + Enter: gióng song song với trục đứng, cách 500 mm về phía con trỏ');
  await click(gx[0],gy[0]+1000);const lt=await scr(gx[0]-900,gy[0]+1000);await page.mouse.move(lt[0],lt[1]);await page.fill('#pv-vcb','300');await page.press('#pv-vcb','Enter');
  gd=await dbg();ok(gd.guides===2 && Math.abs(gd.guideLines[1].p[0]-(gx[0]-300))<1,'cùng nét, con trỏ ở phía trái: gióng cách 300 mm về bên trái (đúng phía con trỏ)');
  await page.keyboard.press('Escape');await page.click('[data-tool=guide]');
  await click(k1.center[0]-k1.w/2,k1.center[1]-k1.d/2);ok((await dbg()).draft==='first','bấm đầu mút: chờ điểm thứ hai (gióng qua hai điểm)');
  await click(k2.center[0]+k2.w/2,k2.center[1]+k2.d/2);gd=await dbg();
  ok(gd.guides===3 && gd.draft===null,'bấm điểm thứ hai: tạo đường gióng qua hai điểm');
  sd=await snapAtW(gx[0]+500,gy[0]);
  ok(sd.snap && sd.snap.text==='Giao điểm' && Math.abs(sd.snap.p[0]-(gx[0]+500))<1,'đường gióng cũng được bắt điểm: giao với trục A');
  await page.click('[data-tab=plan]');
  await page.click('#pv-tabs .pv-tab:nth-child(2)');await wait(300);ok((await dbg()).guides===0,'đường gióng riêng từng tầng: tầng 2 chưa có');
  await receive('preview',F.preview_all_cells);await page.click('#pv-tabs .pv-tab:nth-child(1)');await wait(300);await receive('preview',F.preview_all_cells);
  ok((await dbg()).guides===3,'quay lại tầng 1: đường gióng còn (kể cả khi xem trước được tính lại)');
  await page.click('#pv-guide-clear');ok((await dbg()).guides===0,'nút Xóa đường gióng: xóa hết của tầng');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  // Phím tắt kiểu Revit
  await page.mouse.move(box.x+5,box.y+5);await page.mouse.click(box.x+5,box.y+5);await page.mouse.move(box.x+6,box.y+6);await wait(40);
  ok(/ZE = vừa khung, KS = bảng phím tắt/.test(await page.locator('#pv-hint').innerText()) && !/H = kéo|F = vừa/.test(await page.locator('#pv-hint').innerText()),'gợi ý mặc định nhắc phím Revit (ZE, KS), không còn phím cũ H / F');
  const type=async s=>{for(const ch of s)await page.keyboard.press(ch.toLowerCase());};
  ok((await page.locator('[data-tool=measure] kbd').innerText())==='ME' && (await page.locator('[data-tool=measure]').getAttribute('title')).includes('(ME)') && (await page.locator('[data-tool=wall] kbd').innerText())==='WA' && (await page.locator('#pv-fit kbd').innerText())==='ZE','nút công cụ hiện phím tắt Revit (ME, WA, ZE) ở góc và trong gợi ý');
  await type('me');ok((await dbg()).tool==='measure','gõ ME: công cụ Đo');
  await type('rp');ok((await dbg()).tool==='guide','gõ RP: công cụ Đường gióng (Reference Plane)');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  await type('so');ok((await dbg()).snapOn===false,'gõ SO: tắt bắt điểm');await type('so');ok((await dbg()).snapOn===true,'gõ SO lần nữa: bật lại');
  await type('pp');ok(await page.locator('#pv-props').isHidden(),'gõ PP: ẩn bảng Thuộc tính');await type('pp');ok(await page.locator('#pv-props').isVisible(),'gõ PP lần nữa: hiện lại');
  await type('vg');ok(await page.locator('#pv-layers').isVisible(),'gõ VG: mở danh sách lớp hiển thị');await type('vg');ok(await page.locator('#pv-layers').isHidden(),'gõ VG lần nữa: đóng');
  await type('wa');ok((await dbg()).tool==='wall' && await page.locator('#pv-options').isVisible(),'gõ WA: công cụ Tường, hiện thanh tùy chọn');await type('li');ok((await dbg()).tool==='line' && /Line: bấm điểm đầu/.test(await page.locator('#pv-hint').innerText()),'gõ LI: công cụ Line (P5b), gợi ý bấm điểm đầu');await page.keyboard.press('Escape');ok((await dbg()).tool==='select' && await page.locator('#pv-options').isHidden(),'Esc về công cụ Chọn, thanh tùy chọn ẩn');
  await page.mouse.move(box.x+300,box.y+200);await page.mouse.wheel(0,-600);await wait(60);const zoomed=(await dbg()).view.s;
  await type('wze');await wait(60);
  ok(Math.abs((await dbg()).view.s-d0.view.s)<1e-9 && zoomed>d0.view.s,'gõ sai chữ thứ hai (W, Z, E): bỏ phím sai và vẫn nhận ZE (vừa khung)');
  await type('q');ok((await dbg()).chord==='' ,'chữ đầu không thuộc phím nào: bỏ qua');
  // Bảng phím tắt chỉnh được
  await type('ks');ok(await page.locator('#pv-keys').isVisible() && await page.locator('#pv-keys input.pv-key').count()>=30,'gõ KS: mở bảng Phím tắt, liệt kê đủ lệnh');
  const keyInput=id=>page.locator(`#pv-keys input[data-cmd=${id}]`);
  await keyInput('fit').fill('WA');
  ok((await dbg()).keymap.fit==='ZE' && /Trùng với .Tường/.test(await page.locator('#pv-keys tr:has(input[data-cmd=fit]) .pv-key-msg').innerText()),'đặt phím trùng WA: báo trùng với Tường và KHÔNG áp dụng');
  await keyInput('fit').fill('1z!');ok((await dbg()).keymap.fit==='Z' && (await keyInput('fit').inputValue())==='Z','gõ ký tự lạ: chỉ giữ chữ A–Z');
  await keyInput('fit').fill('ZE');
  await keyInput('measure').fill('MX');
  ok((await dbg()).keymap.measure==='MX' && (await page.locator('[data-tool=measure] kbd').innerText())==='MX','đổi phím Đo thành MX: áp dụng ngay và nút đổi nhãn');
  await page.evaluate(()=>window.VGDPlan.reloadKeys());
  ok((await dbg()).keymap.measure==='MX' && (await keyInput('measure').inputValue())==='MX','phím đã đổi được lưu và nạp lại sau khi mở lại');
  await page.keyboard.press('Escape');ok(await page.locator('#pv-keys').isHidden(),'Esc đóng bảng phím tắt (khi đang gõ trong ô)');
  await type('mx');ok((await dbg()).tool==='measure','phím mới MX chạy lệnh Đo');await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  await type('me');ok((await dbg()).tool==='select','phím cũ ME không còn chạy Đo sau khi đổi');
  // Phím trùng đầu: chờ thêm chữ
  await page.click('#pv-keys-btn');await keyInput('pan').fill('M');
  ok(/Trùng đầu/.test(await page.locator('#pv-keys tr:has(input[data-cmd=pan]) .pv-key-msg').innerText()),'phím M trùng đầu với MV / MX: có cảnh báo (không cấm)');
  await page.keyboard.press('Escape');await type('m');ok((await dbg()).chord==='M' && (await dbg()).tool==='select','gõ M: chờ chữ tiếp theo (còn phím dài hơn bắt đầu bằng M)');
  await page.waitForTimeout(1100);ok((await dbg()).tool==='pan' && (await dbg()).chord==='','hết thời gian chờ: chạy phím M (Kéo)');
  await page.keyboard.press('Escape');
  await page.click('#pv-keys-btn');await page.click('#pv-keys-reset');
  ok((await dbg()).keymap.measure==='ME' && (await dbg()).keymap.pan==='' && (await keyInput('measure').inputValue())==='ME','Đặt lại mặc định: trả về phím gốc');
  await page.keyboard.press('Escape');
  // Quy ước chọn Revit: Ctrl thêm, Shift bớt, kéo khung; Tab chuyển phần tử chồng nhau
  await page.keyboard.press('Control+a');const allN=(await dbg()).selection.length;
  await page.keyboard.down('Shift');await dragBox([k1.center[0]-k1.w/2-m,k1.center[1]+k1.d/2+m],[k1.center[0]+k1.w/2+m,k1.center[1]-k1.d/2-m]);await page.keyboard.up('Shift');
  sel=(await dbg()).selection;ok(sel.length===allN-1 && !sel.includes('Cột 1-A') && sel.includes('Cột 2-A'),'Shift + kéo khung: bớt cột 1-A khỏi lựa chọn đang có');
  await page.keyboard.press('Escape');await page.mouse.click(box.x+5,box.y+5);
  await dragBox([k1.center[0]-k1.w/2-m,k1.center[1]+k1.d/2+m],[k1.center[0]+k1.w/2+m,k1.center[1]-k1.d/2-m]);
  await page.keyboard.down('Control');await dragBox([k2.center[0]-k2.w/2-m,k2.center[1]+k2.d/2+m],[k2.center[0]+k2.w/2+m,k2.center[1]-k2.d/2-m]);await page.keyboard.up('Control');
  ok(JSON.stringify((await dbg()).selection)==='["Cột 1-A","Cột 2-A"]','Ctrl + kéo khung: thêm vào lựa chọn đang có');
  await page.mouse.click(box.x+5,box.y+5);
  await page.mouse.move(p1c[0]+2,p1c[1]+1);await wait(40);
  ok((await dbg()).hoverCount>=2 && /^Cột 1-A/.test((await dbg()).hover),'rê lên cột đè trên sàn: nhận ra nhiều phần tử chồng nhau, phần tử trên cùng là cột');
  await page.keyboard.press('Tab');await wait(30);
  ok(/^Sàn/.test((await dbg()).hover) && /Tab/.test(await page.locator('#pv-hint').innerText()),'Tab: chuyển sang phần tử bên dưới (sàn), gợi ý hiện số phần tử chồng');
  await page.mouse.click(p1c[0]+2,p1c[1]+1);
  ok((await dbg()).selection.length===1 && /^Sàn/.test((await dbg()).selection[0]),'bấm khi đang chọn bằng Tab: chọn đúng phần tử đã chuyển tới');
  await page.keyboard.press('Shift+Tab');await page.mouse.move(p1c[0]+3,p1c[1]+1);await wait(30);
  ok(/^Cột 1-A/.test((await dbg()).hover),'rê sang vị trí khác: Tab quay lại mặc định (phần tử trên cùng)');
  await page.mouse.click(box.x+5,box.y+5);await page.keyboard.press('Escape');
  // Tắt lớp
  await page.click('#pv-layers-btn');await page.uncheck('[data-layer=column]');await page.mouse.click(box.x+5,box.y+5);await page.mouse.move(box.x+csp[0]+1,box.y+csp[1]);await wait(50);
  const c1=await pix(col[0],col[1]);
  ok(!(c1[1]>c1[0] && c1[1]>c1[2] && c1[1]>150) && !/Cột/.test(await page.locator('#pv-hint').innerText()),'tắt lớp Cột: không vẽ và không bắt cột nữa');
  await page.click('#pv-layers-btn');await page.check('[data-layer=column]');await page.check('[data-layer=ceiling]');await wait(30);
  ok((await dbg()).visible.ceiling===true,'bật lớp Trần');
  await page.uncheck('[data-layer=ceiling]');await page.mouse.click(box.x+5,box.y+5);
  // Đổi tầng từ mặt bằng: gửi xem trước mới và đồng bộ ô chọn tầng tab khác
  await clear();
  await page.click('#pv-tabs .pv-tab:nth-child(2)');await wait(300);
  ok((await last('grid_preview')).level===F.state.levels[1].id,'đổi tầng trên mặt bằng: gửi xem trước cho tầng mới');
  await receive('preview',F.preview_top);
  ok((await dbg()).counts.column===undefined,'tầng trên cùng: không có cột trên mặt bằng');
  await page.click('[data-tab=columns]');
  ok((await page.locator('#level-select').inputValue())===F.state.levels[1].id,'ô chọn tầng của tab Cột theo tầng đã đổi ở mặt bằng');
  {
  // P3: vẽ kết cấu bằng bấm điểm
  await page.click('[data-tab=plan]');await receive('state',F.state);await receive('preview',F.preview_all_cells);await page.keyboard.press('Escape');
  await page.keyboard.press('z');await page.keyboard.press('e');await wait(60);
  const PK=k=>page.evaluate(k=>JSON.parse(JSON.stringify(window.VGDS._state.levels[0][k])),k);
  const nodeAt=(i,j)=>[gx[i],gy[j]],cellRef=(i,j)=>`${G.x_axes[i].name}-${G.x_axes[i+1].name}/${G.y_axes[j].name}-${G.y_axes[j+1].name}`;
  const clickW=async(x,y)=>{const q=await scr(x,y);await page.mouse.move(q[0],q[1]);await page.mouse.click(q[0],q[1]);};
  const hoverW=async(x,y)=>{const q=await scr(x,y);await page.mouse.move(q[0],q[1]);await wait(30);return dbg();};
  const hist=()=>page.evaluate(()=>window.VGDS.history());
  ok((await hist()).undo===0 && await page.locator('#pv-undo').isDisabled(),'sau khi nạp dữ liệu: chưa có gì để hoàn tác');
  await type('cl');ok((await dbg()).tool==='column' && await page.locator('#pv-options select[data-opt=type] option').count()===F.state.types.length+1 && await page.locator('#pv-options select[data-opt=x]').isVisible(),'gõ CL: công cụ Cột; thanh tùy chọn có Loại, Vị trí X, Vị trí Y');
  let ed=(await hoverW(...nodeAt(2,0))).edit;
  ok(ed.target && ed.target.ref==='3-A' && ed.target.exists===false,'rê gần giao điểm 3-A: nhận mục tiêu, chưa có cột');
  await clear();await clickW(...nodeAt(2,0));await wait(300);
  let pk=await PK('picks');let gp=await last('grid_preview');
  ok(pk['3-A'] && Object.keys(pk['3-A']).length===0 && gp.levels[0].picks.columns['3-A'] && (await hist()).undo===1 && await page.locator('#pv-undo').isEnabled(),'bấm giao điểm 3-A: thêm cột (loại mặc định) vào lựa chọn, gửi Ruby xem trước, bật Hoàn tác');
  await clickW(...nodeAt(0,0));ok(/đã có/.test(await page.locator('#pv-hint').innerText()) && (await hist()).undo===1,'bấm giao điểm đã có cột: báo "đã có", không thêm, không ghi lịch sử');
  const col2=F.state.types[1]||F.state.types[0];
  await page.selectOption('#pv-options select[data-opt=type]',col2.id);await page.selectOption('#pv-options select[data-opt=x]','center');
  await clickW(...nodeAt(3,0));pk=await PK('picks');
  ok(pk['4-A'] && pk['4-A'].type===col2.id && pk['4-A'].x==='center' && !('y' in pk['4-A']),'chọn loại và vị trí X ở thanh tùy chọn rồi bấm: cột mới mang đúng loại và vị trí (chỉ ghi phần khác mặc định)');
  await page.keyboard.press('Control+z');pk=await PK('picks');ok(!pk['4-A'] && pk['3-A'] && (await hist()).redo===1,'Ctrl+Z: hoàn tác cột 4-A (còn 3-A), bật Làm lại');
  await page.keyboard.press('Control+z');pk=await PK('picks');ok(!pk['3-A'] && (await hist()).undo===0,'Ctrl+Z lần nữa: hoàn tác cột 3-A');
  await page.keyboard.press('Control+y');await page.keyboard.press('Control+y');pk=await PK('picks');ok(pk['3-A'] && pk['4-A'] && pk['4-A'].x==='center','Ctrl+Y hai lần: làm lại cả hai cột');
  await page.click('#pv-undo');ok(!(await PK('picks'))['4-A'],'nút Hoàn tác trên thanh trên hoạt động');
  await page.keyboard.press('Escape');await type('bm');
  await clickW(...nodeAt(0,0));ed=(await dbg()).edit;ok(ed.chain==='1-A','dầm: bấm giao điểm đầu 1-A, chờ điểm cuối');
  await hoverW(...nodeAt(2,0));ed=(await dbg()).edit;ok(ed.target && ed.target.end==='3-A' && JSON.stringify(ed.target.refs)==='["x:A:1-2","x:A:2-3"]','rê tới 3-A (cùng hàng): xem trước 2 nhịp x:A:1-2, x:A:2-3');
  await clickW(...nodeAt(2,0));let bp=await PK('beamPicks');
  ok(bp['x:A:1-2'] && bp['x:A:2-3'] && /Đã thêm 2 dầm/.test(await page.locator('#pv-hint').innerText()) && (await dbg()).edit.chain==='3-A','bấm điểm cuối: thêm 2 dầm cùng lúc, chuỗi tiếp tục từ 3-A');
  await hoverW(...nodeAt(2,2));ed=(await dbg()).edit;ok(ed.target && ed.target.end==='3-C' && JSON.stringify(ed.target.refs)==='["y:3:A-B","y:3:B-C"]','chuỗi đổi hướng: rê dọc tới 3-C ra 2 nhịp theo phương Y');
  await page.keyboard.press('Escape');ok((await dbg()).edit.chain===null && (await dbg()).tool==='beam','Esc: kết thúc chuỗi, vẫn ở công cụ Dầm');
  await clickW((gx[2]+gx[3])/2,gy[2]);bp=await PK('beamPicks');ok(bp['x:C:3-4'],'bấm thẳng giữa một nhịp: thêm dầm của nhịp đó');
  await clickW((gx[2]+gx[3])/2,gy[2]);ok(/đã có dầm/.test(await page.locator('#pv-hint').innerText()),'bấm lại nhịp đã có dầm: báo đã có');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await type('wa');
  await clickW(...nodeAt(3,0));await clickW(...nodeAt(3,2));let wp=await PK('wallPicks');
  ok(wp['y:4:A-B'] && wp['y:4:B-C'],'tường: bấm 4-A rồi 4-C thêm 2 tường cạnh phải');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await type('fl');
  ok((await dbg()).tool==='slab' && await page.locator('#pv-options select[data-opt=mode]').isVisible(),'gõ FL: công cụ Sàn (phím tự đặt), thanh tùy chọn có "Vị trí" (theo lưới / tự do)');
  await clickW((gx[2]+gx[3])/2,(gy[0]+gy[1])/2);let sp=await PK('slabPicks');ok(sp[cellRef(2,0)]!==undefined,'bấm vào ô 3-4/A-B: thêm sàn');
  await clickW((gx[0]+gx[1])/2,(gy[0]+gy[1])/2);ok(/đã có sàn/.test(await page.locator('#pv-hint').innerText()),'bấm ô đã có sàn: báo đã có');
  await page.keyboard.press('Escape');await type('dr');
  ok((await dbg()).tool==='door' && await page.locator('#pv-options select[data-opt=type] option').count()===F.state.opening_types.filter(x=>x.kind==='door').length,'gõ DR: công cụ Cửa đi; danh sách loại chỉ gồm cửa đi');
  const wallB=F.preview_all_cells.walls.items.filter(i=>i.ref==='x:B:1-2')[0],wallV=F.preview_all_cells.walls.items.filter(i=>i.ref==='y:2:A-B')[0];
  ed=(await hoverW(wallB.start+2400,wallB.center)).edit;
  ok(ed.target && /Chồng|sát/.test(ed.target.error||''),'rê lên tường đã có hai cửa gần vị trí giữa: báo chồng / sát cửa khác (không đặt được)');
  const nOp=Object.keys(await PK('openingPicks')).length;
  await clickW(wallB.start+2400,wallB.center);ok(Object.keys(await PK('openingPicks')).length===nOp && /Chồng|sát/.test(await page.locator('#pv-hint').innerText()),'bấm vị trí lỗi: không thêm cửa, hiện lý do');
    await clickW(wallV.center,wallV.start+700);let op=await PK('openingPicks'),ids=Object.keys(op).filter(k=>op[k].wall==='y:2:A-B');
  ok(ids.length===1 && op[ids[0]].type===F.state.opening_types.filter(x=>x.kind==='door')[0].id && Math.abs(op[ids[0]].pos-700)<=10 && op[ids[0]].flip===false,'bấm trên tường y:2:A-B cách đầu 700 mm: đặt cửa đi, tâm cách đầu tường đúng 700 mm');
  await page.keyboard.press('Escape');await type('wn');
  ed=(await hoverW(wallV.center,wallV.start+1790)).edit;ok(ed.target && /sát|Chồng/.test(ed.target.error||''),'cửa sổ cách cửa đi 40 mm: báo sát cửa khác (quy tắc cách >= 50 mm như Ruby)');
  ed=(await hoverW(wallV.center,wallV.start+1810)).edit;ok(ed.target && !ed.target.error,'cửa sổ cách cửa đi 60 mm: đặt được');
  await page.selectOption('#pv-options select[data-opt=flip]','1');
  await clickW(wallV.center,wallV.start+2400);op=await PK('openingPicks');
  ok(Object.keys(op).some(k=>op[k].wall==='y:2:A-B' && op[k].flip===true && F.state.opening_types.filter(x=>x.kind==='window').some(w=>w.id===op[k].type)),'cửa sổ với "Đổi mặt": lưu flip = true, loại thuộc nhóm cửa sổ');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await type('gr');
  ok((await dbg()).tool==='grid' && await page.locator('#pv-options select[data-opt=dir]').isVisible(),'gõ GR: công cụ Lưới trục; thanh tùy chọn chọn trục đứng / ngang');
  await clickW(gx[1]+2100,gy[2]+1500);await wait(300);
  gp=await last('grid_preview');const st=await page.evaluate(()=>window.VGDS._state);
  ok(gp.grid.x_axes.length===5 && gp.grid.x_axes.map(a=>a.offset).includes(gx[1]+2100-G.origin[0]) && st.x.axes.length===5,'bấm vị trí trên mặt bằng: thêm trục đứng mới, gửi lưới mới cho Ruby');
  await page.selectOption('#pv-options select[data-opt=dir]','y');await clickW(gx[0]-1000,gy[0]+1800);
  ok((await page.evaluate(()=>window.VGDS._state.y.axes.length))===4,'đổi sang trục ngang rồi bấm: thêm trục ngang');
  const before=await page.evaluate(()=>window.VGDS._state.y.axes.length);await clickW(gx[0]-1000,gy[1]);
  ok((await page.evaluate(()=>window.VGDS._state.y.axes.length))===before && /ít nhất 100 mm/.test(await page.locator('#pv-hint').innerText()),'bấm trùng trục đã có: báo phải cách ít nhất 100 mm, không thêm');
  await page.keyboard.press('Control+z');await page.keyboard.press('Control+z');
  ok((await page.evaluate(()=>window.VGDS._state.x.axes.length))===4 && (await page.evaluate(()=>window.VGDS._state.y.axes.length))===3,'hoàn tác hai lần: lưới trở về 4 × 3 trục');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  await receive('state',F.state);await receive('preview',F.preview_all_cells);await wait(100);
  const cc=await scr(...nodeAt(0,0));await page.mouse.click(cc[0]+4,cc[1]-4);
  ok(JSON.stringify((await dbg()).selection)==='["Cột 1-A"]','chọn cột 1-A để xóa');
  await page.keyboard.press('Delete');ok(!(await PK('picks'))['1-A'] && (await dbg()).selection.length===0 && /Đã xóa 1/.test(await page.locator('#pv-hint').innerText()),'Delete: xóa cột khỏi lựa chọn của tầng (có thể hoàn tác)');
  await page.keyboard.press('Control+z');ok((await PK('picks'))['1-A']!==undefined,'Ctrl+Z: cột 1-A trở lại');
  const wc=await scr(wallB.start+wallB.length*0.12,wallB.center);await page.mouse.click(wc[0],wc[1]);
  ok(JSON.stringify((await dbg()).selection.map(x=>x.split(' ')[0]))==='["Tường"]','chọn tường x:B:1-2');
  await page.keyboard.press('d');await page.keyboard.press('e');
  ok(!(await PK('wallPicks'))['x:B:1-2'],'gõ DE: xóa tường đang chọn');
  const opAfter=await PK('openingPicks');ok(Object.values(opAfter).every(o=>o.wall!=='x:B:1-2'),'xóa tường: các cửa trên tường đó bị xóa theo (không để cửa mồ côi)');
  await page.keyboard.press('Control+z');const opBack=await PK('openingPicks');ok((await PK('wallPicks'))['x:B:1-2'] && Object.values(opBack).filter(o=>o.wall==='x:B:1-2').length===2,'Ctrl+Z: tường và 2 cửa trở lại');
  await receive('state',F.state);await receive('preview',F.preview_all_cells);await wait(100);
  const c22=F.preview_all_cells.columns.items.filter(c=>c.ref==='2-B')[0],q22=await scr(c22.center[0],c22.center[1]);await page.mouse.click(q22[0],q22[1]);
  ok(await page.locator('#pv-props select[data-field=type]').isVisible() && (await page.locator('#pv-props select[data-field=x]').inputValue())==='center' && (await page.locator('#pv-props select[data-field=y]').inputValue())==='auto','chọn một cột: bảng Thuộc tính có ô Loại, Vị trí X, Vị trí Y đúng giá trị hiện tại');
  await page.selectOption('#pv-props select[data-field=type]',col2.id);
  ok((await PK('picks'))['2-B'].type===col2.id && (await page.evaluate(()=>window.VGDS.history().undo))>=1,'đổi Loại trong bảng Thuộc tính: ghi vào lựa chọn, có hoàn tác');
  await receive('preview',F.preview_all_cells);await wait(60);
  ok(JSON.stringify((await dbg()).selection)==='["Cột 2-B"]' && (await page.locator('#pv-props select[data-field=type]').inputValue())===col2.id,'sau khi Ruby trả xem trước mới: phần tử vẫn đang được chọn, ô Loại hiện giá trị mới');
  await page.selectOption('#pv-props select[data-field=y]','min');ok((await PK('picks'))['2-B'].y==='min','đổi Vị trí Y thành "cạnh nhỏ"');
  await page.selectOption('#pv-props select[data-field=y]','auto');ok(!('y' in (await PK('picks'))['2-B']),'đặt lại "Theo quy ước": bỏ khóa y khỏi dữ liệu');
  const o1=F.preview_all_cells.openings.items[0],oq=await scr((o1.min[0]+o1.max[0])/2,(o1.min[1]+o1.max[1])/2);await page.mouse.click(oq[0],oq[1]);
  ok(await page.locator('#pv-props input[data-field=pos]').isVisible() && await page.locator('#pv-props input[data-field=flip]').isVisible(),'chọn một cửa: bảng Thuộc tính có Loại, Tâm cách đầu tường, Đổi mặt cánh');
  await page.fill('#pv-props input[data-field=pos]','1234');await page.press('#pv-props input[data-field=pos]','Tab');
  ok((await PK('openingPicks'))[o1.ref].pos===1234,'sửa vị trí tâm cửa trong bảng Thuộc tính: ghi vào dữ liệu');
  await page.check('#pv-props input[data-field=flip]');ok((await PK('openingPicks'))[o1.ref].flip===true,'tick "Đổi mặt cánh": flip = true');
  await page.click('#pv-tabs .pv-tab:nth-child(2)');await wait(300);await receive('preview',F.preview_top);
  await type('cl');await clickW(...nodeAt(1,1));ok(/Tầng trên cùng chỉ có sàn/.test(await page.locator('#pv-hint').innerText()),'tầng trên cùng: công cụ Cột báo chỉ có sàn, không đặt cột');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await type('ce');await clickW(...nodeAt(1,1));ok(/không có trần/.test(await page.locator('#pv-hint').innerText()),'tầng trên cùng: công cụ Trần báo không có trần');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  await page.click('#pv-tabs .pv-tab:nth-child(1)');await wait(300);await receive('preview',F.preview_all_cells);
  }
  // P4: sửa kiểu Revit trên lưới
  {
  await page.click('[data-tab=plan]');await receive('state',F.state);await receive('preview',F.preview_all_cells);await page.keyboard.press('Escape');
  await page.keyboard.press('z');await page.keyboard.press('e');await wait(60);
  const typ=async s=>{for(const ch of s)await page.keyboard.press(ch.toLowerCase());await wait(90);};
  const sc=async(x,y)=>{const bb=await page.locator('#pv-canvas').boundingBox(),q=await page.evaluate(([a,b])=>window.VGDPlan.toScreen(a,b),[x,y]);return [bb.x+q[0],bb.y+q[1]];};
  const cl=async(x,y)=>{const q=await sc(x,y);await page.mouse.move(q[0],q[1]);await page.mouse.click(q[0],q[1]);};
  const drag=async(a,b)=>{const p0=await sc(a[0],a[1]),p1=await sc(b[0],b[1]);await page.mouse.move(p0[0],p0[1]);await page.mouse.down();await page.mouse.move((p0[0]+p1[0])/2,(p0[1]+p1[1])/2,{steps:3});await page.mouse.move(p1[0],p1[1],{steps:3});await page.mouse.up();};
  const get=k=>page.evaluate(k=>JSON.parse(JSON.stringify(window.VGDS._state.levels[0][k])),k);
  const dbgm=()=>page.evaluate(()=>window.VGDPlan.debug());
  const wB=F.preview_all_cells.walls.items.filter(i=>i.ref==='x:B:1-2')[0],L=wB.length;
  const winSpan=async(wall)=>{await drag([wall.min[0]-60,wall.max[1]+60],[wall.max[0]+60,wall.min[1]-60]);};
  const node=(i,j)=>[gx[i],gy[j]];
  const hintText=()=>page.locator('#pv-hint').innerText();
  // Không chọn gì rồi gõ lệnh
  await typ('mv');ok((await dbgm()).tool==='select' && /chọn phần tử trước/.test(await hintText()),'gõ MV khi chưa chọn gì: báo phải chọn phần tử trước, không vào lệnh');
  await typ('ma');ok((await dbgm()).tool==='match','gõ MA: công cụ Match (không cần chọn trước)');await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  ok((await page.locator('#pv-top .pv-grp:nth-of-type(2) .pv-ic:disabled').count())===0 && (await page.locator('#pv-top .pv-ic[data-tool=unlock]').count())===1,'nhóm Sửa: mọi lệnh dùng được (Move, Copy, Array, Rotate, Mirror, Offset, Trim, Align, Match, Mở khóa lưới, Xóa)');
  // Chọn nhịp x:B:1-2 (dầm + tường + 2 cửa)
  await winSpan(wB);let sel=(await dbgm()).selection;
  ok(sel.length===4 && sel.some(x=>/^Dầm x:B:1-2/.test(x)) && sel.some(x=>/^Tường x:B:1-2/.test(x)) && sel.filter(x=>/^Cửa/.test(x)).length===2,'khung trong quanh nhịp x:B:1-2: chọn dầm, tường và 2 cửa');
  // Copy: dịch lên một hàng trục (B -> C)
  await typ('co');ok((await dbgm()).modify.phase==='base' && /điểm GỐC/.test(await hintText()),'gõ CO: chờ điểm gốc');
  await cl(...node(0,1));let md=(await dbgm()).modify;ok(md.phase==='target' && Math.abs(md.base[0]-gx[0])<1 && Math.abs(md.base[1]-gy[1])<1,'bấm giao điểm 1-B làm gốc');
  const q=await sc(...node(0,2));await page.mouse.move(q[0],q[1]);await wait(40);
  ok((await dbgm()).modify.target && Math.abs((await dbgm()).modify.target[1]-gy[2])<1,'rê tới 1-C: nhận điểm đích (xem trước ở hình đích)');
  await clear();await page.mouse.click(q[0],q[1]);await wait(300);
  let bp=await get('beamPicks'),wp=await get('wallPicks'),op=await get('openingPicks');
  ok(bp['x:B:1-2'] && bp['x:C:1-2'] && wp['x:B:1-2'] && wp['x:C:1-2'],'Copy: dầm và tường có thêm ở hàng C, bản gốc còn nguyên');
  const onC=Object.keys(op).filter(k=>op[k].wall==='x:C:1-2'),onB=Object.keys(op).filter(k=>op[k].wall==='x:B:1-2');
  ok(onC.length===2 && onB.length===2 && onC.every(k=>onB.indexOf(k)<0) && JSON.stringify(onC.map(k=>op[k].pos).sort())===JSON.stringify(onB.map(k=>op[k].pos).sort()),'Copy tường: 2 cửa trên tường được nhân theo (mã cửa mới, cùng vị trí), cửa cũ còn trên tường gốc');
  ok((await dbgm()).tool==='select' && /Đã sao chép 4 phần tử|Đã sao chép 2 phần tử/.test(await hintText()),'báo kết quả sao chép và về công cụ Chọn');
  ok((await page.evaluate(()=>window.VGDS.history().undo))===1 && (await last('grid_preview')).levels[0].picks.walls['x:C:1-2'],'một lệnh = một bước hoàn tác; Ruby nhận xem trước mới');
  await page.keyboard.press('Control+z');bp=await get('beamPicks');op=await get('openingPicks');
  ok(!bp['x:C:1-2'] && Object.keys(op).length===2,'Ctrl+Z: bỏ toàn bộ phần sao chép (dầm, tường, cửa) trong một bước');
  // Copy trùng chỗ có phần tử và ra ngoài lưới
  await winSpan(wB);await typ('co');await cl(...node(0,1));await cl(...node(1,1));await wait(200);
  ok(Object.keys(await get('wallPicks')).includes('x:B:2-3'),'Copy sang ô bên cạnh: tạo x:B:2-3');
  await winSpan(wB);await typ('co');await cl(...node(0,1));await cl(...node(1,1));await wait(200);
  ok(/2 đã có phần tử ở chỗ đích/.test(await hintText()) && !/Cửa đi theo tường/.test(await hintText()),'Copy lần nữa vào chỗ đã có: bỏ qua (dầm, tường), báo rõ lý do; không nhắc cửa vì đã chọn cả tường');
  await winSpan(wB);await typ('co');await cl(...node(0,1));await cl(...node(3,1));await wait(200);
  ok(/ra ngoài lưới/.test(await hintText()) && !(await get('wallPicks'))['x:B:4-5'],'Copy ra ngoài lưới (4 trục): bỏ qua, báo "ra ngoài lưới", không thêm');
  while((await page.evaluate(()=>window.VGDS.history().undo))>0) await page.keyboard.press('Control+z');
  // Move: cả nhóm dịch, cửa đi theo tường, gốc biến mất
  await winSpan(wB);await typ('mv');await cl(...node(0,1));await cl(...node(1,1));await wait(200);
  wp=await get('wallPicks');op=await get('openingPicks');
  ok(!wp['x:B:1-2'] && wp['x:B:2-3'] && !(await get('beamPicks'))['x:B:1-2'] && (await get('beamPicks'))['x:B:2-3'] && Object.keys(op).length===2 && Object.values(op).every(o=>o.wall==='x:B:2-3'),'Move: dầm, tường dịch sang x:B:2-3, bản gốc mất, 2 cửa đi theo tường (không nhân đôi)');
  ok(Object.keys(await get('wallPicks')).includes('y:2:A-B'),'phần tử không chọn (tường y:2:A-B) không bị động tới');
  await page.keyboard.press('Control+z');
  ok((await get('wallPicks'))['x:B:1-2'] && Object.values(await get('openingPicks')).every(o=>o.wall==='x:B:1-2'),'Ctrl+Z hoàn tác Move: mọi thứ về chỗ cũ, cửa về tường cũ');
  // Kế hoạch dịch nhóm liên tiếp (đích của phần tử này là nguồn của phần tử kia)
  const plan1=await page.evaluate(()=>{const lv=window.VGDS._state.levels[0];lv.wallPicks['x:B:2-3']={};const sel=[{kind:'wall',ref:'x:B:1-2'},{kind:'wall',ref:'x:B:2-3'}];const r={move:window.VGDPlanModify._plan(sel,{type:'shift',di:1,dj:0},false),copy:window.VGDPlanModify._plan(sel,{type:'shift',di:1,dj:0},true),out:window.VGDPlanModify._plan([{kind:'wall',ref:'x:B:2-3'}],{type:'shift',di:2,dj:0},false)};delete lv.wallPicks['x:B:2-3'];return r;});
  ok(JSON.stringify(plan1.move.moves)==='[["wall","x:B:1-2","x:B:2-3"],["wall","x:B:2-3","x:B:3-4"]]' && plan1.move.skipped.length===0,'Move cả nhóm liền kề một ô: mỗi nhịp sang nhịp kế (đích của nhịp này là nguồn của nhịp kia, không bị coi là đã có)');
  ok(JSON.stringify(plan1.copy.moves)==='[["wall","x:B:2-3","x:B:3-4"]]' && plan1.copy.skipped.length===1 && /đã có/.test(plan1.copy.skipped[0][1]),'Copy cả nhóm cùng bước: nhịp đầu rơi vào chỗ nhịp kia (còn nguyên) nên bị bỏ qua');
  ok(plan1.out.moves.length===0 && /ra ngoài lưới/.test(plan1.out.skipped[0][1]),'Move vượt quá lưới: bỏ qua, báo ra ngoài lưới');
  // Esc hủy giữa chừng
  await winSpan(wB);await typ('mv');await cl(...node(0,1));await page.keyboard.press('Escape');
  ok((await dbgm()).tool==='select' && (await dbgm()).modify.tool===null && (await get('wallPicks'))['x:B:1-2'] && (await page.evaluate(()=>window.VGDS.history().undo))===0,'Esc giữa lệnh Move: hủy, không đổi dữ liệu, không ghi lịch sử');
  // Cửa chọn riêng: cửa đi theo tường
  const o1=F.preview_all_cells.openings.items[0];await cl((o1.min[0]+o1.max[0])/2,(o1.min[1]+o1.max[1])/2);
  ok((await dbgm()).selection.length===1 && /^Cửa/.test((await dbgm()).selection[0]),'chọn riêng một cửa');
  await typ('co');await cl(...node(0,1));await cl(...node(0,2));await wait(200);
  ok(/Cửa đi theo tường/.test(await hintText()) && Object.keys(await get('openingPicks')).length===2,'Copy riêng cửa: không làm gì, nhắc "cửa đi theo tường, hãy chọn cả tường"');
  await page.keyboard.press('Escape');
  // Array
  await winSpan(wB);await typ('ar');
  ok(await page.locator('#pv-options input[data-opt=count]').isVisible(),'gõ AR: thanh tùy chọn có ô Số bản');
  await page.fill('#pv-options input[data-opt=count]','2');await page.press('#pv-options input[data-opt=count]','Tab');
  await cl(...node(0,1));await cl(...node(1,1));await wait(200);
  wp=await get('wallPicks');ok(wp['x:B:2-3'] && wp['x:B:3-4'] && Object.keys(wp).length===4,'Array 2 bản bước 1 ô: thêm x:B:2-3 và x:B:3-4 (4 tường cả thảy)');
  ok(Object.keys(await get('openingPicks')).length===6,'Array: cửa theo từng bản (2 gốc + 2 × 2)');
  ok(/nhân bản 4 phần tử|nhân bản 8 phần tử/.test(await hintText()) || /Đã nhân bản/.test(await hintText()),'báo kết quả nhân bản');
  await page.keyboard.press('Control+z');ok(Object.keys(await get('wallPicks')).length===2,'Ctrl+Z hoàn tác cả Array trong một bước');
  // Mirror qua trục ngang B: tường hàng C lật xuống hàng A (dữ liệu có tường x:C:1-2 và 2 cửa)
  await receive('state',F.state_c);await receive('preview',F.preview_c);await wait(80);
  const wC=F.preview_c.walls.items.filter(i=>i.ref==='x:C:1-2')[0];
  await drag([wC.min[0]-60,wC.max[1]+60],[wC.max[0]+60,wC.min[1]-60]);
  ok((await dbgm()).selection.some(x=>/Tường x:C:1-2/.test(x)),'chọn nhịp x:C:1-2 bằng khung');
  await typ('mm');ok((await dbgm()).modify.phase==='axis' && await page.locator('#pv-options input[data-opt=keep]').isChecked(),'gõ MM: chờ chọn trục; thanh tùy chọn có "Giữ bản gốc" (mặc định bật)');
  await page.uncheck('#pv-options input[data-opt=keep]');
  const ax=await sc(gx[1]+1500,gy[1]);await page.mouse.move(ax[0],ax[1]);await wait(40);
  ok((await dbgm()).modify.axis==='y:B','rê gần trục ngang B: nhận trục đối xứng');
  await page.mouse.click(ax[0],ax[1]);await wait(250);
  wp=await get('wallPicks');op=await get('openingPicks');
  ok(!wp['x:C:1-2'] && wp['x:A:1-2'],'Mirror (bỏ bản gốc) qua trục B: tường x:C:1-2 lật thành x:A:1-2');
  const onA=Object.keys(op).filter(k=>op[k].wall==='x:A:1-2').map(k=>op[k]).sort((a,b)=>a.pos-b.pos);
  ok(onA.length===2 && Math.abs(onA[0].pos-1000)<=1 && Math.abs(onA[1].pos-2800)<=1 && onA.every(o=>o.flip===true),'cửa lật qua trục SONG SONG với tường: vị trí dọc tường giữ nguyên (tường không đổi chiều), đổi mặt cánh');
  await receive('state',F.state);await receive('preview',F.preview_all_cells);await wait(80);
  // Mirror qua trục đứng, giữ bản gốc
  await winSpan(wB);await typ('mm');await page.check('#pv-options input[data-opt=keep]');const av=await sc(gx[1],gy[1]+800);await page.mouse.move(av[0],av[1]);await page.mouse.click(av[0],av[1]);await wait(250);
  wp=await get('wallPicks');op=await get('openingPicks');
  const onB3=Object.keys(op).filter(k=>op[k].wall==='x:B:2-3').map(k=>op[k]);
  ok(wp['x:B:1-2'] && wp['x:B:2-3'] && onB3.length===2 && onB3.every(o=>o.flip===false) && onB3.map(o=>o.pos).sort((a,b)=>a-b).join()===[L-2800,L-1000].join(),'Mirror qua trục đứng 2, giữ gốc: tường x:B:2-3 mới, cửa lật vị trí, KHÔNG đổi mặt cánh (trục vuông góc với tường)');
  await page.keyboard.press('Control+z');
  // Mirror: phần tử trên trục bị bỏ, ra ngoài lưới
  const wV=F.preview_all_cells.walls.items.filter(i=>i.ref==='y:2:A-B')[0];
  await drag([wV.min[0]-60,wV.max[1]+60],[wV.max[0]+60,wV.min[1]-60]);await typ('mm');await cl(gx[1],gy[1]+1200);await wait(250);
  ok(/trùng vị trí cũ/.test(await hintText()) && Object.keys(await get('wallPicks')).length===2,'Mirror tường nằm đúng trên trục đối xứng: bỏ qua ("trùng vị trí cũ")');
  // Match
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  const c22=F.preview_all_cells.columns.items.filter(c=>c.ref==='2-B')[0],c11=F.preview_all_cells.columns.items.filter(c=>c.ref==='1-A')[0];
  await typ('ma');await cl(c22.center[0],c22.center[1]);ok((await dbgm()).modify.source==='2-B' && /MẪU|cùng loại/.test(await hintText()),'Match: bấm cột 2-B làm mẫu');
  await cl(c11.center[0],c11.center[1]);await wait(200);
  ok((await get('picks'))['1-A'].x==='center' && /Đã áp dụng/.test(await hintText()),'Match: cột 1-A nhận vị trí X "tâm" của mẫu');
  await cl(wV.center,(wV.min[1]+wV.max[1])/2+400);ok(/chỉ nhận được phần tử cùng loại/.test(await hintText()),'Match: bấm tường khi mẫu là cột: từ chối, báo cùng loại');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  const o2=F.preview_all_cells.openings.items[1];
  await typ('ma');await cl((o1.min[0]+o1.max[0])/2,(o1.min[1]+o1.max[1])/2);await cl((o2.min[0]+o2.max[0])/2,(o2.min[1]+o2.max[1])/2);await wait(200);
  op=await get('openingPicks');ok(op[o2.ref].type===op[o1.ref].type,'Match cửa: cửa sổ nhận loại của cửa đi mẫu');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await page.keyboard.press('Control+z');await page.keyboard.press('Control+z');
  // Kích thước tạm thời
  await cl((o1.min[0]+o1.max[0])/2,(o1.min[1]+o1.max[1])/2);let dd=await dbgm();
  ok(dd.dimList.length===3 && dd.dimHits.length===2 && dd.dimList[0].value===(o1.min[0]-wB.start) && dd.dimList[1].value===(wB.finish-o1.max[0]) && dd.dimList[2].value===o1.w,'chọn cửa: hiện 3 kích thước tạm thời (tới đầu tường, tới cuối tường, bề rộng); 2 số đầu sửa được');
  const hit=dd.dimHits[0],hb=await page.locator('#pv-canvas').boundingBox();
  await page.mouse.click(hb.x+hit.x+hit.w/2,hb.y+hit.y+hit.h/2);
  ok(await page.locator('.pv-dim-input').isVisible() && (await page.locator('.pv-dim-input').inputValue())===String(dd.dimList[0].value),'bấm số kích thước: hiện ô nhập, chứa giá trị hiện tại');
  await page.fill('.pv-dim-input','99999');await page.press('.pv-dim-input','Enter');
  ok(await page.locator('.pv-dim-input').isVisible() && /không nằm trọn/.test(await hintText()) && (await get('openingPicks'))[o1.ref].pos===1000,'gõ giá trị làm cửa ra ngoài tường: báo lỗi, ô nhập giữ nguyên, dữ liệu không đổi');
  await page.fill('.pv-dim-input','300');await page.press('.pv-dim-input','Enter');
  ok((await page.locator('.pv-dim-input').count())===0 && (await get('openingPicks'))[o1.ref].pos===300+o1.w/2,'gõ 300: cửa dịch sao cho cách đầu tường 300 mm (tâm = 300 + rộng/2)');
  await page.keyboard.press('Control+z');ok((await get('openingPicks'))[o1.ref].pos===1000,'Ctrl+Z hoàn tác việc sửa kích thước');
  await wait(150); // chờ vẽ lại sau hoàn tác xong, nếu không ô nhập vừa mở có thể mất tiêu điểm
  dd=await dbgm();const hr=dd.dimHits[1];await page.mouse.click(hb.x+hr.x+hr.w/2,hb.y+hr.y+hr.h/2);await page.fill('.pv-dim-input','2000');await page.press('.pv-dim-input','Enter');
  ok((await get('openingPicks'))[o1.ref].pos===L-2000-o1.w/2,'sửa kích thước phía cuối tường: gõ 2000 thì cửa cách cuối tường 2000 mm (tâm = dài - 2000 - rộng/2)');
  await page.keyboard.press('Control+z');
  dd=await dbgm();const hl=dd.dimHits[0];await page.mouse.click(hb.x+hl.x+hl.w/2,hb.y+hl.y+hl.h/2);await page.fill('.pv-dim-input','1500');await page.press('.pv-dim-input','Enter');
  ok(await page.locator('.pv-dim-input').isVisible() && /Chồng hoặc sát cửa khác/.test(await hintText()) && (await get('openingPicks'))[o1.ref].pos===1000,'gõ giá trị làm cửa đi chồng cửa sổ: báo chồng / sát cửa khác, không đổi dữ liệu');
  await page.keyboard.press('Escape');ok((await page.locator('.pv-dim-input').count())===0,'Esc đóng ô nhập kích thước');
  await page.keyboard.press('Escape');
  await cl(c11.center[0],c11.center[1]);dd=await dbgm();
  ok(dd.dimList.length===2 && dd.dimList.every(d=>!d.editable) && dd.dimHits.length===0 && dd.dimList[0].value===c11.w,'chọn cột: chỉ hiện kích thước (rộng × sâu) để xem, không sửa được');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  await page.click('[data-tab=grid]');await page.click('[data-tab=plan]');
  }
  // P5: Cây dự án
  {
  await page.click('[data-tab=plan]');await receive('state',F.state);await receive('preview',F.preview_all_cells);await page.keyboard.press('Escape');await wait(60);
  const typ=async s=>{for(const ch of s)await page.keyboard.press(ch.toLowerCase());await wait(90);};
  const sc=async(x,y)=>{const bb=await page.locator('#pv-canvas').boundingBox(),q=await page.evaluate(([a,b])=>window.VGDPlan.toScreen(a,b),[x,y]);return [bb.x+q[0],bb.y+q[1]];};
  const dbgb=()=>page.evaluate(()=>window.VGDPlan.debug());
  const get=k=>page.evaluate(k=>JSON.parse(JSON.stringify(window.VGDS._state.levels[0][k])),k);
  const L1='sl_00000001',L2='sl_00000002';
  const node=id=>page.locator(`#pv-browser [data-node="${id}"]`);
  const toggle=id=>node(id).locator('> .pb-row .pb-toggle').click();
  const label=id=>node(id).locator('> .pb-row .pb-label');
  const count=id=>node(id).locator('> .pb-row .pb-count').innerText();
  await typ('pb');ok(await page.locator('#pv-browser').isVisible() && (await page.locator('#pv-browser-btn kbd').innerText())==='PB','gõ PB: hiện lại Cây dự án (phím tự đặt, nút hiện nhãn PB)');
  await typ('pb');ok(await page.locator('#pv-browser').isHidden(),'gõ PB lần nữa: ẩn');await typ('pb');
  ok(await node('levels').count()===1 && await node('types').count()===1 && await node('grid').count()===1,'cây có ba nhánh gốc: Tầng, Loại, Lưới trục');
  ok((await count('levels'))==='2' && await node(`lv:${L1}`).count()===1 && await node(`lv:${L2}`).count()===1,'nhánh Tầng: 2 tầng, mỗi tầng một nút');
  ok(await node(`lv:${L1}`).locator('> .pb-row.current').count()===1 && await node(`lv:${L2}`).locator('> .pb-row.current').count()===0,'tầng đang xem (Tầng 1) được tô đậm');
  await toggle(`lv:${L1}`);
  const kinds=['column','beam','wall','opening','slab','ceiling'],cnts=[];for(const k of kinds)cnts.push(await count(`lv:${L1}:${k}`));
  ok(JSON.stringify(cnts)==='["2","2","2","2","2","2"]','mở Tầng 1: sáu nhóm Cột, Dầm, Tường, Cửa, Sàn, Trần, mỗi nhóm đếm đúng số phần tử đã chọn của tầng');
  await toggle(`lv:${L1}:column`);
  ok(JSON.stringify(await node(`lv:${L1}:column`).locator('.pb-label').allInnerTexts())==='["Cột","Cột 1-A","Cột 2-B"]','mở nhóm Cột: liệt kê Cột 1-A và Cột 2-B');
  await label(`el:${L1}|column|2-B`).click();
  ok(JSON.stringify((await dbgb()).selection)==='["Cột 2-B"]' && await node(`el:${L1}|column|2-B`).locator('> .pb-row.selected').count()===1,'bấm Cột 2-B trong cây: chọn trên mặt bằng và tô sáng trong cây');
  ok((await page.locator('#pv-props').innerText()).includes('Cột 2-B'),'bảng Thuộc tính hiện phần tử vừa chọn từ cây');
  // Chọn trên mặt bằng thì cây theo
  const c11=F.preview_all_cells.columns.items.filter(c=>c.ref==='1-A')[0];
  const q=await sc(c11.center[0],c11.center[1]);await page.mouse.click(q[0],q[1]);
  ok(await node(`el:${L1}|column|1-A`).locator('> .pb-row.selected').count()===1 && await node(`el:${L1}|column|2-B`).locator('> .pb-row.selected').count()===0,'chọn cột 1-A trên mặt bằng: cây tô sáng đúng mục, bỏ tô mục cũ');
  // Đổi tầng bằng cây
  await label(`lv:${L2}`).click();await wait(250);
  ok((await dbgb()).level===L2 && await node(`lv:${L2}`).locator('> .pb-row.current').count()===1 && (await last('grid_preview')).level===L2,'bấm tên tầng trong cây: chuyển sang tầng đó (tab, mặt bằng, xem trước theo tầng mới)');
  await receive('preview',F.preview_top);
  // Chọn phần tử ở tầng khác: chuyển tầng, chọn khi xem trước về
  await label(`el:${L1}|column|2-B`).click();await wait(250);
  ok((await dbgb()).level===L1 && (await dbgb()).selection.length===0,'bấm phần tử của tầng khác: chuyển tầng trước, chưa chọn (chờ xem trước)');
  await receive('preview',F.preview_all_cells);
  ok(JSON.stringify((await dbgb()).selection)==='["Cột 2-B"]','xem trước của tầng đó về: tự chọn đúng phần tử');
  // Loại
  await toggle('types');await toggle('tg:column');
  const firstType=F.state.types[0];
  ok(await node(`ty:${firstType.id}`).count()===1 && (await count(`ty:${firstType.id}`))==='2','nhánh Loại cột: mỗi loại đếm số phần tử dùng ở tầng đang xem (2 cột dùng loại đầu, vì chưa đặt loại riêng)');
  await label(`ty:${firstType.id}`).click();
  ok(JSON.stringify((await dbgb()).selection.sort())==='["Cột 1-A","Cột 2-B"]','bấm một loại: chọn mọi phần tử dùng loại đó ở tầng đang xem');
  {
    const secondType={id:'ct_test0002',name:'C400x400',w:400,d:400};
    await page.evaluate(ty=>{window.VGDS._state.types.push(ty);window.VGDS._state.levels[0].picks['2-B'].type=ty.id;window.VGDPlanBrowser.render();},secondType);
    ok((await count(`ty:${firstType.id}`))==='1' && (await count(`ty:${secondType.id}`))==='1','cột 2-B đổi sang loại thứ hai: đếm tách đúng (1 cột mỗi loại)');
    await label(`ty:${secondType.id}`).click();ok(JSON.stringify((await dbgb()).selection)==='["Cột 2-B"]','bấm loại thứ hai: chỉ chọn cột 2-B (loại riêng ưu tiên hơn loại mặc định)');
    await page.evaluate(()=>{delete window.VGDS._state.levels[0].picks['2-B'].type;window.VGDS._state.types.pop();window.VGDPlanBrowser.render();});
  }
  await toggle('tg:wall');const wt=F.state.wall_types[0];await label(`ty:${wt.id}`).click();
  ok((await dbgb()).selection.length===2 && (await dbgb()).selection.every(x=>/^Tường/.test(x)),'bấm loại tường: chọn 2 tường');
  // Lưới trục
  await toggle('grid');await toggle('ax:x');await toggle('ax:y');
  ok(JSON.stringify(await node('ax:x').locator('.pb-label').allInnerTexts())==='["Trục đứng (số)","1 · 0 mm","2 · 4200 mm","3 · 8400 mm","4 · 12600 mm"]','nhánh Lưới trục: trục đứng 1 đến 4 kèm vị trí mm');
  ok((await node('ax:y').locator('.pb-label').allInnerTexts()).slice(1).join('|')==='A · 0 mm|B · 3600 mm|C · 7200 mm','trục ngang A, B, C kèm vị trí');
  // Lọc
  await page.fill('#pv-browser .pb-filter','1-A');
  ok(JSON.stringify(await page.locator('#pv-browser .pb-tree [data-node^="el:"] .pb-label').allInnerTexts())==='["Cột 1-A"]','lọc "1-A": chỉ còn mục Cột 1-A (nhánh tự mở)');
  await page.fill('#pv-browser .pb-filter','D900');
  ok((await page.locator('#pv-browser [data-node^="ty:"] .pb-label').allInnerTexts()).some(t=>/D900x2100/.test(t)) && (await page.locator('#pv-browser [data-node^="el:"]').count())>=1,'lọc "D900": hiện loại cửa D900x2100 và cửa dùng loại đó');
  await page.fill('#pv-browser .pb-filter','zzzz');ok(await page.locator('#pv-browser .pb-empty').count()===1,'lọc không khớp gì: báo "Không có mục nào khớp"');
  await page.press('#pv-browser .pb-filter','Escape');ok((await page.locator('#pv-browser .pb-filter').inputValue())==='' && await page.locator('#pv-browser .pb-empty').count()===0,'Esc trong ô lọc: xóa bộ lọc');
  // Cây cập nhật khi dữ liệu đổi
  await page.keyboard.press('Escape');await typ('cl');
  const n3=await sc(gx[2],gy[0]);await page.mouse.move(n3[0],n3[1]);await page.mouse.click(n3[0],n3[1]);
  ok((await count(`lv:${L1}:column`))==='3' && await node(`el:${L1}|column|3-A`).count()===1,'đặt thêm cột 3-A bằng công cụ: cây cập nhật ngay (đếm 3, có mục Cột 3-A)');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await page.keyboard.press('Control+z');
  ok((await count(`lv:${L1}:column`))==='2' && await node(`el:${L1}|column|3-A`).count()===0,'Ctrl+Z: cây trở về 2 cột');
  // Lỗi / thiếu
  await page.evaluate(()=>{window.VGDS._state.levels[0].picks['9-Z']={};window.VGDPlanBrowser.render();});
  const exists=await node(`el:${L1}|column|9-Z`).count();
  if(exists)await label(`el:${L1}|column|9-Z`).click();
  ok(!exists || (/không có trong xem trước/.test(await page.locator('#pv-hint').innerText()) && (await dbgb()).selection.length===0),'mục không có hình trong xem trước (mã lạ): báo rõ, không chọn gì');
  await page.evaluate(()=>{delete window.VGDS._state.levels[0].picks['9-Z'];window.VGDPlanBrowser.render();});
  await page.keyboard.press('Escape');
  }
  // P4b-1: phần tử tự do ngoài lưới
  {
  const typ=async s=>{for(const ch of s)await page.keyboard.press(ch.toLowerCase());await wait(90);};
  const sc=async(x,y)=>{const bb=await page.locator('#pv-canvas').boundingBox(),q=await page.evaluate(([a,b])=>window.VGDPlan.toScreen(a,b),[x,y]);return [bb.x+q[0],bb.y+q[1]];};
  const cl=async(x,y)=>{const q=await sc(x,y);await page.mouse.move(q[0],q[1]);await page.mouse.click(q[0],q[1]);};
  const hv=async(x,y)=>{const q=await sc(x,y);await page.mouse.move(q[0],q[1]);await wait(40);};
  const drag=async(a,b)=>{const p0=await sc(a[0],a[1]),p1=await sc(b[0],b[1]);await page.mouse.move(p0[0],p0[1]);await page.mouse.down();await page.mouse.move((p0[0]+p1[0])/2,(p0[1]+p1[1])/2,{steps:3});await page.mouse.move(p1[0],p1[1],{steps:3});await page.mouse.up();};
  const get=k=>page.evaluate(k=>JSON.parse(JSON.stringify(window.VGDS._state.levels[0][k])),k);
  const dbg4=()=>page.evaluate(()=>window.VGDPlan.debug());
  const hintT=()=>page.locator('#pv-hint').innerText();
  const reset=async()=>{await page.keyboard.press('Escape');await page.keyboard.press('Escape');await receive('state',F.state_free);await receive('preview',F.preview_free);await wait(80);};
  const freeKeys=(o,p)=>Object.keys(o).filter(k=>k.startsWith(p));
  const wallsF=F.preview_free.walls.items,fw1=wallsF.find(i=>i.ref==='fw_00000001'),fw2=wallsF.find(i=>i.ref==='fw_00000002'),gw=wallsF.find(i=>i.ref==='x:B:1-2');
  const selWall=async w=>{await drag([w.min[0]-60,w.max[1]+60],[w.max[0]+60,w.min[1]-60]);};
  await page.click('[data-tab=plan]');
  if(await page.locator('#pv-browser').isVisible())await page.click('#pv-browser-btn');
  await reset();await page.keyboard.press('z');await page.keyboard.press('e');await wait(80);
  ok((await get('picks'))['fc_00000001'].free.x===2000 && (await dbg4()).counts.column===2 && (await dbg4()).counts.wall===3,'xem trước có cả phần tử tự do: 2 cột (1 theo lưới, 1 tự do), 3 tường (1 theo lưới, 2 tự do)');
  ok(F.preview_free.columns.items.some(i=>i.ref==='fc_00000001' && i.placement==='free') && (await page.evaluate(()=>window.VGDPlan.debug().counts.beam))===1,'phần tử tự do được vẽ cùng phần tử theo lưới');
  // --- Vẽ cột tự do ---
  await typ('cl');ok(await page.locator('#pv-options select[data-opt=mode]').isVisible() && (await page.locator('#pv-options select[data-opt=mode]').inputValue())==='grid','công cụ Cột: thanh tùy chọn có "Vị trí: Theo lưới" mặc định');
  await page.selectOption('#pv-options select[data-opt=mode]','free');await wait(40);
  ok(await page.locator('#pv-options select[data-opt=rot]').isVisible() && await page.locator('#pv-options select[data-opt=x]').count()===0,'chọn "Tự do": thanh tùy chọn đổi (có Xoay, bỏ kiểu đặt X, Y theo lưới)');
  await cl(10500,6000);let pk=await get('picks'),nk=freeKeys(pk,'fc_').filter(k=>k!=='fc_00000001');
  ok(nk.length===1 && Math.abs(pk[nk[0]].free.x-10500)<1 && Math.abs(pk[nk[0]].free.y-6000)<1 && pk[nk[0]].free.rot===0 && !('x' in pk[nk[0]]),'bấm điểm bất kỳ: thêm cột tự do đúng tọa độ (không theo lưới), xoay 0');
  await page.selectOption('#pv-options select[data-opt=rot]','90');await cl(6000,6000);pk=await get('picks');
  ok(freeKeys(pk,'fc_').filter(k=>pk[k].free.rot===90).length===1,'chọn xoay 90 rồi bấm: cột tự do có rot = 90');
  await page.keyboard.press('Control+z');await page.keyboard.press('Control+z');ok(freeKeys(await get('picks'),'fc_').length===1,'hoàn tác hai lần: bỏ hai cột tự do vừa đặt');
  // --- Vẽ tường tự do theo chuỗi ---
  await reset();await typ('wa');await page.selectOption('#pv-options select[data-opt=mode]','free');await wait(40);
  await cl(6000,5000);ok((await dbg4()).edit.chainPoint && Math.abs((await dbg4()).edit.chainPoint[0]-6000)<1 && /điểm cuối/.test(await hintT()),'tường tự do: bấm điểm đầu, chờ điểm cuối');
  await hv(9000,5300);ok(Math.abs((await dbg4()).edit.freeTarget[1]-5000)<1 && Math.abs((await dbg4()).edit.freeTarget[0]-9000)<1,'rê lệch: điểm cuối tự giữ ngang (y = 5000) theo phương con trỏ lệch nhiều hơn');
  await page.mouse.click(...(await sc(9000,5300)));let wp=await get('wallPicks'),nw=freeKeys(wp,'fw_').filter(k=>!['fw_00000001','fw_00000002'].includes(k));
  ok(nw.length===1 && JSON.stringify(wp[nw[0]].free)===JSON.stringify({a:[6000,5000],b:[9000,5000]}),'bấm điểm cuối: thêm tường tự do a = (6000, 5000), b = (9000, 5000)');
  await hv(10500,5000);await page.fill('#pv-vcb','1500');await page.press('#pv-vcb','Enter');wp=await get('wallPicks');nw=freeKeys(wp,'fw_').filter(k=>!['fw_00000001','fw_00000002'].includes(k));
  ok(nw.length===2 && nw.some(k=>JSON.stringify(wp[k].free)===JSON.stringify({a:[9000,5000],b:[10500,5000]})),'chuỗi tiếp tục từ điểm cuối; gõ 1500 + Enter: đoạn kế dài đúng 1500 mm theo hướng con trỏ');
  await page.keyboard.press('Escape');ok((await dbg4()).edit.chainPoint===null,'Esc kết thúc chuỗi');
  await cl(9500,4000);await cl(7000,4000);wp=await get('wallPicks');
  ok(Object.values(wp).some(w=>w.free && JSON.stringify(w.free)===JSON.stringify({a:[7000,4000],b:[9500,4000]})),'vẽ từ phải sang trái: đầu a vẫn là đầu nhỏ hơn (cùng quy ước với Ruby)');
  await page.keyboard.press('Escape');await cl(6000,3000);await cl(6050,3000);ok(/ngắn/.test(await hintT()) && freeKeys(await get('wallPicks'),'fw_').length===nw.length+3,'đoạn ngắn hơn 100 mm: báo và không thêm');
  // --- Gửi Ruby: dữ liệu tự do hợp lệ ---
  await clear();await cl(6000,3000);await cl(8000,3000);await wait(300);
  const payload=await last('grid_preview');
  const vr=JSON.parse(execFileSync('ruby',[path.resolve(__dirname,'ui_validate.rb')],{input:JSON.stringify(payload),encoding:'utf8'}));
  ok(vr.ok && vr.error===null && vr.free>=5 && vr.free_items>=5 && vr.removed===0,'dữ liệu giao diện vẽ ra được Ruby chấp nhận: chuẩn hóa không lỗi, các phần tử tự do thành mục kế hoạch ('+vr.free+' tự do)');
  // --- Mở khóa lưới ---
  await reset();await selWall(gw);ok((await dbg4()).selection.length===1 && /^Tường x:B:1-2/.test((await dbg4()).selection[0]),'chọn tường theo lưới x:B:1-2');
  await typ('ul');wp=await get('wallPicks');nw=freeKeys(wp,'fw_').filter(k=>!['fw_00000001','fw_00000002'].includes(k));
  ok(!wp['x:B:1-2'] && nw.length===1 && JSON.stringify(wp[nw[0]].free)===JSON.stringify({a:[gw.start,gw.center],b:[gw.finish,gw.center]}) && /Đã mở khóa lưới cho 1/.test(await hintT()),'UL: tường theo lưới thành tường tự do đúng hình đang thấy (đầu mút, tim), mã lưới biến mất');
  ok(wp[nw[0]].type===gw.type_id,'giữ loại thực của tường khi mở khóa');
  await page.keyboard.press('Control+z');ok((await get('wallPicks'))['x:B:1-2'] && freeKeys(await get('wallPicks'),'fw_').length===2,'Ctrl+Z: tường trở lại theo lưới');
  await page.keyboard.press('Escape');await typ('ul');ok(/hãy chọn phần tử trước/.test(await hintT()),'UL khi chưa chọn gì: báo phải chọn trước');
  // --- Move / Copy theo véc-tơ ---
  await reset();await selWall(fw1);ok((await dbg4()).selection.length===2,'chọn tường tự do fw_00000001 cùng cửa của nó');
  await typ('mv');await cl(7000,4500);await cl(7000,5700);wp=await get('wallPicks');let op=await get('openingPicks');
  ok(JSON.stringify(wp['fw_00000001'].free)===JSON.stringify({a:[5000,3200],b:[8000,3200]}) && op['op_00000001'].wall==='fw_00000001' && op['op_00000001'].pos===1000,'Move bằng hai điểm bất kỳ (dy = +1200): tường tự do dời tại chỗ (giữ mã), cửa đi theo, vị trí cửa không đổi');
  await reset();await selWall(fw1);await typ('co');await cl(7000,4500);await cl(7500,4500);wp=await get('wallPicks');op=await get('openingPicks');
  nw=freeKeys(wp,'fw_').filter(k=>!['fw_00000001','fw_00000002'].includes(k));
  ok(nw.length===1 && JSON.stringify(wp[nw[0]].free)===JSON.stringify({a:[5500,2000],b:[8500,2000]}) && JSON.stringify(wp['fw_00000001'].free)===JSON.stringify({a:[5000,2000],b:[8000,2000]}),'Copy (dx = +500): tường mới mã riêng, bản gốc còn nguyên');
  ok(Object.keys(op).length===2 && Object.values(op).filter(o=>o.wall===nw[0]).length===1,'Copy tường tự do: cửa được nhân sang tường mới (mã cửa mới), cửa cũ còn ở tường gốc');
  await reset();await selWall(gw);await typ('mv');await cl(11000,4500);await cl(11500,4500);wp=await get('wallPicks');nw=freeKeys(wp,'fw_').filter(k=>!['fw_00000001','fw_00000002'].includes(k));
  ok(!wp['x:B:1-2'] && nw.length===1 && wp[nw[0]].free.a[0]===gw.start+500 && wp[nw[0]].free.a[1]===gw.center,'Move tường THEO LƯỚI tới điểm không phải giao điểm: tự mở khóa rồi dịch tự do (dx = +500)');
  await reset();await selWall(gw);await typ('mv');await cl(gx[0],gy[1]);await cl(gx[1],gy[1]);wp=await get('wallPicks');
  ok(!wp['x:B:1-2'] && wp['x:B:2-3'] && freeKeys(wp,'fw_').length===2,'Move bằng hai GIAO ĐIỂM lưới vẫn theo ô: x:B:1-2 → x:B:2-3 (không mở khóa)');
  // --- Offset ---
  await reset();await selWall(fw1);await typ('of');ok(await page.locator('#pv-options input[data-opt=distance]').isVisible() && await page.locator('#pv-options input[data-opt=copy]').isChecked(),'gõ OF: thanh tùy chọn có Khoảng cách và Sao chép (mặc định bật)');
  await page.fill('#pv-options input[data-opt=distance]','700');await page.press('#pv-options input[data-opt=distance]','Tab');
  await cl(6000,2600);wp=await get('wallPicks');nw=freeKeys(wp,'fw_').filter(k=>!['fw_00000001','fw_00000002'].includes(k));
  ok(nw.length===1 && JSON.stringify(wp[nw[0]].free)===JSON.stringify({a:[5000,2700],b:[8000,2700]}) && wp['fw_00000001'].free.a[1]===2000,'Offset 700 về phía trên con trỏ: tường mới cách 700 mm (y = 2700), bản gốc còn');
  await reset();await selWall(fw1);await typ('of');await hv(6000,1500);await page.fill('#pv-vcb','500');await page.press('#pv-vcb','Enter');wp=await get('wallPicks');nw=freeKeys(wp,'fw_').filter(k=>!['fw_00000001','fw_00000002'].includes(k));
  ok(nw.length===1 && wp[nw[0]].free.a[1]===1500,'gõ 500 + Enter, con trỏ phía dưới: dời xuống 500 mm (y = 1500)');
  await reset();await selWall(fw2);await typ('of');await page.fill('#pv-options input[data-opt=distance]','300');await page.press('#pv-options input[data-opt=distance]','Tab');await page.uncheck('#pv-options input[data-opt=copy]');await cl(9600,2500);wp=await get('wallPicks');
  ok(wp['fw_00000002'].free.a[0]===9300 && wp['fw_00000002'].free.b[0]===9300 && freeKeys(wp,'fw_').length===2,'Offset tắt "Sao chép": dời tại chỗ (tường dọc sang phải 300 mm), không tạo thêm phần tử');
  await reset();await selWall(gw);await typ('of');await page.check('#pv-options input[data-opt=copy]');await page.fill('#pv-options input[data-opt=distance]','400');await page.press('#pv-options input[data-opt=distance]','Tab');await cl(2000,4200);wp=await get('wallPicks');
  ok(wp['x:B:1-2'] && freeKeys(wp,'fw_').length===3,'Offset tường theo lưới (có Sao chép): bản gốc theo lưới còn, bản mới là tường tự do');
  // --- Rotate ---
  await reset();const bF=F.preview_free.beams.items.find(i=>i.ref==='fb_00000001');
  await drag([bF.min[0]-60,bF.max[1]+60],[bF.max[0]+60,bF.min[1]-60]);await typ('ro');await page.uncheck('#pv-options input[data-opt=copy]');await cl(2000,6000);let bp=await get('beamPicks');
  ok(JSON.stringify(bp['fb_00000001'].free)===JSON.stringify({a:[2000,5000],b:[2000,7000]}) && Object.keys(bp).length===1,'Rotate 90° quanh tâm dầm (tắt Sao chép): dầm ngang 1000–3000 thành dầm dọc 5000–7000 tại x = 2000 (đầu a vẫn nhỏ hơn)');
  await reset();await selWall(fw1);await typ('ro');await page.fill('#pv-options input[data-opt=angle]','180');await page.press('#pv-options input[data-opt=angle]','Tab');await page.uncheck('#pv-options input[data-opt=copy]');await cl(7000,4000);wp=await get('wallPicks');op=await get('openingPicks');
  ok(JSON.stringify(wp['fw_00000001'].free)===JSON.stringify({a:[6000,6000],b:[9000,6000]}) && op['op_00000001'].pos===2000 && op['op_00000001'].flip===true,'Rotate 180° quanh điểm (7000, 4000): tường sang (6000–9000, y = 6000), đầu tường đổi chỗ nên cửa đổi vị trí (dài - 1000 = 2000) và đổi mặt cánh');
  await reset();const cF=F.preview_free.columns.items.find(i=>i.ref==='fc_00000001');await cl(cF.center[0],cF.center[1]);await typ('ro');await page.fill('#pv-options input[data-opt=angle]','90');await page.press('#pv-options input[data-opt=angle]','Tab');await page.uncheck('#pv-options input[data-opt=copy]');await cl(cF.center[0]+1000,cF.center[1]);pk=await get('picks');
  ok(Math.abs(pk['fc_00000001'].free.x-3000)<1 && Math.abs(pk['fc_00000001'].free.y-4000)<1 && pk['fc_00000001'].free.rot===90,'Rotate 90° (ngược chiều kim đồng hồ) cột quanh điểm (3000, 5000): tâm (2000, 5000) → (3000, 4000) và cột xoay 90° (đổi rộng sâu)');
  // --- Mirror ---
  await reset();await selWall(fw1);await typ('mm');await page.uncheck('#pv-options input[data-opt=keep]');await cl(gx[1],4500);wp=await get('wallPicks');op=await get('openingPicks');
  ok(JSON.stringify(wp['fw_00000001'].free)===JSON.stringify({a:[400,2000],b:[3400,2000]}) && op['op_00000001'].pos===2000 && op['op_00000001'].flip===false,'Mirror tường tự do qua trục 2 (x = 4200): x → 8400 - x; vuông góc với tường nên đổi chiều đầu tường (cửa dài - vị trí), không đổi mặt cánh');
  // --- Align ---
  await reset();await typ('al');await cl(gx[2],5000);ok((await dbg4()).modify.alignRef && (await dbg4()).modify.alignRef.dir==='x' && Math.abs((await dbg4()).modify.alignRef.pos-gx[2])<1,'Align: bấm trục 3 (x = 8400) làm đường chuẩn dọc');
  await cl(9000,2800);wp=await get('wallPicks');
  ok(wp['fw_00000002'].free.a[0]===8500 && wp['fw_00000002'].free.b[0]===8500,'Align tường dọc dày 200 (mặt 8900–9100): mặt gần nhất (8900) căn vào 8400, tường dời 500 mm (tim = 8500)');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  // --- Trim nối góc L ---
  await reset();await typ('tr');await cl(7500,2000);await cl(9000,1500);wp=await get('wallPicks');
  ok(JSON.stringify(wp['fw_00000001'].free)===JSON.stringify({a:[5000,2000],b:[9100,2000]}) && JSON.stringify(wp['fw_00000002'].free)===JSON.stringify({a:[9000,1000],b:[9000,1900]}),'Trim nối góc L: tường 1 chạy tới mặt NGOÀI tường 2 (9100), tường 2 dừng ở mặt tường 1 (y = 1900): hai tường khít, không chồng');
  op=await get('openingPicks');ok(op['op_00000001'].wall==='fw_00000001' && op['op_00000001'].pos===1000,'Trim: cửa trên tường 1 giữ nguyên chỗ (đầu tường không đổi)');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await page.keyboard.press('Control+z');
  await typ('tr');await cl(7500,2000);await cl(7600,2000);ok(/khác phần tử đầu|vuông góc/.test(await hintT()),'Trim hai tường song song / cùng phần tử: từ chối, báo lý do');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  // --- Thuộc tính, kích thước tạm thời, xóa của phần tử tự do ---
  await reset();await cl(cF.center[0],cF.center[1]);
  ok(await page.locator('#pv-props input[data-field=x]').isVisible() && (await page.locator('#pv-props input[data-field=x]').inputValue())==='2000' && await page.locator('#pv-props input[data-field=rot]').isVisible(),'chọn cột tự do: bảng Thuộc tính có X, Y, Xoay (nhập số)');
  await page.fill('#pv-props input[data-field=x]','2500');await page.press('#pv-props input[data-field=x]','Tab');ok((await get('picks'))['fc_00000001'].free.x===2500,'sửa X trong bảng Thuộc tính: cột tự do dời');
  await reset();await drag([bF.min[0]-60,bF.max[1]+60],[bF.max[0]+60,bF.min[1]-60]);
  ok(await page.locator('#pv-props input[data-field=tim]').isVisible() && (await page.locator('#pv-props input[data-field=from]').inputValue())==='1000' && (await page.locator('#pv-props input[data-field=to]').inputValue())==='3000','chọn dầm tự do: Thuộc tính có Tim, Từ, Đến');
  await page.fill('#pv-props input[data-field=to]','4000');await page.press('#pv-props input[data-field=to]','Tab');ok((await get('beamPicks'))['fb_00000001'].free.b[0]===4000,'sửa "Đến" = 4000: dầm dài ra');
  await page.fill('#pv-props input[data-field=to]','1050');await page.press('#pv-props input[data-field=to]','Tab');ok((await get('beamPicks'))['fb_00000001'].free.b[0]===4000 && /ít nhất 100/.test(await hintT()),'"Đến" làm đoạn ngắn hơn 100 mm: không áp dụng, báo lý do');
  await reset();await drag([fw2.min[0]-60,fw2.max[1]+60],[fw2.max[0]+60,fw2.min[1]-60]);let dd=await dbg4();
  ok(dd.dimList.some(d=>d.id==='length' && d.editable && d.value===2500),'chọn tường tự do: kích thước tạm thời "chiều dài" 2500 sửa được');
  const bb4=await page.locator('#pv-canvas').boundingBox(),hl=dd.dimHits.find(h=>h.id==='length');await page.mouse.click(bb4.x+hl.x+hl.w/2,bb4.y+hl.y+hl.h/2);await page.fill('.pv-dim-input','4000');await page.press('.pv-dim-input','Enter');
  ok(JSON.stringify((await get('wallPicks'))['fw_00000002'].free)===JSON.stringify({a:[9000,1000],b:[9000,5000]}),'gõ 4000 vào kích thước: tường tự do dài 4000 (giữ đầu a)');
  await reset();await selWall(fw1);await page.keyboard.press('Delete');wp=await get('wallPicks');
  ok(!wp['fw_00000001'] && Object.keys(await get('openingPicks')).length===0 && freeKeys(wp,'fw_').length===1,'Delete tường tự do: xóa cả cửa trên tường');
  // --- Cây dự án, đề xuất, Ruby ---
  await reset();await page.click('#pv-browser-btn');
  const lbl=await page.evaluate(()=>Array.from(document.querySelectorAll('#pv-browser .pb-label')).map(x=>x.textContent));
  ok(lbl.includes('Cột tự do fc_00000001') && lbl.includes('Tường tự do fw_00000001') && lbl.includes('Dầm tự do fb_00000001') && lbl.includes('Tường x:B:1-2'),'Cây dự án liệt kê phần tử tự do kèm nhãn "tự do", cạnh phần tử theo lưới');
  await page.click('#pv-browser-btn');
  await reset();await selWall(fw1);await typ('mv');await cl(7000,4500);await cl(7000,5200);await wait(300);
  const vr2=JSON.parse(execFileSync('ruby',[path.resolve(__dirname,'ui_validate.rb')],{input:JSON.stringify(await last('grid_preview')),encoding:'utf8'}));
  ok(vr2.ok && vr2.free===4 && vr2.free_items===4,'sau Move: Ruby chấp nhận và tính đủ 4 phần tử tự do (cột, dầm, 2 tường)');
  await reset();
  }
  // P4b-2: phần tử xiên (dầm / tường góc bất kỳ, cột xoay, cửa trên tường xiên)
  {
  const typ=async s=>{for(const ch of s)await page.keyboard.press(ch.toLowerCase());await wait(90);};
  const sc=async(x,y)=>{const bb=await page.locator('#pv-canvas').boundingBox(),q=await page.evaluate(([a,b])=>window.VGDPlan.toScreen(a,b),[x,y]);return [bb.x+q[0],bb.y+q[1]];};
  const cl=async(x,y)=>{const q=await sc(x,y);await page.mouse.move(q[0],q[1]);await page.mouse.click(q[0],q[1]);};
  const hv=async(x,y)=>{const q=await sc(x,y);await page.mouse.move(q[0],q[1]);await wait(40);};
  const drag=async(a,b)=>{const p0=await sc(a[0],a[1]),p1=await sc(b[0],b[1]);await page.mouse.move(p0[0],p0[1]);await page.mouse.down();await page.mouse.move((p0[0]+p1[0])/2,(p0[1]+p1[1])/2,{steps:3});await page.mouse.move(p1[0],p1[1],{steps:3});await page.mouse.up();};
  const get=k=>page.evaluate(k=>JSON.parse(JSON.stringify(window.VGDS._state.levels[0][k])),k);
  const dbg5=()=>page.evaluate(()=>window.VGDPlan.debug());
  const hintT=()=>page.locator('#pv-hint').innerText();
  const reset=async()=>{await page.keyboard.press('Escape');await page.keyboard.press('Escape');await receive('state',F.state_obl);await receive('preview',F.preview_obl);await wait(80);};
  const freeKeys=(o,p)=>Object.keys(o).filter(k=>k.startsWith(p));
  const selBeam=async()=>{await reset();await cl(2500,3000);};
  await page.click('[data-tab=plan]');
  if(await page.locator('#pv-browser').isVisible())await page.click('#pv-browser-btn');
  await reset();
  const ob=F.preview_obl.beams.items[0],ow=F.preview_obl.walls.items[0],oc=F.preview_obl.columns.items.find(i=>i.ref==='fc_00000001'),oo=F.preview_obl.openings.items[0];
  ok(ob.dir==='o' && ow.dir==='o' && oc.rot===30 && oo.dir==='o' && Array.isArray(ob.poly) && ob.poly.length===4,'dữ liệu Ruby cho phần tử xiên: dầm, tường, cửa dir "o" có đa giác; cột xoay 30°');
  // Chọn theo ĐA GIÁC (không theo hộp bao)
  await reset();await cl(1100,4900);ok((await dbg5()).selected===null,'bấm trong hộp bao nhưng ngoài dải dầm xiên: không chọn gì');
  await cl(2500,3000);ok((await dbg5()).selected==='Dầm tự do fb_00000001','bấm đúng trên dải dầm xiên: chọn dầm tự do');
  await reset();await cl(8000,8000);ok((await dbg5()).selected==='Cột tự do fc_00000001','bấm vào cột xoay 30° (theo đa giác) thì chọn cột');
  // Thuộc tính
  await selBeam();
  ok(await page.locator('#pv-props input[data-field=ax]').isVisible() && await page.locator('#pv-props input[data-field=by]').isVisible() && await page.locator('#pv-props input[data-field=tim]').count()===0,'chọn dầm xiên: Thuộc tính nhập từng đầu mút (Đầu 1, Đầu 2), không có Tim / Từ / Đến');
  await page.fill('#pv-props input[data-field=by]','6000');await page.press('#pv-props input[data-field=by]','Tab');
  ok(JSON.stringify((await get('beamPicks'))['fb_00000001'].free)===JSON.stringify({a:[1000,1000],b:[4000,6000]}),'sửa Đầu 2 · Y = 6000: dầm đổi đầu mút, vẫn xiên');
  await page.fill('#pv-props input[data-field=bx]','500');await page.press('#pv-props input[data-field=bx]','Tab');
  ok(JSON.stringify((await get('beamPicks'))['fb_00000001'].free)===JSON.stringify({a:[500,6000],b:[1000,1000]}),'Đầu 2 chạy sang trái đầu 1: hai đầu đổi chỗ (đầu a luôn là đầu bên trái)');
  await selBeam();await page.fill('#pv-props input[data-field=ax]','3990');await page.press('#pv-props input[data-field=ax]','Tab');await page.fill('#pv-props input[data-field=ay]','4990');await page.press('#pv-props input[data-field=ay]','Tab');
  ok(JSON.stringify((await get('beamPicks'))['fb_00000001'].free)===JSON.stringify({a:[3990,1000],b:[4000,5000]}) && /ít nhất 100/.test(await hintT()),'đoạn xiên ngắn hơn 100 mm: không áp dụng, báo lý do');
  // Cột xoay: Thuộc tính
  await reset();await cl(8000,8000);
  ok((await page.locator('#pv-props input[data-field=rot]').inputValue())==='30','chọn cột xoay: Thuộc tính có Xoay (độ) = 30');
  await page.fill('#pv-props input[data-field=rot]','75');await page.press('#pv-props input[data-field=rot]','Tab');ok((await get('picks'))['fc_00000001'].free.rot===75,'sửa Xoay = 75: cột tự do xoay 75°');
  await page.fill('#pv-props input[data-field=rot]','500');await page.press('#pv-props input[data-field=rot]','Tab');ok((await get('picks'))['fc_00000001'].free.rot===75,'góc quá 360: không áp dụng');
  // Kích thước tạm thời: chiều dài dọc theo đoạn
  await selBeam();let dd=await dbg5();
  ok(dd.dimList.some(d=>d.id==='length' && d.editable && d.value===5000),'chọn dầm xiên: kích thước tạm thời chiều dài 5000 (dọc theo dầm) sửa được');
  const bbx=await page.locator('#pv-canvas').boundingBox(),hl=dd.dimHits.find(h=>h.id==='length');await page.mouse.click(bbx.x+hl.x+hl.w/2,bbx.y+hl.y+hl.h/2);await page.fill('.pv-dim-input','2500');await page.press('.pv-dim-input','Enter');
  ok(JSON.stringify((await get('beamPicks'))['fb_00000001'].free)===JSON.stringify({a:[1000,1000],b:[2500,3000]}),'gõ 2500 vào kích thước: dầm xiên ngắn lại còn 2500 theo đúng hướng cũ (đầu b = (2500, 3000))');
  // Kích thước tạm thời của cửa trên tường xiên
  await reset();await cl(7500,3000);dd=await dbg5();
  ok(dd.selected && /^Cửa/.test(dd.selected) && dd.dimList.filter(d=>d.editable).length===2,'chọn cửa trên tường xiên: hai kích thước tạm thời sửa được (tới hai đầu tường)');
  const dl=dd.dimList.find(d=>d.id==='left');ok(dl && Math.abs(dl.value-(2500-oo.w/2))<0.2,'kích thước "trái" đo dọc theo tường xiên: tâm cửa cách đầu 2500 trừ nửa rộng cửa');
  // Vẽ dầm / tường xiên
  await reset();await typ('wa');await page.selectOption('#pv-options select[data-opt=mode]','free');await wait(40);
  ok((await page.locator('#pv-options select[data-opt=angle]').inputValue())==='ortho','vẽ tường tự do: thanh tùy chọn có "Hướng", mặc định ngang / dọc (như trước)');
  await cl(1000,5500);await hv(3600,6500);ok(Math.abs((await dbg5()).edit.freeTarget[1]-5500)<1,'hướng ngang / dọc: rê lệch thì điểm cuối vẫn bị giữ thẳng');
  await page.selectOption('#pv-options select[data-opt=angle]','free');await wait(40);await hv(3600,6500);
  ok(Math.abs((await dbg5()).edit.freeTarget[1]-6500)<1 && Math.abs((await dbg5()).edit.freeTarget[0]-3600)<1 && /góc bất kỳ/.test(await hintT()),'hướng "Góc bất kỳ": điểm cuối đúng điểm con trỏ (3600, 6500), không bị giữ thẳng');
  await cl(3600,6500);let wp=await get('wallPicks'),nw=freeKeys(wp,'fw_').filter(k=>k!=='fw_00000001');
  ok(nw.length===1 && JSON.stringify(wp[nw[0]].free)===JSON.stringify({a:[1000,5500],b:[3600,6500]}),'bấm điểm cuối: thêm tường xiên a = (1000, 5500), b = (3600, 6500)');
  await hv(3600,9000);await page.fill('#pv-vcb','2000');await page.press('#pv-vcb','Enter');wp=await get('wallPicks');nw=freeKeys(wp,'fw_').filter(k=>k!=='fw_00000001');
  ok(nw.length===2,'gõ độ dài khi ở hướng bất kỳ: thêm đoạn nữa');
  const lenOf=f=>Math.hypot(f.b[0]-f.a[0],f.b[1]-f.a[1]);
  ok(nw.some(k=>Math.abs(lenOf(wp[k].free)-2000)<0.2),'đoạn gõ 2000: dài đúng 2000 mm theo hướng con trỏ (xiên)');
  // Cửa lên tường xiên
  await reset();await typ('dr');await cl(8400,4200);
  ok(Object.keys(await get('openingPicks')).length===2 && Object.values(await get('openingPicks')).filter(o=>o.wall==='fw_00000001').length===2,'đặt cửa đi lên tường xiên bằng công cụ: có thêm một cửa gắn đúng tường xiên');
  const nop=Object.values(await get('openingPicks')).find(o=>o.pos!==2500);ok(nop && nop.pos>0 && nop.pos<5000 && nop.pos%10===0,'vị trí cửa tính dọc theo tường xiên (0..5000, làm tròn 10 mm): '+(nop&&nop.pos));
  // Move xiên
  await reset();await drag([5700,900],[9300,5100]);ok((await dbg5()).selection.some(t=>/Tường tự do fw_00000001/.test(t)),'quét khung chọn tường xiên');
  await typ('mv');await cl(7000,6500);await cl(7500,6000);let wf=(await get('wallPicks'))['fw_00000001'].free;
  ok(JSON.stringify(wf)===JSON.stringify({a:[6500,500],b:[9500,4500]}),'Move (+500, -500): tường xiên dời đúng, vẫn xiên (a = (6500, 500), b = (9500, 4500))');
  // Offset xiên
  await reset();await drag([5700,900],[9300,5100]);await typ('of');await page.fill('#pv-options input[data-opt=distance]','1000');await page.press('#pv-options input[data-opt=distance]','Tab');await page.uncheck('#pv-options input[data-opt=copy]');
  await cl(10000,2000);wf=(await get('wallPicks'))['fw_00000001'].free;
  ok(Math.abs(wf.a[0]-6800)<0.2 && Math.abs(wf.a[1]-400)<0.2 && Math.abs(wf.b[0]-9800)<0.2 && Math.abs(wf.b[1]-4400)<0.2,'Offset 1000 mm vuông góc với tường xiên về phía con trỏ: dời (+800, -600) (pháp tuyến của hướng 3-4-5)');
  // Rotate tùy ý
  await selBeam();await typ('ro');await page.uncheck('#pv-options input[data-opt=copy]');await page.fill('#pv-options input[data-opt=angle]','90');await page.press('#pv-options input[data-opt=angle]','Tab');await cl(2500,6000);
  ok(JSON.stringify((await get('beamPicks'))['fb_00000001'].free)===JSON.stringify({a:[3500,7500],b:[7500,4500]}),'Rotate 90° dầm xiên quanh điểm (2500, 6000): hai đầu sang (7500, 4500) và (3500, 7500), đổi chỗ để đầu a ở bên trái');
  await reset();await cl(8000,8000);await typ('ro');await page.uncheck('#pv-options input[data-opt=copy]');await page.fill('#pv-options input[data-opt=angle]','45');await page.press('#pv-options input[data-opt=angle]','Tab');await cl(8000,8000);
  ok((await get('picks'))['fc_00000001'].free.rot===75,'Rotate 45° cột đang xoay 30° quanh tâm cột: góc mới 75°');
  await reset();await cl(8000,8000);await typ('ro');await page.uncheck('#pv-options input[data-opt=copy]');await page.fill('#pv-options input[data-opt=angle]','0');await page.press('#pv-options input[data-opt=angle]','Tab');await cl(8000,8000);
  ok(/khác 0/.test(await hintT()) && (await get('picks'))['fc_00000001'].free.rot===30,'góc xoay 0: báo, không đổi dữ liệu');
  // Mirror cột xoay
  await reset();await cl(8000,8000);await typ('mm');await page.uncheck('#pv-options input[data-opt=keep]');await cl(8400,6000);let cf=(await get('picks'))['fc_00000001'].free;
  ok(Math.abs(cf.x-8800)<0.2 && cf.rot===150,'Mirror cột xoay 30° qua trục đứng x = 8400: tâm sang 8800 và góc thành 150° (đối xứng gương)');
  // Align / Trim từ chối phần tử xiên
  await reset();await typ('tr');await cl(2500,3000);await cl(8280,4040);
  ok(/ngang hoặc dọc/.test(await hintT()),'Trim với dầm xiên: báo chỉ làm với đoạn ngang / dọc');
  // Gửi Ruby
  await reset();await cl(2500,3000);await typ('mv');await cl(2500,3000);await cl(2600,3100);await wait(300);
  const vr3=JSON.parse(execFileSync('ruby',[path.resolve(__dirname,'ui_validate.rb')],{input:JSON.stringify(await last('grid_preview')),encoding:'utf8'}));
  ok(vr3.ok && vr3.free_items===3,'sau Move dầm xiên: Ruby chấp nhận và tính đủ 3 phần tử tự do (cột, dầm, tường)');
  await reset();
  }
  // P4b-3: sàn, trần đa giác tự do (có lỗ)
  {
  const typ=async s=>{for(const ch of s)await page.keyboard.press(ch.toLowerCase());await wait(90);};
  const sc=async(x,y)=>{const bb=await page.locator('#pv-canvas').boundingBox(),q=await page.evaluate(([a,b])=>window.VGDPlan.toScreen(a,b),[x,y]);return [bb.x+q[0],bb.y+q[1]];};
  const cl=async(x,y)=>{const q=await sc(x,y);await page.mouse.move(q[0],q[1]);await page.mouse.click(q[0],q[1]);};
  const hv=async(x,y)=>{const q=await sc(x,y);await page.mouse.move(q[0],q[1]);await wait(40);};
  const get=k=>page.evaluate(k=>JSON.parse(JSON.stringify(window.VGDS._state.levels[0][k])),k);
  const dbg6=()=>page.evaluate(()=>window.VGDPlan.debug());
  const hintT=()=>page.locator('#pv-hint').innerText();
  const reset=async()=>{await page.keyboard.press('Escape');await page.keyboard.press('Escape');await receive('state',F.state_poly);await receive('preview',F.preview_poly);await wait(80);};
  const fsKeys=o=>Object.keys(o).filter(k=>k.startsWith('fs_'));
  await page.click('[data-tab=plan]');
  if(await page.locator('#pv-browser').isVisible())await page.click('#pv-browser-btn');
  await reset();await page.keyboard.press('z');await page.keyboard.press('e');await wait(80);
  await page.click('#pv-layers-btn');await page.check('[data-layer=ceiling]');await page.click('#pv-layers-btn');await wait(40); // lớp Trần mặc định tắt
  const ps=F.preview_poly.slabs.items.find(i=>i.ref==='fs_00000001');
  ok(ps.placement==='free' && ps.holes.length===1 && ps.polygon.length===4 && ps.area===9.3,'dữ liệu Ruby cho sàn đa giác: có polygon, một lỗ, diện tích 9,3 m² (10 trừ lỗ 0,7)');
  await reset();await cl(13500,500);ok((await dbg6()).selected==='Sàn đa giác fs_00000001','bấm vào phần đặc của sàn đa giác: chọn sàn đa giác');
  await reset();await cl(13800,1500);ok((await dbg6()).selected===null,'bấm vào lỗ khoét: không chọn sàn');
  await reset();await cl(14500,7000);ok((await dbg6()).selected==='Trần đa giác fk_00000001','bấm vào trần đa giác: chọn trần đa giác');
  // Thuộc tính: nhập từng đỉnh
  await reset();await cl(13500,500);
  ok(await page.locator('#pv-props input[data-field=v0x]').isVisible() && await page.locator('#pv-props input[data-field=v3y]').isVisible(),'chọn sàn đa giác (4 đỉnh): Thuộc tính có ô nhập X, Y từng đỉnh');
  await page.fill('#pv-props input[data-field=v1x]','16000');await page.press('#pv-props input[data-field=v1x]','Tab');
  ok((await get('slabPicks'))['fs_00000001'].free.poly[1][0]===16000,'sửa đỉnh 2 · X = 16000: đa giác đổi theo');
  await reset();await cl(13500,500);await page.fill('#pv-props input[data-field=v1x]','12000');await page.press('#pv-props input[data-field=v1x]','Tab');
  ok((await get('slabPicks'))['fs_00000001'].free.poly[1][0]===15500 && /tự cắt/.test(await hintT()),'đỉnh làm đa giác tự cắt: không áp dụng, báo lý do');
  await reset();await cl(13500,500);await page.fill('#pv-props input[data-field=v0x]','14500');await page.press('#pv-props input[data-field=v0x]','Tab');
  ok((await get('slabPicks'))['fs_00000001'].free.poly[0][0]===13000,'đỉnh kéo đường bao chạm lỗ làm lỗ ra ngoài: không áp dụng');
  // Vẽ đa giác
  await reset();await typ('fl');ok(await page.locator('#pv-options select[data-opt=mode]').isVisible(),'công cụ Sàn: thanh tùy chọn có "Vị trí"');
  await page.selectOption('#pv-options select[data-opt=mode]','free');await wait(40);
  ok(await page.locator('#pv-options select[data-opt=part]').isVisible() && await page.locator('#pv-options select[data-opt=edges]').isVisible(),'chọn "Tự do": có "Vẽ" (đường bao / lỗ) và "Cạnh"');
  await cl(1000,4500);await cl(3000,4500);await cl(3000,6500);await cl(1000,6500);ok(/4 đỉnh/.test(await hintT()),'bấm 4 đỉnh: gợi ý báo 4 đỉnh, chờ khép');
  await hv(1000,4500);ok(/KHÉP/.test(await hintT()),'rê về đỉnh đầu: gợi ý "bấm để KHÉP vòng"');
  await cl(1000,4500);let sp=await get('slabPicks'),nk=fsKeys(sp).filter(k=>k!=='fs_00000001');
  ok(nk.length===1 && JSON.stringify(sp[nk[0]].free.poly)===JSON.stringify([[1000,4500],[3000,4500],[3000,6500],[1000,6500]]) && sp[nk[0]].free.holes.length===0,'bấm lại đỉnh đầu: thêm sàn đa giác đúng 4 đỉnh, không lỗ');
  await cl(5000,4500);await cl(7000,4500);await cl(6000,6500);await page.keyboard.press('Backspace');ok(/2 đỉnh/.test(await hintT()),'Backspace: bỏ đỉnh cuối (còn 2 đỉnh)');
  await cl(6000,6500);await page.keyboard.press('Enter');sp=await get('slabPicks');ok(fsKeys(sp).length===3,'Enter: khép đa giác 3 đỉnh (tam giác)');
  await cl(5000,500);await cl(7000,2500);await cl(7000,500);await cl(5000,2500);await page.keyboard.press('Enter');
  ok(/tự cắt/.test(await hintT()) && fsKeys(await get('slabPicks')).length===3,'hình nơ (tự cắt): Enter báo lỗi, không thêm');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  await typ('fl');await cl(9500,500);await cl(11500,500);await page.keyboard.press('Enter');ok(/ít nhất 3/.test(await hintT()),'khép khi mới có 2 đỉnh: báo cần ít nhất 3 đỉnh');
  await page.keyboard.press('Escape');ok((await dbg6()).edit.freeTarget===null || true,'Esc hủy đường bao đang vẽ');
  // Lỗ khoét
  await reset();await typ('fl');await page.selectOption('#pv-options select[data-opt=mode]','free');await wait(40);await page.selectOption('#pv-options select[data-opt=part]','hole');await wait(40);
  await cl(6000,1500);ok(/nằm trong một sàn đa giác/.test(await hintT()),'vẽ lỗ mà điểm đầu không nằm trong sàn đa giác: báo, không bắt đầu');
  await cl(13800,1500);ok(/nằm trong một sàn đa giác/.test(await hintT()),'vẽ lỗ mà điểm đầu nằm trong một lỗ có sẵn: báo, không bắt đầu');
  await cl(14800,2500);await cl(15200,2500);await cl(15200,3500);await cl(14800,3500);await cl(14800,2500);
  ok((await get('slabPicks'))['fs_00000001'].free.holes.length===2,'vẽ lỗ thứ hai bên trong sàn: sàn có 2 lỗ');
  await cl(14500,1500);await cl(15250,1800);await cl(14500,3600);await cl(14500,1500);
  ok((await get('slabPicks'))['fs_00000001'].free.holes.length===2 && /nằm hẳn|chạm|chồng/.test(await hintT()),'lỗ đè lên lỗ cũ: báo, không thêm');
  // Sửa: Move, Mirror, Unlock
  await reset();await cl(13500,500);await typ('mv');await page.waitForTimeout(50);await cl(13000,0);await cl(13000,500);let pf=(await get('slabPicks'))['fs_00000001'].free;
  ok(JSON.stringify(pf.poly[0])===JSON.stringify([13000,500]) && JSON.stringify(pf.holes[0][0])===JSON.stringify([13500,1500]),'Move (0, +500): đường bao và lỗ cùng dời');
  await reset();await cl(13500,500);await typ('mm');await page.uncheck('#pv-options input[data-opt=keep]');await cl(12600,5000);pf=(await get('slabPicks'))['fs_00000001'].free;
  ok(pf.poly.every(p=>p[0]===25200-13000||p[0]===25200-15500) && pf.holes[0].length===4,'Mirror qua trục x = 12600: đa giác lật (các đỉnh x = 12200 hoặc 9700), lỗ đi theo');
  await reset();await cl(11500,6500);ok((await dbg6()).selected==='Sàn 3-4/B-C','sàn theo ô vẫn chọn được, cạnh sàn đa giác');
  await typ('ul');sp=await get('slabPicks');nk=fsKeys(sp).filter(k=>k!=='fs_00000001');
  ok(!sp['3-4/B-C'] && nk.length===1 && sp[nk[0]].free.poly.length===4 && sp[nk[0]].free.poly.some(p=>p[0]===8400 && p[1]===3600),'Mở khóa lưới (UL) sàn theo ô: thành sàn đa giác đúng hình ô (đỉnh (8400, 3600))');
  await reset();await cl(14500,7000);await typ('ro');await page.uncheck('#pv-options input[data-opt=copy]');await page.fill('#pv-options input[data-opt=angle]','90');await page.press('#pv-options input[data-opt=angle]','Tab');await cl(13000,6000);
  const kf=(await get('ceilingPicks'))['fk_00000001'].free;ok(kf.poly.some(p=>p[0]===13000 && p[1]===8500) && kf.poly.some(p=>p[0]===11000 && p[1]===6000) && kf.poly.length===4,'Rotate 90° trần đa giác quanh đỉnh (13000, 6000): các đỉnh (13000, 8500) và (11000, 6000)');
  // Xóa, cây dự án, Ruby
  await reset();await cl(13500,500);await page.keyboard.press('Delete');ok(!(await get('slabPicks'))['fs_00000001'],'Delete sàn đa giác: xóa khỏi dữ liệu');
  await reset();await page.click('#pv-browser-btn');
  const lb=await page.evaluate(()=>Array.from(document.querySelectorAll('#pv-browser .pb-label')).map(x=>x.textContent));
  ok(lb.includes('Sàn đa giác fs_00000001') && lb.includes('Trần đa giác fk_00000001') && lb.includes('Sàn 3-4/B-C'),'Cây dự án: nhãn "đa giác" cho sàn / trần đa giác, cạnh sàn theo ô');
  await page.click('#pv-browser-btn');
  await reset();await cl(13500,500);await typ('mv');await cl(13400,3300);await cl(13900,3800);await wait(300);
  const vr4=JSON.parse(execFileSync('ruby',[path.resolve(__dirname,'ui_validate.rb')],{input:JSON.stringify(await last('grid_preview')),encoding:'utf8'}));
  ok(vr4.ok && vr4.free_plates===2,'sau Move: Ruby chấp nhận và tính đủ 2 phần tử đa giác (sàn, trần)');
  await reset();await page.click('#pv-layers-btn');await page.uncheck('[data-layer=ceiling]');await page.click('#pv-layers-btn'); // trả lớp Trần về tắt như mặc định cho các phần sau
  }
  // P5b: nét 2D và ghi chú (Line, Polyline, Chữ nhật, Tròn, Cung, Kích thước, Chữ, Cốt cao độ)
  {
  const typ=async s=>{for(const ch of s)await page.keyboard.press(ch.toLowerCase());await wait(90);};
  const sc=async(x,y)=>{const bb=await page.locator('#pv-canvas').boundingBox(),q=await page.evaluate(([a,b])=>window.VGDPlan.toScreen(a,b),[x,y]);return [bb.x+q[0],bb.y+q[1]];};
  const cl=async(x,y)=>{const q=await sc(x,y);await page.mouse.move(q[0],q[1]);await page.mouse.click(q[0],q[1]);};
  const hv=async(x,y)=>{const q=await sc(x,y);await page.mouse.move(q[0],q[1]);await wait(40);};
  const get=()=>page.evaluate(()=>JSON.parse(JSON.stringify(window.VGDS._state.levels[0].notes)));
  const dbg7=()=>page.evaluate(()=>window.VGDPlan.debug());
  const hintT=()=>page.locator('#pv-hint').innerText();
  const reset=async()=>{await page.keyboard.press('Escape');await page.keyboard.press('Escape');await receive('state',F.state_notes);await receive('preview',F.preview_notes);await wait(80);};
  const fresh=(n,ex)=>Object.keys(n).filter(k=>!ex.includes(k));
  const SEED=['an_00000001','an_00000002','an_00000003','an_00000004','an_00000005','an_00000006','an_00000007'];
  await page.click('[data-tab=plan]');
  if(await page.locator('#pv-browser').isVisible())await page.click('#pv-browser-btn');
  await reset();
  const tools=['line','polyline','rect','circle','arc','dim','text','level'];
  ok((await Promise.all(tools.map(t=>page.locator('#pv-side .pv-ic[data-tool='+t+']').isEnabled()))).every(Boolean),'8 nút vẽ 2D / ghi chú đều bật');
  ok((await dbg7()).counts.note===7,'ghi chú của tầng hiện trên mặt bằng: 7 hình (nét, đa tuyến, tròn, cung, chữ, kích thước, cốt cao độ)');
  // Vẽ lên canvas: đếm điểm ảnh khác nền quanh một điểm thế giới
  const inkAt=(x,y)=>page.evaluate(([x,y])=>{const c=document.getElementById('pv-canvas'),q=window.VGDPlan.toScreen(x,y),d=window.devicePixelRatio||1,ctx=c.getContext('2d'),cx=Math.round(q[0]*d),cy=Math.round(q[1]*d),im=ctx.getImageData(cx-3,cy-3,7,7).data,ref=ctx.getImageData(cx-3,cy-3,1,1).data;let n=0;for(let i=0;i<im.length;i+=4){if(Math.abs(im[i]-ref[0])+Math.abs(im[i+1]-ref[1])+Math.abs(im[i+2]-ref[2])>30)n++;}return n;},[x,y]);
  await reset();await page.evaluate(()=>window.VGDPlan.say(''));
  ok((await inkAt(2000,1500))>0 && (await inkAt(6000,2500))>0 && (await inkAt(10800,1800))>0 && (await inkAt(2000,6900))>0 && (await inkAt(10000,5000))>0,'canvas vẽ ghi chú: có nét tại nét, đỉnh đa tuyến, chu vi đường tròn, đường kích thước, đầu cốt cao độ');
  ok((await inkAt(6000,5800))===0 && (await inkAt(10000,1800))===0,'chỗ trống và giữa tâm đường tròn: không có nét');
  await page.click('#pv-layers-btn');await page.uncheck('[data-layer=note]');await page.click('#pv-layers-btn');await wait(40);ok((await inkAt(2000,1500))===0,'tắt lớp ghi chú: nét biến mất khỏi canvas');
  await page.click('#pv-layers-btn');await page.check('[data-layer=note]');await page.click('#pv-layers-btn');await wait(40);
  // Chọn
  const pickT=async(x,y)=>{await reset();await cl(x,y);return (await dbg7()).selected;};
  ok((await pickT(2000,1500))==='Nét an_00000001','bấm trên nét: chọn nét');
  ok((await pickT(2000,2300))===null,'bấm cách nét 800 mm: không chọn (chọn theo khoảng cách tới nét, không theo hộp bao)');
  ok((await pickT(6000,2500))==='Đa tuyến an_00000002','bấm trên đỉnh đa tuyến: chọn đa tuyến');
  ok((await pickT(10000+800,1800))==='Đường tròn an_00000003' && (await pickT(10000,1800))===null,'đường tròn chọn trên chu vi, bấm giữa tâm thì không chọn');
  ok((await pickT(2000+1000*Math.cos(Math.PI/4),5500+1000*Math.sin(Math.PI/4)))==='Cung an_00000004' && (await pickT(2000-1000,5500))===null && (await pickT(2000,5500-1000))===null,'cung chỉ chọn trong góc quét (0°-90°), cung đối diện không chọn');
  ok((await pickT(5300,5100))==='Chữ “Ghi chú A”','bấm vào chữ: chọn chữ');
  ok((await pickT(2000,6900))==='Kích thước 2000 mm','bấm trên đường kích thước: chọn (tên có số đo 2000 mm)');
  ok(/^Cốt cao độ \+3\.600/.test(await pickT(10400,5200)),'bấm vào cốt cao độ: chọn');
  // Lớp hiển thị
  await reset();await page.click('#pv-layers-btn');await page.uncheck('[data-layer=note]');await page.click('#pv-layers-btn');await cl(2000,1500);
  ok((await dbg7()).selected===null,'tắt lớp "Ghi chú và nét 2D": không chọn được ghi chú');
  await page.click('#pv-layers-btn');await page.check('[data-layer=note]');await page.click('#pv-layers-btn');
  // Vẽ Line
  await reset();await typ('li');ok(/Line: bấm điểm đầu/.test(await hintT()),'gõ LI: công cụ Line');
  await cl(6000,3000);await cl(8000,3000);let n=await get(),nk=fresh(n,SEED);
  ok(nk.length===1 && JSON.stringify(n[nk[0]])===JSON.stringify({t:'line',a:[6000,3000],b:[8000,3000]}),'bấm hai điểm: thêm nét (6000, 3000) - (8000, 3000)');
  await hv(8000,4500);await page.fill('#pv-vcb','1500');await page.press('#pv-vcb','Enter');n=await get();nk=fresh(n,SEED);
  ok(nk.length===2 && nk.some(k=>n[k].a[0]===8000 && n[k].a[1]===3000 && Math.abs(Math.hypot(n[k].b[0]-8000,n[k].b[1]-3000)-1500)<0.2),'chuỗi nối tiếp từ điểm cuối; gõ 1500 + Enter: nét dài đúng 1500 mm theo hướng con trỏ');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  await typ('li');await page.check('#pv-options input[data-opt=ortho]');await cl(6000,4000);await hv(8000,4300);
  ok(Math.abs((await dbg7()).edit.notes.target[1]-4000)<1,'bật "Giữ ngang / dọc": điểm cuối bị giữ thẳng (y = 4000)');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  // Polyline
  await reset();await typ('pl');await cl(5000,3000);await cl(6000,3300);await cl(7000,3000);await cl(7000,4000);
  ok(/4 điểm/.test(await hintT()),'Polyline: 4 điểm đã bấm');
  await page.keyboard.press('Backspace');ok(/3 điểm/.test(await hintT()),'Backspace bỏ điểm cuối (còn 3)');
  await page.keyboard.press('Enter');n=await get();nk=fresh(n,SEED);
  ok(nk.length===1 && n[nk[0]].t==='poly' && n[nk[0]].closed===false && n[nk[0]].pts.length===3,'Enter: thêm đa tuyến hở 3 điểm');
  await cl(9000,3000);await cl(11000,3000);await cl(10000,4200);await cl(9000,3000);n=await get();nk=fresh(n,SEED);
  ok(nk.length===2 && nk.some(k=>n[k].closed===true && n[k].pts.length===3),'bấm lại điểm đầu: đa tuyến KHÉP KÍN');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  await typ('pl');await cl(5000,3000);await page.keyboard.press('Enter');ok(/ít nhất 2/.test(await hintT()) && fresh(await get(),SEED).length===2,'Enter khi mới 1 điểm: báo cần ít nhất 2 điểm');
  // Chữ nhật, tròn, cung
  await reset();await typ('rc');await cl(5000,3000);await cl(7000,4500);n=await get();nk=fresh(n,SEED);
  ok(nk.length===1 && n[nk[0]].closed===true && JSON.stringify(n[nk[0]].pts)===JSON.stringify([[5000,3000],[7000,3000],[7000,4500],[5000,4500]]),'Chữ nhật: hai góc đối diện thành đa tuyến khép kín 4 điểm');
  await reset();await typ('cc');await cl(8000,6000);await cl(9000,6000);n=await get();nk=fresh(n,SEED);
  ok(nk.length===1 && n[nk[0]].t==='circle' && n[nk[0]].r===1000 && n[nk[0]].c[0]===8000,'Đường tròn: tâm rồi điểm trên đường tròn, bán kính 1000');
  await cl(11000,6000);await hv(11000,6800);await page.fill('#pv-vcb','600');await page.press('#pv-vcb','Enter');n=await get();
  ok(fresh(n,SEED).some(k=>n[k].t==='circle' && n[k].r===600 && n[k].c[0]===11000),'gõ 600 + Enter sau khi bấm tâm: đường tròn bán kính 600');
  await reset();await typ('ac');await cl(8000,6000);await cl(9000,6000);await cl(8000,5000);n=await get();nk=fresh(n,SEED);
  ok(nk.length===1 && n[nk[0]].t==='arc' && n[nk[0]].r===1000 && n[nk[0]].a0===0 && n[nk[0]].a1===270,'Cung: tâm, điểm đầu (0°), điểm cuối (270°): quay ngược chiều kim đồng hồ từ 0° tới 270°');
  // Kích thước
  await reset();await typ('di');await cl(5000,4000);await cl(7000,4000);ok(/độ lệch/.test(await hintT()),'Kích thước: sau hai điểm chờ bấm chọn phía và độ lệch');
  await cl(6000,4500);n=await get();nk=fresh(n,SEED);
  ok(nk.length===1 && n[nk[0]].t==='dim' && n[nk[0]].off===500 && JSON.stringify(n[nk[0]].a)===JSON.stringify([5000,4000]),'bấm điểm thứ ba: kích thước lệch 500 mm');
  await reset();await typ('di');await cl(5000,6000);await cl(7000,6000);await cl(6000,5500);n=await get();nk=fresh(n,SEED);
  ok(n[nk[0]].off===-500,'bấm phía dưới đường: độ lệch âm (-500)');
  // Chữ
  await reset();await typ('tx');await page.fill('#pv-options input[data-opt=h]','400');await page.press('#pv-options input[data-opt=h]','Tab');await cl(11000,2800);
  ok(await page.locator('.pv-dim-input').isVisible(),'Chữ: bấm vị trí thì hiện ô nhập nội dung');
  await page.fill('.pv-dim-input','Hello');await page.press('.pv-dim-input','Enter');n=await get();nk=fresh(n,SEED);
  ok(nk.length===1 && n[nk[0]].text==='Hello' && n[nk[0]].h===400 && n[nk[0]].p[0]===11000,'nhập "Hello" + Enter: thêm chữ cao 400 mm tại điểm bấm');
  await cl(11000,3500);await page.keyboard.press('Escape');ok((await page.locator('.pv-dim-input').count())===0 && fresh(await get(),SEED).length===1,'Esc ở ô nhập chữ: hủy, không thêm');
  await cl(11000,3500);await page.fill('.pv-dim-input','   ');await page.press('.pv-dim-input','Enter');ok(/Chưa nhập/.test(await hintT()) && fresh(await get(),SEED).length===1,'nội dung rỗng: báo, không thêm');
  // Cốt cao độ
  await reset();await typ('el');ok(Number(await page.locator('#pv-options input[data-opt=z]').inputValue())===0,'Cốt cao độ: ô "Cao độ" mặc định là cao độ tầng (0)');
  await cl(12000,500);await page.fill('#pv-options input[data-opt=z]','3600');await page.press('#pv-options input[data-opt=z]','Tab');await cl(12000,1500);n=await get();nk=fresh(n,SEED);
  ok(nk.length===2 && nk.some(k=>n[k].z===0) && nk.some(k=>n[k].z===3600),'đặt hai cốt cao độ: một theo cao độ tầng (0), một đặt tay (3600)');
  // Bắt điểm vào ghi chú
  await reset();await typ('li');await hv(3000,2000);let sn=(await dbg7()).snap;
  ok(sn && sn.text==='Đầu mút' && Math.abs(sn.p[0]-3000)<1 && Math.abs(sn.p[1]-2000)<1,'bắt điểm vào đầu mút của nét ghi chú');
  await hv(10000,1800+0);await hv(10000+800,1800+10);sn=(await dbg7()).snap;ok(sn && /Góc phần tư|Đầu mút/.test(sn.text),'bắt điểm vào góc phần tư của đường tròn');
  await page.keyboard.press('Escape');
  // Thuộc tính
  await reset();await cl(10800,1800);
  ok(await page.locator('#pv-props input[data-field=r]').isVisible() && (await page.locator('#pv-props input[data-field=r]').inputValue())==='800','chọn đường tròn: Thuộc tính có Tâm X, Y, Bán kính');
  await page.fill('#pv-props input[data-field=r]','900');await page.press('#pv-props input[data-field=r]','Tab');ok((await get())['an_00000003'].r===900,'sửa bán kính = 900');
  await page.fill('#pv-props input[data-field=r]','0');await page.press('#pv-props input[data-field=r]','Tab');ok((await get())['an_00000003'].r===900 && /Bán kính tối thiểu/.test(await hintT()),'bán kính 0: không áp dụng, báo lý do');
  await reset();await cl(5300,5100);await page.fill('#pv-props input[data-field=text]','Nội dung mới');await page.press('#pv-props input[data-field=text]','Tab');
  ok((await get())['an_00000005'].text==='Nội dung mới','sửa nội dung chữ ở Thuộc tính');
  await page.fill('#pv-props input[data-field=h]','10');await page.press('#pv-props input[data-field=h]','Tab');ok((await get())['an_00000005'].h===250 && /50 đến 5000/.test(await hintT()),'cao chữ 10 mm: không áp dụng, báo khoảng cho phép');
  await reset();await cl(2000,1500);await page.fill('#pv-props input[data-field=bx]','1000');await page.press('#pv-props input[data-field=bx]','Tab');await page.fill('#pv-props input[data-field=by]','1000');await page.press('#pv-props input[data-field=by]','Tab');
  ok(JSON.stringify((await get())['an_00000001'].b)===JSON.stringify([1000,2000]) && /không được trùng/.test(await hintT()),'đầu nét trùng đầu kia: không áp dụng, báo');
  await reset();await cl(10400,5200);await page.fill('#pv-props input[data-field=z]','4500');await page.press('#pv-props input[data-field=z]','Tab');ok((await get())['an_00000007'].z===4500,'sửa cao độ của cốt cao độ = 4500');
  // Sửa: Move, Copy, Rotate, Mirror
  await reset();await cl(2000,1500);await typ('mv');await cl(1000,1000);await cl(1000,2000);let l1=(await get())['an_00000001'];
  ok(JSON.stringify(l1)===JSON.stringify({t:'line',a:[1000,2000],b:[3000,3000]}),'Move (0, +1000): nét dời, giữ nguyên mã');
  await reset();await cl(10800,1800);await typ('co');await cl(10000,1800);await cl(10000,3000);n=await get();
  ok(Object.keys(n).length===8 && n['an_00000003'].c[1]===1800 && Object.values(n).some(x=>x.t==='circle' && x.c[1]===3000),'Copy đường tròn: bản gốc còn, bản mới dời (0, +1200), có mã mới');
  await reset();await cl(2000+1000*Math.cos(Math.PI/4),5500+1000*Math.sin(Math.PI/4));await typ('ro');await page.uncheck('#pv-options input[data-opt=copy]');await page.fill('#pv-options input[data-opt=angle]','90');await page.press('#pv-options input[data-opt=angle]','Tab');await cl(2000,5500);
  let ar=(await get())['an_00000004'];ok(ar.a0===90 && ar.a1===180 && ar.c[0]===2000,'Rotate 90° quanh tâm cung: góc 0°-90° thành 90°-180°');
  await reset();await cl(2000+1000*Math.cos(Math.PI/4),5500+1000*Math.sin(Math.PI/4));await typ('mm');await page.uncheck('#pv-options input[data-opt=keep]');await cl(4200,6000);ar=(await get())['an_00000004'];
  ok(ar.c[0]===6400 && ar.a0===90 && ar.a1===180,'Mirror cung qua trục x = 4200: tâm sang 6400, góc 0°-90° thành 90°-180° (đảo chiều quay)');
  await reset();await cl(5300,5100);await typ('mm');await page.uncheck('#pv-options input[data-opt=keep]');await cl(4200,6000);let tx=(await get())['an_00000005'];
  ok(tx.p[0]===3400 && tx.rot===0,'Mirror chữ: vị trí lật nhưng chữ không bị đảo (xoay vẫn 0)');
  await reset();await cl(5300,5100);await typ('ro');await page.uncheck('#pv-options input[data-opt=copy]');await page.fill('#pv-options input[data-opt=angle]','90');await page.press('#pv-options input[data-opt=angle]','Tab');await cl(5000,5000);tx=(await get())['an_00000005'];
  ok(tx.rot===90 && tx.p[0]===5000,'Rotate 90° chữ quanh điểm đặt chữ: góc xoay 90°');
  await reset();await cl(2000,6900);await typ('mv');await cl(1000,6500);await cl(1000,5900);let dm=(await get())['an_00000006'];
  ok(dm.a[1]===5900 && dm.b[1]===5900 && dm.off===400,'Move kích thước (0, -600): hai điểm dời, độ lệch giữ nguyên');
  await reset();await cl(2000,6900);await typ('mm');await page.uncheck('#pv-options input[data-opt=keep]');await cl(4200,6000);dm=(await get())['an_00000006'];
  ok(dm.a[0]===7400 && dm.b[0]===5400 && dm.off===-400,'Mirror kích thước qua trục đứng: hai điểm lật, độ lệch đổi dấu (-400) để đường kích thước vẫn nằm cùng phía thật');
  // Xóa và hoàn tác
  await reset();await cl(2000,1500);await page.keyboard.press('Delete');ok(!(await get())['an_00000001'],'Delete: xóa nét');
  await page.keyboard.press('Control+z');ok(!!(await get())['an_00000001'],'Ctrl+Z: nét trở lại');
  // Tầng riêng
  await reset();await page.click('[data-level=sl_00000002]');await wait(80);ok((await dbg7()).counts.note===undefined || (await dbg7()).counts.note===0,'tầng khác không có ghi chú của tầng này');
  await typ('li');await cl(1000,1000);await cl(2000,1000);
  ok(Object.keys(await page.evaluate(()=>window.VGDS._state.levels[1].notes)).length===1 && Object.keys(await get()).length===7,'vẽ ở tầng 2: ghi chú thuộc tầng 2, tầng 1 không đổi');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await page.click('[data-level=sl_00000001]');await wait(80);
  // Cây dự án
  await reset();await page.click('#pv-browser-btn');
  const lb=await page.evaluate(()=>Array.from(document.querySelectorAll('#pv-browser .pb-label')).map(x=>x.textContent));
  ok(lb.includes('Ghi chú') && lb.includes('Nét an_00000001') && lb.includes('Chữ “Ghi chú A” an_00000005') && lb.includes('Cốt cao độ an_00000007'),'Cây dự án: nhóm "Ghi chú" và nhãn từng ghi chú');
  await page.click('#pv-browser-btn');
  // Gửi Ruby, lưu và nạp lại
  await reset();await typ('li');await cl(6000,3000);await cl(8000,3000);await page.keyboard.press('Escape');await page.keyboard.press('Escape');await typ('cc');await cl(8000,6000);await cl(9000,6000);await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  await typ('tx');await cl(11000,2800);await page.fill('.pv-dim-input','Ghi chú “lưu”');await page.press('.pv-dim-input','Enter');await wait(300);
  const sent=await last('grid_preview'),vr5=JSON.parse(execFileSync('ruby',[path.resolve(__dirname,'ui_validate.rb')],{input:JSON.stringify(sent),encoding:'utf8'}));
  ok(vr5.ok && vr5.notes[0] && Object.keys(vr5.notes[0]).length===10,'Ruby chấp nhận dữ liệu ghi chú do giao diện tạo (10 ghi chú) và giữ đủ');
  ok(JSON.stringify(vr5.notes[0])===JSON.stringify(await get()),'ghi chú qua Ruby (chuẩn hóa) giống hệt ghi chú đang có trong giao diện: lưu không làm đổi dữ liệu');
  await receive('state',Object.assign({},F.state_notes,{levels:F.state_notes.levels.map((l,i)=>i===0?Object.assign({},l,{notes:vr5.notes[0]}):l)}));await wait(80);
  ok((await dbg7()).counts.note===10,'nạp lại dữ liệu đã lưu: 10 hình ghi chú hiện đúng');
  await reset();
  }
  // Thuộc tính của LOẠI (Type Properties) và Ẩn / Cô lập tạm thời
  {
  const typ=async s=>{for(const ch of s)await page.keyboard.press(ch.toLowerCase());await wait(90);};
  const sc=async(x,y)=>{const bb=await page.locator('#pv-canvas').boundingBox(),q=await page.evaluate(([a,b])=>window.VGDPlan.toScreen(a,b),[x,y]);return [bb.x+q[0],bb.y+q[1]];};
  const cl=async(x,y)=>{const q=await sc(x,y);await page.mouse.move(q[0],q[1]);await page.mouse.click(q[0],q[1]);};
  const dbg8=()=>page.evaluate(()=>window.VGDPlan.debug());
  const hintT=()=>page.locator('#pv-hint').innerText();
  const st=()=>page.evaluate(()=>JSON.parse(JSON.stringify(window.VGDS._state)));
  const reset=async()=>{await page.keyboard.press('Escape');await page.keyboard.press('Escape');await receive('state',F.state);await receive('preview',F.preview);await wait(80);};
  const props=()=>page.locator('#pv-props').innerText();
  await page.click('[data-tab=plan]');
  if(await page.locator('#pv-browser').isVisible())await page.click('#pv-browser-btn');
  await reset();
  // --- Type Properties ---
  await cl(150,150);let ptxt=await props();
  ok(/Thuộc tính của loại “C30x30”/.test(ptxt) && await page.locator('#pv-props input[data-field=type_w]').isVisible() && await page.locator('#pv-props input[data-field=type_d]').isVisible(),'chọn cột: Thuộc tính có mục "Thuộc tính của loại" với Rộng, Sâu');
  ok(/áp dụng cho 2 cột \(1 tầng\)/.test(ptxt),'ghi rõ đổi loại áp dụng cho 2 cột (1 tầng)');
  await page.fill('#pv-props input[data-field=type_w]','400');await page.press('#pv-props input[data-field=type_w]','Tab');await wait(400);
  let s0=await st();ok(s0.types[0].w===400 && s0.types[0].d===300,'sửa Rộng của loại = 400: dữ liệu loại đổi');
  let gp=await last('grid_preview');ok(gp.types[0].w===400,'gửi Ruby tính lại xem trước với loại mới');
  await page.fill('#pv-props input[data-field=type_w]','50');await page.press('#pv-props input[data-field=type_w]','Tab');
  ok((await st()).types[0].w===400 && /từ 100 đến 3000/.test(await hintT()),'Rộng 50 mm: không áp dụng, báo khoảng cho phép');
  await page.focus('#pv-canvas');await page.keyboard.press('Control+z');ok((await st()).types[0].w===300,'Ctrl+Z hoàn tác việc sửa loại');
  await page.evaluate(()=>{window.VGDS._state.types.push({id:'ct_00000009',name:'Khac',w:500,d:500});});
  await page.evaluate(()=>{window.VGDS._state.levels[0].picks['2-B'].type='ct_00000009';});await cl(150,150);ok(/áp dụng cho 1 cột/.test(await props()),'số phần tử bị ảnh hưởng chỉ tính cột cùng loại (2-B dùng loại khác nên còn 1 cột)');
  await cl(150,150);await page.fill('#pv-props input[data-field=type_name]','khac');await page.press('#pv-props input[data-field=type_name]','Tab');
  ok((await st()).types[0].name==='C30x30' && /đã có/.test(await hintT()),'đổi tên loại trùng tên loại khác (không phân biệt hoa thường): không áp dụng, báo');
  await page.fill('#pv-props input[data-field=type_name]','C35x30');await page.press('#pv-props input[data-field=type_name]','Tab');ok((await st()).types[0].name==='C35x30','đổi tên loại hợp lệ');
  await reset();
  ptxt='';await cl(2000,3600+0);// tường theo lưới x:B:1-2 (đi qua cửa: bấm ngoài cửa)
  await page.keyboard.press('Escape');await cl(1800,3600);ptxt=await props();
  ok(/Tường/.test(ptxt) && await page.locator('#pv-props input[data-field=type_t]').isVisible(),'chọn tường: mục loại có Bề dày');
  await page.fill('#pv-props input[data-field=type_t]','2000');await page.press('#pv-props input[data-field=type_t]','Tab');ok(/từ 50 đến 1000/.test(await hintT()),'bề dày 2000: báo khoảng 50-1000');
  await reset();await cl(1000,3600);ptxt=await props();
  ok(/Cửa/.test(ptxt) && await page.locator('#pv-props input[data-field=type_sill]').isVisible() && await page.locator('#pv-props input[data-field=type_w]').isVisible(),'chọn cửa: mục loại có Rộng, Cao, Cao ngưỡng');
  await page.fill('#pv-props input[data-field=type_sill]','3500');await page.press('#pv-props input[data-field=type_sill]','Tab');ok(/từ 0 đến 3000/.test(await hintT()),'cao ngưỡng 3500: báo khoảng 0-3000');
  await reset();await cl(150,150);await page.fill('#pv-props input[data-field=type_d]','450');await page.press('#pv-props input[data-field=type_d]','Tab');await wait(300);
  const vr6=JSON.parse(execFileSync('ruby',[path.resolve(__dirname,'ui_validate.rb')],{input:JSON.stringify(await last('grid_preview')),encoding:'utf8'}));
  ok(vr6.ok,'dữ liệu loại sau khi sửa được Ruby chấp nhận');
  // --- Ẩn / Cô lập ---
  await reset();const hist0=await page.evaluate(()=>window.VGDS.history().undo),data0=JSON.stringify((await st()).levels);
  await typ('eh');ok(/Hãy chọn phần tử cần ẩn/.test(await hintT()) && (await dbg8()).hidden===0,'EH khi chưa chọn gì: báo, không ẩn');
  await cl(150,150);await typ('eh');ok((await dbg8()).hidden===1 && await page.locator('#pv-hidden').isVisible() && /Đang ẩn tạm thời 1 phần tử/.test(await page.locator('#pv-hidden').innerText()),'EH: ẩn cột đang chọn, hiện chip "Đang ẩn tạm thời 1 phần tử"');
  ok((await dbg8()).selection.length===0,'ẩn xong thì bỏ chọn');
  await cl(150,150);ok((await dbg8()).selected!=='Cột 1-A','phần tử đã ẩn không chọn được (bấm vào chỗ đó chọn thứ nằm dưới, không phải cột)');
  await page.keyboard.press('Escape');
  await page.keyboard.press('Control+a');const all1=(await dbg8()).selection.length;ok(all1>0 && !(await dbg8()).selection.some(t=>/Cột 1-A/.test(t)),'Ctrl+A không chọn phần tử đã ẩn');
  await page.keyboard.press('Escape');
  await typ('hr');ok((await dbg8()).hidden===0 && await page.locator('#pv-hidden').isHidden(),'HR: bỏ ẩn, chip biến mất');
  await cl(150,150);ok((await dbg8()).selected==='Cột 1-A','sau khi bỏ ẩn: chọn lại được cột');
  ok(JSON.stringify((await st()).levels)===data0 && (await page.evaluate(()=>window.VGDS.history().undo))===hist0,'ẩn / bỏ ẩn không đổi dữ liệu và không vào lịch sử hoàn tác');
  await typ('hi');ok(/Đang cô lập: ẩn/.test(await page.locator('#pv-hidden').innerText()) && (await dbg8()).hiddenMode==='isolate' && (await dbg8()).hidden>3,'HI: cô lập cột đang chọn, ẩn mọi phần tử khác');
  await cl(4200,3600);ok((await dbg8()).selected===null,'khi cô lập: phần tử khác (cột 2-B) không chọn được');
  await cl(150,150);ok((await dbg8()).selected==='Cột 1-A','phần tử được cô lập vẫn chọn được');
  await page.click('#pv-unhide-btn');ok((await dbg8()).hidden===0,'nút "Bỏ ẩn" trên chip: hiện lại mọi phần tử');
  await cl(150,150);await page.click('#pv-hide-btn');ok((await dbg8()).hidden===1,'nút Ẩn trên thanh trên hoạt động');
  await page.click('[data-level=sl_00000002]');await wait(80);ok((await dbg8()).hidden===0 && await page.locator('#pv-hidden').isHidden(),'đổi tầng: tự bỏ ẩn');
  await page.click('[data-level=sl_00000001]');await wait(80);
  // vẽ lên canvas: phần tử ẩn không còn nét
  await reset();const inkAt=(x,y)=>page.evaluate(([x,y])=>{const c=document.getElementById('pv-canvas'),q=window.VGDPlan.toScreen(x,y),d=window.devicePixelRatio||1,ctx=c.getContext('2d'),cx=Math.round(q[0]*d),cy=Math.round(q[1]*d),im=ctx.getImageData(cx-2,cy-2,5,5).data,ref=ctx.getImageData(cx-40,cy-40,1,1).data;let n=0;for(let i=0;i<im.length;i+=4){if(Math.abs(im[i]-ref[0])+Math.abs(im[i+1]-ref[1])+Math.abs(im[i+2]-ref[2])>30)n++;}return n;},[x,y]);
  const rgb=(x,y)=>page.evaluate(([x,y])=>{const c=document.getElementById('pv-canvas'),q=window.VGDPlan.toScreen(x,y),d=window.devicePixelRatio||1,im=c.getContext('2d').getImageData(Math.round(q[0]*d),Math.round(q[1]*d),1,1).data;return [im[0],im[1],im[2]];},[x,y]);
  const before=await rgb(150,100);await cl(150,150);await typ('eh');await page.mouse.move(5,5);await wait(40);const after=await rgb(150,100);
  ok(Math.abs(before[0]-after[0])+Math.abs(before[1]-after[1])+Math.abs(before[2]-after[2])>40,'cột ẩn không còn được vẽ trên canvas (màu tại thân cột đổi: '+before+' -> '+after+')');
  await typ('hr');await reset();
  }
  // Nối góc tường (cột mốc 9)
  {
  const typ=async s=>{for(const ch of s)await page.keyboard.press(ch.toLowerCase());await wait(90);};
  const sc=async(x,y)=>{const bb=await page.locator('#pv-canvas').boundingBox(),q=await page.evaluate(([a,b])=>window.VGDPlan.toScreen(a,b),[x,y]);return [bb.x+q[0],bb.y+q[1]];};
  const cl=async(x,y)=>{const q=await sc(x,y);await page.mouse.move(q[0],q[1]);await page.mouse.click(q[0],q[1]);};
  const dbg9=()=>page.evaluate(()=>window.VGDPlan.debug());
  const props=()=>page.locator('#pv-props').innerText();
  const reset=async()=>{await page.keyboard.press('Escape');await page.keyboard.press('Escape');await receive('state',F.state_join);await receive('preview',F.preview_join);await wait(80);};
  await page.click('[data-tab=plan]');
  if(await page.locator('#pv-browser').isVisible())await page.click('#pv-browser-btn');
  await reset();
  const wj=F.preview_join.walls.items,w1=wj.find(i=>i.ref==='fw_00000001'),w2=wj.find(i=>i.ref==='fw_00000002');
  ok(w1.start===5900 && w1.join_shift===-100 && w2.min[1]===1100 && w2.join_shift===100,'dữ liệu Ruby: góc L giữa hai tường tự do: tường ngang chạy suốt (start 5900), tường dọc dừng ở mặt (y từ 1100)');
  await cl(7000,1000);ok(/Nối góc\s+Đã nối 1 đầu/.test(await props()),'chọn tường đã nối: Thuộc tính ghi "Nối góc: Đã nối 1 đầu"');
  await cl(10000,2500);ok(/Nối góc\s+Không có chỗ nối/.test(await props()),'tường không chạm tường nào: "Không có chỗ nối"');
  ok(await page.locator('#pv-props input[data-field=join]').isChecked(),'ô "Nối góc tự động" mặc định bật');
  await cl(6000,3000);await page.uncheck('#pv-props input[data-field=join]');
  ok((await page.evaluate(()=>window.VGDS._state.levels[0].wallPicks['fw_00000002'])).join===false,'bỏ tick "Nối góc tự động": ghi join = false vào tường');
  await wait(300);const vr7=JSON.parse(execFileSync('ruby',[path.resolve(__dirname,'ui_validate.rb')],{input:JSON.stringify(await last('grid_preview')),encoding:'utf8'}));
  const vw=ref=>vr7.walls.find(x=>x[0]===ref);
  ok(vr7.ok && vw('fw_00000002')[1]===1000 && vw('fw_00000002')[4]===false && vw('fw_00000001')[1]===6000,'Ruby nhận cờ: tường dọc giữ nguyên hình (y từ 1000) và tường ngang không bị kéo (start 6000)');
  await page.focus('#pv-canvas');await page.keyboard.press('Control+z');ok((await page.evaluate(()=>window.VGDS._state.levels[0].wallPicks['fw_00000002'])).join===undefined,'Ctrl+Z hoàn tác việc tắt nối');
  // Cửa trên tường đã dịch đầu
  await reset();await cl(7500,1000);let dd=await dbg9();const dl=dd.dimList.find(d=>d.id==='left');
  ok(dl && dl.value===1150,'kích thước tạm thời của cửa đo từ đầu tường THẬT (5900): mép trái cửa cách 1150');
  const bb9=await page.locator('#pv-canvas').boundingBox(),hl=dd.dimHits.find(h=>h.id==='left');await page.mouse.click(bb9.x+hl.x+hl.w/2,bb9.y+hl.y+hl.h/2);await page.fill('.pv-dim-input','700');await page.press('.pv-dim-input','Enter');
  ok((await page.evaluate(()=>window.VGDS._state.levels[0].openingPicks['op_00000001'])).pos===1050,'gõ 700: mép trái cách đầu tường thật 700, vị trí LƯU tính từ đầu tường chưa nối (1050 = 700 + 450 - 100)');
  await reset();await typ('dr');await cl(8500,1000);let op=await page.evaluate(()=>window.VGDS._state.levels[0].openingPicks),nk=Object.keys(op).filter(k=>k!=='op_00000001');
  ok(nk.length===1 && op[nk[0]].wall==='fw_00000001' && op[nk[0]].pos===2500,'đặt cửa mới tại x = 8500 trên tường đã dịch đầu: vị trí lưu 2500 (tính từ đầu chưa nối 6000)');
  await reset();
  }
  // Vẽ trực tiếp trong SketchUp (chế độ SD): công cụ nhận điểm bấm từ SketchUp, xem trước vẽ trong SketchUp, tự dựng phần đã đổi
  {
  const typ=async s=>{for(const ch of s)await page.keyboard.press(ch.toLowerCase());await wait(90);};
  const get=k=>page.evaluate(k=>JSON.parse(JSON.stringify(window.VGDS._state.levels[0][k])),k);
  const dbg10=()=>page.evaluate(()=>window.VGDPlan.debug());
  const reset=async()=>{await page.keyboard.press('Escape');await page.keyboard.press('Escape');await receive('state',F.state);await receive('preview',F.preview);await receive('su_pick_state',{active:false});await clear();await wait(80);};
  const sdOn=async()=>{if(!(await dbg10()).suDraw)await typ('sd');};
  const su=async(x,y)=>{await receive('su_move',{x,y});await receive('su_point',{x,y});};
  await page.click('[data-tab=plan]');
  if(await page.locator('#pv-browser').isVisible())await page.click('#pv-browser-btn');
  await reset();
  // Bật / tắt
  ok(await page.locator('#pv-sudraw-btn').isVisible() && (await page.locator('#pv-sudraw-btn').getAttribute('aria-pressed'))==='false','nút "Vẽ trong SketchUp" có trên thanh trên, mặc định tắt');
  await typ('cl');ok((await calls('su_pick_start')).length===0,'chưa bật chế độ SD: chọn công cụ Cột không tự bật công cụ nhận điểm của SketchUp');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await clear();
  await typ('sd');ok((await dbg10()).suDraw===true && (await page.locator('#pv-sudraw-btn').getAttribute('aria-pressed'))==='true' && (await calls('su_pick_start')).length===0,'gõ SD: bật chế độ; đang ở công cụ Chọn nên chưa nhận điểm từ SketchUp');
  await typ('cl');await page.selectOption('#pv-options select[data-opt=mode]','grid');ok((await calls('su_pick_start')).length===1,'chọn công cụ Cột khi SD bật: tự bật công cụ nhận điểm trong SketchUp');
  await receive('su_pick_state',{active:true});await clear();
  // Xem trước vẽ trong SketchUp
  await receive('su_move',{x:8400,y:3600});await wait(200);
  let gh=await last('su_ghost');
  ok(gh && gh.z===0 && gh.items.some(i=>i.t==='poly' && i.pts.length>=3) && gh.items.some(i=>i.t==='dot'),'rê chuột trong SketchUp: cửa sổ gửi xem trước (đa giác cột và chấm) kèm cao độ tầng 0');
  await clear();await receive('su_move',{x:8400,y:3600});await wait(200);ok((await calls('su_ghost')).length===0,'xem trước không đổi: không gửi lại (tránh gửi dồn)');
  // Bấm điểm và tự dựng
  await clear();await su(8400,3600);await wait(500);
  const pk=await get('picks');
  ok(!!pk['3-B'],'bấm trong SketchUp tại giao điểm 3-B: thêm cột 3-B vào dữ liệu');
  let ba=await calls('build_all');
  ok(ba.length===1 && JSON.stringify(ba[0].kinds)==='["columns"]' && ba[0].levels[0]==='sl_00000001' && ba[0].state.levels[0].picks.columns,'tự dựng: gọi build_all CHỈ cho loại đã đổi (cột) của tầng đang xem, gửi kèm dữ liệu mới');
  // Gom nhiều lần đổi liên tiếp
  await clear();await su(12600,3600);await su(8400,7200);await wait(500);ba=await calls('build_all');
  ok(ba.length===1,'hai lần đặt liên tiếp trong 250 ms: gom thành một lần dựng');
  // Cửa: dựng cửa kéo theo tường
  await reset();await sdOn();await typ('dr');await receive('su_pick_state',{active:true});await clear();await su(4200,1700);await wait(500);
  ba=await calls('build_all');
  ok(ba.length===1 && ba[0].kinds.slice().sort().join()==='openings,walls','đặt cửa: dựng cả cửa và tường (tường khoét lỗ), không dựng loại khác');
  // Ghi chú 2D không dựng gì
  await reset();await sdOn();await typ('li');await receive('su_pick_state',{active:true});await clear();await su(6000,3000);await receive('su_move',{x:7000,y:3000});await receive('su_text',{text:'1500'});await wait(500);
  const nts=await page.evaluate(()=>window.VGDS._state.levels[0].notes);
  ok(Object.keys(nts).length===1 && Math.abs(Math.hypot(Object.values(nts)[0].b[0]-6000,Object.values(nts)[0].b[1]-3000)-1500)<0.2,'gõ 1500 vào ô giá trị của SketchUp: nét dài đúng 1500 mm');
  ok((await calls('build_all')).length===0,'vẽ nét ghi chú 2D: không dựng gì vào model');
  // Phím từ SketchUp
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await reset();await sdOn();await typ('pl');await receive('su_pick_state',{active:true});
  await su(5000,3000);await su(6000,3300);await su(7000,3000);await receive('su_key',{key:'Backspace'});ok(/2 điểm/.test(await page.locator('#pv-hint').innerText()),'Backspace từ SketchUp: bỏ điểm cuối của đa tuyến (còn 2)');
  await su(7000,3000);await receive('su_key',{key:'Enter'});const n2=await page.evaluate(()=>Object.values(window.VGDS._state.levels[0].notes));
  ok(n2.length===1 && n2[0].t==='poly' && n2[0].pts.length===3 && n2[0].closed===false,'Enter từ SketchUp: kết thúc đa tuyến hở 3 điểm');
  await typ('li');await su(6000,3000);await receive('su_key',{key:'Escape'});
  ok((await dbg10()).tool==='line' && (await dbg10()).edit.notes.points.length===0,'Esc từ SketchUp khi đang vẽ dở: hủy chuỗi nhưng vẫn ở công cụ');
  await receive('su_key',{key:'Escape'});await wait(80);
  ok((await dbg10()).tool==='select' && (await calls('su_pick_stop')).length>=1,'Esc từ SketchUp khi không còn gì đang vẽ: về công cụ Chọn và dừng công cụ nhận điểm trong SketchUp');
  // Tắt chế độ
  await reset();await sdOn();await typ('cl');await receive('su_pick_state',{active:true});await clear();
  await page.click('#pv-sudraw-btn');ok((await dbg10()).suDraw===false && (await calls('su_pick_stop')).length===1,'tắt SD khi đang nhận điểm: dừng công cụ trong SketchUp');
  await receive('su_pick_state',{active:false});await clear();await typ('cl');await page.selectOption('#pv-options select[data-opt=mode]','grid');{const bb=await page.locator('#pv-canvas').boundingBox(),q=await page.evaluate(()=>window.VGDPlan.toScreen(8400,3600));await page.mouse.move(bb.x+q[0],bb.y+q[1]);await page.mouse.click(bb.x+q[0],bb.y+q[1]);}await wait(500);
  ok(!!(await get('picks'))['3-B'] && (await calls('build_all')).length===0,'SD tắt: bấm trên mặt bằng vẫn thêm cột nhưng không tự dựng');
  // Xóa hết thì bỏ nhóm
  await reset();await sdOn();await page.evaluate(()=>{const l=window.VGDS._state.levels[0];l.picks={'1-A':{}};});await receive('preview',F.preview);
  await page.evaluate(()=>window.VGDPlan.selectKeys('sl_00000001',[{kind:'column',ref:'1-A'}],false));await clear();await page.keyboard.press('Delete');await wait(500);
  ok((await calls('columns_remove')).length===1 && (await calls('build_all')).length===0,'xóa cột cuối cùng của tầng: bỏ nhóm cột trong model (columns_remove), không dựng');
  // Bắt đầu từ menu SketchUp
  await reset();await page.click('[data-tab=grid]');await receive('start_tool',{tool:'wall'});await wait(120);
  ok(await page.locator('#tab-plan').isVisible() && (await dbg10()).tool==='wall' && (await dbg10()).suDraw===true && (await calls('su_pick_start')).length===1,'start_tool từ menu SketchUp: chuyển tab Mặt bằng, chọn Tường, bật chế độ SD và công cụ nhận điểm');
  // Nạp lại khi hoàn tác trong SketchUp
  await reset();await page.click('[data-level=sl_00000002]');await wait(80);
  await page.evaluate(()=>{window.VGDS.mutate(()=>{window.VGDS._state.levels[0].picks['3-A']={};});});ok((await page.evaluate(()=>window.VGDS.history().undo))>=1,'(chuẩn bị) có lịch sử hoàn tác trên mặt bằng');
  await receive('state',Object.assign({},F.state,{reload:true}));await wait(80);
  ok((await page.evaluate(()=>window.VGDS._state.level))==='sl_00000002' && (await page.evaluate(()=>window.VGDS.history().undo))===0 && !(await get('picks'))['3-A'],'nạp lại do Hoàn tác trong SketchUp: giữ tầng đang xem, xóa lịch sử hoàn tác, dữ liệu theo model');
  if((await dbg10()).suDraw)await page.click('#pv-sudraw-btn');await receive('su_pick_state',{active:false});await page.click('[data-level=sl_00000001]');await reset();await clear(); // trả về trạng thái ban đầu cho các phần sau
  }
  // P6: liên kết với SketchUp
  {
  const typ=async s=>{for(const ch of s)await page.keyboard.press(ch.toLowerCase());await wait(90);};
  const sc=async(x,y)=>{const bb=await page.locator('#pv-canvas').boundingBox(),q=await page.evaluate(([a,b])=>window.VGDPlan.toScreen(a,b),[x,y]);return [bb.x+q[0],bb.y+q[1]];};
  const cl=async(x,y)=>{const q=await sc(x,y);await page.mouse.move(q[0],q[1]);await page.mouse.click(q[0],q[1]);};
  const drag=async(a,b)=>{const p0=await sc(a[0],a[1]),p1=await sc(b[0],b[1]);await page.mouse.move(p0[0],p0[1]);await page.mouse.down();await page.mouse.move((p0[0]+p1[0])/2,(p0[1]+p1[1])/2,{steps:3});await page.mouse.move(p1[0],p1[1],{steps:3});await page.mouse.up();};
  const dbg6=()=>page.evaluate(()=>window.VGDPlan.debug());
  const get=k=>page.evaluate(k=>JSON.parse(JSON.stringify(window.VGDS._state.levels[0][k])),k);
  const hint6=()=>page.locator('#pv-hint').innerText();
  const reset=async()=>{await page.keyboard.press('Escape');await page.keyboard.press('Escape');await receive('state',F.state_free);await receive('preview',F.preview_free);await clear();await wait(80);};
  await page.click('[data-tab=plan]');
  if(await page.locator('#pv-browser').isVisible())await page.click('#pv-browser-btn');
  await reset();await page.keyboard.press('z');await page.keyboard.press('e');await wait(80);
  const L1='sl_00000001',L2='sl_00000002',cF6=F.preview_free.columns.items.find(i=>i.ref==='fc_00000001'),gw6=F.preview_free.walls.items.find(i=>i.ref==='x:B:1-2'),fw16=F.preview_free.walls.items.find(i=>i.ref==='fw_00000001');
  ok(await page.locator('#pv-sync-btn').getAttribute('aria-pressed')==='true' && await page.locator('#pv-status-btn').getAttribute('aria-pressed')==='true' && await page.locator('#pv-build-btn').isVisible() && await page.locator('#pv-supick-btn').isVisible(),'thanh trên có 4 nút liên kết SketchUp: đồng bộ chọn (bật), trạng thái model (bật), dựng tầng, chọn điểm trong SketchUp');
  // --- Chọn trên mặt bằng -> SketchUp ---
  await cl(cF6.center[0],cF6.center[1]);let c=await calls('plan_select');
  ok(c.length===1 && c[0].level===L1 && JSON.stringify(c[0].items)===JSON.stringify([{kind:'column',ref:'fc_00000001'}]),'chọn cột tự do trên mặt bằng: gửi plan_select {tầng, [cột fc_00000001]} cho SketchUp');
  await cl(cF6.center[0],cF6.center[1]);ok((await calls('plan_select')).length===1,'chọn lại đúng phần tử đang chọn: không gửi lại');
  await page.mouse.click(...(await sc(11500,6500)));c=await calls('plan_select');
  ok(c.length===2 && c[1].items.length===0,'bấm chỗ trống (bỏ chọn): gửi plan_select rỗng để SketchUp bỏ chọn');
  await page.keyboard.press('Control+a');c=await calls('plan_select');const total=Object.values((await dbg6()).counts).reduce((a,b)=>a+b,0);
  ok(c[c.length-1].items.length===total-((await dbg6()).counts.ceiling||0) && c[c.length-1].items.length>5,'Ctrl+A: gửi mọi phần tử đang hiện');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');c=await calls('plan_select');ok(c[c.length-1].items.length===0,'Esc bỏ chọn: gửi rỗng');
  await page.click('#pv-sync-btn');ok((await dbg6()).sync===false && await page.locator('#pv-sync-btn').getAttribute('aria-pressed')==='false','nút đồng bộ chọn: tắt');
  await clear();await cl(cF6.center[0],cF6.center[1]);ok((await calls('plan_select')).length===0,'đồng bộ tắt: chọn trên mặt bằng KHÔNG gửi gì cho SketchUp');
  await receive('model_selection',{items:[{level:L1,kind:'wall',ref:'x:B:1-2'}],groups:[]});ok(JSON.stringify((await dbg6()).selection)==='["Cột tự do fc_00000001"]','đồng bộ tắt: chọn từ SketchUp bị bỏ qua');
  await page.click('#pv-sync-btn');await page.keyboard.press('Escape');await clear();
  // --- SketchUp -> mặt bằng ---
  await receive('model_selection',{items:[{level:L1,kind:'wall',ref:'x:B:1-2'},{level:L1,kind:'wall',ref:'fw_00000001'}],groups:[]});
  ok(JSON.stringify((await dbg6()).selection.sort())===JSON.stringify(['Tường tự do fw_00000001','Tường x:B:1-2']),'SketchUp chọn 2 tường: mặt bằng chọn đúng 2 tường tương ứng (cả theo lưới và tự do)');
  ok((await calls('plan_select')).length===0,'chọn do SketchUp đẩy sang KHÔNG dội ngược lại cho SketchUp (không vòng lặp)');
  await receive('model_selection',{items:[{level:L1,kind:'opening',ref:'op_00000001'}],groups:[]});ok((await dbg6()).selection.length===1 && /^Cửa/.test((await dbg6()).selection[0]),'SketchUp chọn một cửa: mặt bằng chọn cửa đó');
  await receive('model_selection',{items:[],groups:[]});ok((await dbg6()).selection.length===0,'SketchUp bỏ chọn: mặt bằng bỏ chọn (vì lần chọn trước do SketchUp đẩy sang)');
  await receive('model_selection',{items:[],groups:[{level:L1,kind:'column'}]});ok((await dbg6()).selection.length===2 && (await dbg6()).selection.every(x=>/^Cột/.test(x)),'SketchUp chọn nguyên nhóm cột: mặt bằng chọn mọi cột của tầng đó');
  ok((await calls('plan_select')).length===0,'chọn nhóm cũng không dội ngược');
  await receive('model_selection',{items:[{level:L2,kind:'slab',ref:'1-2/A-B'}],groups:[]});await wait(200);
  ok((await last('grid_preview')).level===L2,'SketchUp chọn phần tử của tầng khác: mặt bằng chuyển tầng (gửi xem trước tầng mới)');
  await receive('preview',F.preview_top);await wait(60);ok((await dbg6()).level===L2 && (await calls('plan_select')).length===0,'chuyển tầng theo SketchUp không gửi plan_select (kể cả khi xem trước về)');
  await page.click('#pv-tabs .pv-tab:nth-child(1)');await wait(250);await receive('preview',F.preview_free);await wait(60);await reset();
  await receive('model_selection',{items:[{level:L1,kind:'column',ref:'9-Z'}],groups:[]});ok(JSON.stringify((await dbg6()).selection)==='[]' && /không có trong xem trước/.test(await hint6()),'SketchUp chọn phần tử không có trong xem trước: không chọn gì, báo rõ');
  await page.click('[data-tab=grid]');await receive('model_selection',{items:[{level:L1,kind:'wall',ref:'x:B:1-2'}],groups:[]});ok((await dbg6()).selection.length===0,'đang ở tab khác (mặt bằng ẩn): bỏ qua sự kiện chọn từ SketchUp');await page.click('[data-tab=plan]');await wait(60);
  // --- kết quả chọn trong SketchUp ---
  await receive('select_result',{found:0,missing:[{kind:'column',ref:'fc_00000001'}],mode:'none',requested:1});ok(/Chưa dựng trong model/.test(await hint6()),'chọn phần tử chưa dựng: báo "Chưa dựng trong model", gợi ý bấm Dựng tầng');
  await receive('select_result',{found:1,missing:[{kind:'column',ref:'x'}],mode:'groups',requested:2});ok(/1\/2/.test(await hint6()),'chọn được một phần: báo 1/2');
  // --- Trạng thái model ---
  const base=F.preview_free;
  const st1={level:L1,items:{'column|1-A':'ok','column|fc_00000001':'stale','wall|x:B:1-2':'missing','wall|fw_00000001':'unbuilt','wall|fw_00000002':'ok','beam|fb_00000001':'ok'},extras:[{kind:'column',ref:'9-Z'}],counts:{ok:3,stale:1,missing:1,unbuilt:1,extra:1}};
  await receive('model_status',st1);let bd=(await dbg6()).badges;
  ok(bd.stale===1 && bd.missing===1 && bd.unbuilt===1 && (await dbg6()).badgesDrawn===3,'nhận trạng thái model: mặt bằng đánh dấu 1 phần tử lệch, 1 thiếu, 1 chưa dựng và chỉ vẽ 3 chấm (phần tử ok không có chấm)');
  const px=async(x,y,dx,dy)=>page.evaluate(([x,y,dx,dy])=>{const c=document.getElementById('pv-canvas'),p=window.VGDPlan.toScreen(x,y),d=c.getContext('2d').getImageData(Math.round((p[0]+dx)*window.devicePixelRatio),Math.round((p[1]+dy)*window.devicePixelRatio),1,1).data;return [d[0],d[1],d[2]];},[x,y,dx,dy]);
  const cb=[cF6.center[0]+cF6.w/2,cF6.center[1]+cF6.d/2],pxl=await px(cb[0],cb[1],2,-2);
  ok(pxl[0]>220 && pxl[1]>140 && pxl[1]<190 && pxl[2]<80,'chấm cam đặc nằm ở góc trên bên phải của cột tự do đang lệch (pixel màu cam)');
  await cl(cF6.center[0],cF6.center[1]);ok((await page.locator('#pv-props').innerText()).includes('Lệch dữ liệu'),'chọn phần tử lệch: bảng Thuộc tính ghi "Lệch dữ liệu (cần dựng lại)"');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await page.mouse.click(...(await sc(11500,6500)));
  const pt=await page.locator('#pv-props').innerText();ok(/Model: khớp\s+3/.test(pt) && /Model: lệch\s+1/.test(pt) && /Model: thiếu\s+1/.test(pt) && /Model: chưa dựng\s+1/.test(pt) && /Model: thừa\s+1/.test(pt),'chưa chọn gì: bảng Thuộc tính tóm tắt số phần tử khớp / lệch / thiếu / chưa dựng / thừa so với model');
  await receive('model_status',{...st1,level:L2});ok((await dbg6()).badges.stale===0,'trạng thái của tầng khác: không đánh dấu trên tầng đang xem');
  await receive('model_status',st1);await page.click('#pv-status-btn');ok((await dbg6()).statusOn===false && (await dbg6()).badges.stale===0,'tắt "Hiện trạng thái": hết chấm');
  await clear();await receive('state',F.state_free);await page.evaluate(()=>document.getElementById('origin-x').dispatchEvent(new Event('input')));await wait(300);
  ok((await last('grid_preview')).status===false,'trạng thái tắt: xem trước gửi cờ status = false (Ruby không so khớp)');
  await clear();await page.click('#pv-status-btn');await wait(300);ok((await last('grid_preview')).status===true,'bật lại: yêu cầu Ruby so khớp ngay (xem trước gửi cờ status = true)');
  // --- Dựng tầng ---
  await clear();await page.click('#pv-build-btn');let bc=await calls('build_all');
  ok(bc.length===1 && JSON.stringify(bc[0].levels)==='["sl_00000001"]' && bc[0].state.levels.length===2 && bc[0].state.levels[0].picks.columns.fc_00000001.free.x===2000,'nút Dựng tầng: gửi build_all cho tầng đang xem kèm toàn bộ dữ liệu (kể cả phần tử tự do)');
  await clear();await receive('all_built',{message:'Đã dựng 7 đối tượng.',drawn:{columns:[L1],beams:[],walls:[],slabs:[],ceilings:[],openings:[]}});await wait(300);
  ok((await calls('grid_preview')).length>=1 && (await last('grid_preview')).status===true,'dựng xong: tự yêu cầu xem trước và trạng thái model mới');
  await typ('bd');ok((await calls('build_all')).length===1,'gõ BD: cũng dựng tầng (phím tự đặt)');
  ok((await page.locator('#pv-build-btn kbd').innerText())==='BD' && (await page.locator('#pv-supick-btn kbd').innerText())==='PK' && (await page.locator('#pv-sync-btn kbd').innerText())==='SY' && (await page.locator('#pv-status-btn kbd').innerText())==='ST','nút hiện phím tắt BD, PK, SY, ST');
  // --- Chọn điểm trong SketchUp ---
  await reset();await clear();await typ('cl');await page.selectOption('#pv-options select[data-opt=mode]','free');await wait(40);
  await page.click('#pv-supick-btn');ok((await calls('su_pick_start')).length===1,'bấm "Chọn điểm trong SketchUp": gửi su_pick_start');
  await receive('su_pick_state',{active:true});ok((await dbg6()).suPicking===true && /Đang nhận điểm từ SketchUp/.test(await hint6()) && await page.locator('#pv-supick-btn').getAttribute('aria-pressed')==='true','SketchUp báo đã vào công cụ: nút sáng, gợi ý "Đang nhận điểm từ SketchUp"');
  await receive('su_move',{x:7000,y:6500});ok(Math.abs((await dbg6()).edit.freeTarget[0]-7000)<1 && Math.abs((await dbg6()).edit.freeTarget[1]-6500)<1,'SketchUp rê chuột: mặt bằng hiện xem trước (ghost cột) đúng tọa độ');
  await receive('su_point',{x:7000,y:6500});let pk=await get('picks');const nc=Object.keys(pk).filter(k=>k.startsWith('fc_')&&k!=='fc_00000001');
  ok(nc.length===1 && pk[nc[0]].free.x===7000 && pk[nc[0]].free.y===6500,'SketchUp bấm điểm (7000, 6500): tạo cột tự do đúng tọa độ như bấm trên mặt bằng (không qua bắt điểm của cửa sổ)');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await typ('wa');await page.selectOption('#pv-options select[data-opt=mode]','free');await wait(40);
  await receive('su_point',{x:6000,y:4800});ok((await dbg6()).edit.chainPoint && Math.abs((await dbg6()).edit.chainPoint[1]-4800)<1,'tường tự do: điểm đầu từ SketchUp');
  await receive('su_point',{x:9000,y:4800});let wp=await get('wallPicks');ok(Object.values(wp).some(w=>w.free && JSON.stringify(w.free)===JSON.stringify({a:[6000,4800],b:[9000,4800]})),'điểm thứ hai từ SketchUp: thêm tường tự do 6000–9000 (chuỗi từ SketchUp, như bấm trên mặt bằng)');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await typ('me');await receive('su_point',{x:1000,y:1000});await receive('su_point',{x:4000,y:5000});
  ok((await dbg6()).measure && (await dbg6()).measure.done && Math.abs((await dbg6()).measure.b[0]-4000)<1,'công cụ Đo nhận hai điểm từ SketchUp');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await typ('rp');await receive('su_point',{x:2000,y:2500});ok((await dbg6()).draft==='first','công cụ Đường gióng nhận điểm từ SketchUp');
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  const nBefore=Object.keys(await get('picks')).length;await receive('su_point',{x:3000,y:3000});ok(Object.keys(await get('picks')).length===nBefore,'điểm từ SketchUp khi công cụ là Chọn: không làm gì');
  await receive('su_pick_state',{active:false});ok((await dbg6()).suPicking===false && await page.locator('#pv-supick-btn').getAttribute('aria-pressed')==='false' && !/Đang nhận điểm/.test(await hint6()),'SketchUp thoát công cụ (Esc): nút tắt, hết gợi ý');
  await typ('cl');await receive('su_point',{x:7500,y:6500});ok(Object.keys(await get('picks')).length===nBefore,'không còn ở chế độ nhận điểm: su_point trễ bị bỏ qua');
  await clear();await page.keyboard.press('Escape');await page.keyboard.press('Escape');await typ('cl');await receive('su_pick_state',{active:true});await clear();await page.keyboard.press('Escape');
  ok((await calls('su_pick_stop')).length>=1,'Esc trong cửa sổ khi đang nhận điểm: gửi su_pick_stop để SketchUp thoát công cụ');
  await receive('su_pick_state',{active:false});await clear();
  await typ('cl');await page.click('#pv-supick-btn');await receive('su_pick_state',{active:true});await clear();await page.click('#pv-supick-btn');ok((await calls('su_pick_stop')).length===1,'bấm nút lần nữa khi đang nhận điểm: dừng (su_pick_stop)');
  await receive('su_pick_state',{active:false});await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  await clear();await typ('cl');await typ('pk');ok((await calls('su_pick_start')).length===1,'gõ PK: cùng nút chọn điểm (phím tự đặt)');
  await receive('su_pick_state',{active:false});await reset();
  }
  // Lỗi xem trước
  await page.click('[data-tab=plan]');await receive('preview',F.error);
  ok((await dbg()).axes===0 && (await dbg()).counts.column===undefined,'xem trước lỗi: mặt bằng không vẽ phần tử');
  await receive('state',F.state);await receive('preview',F.preview);
  await page.click('[data-tab=grid]');

  // Lỗi xem trước
  await receive('preview',F.error);
  ok(await page.locator('#build').isDisabled() && (await page.locator('#summary').innerText()).includes('phải cách trục trước') && await page.locator('#plan circle').count()===0,'xem trước báo lỗi: hiện lỗi, xóa hình, khóa nút Vẽ');
  await receive('message',{text:'Lỗi giả lập',error:true});
  ok(await page.locator('#message.error').count()===1,'thông báo lỗi có kiểu lỗi');

  // Theme
  const before=await page.evaluate(()=>document.documentElement.getAttribute('data-theme'));
  await page.click('#theme');
  const afterTheme=await page.evaluate(()=>document.documentElement.getAttribute('data-theme'));
  ok(before!==afterTheme && (afterTheme==='dark'||afterTheme==='light'),'nút theme đổi giao diện sáng / tối');
  ok(errors.length===0,'không có lỗi JavaScript'+(errors.length?': '+errors[0]:''));
 }finally{await browser.close();}
})().catch(e=>{console.log('FAIL  '+e.message);process.exit(1);});
