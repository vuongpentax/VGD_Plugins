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

  ok((await calls('ready')).length===1,'mở cửa sổ: giao diện báo ready cho Ruby một lần');
  await receive('state',F.state);await receive('preview',F.preview);
  ok(JSON.stringify(await names('x'))==='["1","2","3","4"]' && JSON.stringify(await names('y'))==='["A","B","C"]','bảng trục: 4 trục đứng 1-4 và 3 trục ngang A-C');
  ok(JSON.stringify(await spans('x'))==='["0","4200","4200","4200"]' && JSON.stringify(await positions('x'))==='["0","4200","8400","12600"]','nhịp và vị trí cộng dồn đúng; trục đầu không sửa được nhịp');
  ok(await page.locator('#axes-x tr:nth-child(2) td:nth-child(2) input').isDisabled(),'ô nhịp của trục đầu bị khóa (luôn 0)');
  ok(/4 trục đứng × 3 trục ngang: 12 giao điểm, 17 nhịp, 6 ô\. Khung lưới 12600 × 7200 mm\./.test(await page.locator('#summary').innerText()),'tóm tắt do Ruby tính hiện đúng');
  ok(await page.locator('#plan line.axis').count()===7 && await page.locator('#plan circle.bubble').count()===7 && await page.locator('#plan circle.node').count()===12,'xem trước SVG: 7 đường trục, 7 vòng tròn ký hiệu, 12 giao điểm');
  ok(JSON.stringify(await page.locator('#plan text').evaluateAll(l=>l.map(t=>t.textContent)))==='["1","2","3","4","A","B","C"]','tên trục nằm trong vòng tròn');
  ok((await page.locator('#build').innerText())==='Vẽ lưới trục' && await page.locator('#build').isEnabled() && await page.locator('#remove').isDisabled(),'chưa có lưới trong model: nút Vẽ bấm được, Xóa bị khóa');
  ok((await page.locator('#version').innerText())==='v0.2.0-beta.1','hiện phiên bản plugin');

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
