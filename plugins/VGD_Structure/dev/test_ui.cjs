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
  ok((await page.locator('#version').innerText())==='v0.3.0-beta.1','hiện phiên bản plugin');

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
  ok(lr.length===2 && lr[0][0]==='Tầng 1' && lr[0][1]==='0' && lr[0][2]==='120' && lr[0][3]==='Cột cao 3480 mm' && lr[1][3]==='Tầng trên cùng: chỉ có sàn','bảng tầng: 2 tầng, tầng 1 cột cao 3480 (3600 - 120), tầng trên cùng chỉ có sàn');
  ok(await page.locator('#types-table button.del').first().isDisabled(),'còn một loại cột thì không xóa được');
  // sửa cao độ tầng 2
  await clear();
  await page.locator('#levels-table tr:nth-child(3) td:nth-child(2) input').fill('4000');await wait();
  ok((await levelRows())[0][3]==='Cột cao 3880 mm','đổi cao độ tầng 2 thành 4000: ghi chú cột tầng 1 cập nhật ngay (3880)');
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
  await page.locator('#levels-table tr:nth-child(2) select').selectOption({label:'C40x60'});await wait();
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
