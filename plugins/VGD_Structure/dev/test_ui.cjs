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
  ok((await page.locator('#version').innerText())==='v0.10.0-beta.4','hiện phiên bản plugin');

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
  ok(lr.length===2 && lr[0][0]==='Tầng 1' && lr[0][1]==='0' && lr[0][2]==='120' && lr[0][5]==='Cột cao 3480 mm' && lr[1][5]==='Tầng trên cùng: chỉ có sàn','bảng tầng: 2 tầng, tầng 1 cột cao 3480 (3600 - 120), tầng trên cùng chỉ có sàn');
  ok(await page.locator('#types-table button.del').first().isDisabled(),'còn một loại cột thì không xóa được');
  // sửa cao độ tầng 2
  await clear();
  await page.locator('#levels-table tr:nth-child(3) td:nth-child(2) input').fill('4000');await wait();
  ok((await levelRows())[0][5]==='Cột cao 3880 mm','đổi cao độ tầng 2 thành 4000: ghi chú cột tầng 1 cập nhật ngay (3880)');
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
  ok(JSON.stringify(await page.locator('#level-select option').allInnerTexts())==='["Tầng 1","Tầng 2"]' && (await page.locator('#level-note').innerText())==='Cột cao 3480 mm','chọn tầng đang xem; ghi chú chiều cao cột');
  ok(await page.locator('#plan2 rect.col').count()===2 && await page.locator('#plan2 rect.ghost').count()===10,'mặt bằng: 2 cột đã chọn và 10 giao điểm còn lại (khung chấm để bấm chọn)');
  ok(/Tầng 1: 2 cột, cao 3480 mm/.test(await page.locator('#col-summary').innerText()),'tóm tắt cột của tầng');
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
  ok(/Tầng 1: 2 dầm, đỉnh dầm tại cao độ 3480 mm/.test(await page.locator('#beam-summary').innerText()),'tóm tắt dầm: số dầm, cao độ đỉnh');
  ok((await page.locator('#beam-level-note').innerText()).includes('3480') && await page.locator('#build-beams').isEnabled() && await page.locator('#remove-beams').isDisabled(),'ghi chú đỉnh dầm; Dựng bấm được, Xóa khóa khi chưa dựng');
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
  ok(/Tầng 1: 2 tường, từ cao độ 0 mm/.test(await page.locator('#wall-summary').innerText()),'tóm tắt tường: số tường, cao độ chân');
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
  ok(lr3[0][3]==='2800' && lr3[0][4]==='9','bảng tầng có cao trần 2800 và dày trần 9');
  await clear();
  await page.locator('#levels-table tr:nth-child(2) td:nth-child(4) input').fill('3000');
  await page.locator('#levels-table tr:nth-child(2) td:nth-child(5) input').fill('12');await wait();
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
  const dbg=()=>page.evaluate(()=>window.VGDPlan.debug());
  const pix=async(wx,wy)=>page.evaluate(([x,y])=>{const c=document.getElementById('pv-canvas'),p=window.VGDPlan.toScreen(x,y),d=c.getContext('2d').getImageData(Math.round(p[0]*window.devicePixelRatio),Math.round(p[1]*window.devicePixelRatio),1,1).data;return [d[0],d[1],d[2]];},[wx,wy]);
  ok(await page.locator('#tab-plan').isVisible() && !(await page.locator('#tab-grid').isVisible()),'tab Mặt bằng: hiện canvas, ẩn tab khác');
  let d0=await dbg();
  ok(d0.axes===7 && d0.counts.column===12 && d0.counts.slab===6 && d0.counts.wall>0 && d0.counts.beam>0 && d0.counts.ceiling===6,'mặt bằng nhận đủ phần tử từ xem trước: 7 trục, 12 cột, 6 sàn, tường, dầm, 6 trần');
  ok(d0.view.s>0.01 && d0.size.w>300 && d0.size.h>200,'tự vừa khung lần đầu, canvas có kích thước');
  const col=F.preview_all_cells.columns.items[0].center,c0=await pix(col[0],col[1]);
  ok(c0[1]>c0[0] && c0[1]>c0[2] && c0[1]>150,'pixel tại tâm cột có màu xanh lá (cột được vẽ trên canvas)');
  ok(await page.locator('#pv-tabs .pv-tab').count()===F.state.levels.length && (await page.locator('#pv-tabs [aria-selected=true]').getAttribute('data-level'))===F.state.levels[0].id,'tab theo tầng: đủ số tầng, đang chọn tầng hiện hành');
  ok(await page.locator('#pv-top .pv-ic[data-tool=select]').isEnabled() && await page.locator('#pv-top .pv-ic[data-tool=pan]').isEnabled() && await page.locator('#pv-side .pv-ic:disabled').count()===16 && await page.locator('#pv-side .pv-ic:not(:disabled)').count()===0,'cột công cụ bên trái: 16 nút vẽ khóa (làm ở cột mốc sau); thanh trên có Chọn và Kéo dùng được');
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
  const scr=async(x,y)=>{const q=await page.evaluate(([a,b])=>window.VGDPlan.toScreen(a,b),[x,y]);return [box.x+q[0],box.y+q[1]];};
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
  const snapAtW=async(x,y)=>{const q=await scr(x,y);await page.mouse.move(q[0]+3,q[1]+2);await wait(30);return dbg();};
  let sd=await snapAtW(k1.center[0]-k1.w/2,k1.center[1]-k1.d/2);
  ok(sd.snap && sd.snap.text==='Đầu mút' && sd.snap.rank===0 && Math.hypot(sd.snap.p[0]-(k1.center[0]-k1.w/2),sd.snap.p[1]-(k1.center[1]-k1.d/2))<1,'bắt điểm: gần góc cột hiện "Đầu mút" và hít đúng tọa độ góc');
  sd=await snapAtW(gx[2],gy[1]);
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
  await type('wa');ok(/Tường \(Wall\) \(WA\).*cột mốc sau/.test(await page.locator('#pv-hint').innerText()) && (await dbg()).tool==='select','gõ WA: lệnh Tường chưa làm, báo rõ và không đổi công cụ');
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
