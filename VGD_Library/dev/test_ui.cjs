const fs = require('fs'), path = require('path'), { pathToFileURL } = require('url');
const { resolve } = require('./dependencies.cjs'), { chromium } = require(resolve('playwright'));
const version = fs.readFileSync(path.resolve(__dirname,'../runtime/vgd_library.rb'),'utf8').match(/VERSION\s*=\s*'([^']+)'/)[1];
function assert(ok, message) { if (!ok) throw Error(message); }
(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.VGD_BROWSER_EXECUTABLE ? { executablePath: process.env.VGD_BROWSER_EXECUTABLE } : { channel: 'msedge' }) });
  try {
    const page = await browser.newPage({ viewport: { width: 1120, height: 760 } }); page.setDefaultTimeout(6000);
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    await page.addInitScript(() => { window.calls = []; window.sketchup = { vgd: (action, data) => calls.push({ action, args: JSON.parse(data) }) }; });
    await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_library/dialog.html')).href);
    assert((await page.evaluate(() => calls[0])).action === 'ready', 'Initial handshake');
    assert(await page.locator('#apply').isDisabled(), 'Empty selection can apply');
    const svg = color => 'data:image/svg+xml,' + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200"><rect width="200" height="200" fill="${color}"/></svg>`);
    const items = Array.from({ length: 67 }, (_,i) => ({ id:String(i), name:i === 0 ? 'Gỗ sồi A01' : `Map ${i}`, root:'C:/VGD/Materials', category:i % 2 ? 'Đá' : 'Gỗ', format:'PNG', preview:svg(i%2 ? '#aea69b' : '#b49a76') }));
    items[66].name = '<img src=x onerror="window.injected=true">';
    const receive = (method, ...args) => page.evaluate(([method,args]) => VGD[method](...args), [method,args]);
    await receive('begin',{ roots:['C:/VGD/Materials'], favorites:['0'], version });
    await receive('append',items,true,[]);
    await receive('model',{ materials:[],current:null,model_id:'fixture-model' });
    assert(await page.locator('.card').count() === 60, 'Catalog not paginated');
    await page.click('#next'); assert(await page.locator('.card').count()===7, 'Second page incorrect');
    assert(!await page.evaluate(() => window.injected), 'Filename HTML executed');
    await page.fill('#search','go soi'); assert(await page.locator('.card').count()===1, 'Accent-insensitive search');
    await page.locator('.swatch').click(); await page.fill('#width','1220'); await page.fill('#height','2440'); await page.click('#apply');
    let call = await page.evaluate(() => calls.at(-1)); assert(call.action==='apply' && call.args.id==='0' && call.args.width==='1220', 'Apply/dimension payload');
    await page.locator('.favorite').click(); call=await page.evaluate(() => calls.at(-1)); assert(call.action==='favorite' && call.args.id==='0', 'Favorite payload');
    await page.fill('#search',''); await page.click('[data-view="favorites"]'); assert(await page.locator('.card').count()===1, 'Favorite filter');
    await receive('favorites',[]); assert(await page.locator('.card').count()===0, 'Unfavorite did not update');
    await receive('model',{ materials:[{name:'ModelOak',label:'Sồi trong model',color:'#ac987c',width:1200,height:2400}], current:'ModelOak',model_id:'fixture-model' });
    await page.click('[data-view="model"]'); await page.locator('.swatch').click(); await page.click('#apply');
    call=await page.evaluate(() => calls.at(-1)); assert(call.action==='apply_model' && call.args.name==='ModelOak', 'Model material routed as file');
    assert(await page.inputValue('#width')==='1200', 'Model dimensions not displayed');
    await page.click('.inspector [data-action="rotate"]'); assert((await page.evaluate(() => calls.at(-1))).action==='rotate', 'Texture action payload');
    await page.fill('#angle','-30'); await page.click('#rotateAngle'); assert((await page.evaluate(() => calls.at(-1))).args.angle==='-30', 'Custom angle');
    await receive('feedback','Không có mặt được chọn.',true); assert(await page.locator('#status').getAttribute('class')==='error', 'Error not displayed');
    // Regression: a full HTML response previously expanded the footer to the
    // entire window and collapsed the material library to zero height.
    const actualResponse = path.resolve(__dirname,'../outputs/drive_response.html');
    const htmlResponse = fs.existsSync(actualResponse) ? fs.readFileSync(actualResponse,'utf8') : '<!DOCTYPE html><html><body>'+'<div>Drive folder</div>'.repeat(50000)+'</body></html>';
    for (const viewport of [{width:1120,height:760},{width:720,height:600}]) {
      await page.setViewportSize(viewport);
      for (const message of ['Nguồn online: unexpected token at '+htmlResponse, 'Thông báo dài '.repeat(60000)]) {
        await receive('append',[],true,[message]);
        const layout = await page.evaluate(() => ({ footer:document.querySelector('footer').getBoundingClientRect().height, workspace:document.querySelector('.workspace').getBoundingClientRect().height, text:document.querySelector('#status').textContent, title:document.querySelector('#status').title, scrollWidth:document.documentElement.scrollWidth, width:innerWidth }));
        assert(layout.footer===38 && layout.workspace===viewport.height-110 && layout.scrollWidth<=layout.width, 'Error message collapsed or overflowed the library');
        assert(layout.text.length<=500 && layout.title.length<=500 && !layout.text.includes('<html'), 'Raw or unbounded response leaked to status');
        assert(await page.locator('.card').count()>0 && await page.locator('#addFolder').isVisible(), 'Library controls disappeared after source error');
      }
      // CSS protects the viewport even if a future bridge bypasses feedback().
      await page.evaluate(text => { document.querySelector('#status').textContent=text; },htmlResponse);
      assert(await page.locator('footer').evaluate(el=>el.getBoundingClientRect().height)===38,'Footer missing independent CSS height guard');
    }
    await page.setViewportSize({width:1120,height:760});
    await receive('feedback','Nguồn trả về trang web, không phải danh mục JSON.',true);
    fs.mkdirSync(path.resolve(__dirname,'../outputs'),{recursive:true});
    await page.screenshot({path:path.resolve(__dirname,'../outputs/drive_error_fixed.png')});
    await page.click('[data-view="library"]'); await page.selectOption('#category','Gỗ'); assert(await page.locator('.card').count()===34, 'Category filter');
    await page.locator('.folder-row .remove').click(); assert((await page.evaluate(() => calls.at(-1))).action==='remove_folder', 'Remove source action');
    const out=path.resolve(__dirname,'../outputs'); fs.mkdirSync(out,{recursive:true});
    await page.selectOption('#category',''); await page.fill('#search','go soi'); await page.locator('.swatch').click(); await page.fill('#search','');
    await receive('feedback','Đã đọc 67 mẫu. Chọn vật liệu và tô lên vùng chọn.');
    await page.evaluate(() => document.querySelector('.inspector').scrollTop=0); await page.screenshot({path:path.join(out,'vgd_library_preview.png')});
    await page.setViewportSize({width:720,height:600});
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'Minimum dialog width overflows');
    await page.screenshot({path:path.join(out,'vgd_library_compact.png')});
    // Library assets route SKP placement separately from image/SKM painting.
    await page.setViewportSize({width:1120,height:760});
    await receive('begin',{roots:['C:/VGD/Assets'],online_roots:[{id:'online:test',label:'Kho VGD'}],favorites:['door'],version});
    await receive('append',[
      {id:'door',name:'Cánh tủ DC',kind:'model',format:'SKP',category:'Cánh tủ',root:'C:/VGD/Assets'},
      {id:'wood',name:'Sồi tự nhiên',kind:'material',format:'PNG',category:'Gỗ',root:'C:/VGD/Assets',preview:svg('#ba9d77')},
      {id:'online-door',name:'Model online',kind:'model',format:'SKP',category:'Model',root:'online:test',online:true,preview:svg('#747e74')}
    ],true,[]);
    await page.click('[data-view="models"]'); assert(await page.locator('.card').count()===2,'SKP library missing');
    assert((await page.evaluate(() => calls)).some(c => c.action==='thumbnails' && c.args.ids.includes('door')),'SKP thumbnail not requested');
    await receive('thumbnail','door',svg('#ab9478'));
    await page.locator('.card').filter({hasText:'Cánh tủ DC'}).locator('.swatch').click(); await page.click('#apply');
    call=await page.evaluate(() => calls.at(-1)); assert(call.action==='insert' && call.args.id==='door' && call.args.model_id==='fixture-model','SKP not routed to insert');
    await page.click('[data-view="online"]'); assert(await page.locator('.card').count()===1,'Online filter incorrect');
    await page.click('#connectDrive'); assert((await page.evaluate(() => calls.at(-1))).action==='connect_drive','Drive sync source action missing');
    await page.click('#openDrive'); assert((await page.evaluate(() => calls.at(-1))).action==='open_drive','Drive folder action missing');
    await page.click('#importCatalog'); assert((await page.evaluate(() => calls.at(-1))).action==='import_catalog','Catalog import action missing');
    await page.click('[data-view="tools"]'); assert(await page.locator('#toolsPanel').isVisible() && !await page.locator('#grid').isVisible(),'Tools panel not accessible');
    await page.selectOption('#replaceScope','one'); await page.uncheck('#keepSize'); await page.click('#toolsPanel [data-action="replace_pick"]');
    call=await page.evaluate(() => calls.at(-1)); assert(call.action==='replace_pick' && call.args.replace_scope==='one' && call.args.keep_size===false,'Object replacement settings ignored');
    await page.fill('#traceColors','6'); await page.fill('#traceTolerance','0.5'); await page.click('#toolsPanel [data-action="trace"]');
    call=await page.evaluate(() => calls.at(-1)); assert(call.action==='trace' && call.args.colors==='6' && call.args.remove_background===true,'Convert line settings ignored');
    await page.selectOption('#auxKind','stone'); await page.click('#toolsPanel [data-action="aux"]');
    call=await page.evaluate(() => calls.at(-1)); assert(call.action==='aux' && call.args.kind==='stone','Auxiliary export settings ignored');
    await receive('audit',[{id:'123',face:'<img src=x onerror="window.injected=true">',shell:'Sồi'}]);
    assert((await page.locator('#auditResult').innerText()).includes('123') && !await page.evaluate(() => window.injected),'Nesting audit unsafe or missing');
    await page.selectOption('#nestStrategy','faces'); await page.click('#toolsPanel [data-action="fix_nesting"]');
    assert((await page.evaluate(() => calls.at(-1))).args.strategy==='faces','Fix nesting strategy not sent');
    await page.evaluate(() => document.querySelector('main').scrollTop=0); await page.screenshot({path:path.join(out,'vgd_library_tools.png')});
    await page.click('[data-view="models"]'); await page.screenshot({path:path.join(out,'vgd_library_models.png')});
    const seam=await browser.newPage({viewport:{width:980,height:700}}); seam.on('pageerror',error=>errors.push(error.message));
    await seam.addInitScript(() => { window.calls=[];window.sketchup={seam:(action,data)=>calls.push({action,args:JSON.parse(data)})}; });
    await seam.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_library/seamless.html')).href);
    await seam.evaluate(() => VGDSeam.start(['Sồi','Đá']));
    assert((await seam.evaluate(() => calls.at(-1))).action==='preview','Seamless preview handshake');
    await seam.evaluate(data => VGDSeam.preview(data),{index:0,before:svg('#af9572'),after:svg('#baa27e'),before_error:22,after_error:0,width:512,height:512});
    await seam.click('#apply'); call=await seam.evaluate(() => calls.at(-1)); assert(call.action==='apply' && call.args.flatten===50,'Seamless apply ignored options');
    await seam.evaluate(() => VGDSeam.message('Đã áp dụng')); await seam.selectOption('#preset','strong'); await seam.waitForTimeout(450);
    call=await seam.evaluate(() => calls.at(-1)); assert(call.action==='preview' && call.args.flatten===80 && call.args.feather===7,'Seamless preset not recalculated');
    await seam.evaluate(() => VGDSeam.message('Kiểm tra ảnh trước khi áp dụng')); await seam.screenshot({path:path.join(out,'vgd_library_seamless.png')});
    assert(errors.length===0, errors.join('; '));
    console.log('PASS: real Drive HTML and oversized errors keep 38px footer and full workspace at 1120/720px; library/model/online filters, SKP insert/thumbnails, favorites, tool actions/settings, audit safety, tracing/aux payloads, seamless preview/apply/presets.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode=1; });
