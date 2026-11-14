// Test trang báo cáo in PDF (HTML do core/table_report.rb tạo): không tự mở hộp in, nút In chạy, kéo mép tiêu đề chia lại độ rộng cột,
// nút đặt lại, giới hạn độ rộng tối thiểu, ẩn tay kéo khi in. Chạy: node dev/test_report_page.cjs (cần ruby; đặt VGD_PLAYWRIGHT_MODULE nếu cần)
const fs=require('fs'),os=require('os'),path=require('path'),{pathToFileURL}=require('url'),{execFileSync}=require('child_process');
const {chromium}=require(process.env.VGD_PLAYWRIGHT_MODULE || 'playwright');
let failed=0;const ok=(c,m)=>{console.log((c?'PASS  ':'FAIL  ')+m);if(!c){failed++;process.exitCode=1;}};
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'vgd_report_'));
const file=path.join(dir,'bao_cao.html');
const root=path.resolve(__dirname,'../runtime/vgd_bim');
const script=path.join(dir,'tao_trang.rb');
fs.writeFileSync(script,`
  require 'json'; module VGD; module BIM; def self.log(_m); end; end; end
  require '${root}/core/table_report'
  cols=[{'label'=>'STT','unit'=>'','type'=>'ordinal','digits'=>0,'width'=>44},{'label'=>'Tên','unit'=>'','type'=>'text','digits'=>0,'width'=>300},{'label'=>'Mô tả','unit'=>'','type'=>'text','digits'=>0,'width'=>156},{'label'=>'Rộng mm','unit'=>'mm','type'=>'number','digits'=>0,'width'=>100}]
  rows=(1..40).map{|i|{'kind'=>'row','cells'=>[i,'Tủ '+i.to_s,'Mô tả rất dài '*8,1200+i]}}
  r=VGD::BIM::TableReport.build({'title'=>'Bảng','preset'=>'X','decimal_separator'=>',','labels'=>{'model'=>'Mô hình','preset'=>'Preset','date'=>'Ngày','print'=>'In / Lưu PDF','reset'=>'Đặt lại độ rộng cột','hint'=>'Kéo mép'},'columns'=>cols,'rows'=>rows},'Nhà',->(_p){nil})
  File.write('${file}',VGD::BIM::TableReport.html(r),encoding:'UTF-8')
`,'utf8');
execFileSync('ruby',[script]);
(async()=>{
 const browser=await chromium.launch({headless:true,channel:process.env.VGD_BROWSER_CHANNEL||undefined});
 try{
  const page=await browser.newPage({viewport:{width:1100,height:800}});const errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{window.__prints=0;window.print=()=>{window.__prints++;};});
  await page.goto(pathToFileURL(file).href);
  await page.waitForTimeout(900);
  ok(await page.evaluate(()=>window.__prints)===0,'mở trang: KHÔNG tự gọi hộp in (người dùng tự bấm nút)');
  await page.getByRole('button',{name:'In / Lưu PDF'}).click();
  ok(await page.evaluate(()=>window.__prints)===1,'bấm nút In / Lưu PDF: gọi hộp in một lần');
  const pct=()=>page.evaluate(()=>[...document.querySelectorAll('col')].map(c=>parseFloat(c.style.width)));
  const px=()=>page.evaluate(()=>[...document.querySelectorAll('thead th')].map(t=>Math.round(t.getBoundingClientRect().width)));
  const start=await pct();
  ok(Math.abs(start.reduce((a,b)=>a+b,0)-100)<0.05 && Math.abs(start[1]/start[0]-300/44)<0.01,'độ rộng ban đầu theo tỉ lệ độ rộng trên màn hình (44 : 300 : 156 : 100), tổng 100%');
  const wBefore=await px();
  ok(wBefore[1]>wBefore[2],'cột Tên (300) rộng hơn cột Mô tả (156) như đã chỉnh trên màn hình');
  const handle=page.locator('thead th .rz').nth(1);
  const box=await handle.boundingBox();
  await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();await page.mouse.move(box.x+box.width/2-100,box.y+box.height/2,{steps:5});await page.mouse.up();
  const wAfter=await px(),after=await pct();
  ok(wAfter[1]<wBefore[1]-90 && wAfter[2]>wBefore[2]+90,'kéo mép cột Tên sang trái 100 px: Tên hẹp đi, Mô tả rộng thêm tương ứng');
  ok(Math.abs(after.reduce((a,b)=>a+b,0)-100)<0.05 && Math.abs(wAfter[0]-wBefore[0])<2 && Math.abs(wAfter[3]-wBefore[3])<2,'tổng vẫn 100%, các cột khác không đổi');
  await page.mouse.move(box.x+box.width/2-100,box.y+box.height/2);
  const h2=await handle.boundingBox();
  await page.mouse.move(h2.x+h2.width/2,h2.y+h2.height/2);await page.mouse.down();await page.mouse.move(h2.x-900,h2.y+h2.height/2,{steps:5});await page.mouse.up();
  const minPct=await pct();
  ok(minPct[1]>=2.99 && minPct[2]>start[1],'kéo quá xa: cột không hẹp hơn 3% (không biến mất)');
  await page.getByRole('button',{name:'Đặt lại độ rộng cột'}).click();
  const back=await pct();
  ok(back.every((v,i)=>Math.abs(v-start[i])<0.001),'nút Đặt lại độ rộng cột: về đúng độ rộng ban đầu');
  const last=page.locator('thead th').nth(3);
  ok(await last.locator('.rz').count()===0 && await page.locator('thead th .rz').count()===3,'cột cuối không có tay kéo (3 tay kéo cho 4 cột)');
  const wrap=await page.evaluate(()=>{const td=document.querySelectorAll('tbody tr')[0].children[2];return {h:td.getBoundingClientRect().height,over:td.scrollWidth>td.clientWidth+1};});
  ok(wrap.h>30 && !wrap.over,'chữ dài trong ô tự xuống dòng, không tràn ra ngoài ô');
  await page.emulateMedia({media:'print'});
  ok(await page.evaluate(()=>getComputedStyle(document.querySelector('.bar')).display)==='none' && await page.evaluate(()=>getComputedStyle(document.querySelector('.rz')).display)==='none','khi in: ẩn thanh nút và tay kéo');
  ok(errors.length===0,'không có lỗi JavaScript'+(errors.length?': '+errors.join('|'):''));
 }finally{await browser.close();fs.rmSync(dir,{recursive:true,force:true});}
 console.log(failed?`${failed} lỗi`:'Done');
})().catch(e=>{console.log('FAIL  '+e.message);process.exit(1);});
