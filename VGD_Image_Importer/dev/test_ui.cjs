const fs = require('fs'), path = require('path'), assert = require('assert');
const { pathToFileURL } = require('url'), { resolve } = require('./dependencies.cjs');
const { chromium } = require(resolve('playwright'));
(async () => {
  const outputs = path.resolve(__dirname, '../outputs'); fs.mkdirSync(outputs, { recursive: true });
  const browser = await chromium.launch({headless:true,...(process.env.VGD_BROWSER_EXECUTABLE ? {executablePath:process.env.VGD_BROWSER_EXECUTABLE} : {channel:'msedge'})});
  try {
    const page = await browser.newPage({viewport:{width:860,height:720}}), errors=[];
    page.setDefaultTimeout(6000);
    page.on('pageerror', error => errors.push(error.message));
    await page.addInitScript(() => { window.calls=[]; window.sketchup={vgd_importer:(action,data)=>calls.push({action,data:JSON.parse(data)})}; });
    await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_image_importer/dialog.html')).href);
    const last = () => page.evaluate(() => calls.at(-1));
    const receive = (event,data) => page.evaluate(([event,data]) => VGDImporter.receive(event,data), [event,data]);
    assert((await last()).action==='ready','Missing ready handshake');
    assert(await page.locator('#import').isDisabled(),'Empty queue enabled import');
    await receive('settings',{theme:'light',importType:'comp_2d',version:'1.1.0-beta.4'});
    await page.check('#recursive'); await page.click('#chooseFolder');
    assert.deepStrictEqual((await last()).data,{kind:'folder',recursive:true},'Recursive folder callback wrong');
    await page.click('#chooseFiles'); assert((await last()).data.kind==='files','File picker callback wrong');
    assert(!(await page.locator('.source-pane>.hint').innerText()).includes('Cancel'),'Old cancel-to-finish flow still documented');
    // Decode real lossless WebP with transparency, then inspect actual PNG bytes.
    const webp=await page.evaluate(()=>{const canvas=document.createElement('canvas');canvas.width=4;canvas.height=3;const ctx=canvas.getContext('2d');ctx.fillStyle='#d27634';ctx.fillRect(0,0,2,3);return canvas.toDataURL('image/webp',1).split(',')[1]});
    fs.writeFileSync(path.join(outputs,'transparent.webp'),Buffer.from(webp,'base64'));
    await receive('convert',{token:'webp-test',id:9,name:'Ảnh trong suốt.webp',mime:'image/webp',base64:webp});
    await page.waitForFunction(()=>calls.some(call=>call.action==='converted' && call.data.token==='webp-test'));
    const converted=(await last()).data;
    assert(converted.id===9 && !converted.error && Buffer.from(converted.base64,'base64').subarray(0,8).equals(Buffer.from('89504e470d0a1a0a','hex')),'WebP did not produce PNG');
    const pixels=await page.evaluate(async base64=>{const image=new Image();image.src='data:image/png;base64,'+base64;await image.decode();const c=document.createElement('canvas');c.width=image.width;c.height=image.height;const ctx=c.getContext('2d');ctx.drawImage(image,0,0);return {width:image.width,height:image.height,alpha:ctx.getImageData(3,1,1,1).data[3]};},converted.base64);
    assert.deepStrictEqual(pixels,{width:4,height:3,alpha:0},'Converted PNG lost size or alpha');
    fs.writeFileSync(path.join(outputs,'converted_webp.png'),Buffer.from(converted.base64,'base64'));
    // Browser decoder also accepts GIF and SVG; corrupt images return a named error.
    for(const [id,mime,bytes] of [
      [10,'image/gif',Buffer.from('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7','base64')],
      [11,'image/svg+xml',Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="8" height="5"><rect width="8" height="5" fill="red"/></svg>')]
    ]) {
      await receive('convert',{token:'other-'+id,id,name:'format-'+id,mime,base64:bytes.toString('base64')});
      await page.waitForFunction(token=>calls.some(call=>call.action==='converted' && call.data.token===token),'other-'+id);
      assert(!(await last()).data.error, mime+' conversion failed');
    }
    await receive('convert',{token:'corrupt',id:12,name:'corrupt.webp',mime:'image/webp',base64:Buffer.from('broken').toString('base64')});
    await page.waitForFunction(()=>calls.some(call=>call.action==='converted' && call.data.token==='corrupt'));
    assert((await last()).data.error,'Corrupt image not reported');
    const realFormats=path.join(outputs,'formats');
    if(fs.existsSync(realFormats)) {
      for(const [extension,mime] of [['webp','image/webp'],['gif','image/gif'],['avif','image/avif'],['ico','image/x-icon'],['svg','image/svg+xml'],['jfif','image/jpeg']]) {
        const bytes=fs.readFileSync(path.join(realFormats,'Ảnh người #1.'+extension)), token='real-'+extension;
        await receive('convert',{token,id:20,name:'Ảnh người #1.'+extension,mime,base64:bytes.toString('base64')});
        await page.waitForFunction(token=>calls.some(call=>call.action==='converted' && call.data.token===token),token);
        const result=(await last()).data;
        assert(!result.error,'Real '+extension+' failed: '+result.error);
        fs.writeFileSync(path.join(realFormats,'decoded_'+extension+'.png'),Buffer.from(result.base64,'base64'));
      }
    }
    const iconPath = path.resolve(__dirname,'../runtime/vgd_image_importer/vgd_icon.png');
    const samples = [
      {id:0,name:'Cây xanh 01.png',path:iconPath},
      {id:1,name:'Người đi bộ 02.png',path:iconPath},
      {id:2,name:'Mặt bằng tầng 1.tiff',path:'C:/VGD/Photos/Mặt bằng tầng 1.tiff'},
      {id:3,name:'Ảnh tham chiếu 04.png',path:iconPath}
    ];
    await receive('files',samples);
    await page.screenshot({path:path.join(outputs,'vgd_image_importer_light.png')});
    await page.locator('.remove').first().click(); assert((await last()).action==='remove' && (await last()).data.id===0,'Removal callback wrong');
    await page.selectOption('#scaleMethod','width'); assert(await page.locator('#widthRow').isVisible() && !await page.locator('#pixelRow').isVisible(),'Width UI missing');
    await page.fill('#targetWidth','2400'); await page.fill('#spacing','0'); await page.click('[data-type=flat]');
    assert(!await page.locator('#faceCamRow').isVisible(),'Flat billboard setting visible');
    await page.click('#import'); await page.waitForFunction(() => calls.some(c=>c.action==='import'));
    let imported = await page.evaluate(() => calls.filter(c=>c.action==='import').at(-1));
    assert(imported.data.spacing===0 && imported.data.targetWidth===2400 && imported.data.importType==='flat','Import options wrong');
    assert(await page.locator('#import').isDisabled() && await page.locator('#clear').isDisabled(),'Busy controls enabled');
    await receive('result',{imported:3,failed:1,errors:[{name:'<img src=x onerror="window.injected=true">',message:'Không đọc được ảnh'}]});
    assert(await page.locator('#resultDialog').isVisible(),'Result missing');
    assert(!await page.evaluate(()=>window.injected),'Error name injected HTML');
    await page.click('#closeResult');
    await page.click('[data-type=texture_only]'); assert(!await page.locator('#layoutCard').isVisible(),'Materials layout visible');
    await page.click('[data-type=comp_2d]'); await page.selectOption('#scaleMethod','pixel');
    await page.fill('#itemsPerRow','0'); const before=await page.evaluate(()=>calls.filter(c=>c.action==='import').length);
    await page.click('#import'); assert((await page.evaluate(()=>calls.filter(c=>c.action==='import').length))===before,'Zero row count sent');
    assert(await page.locator('#status.error').count()===1,'Invalid input feedback missing');
    await page.fill('#itemsPerRow','10'); await page.click('#theme');
    assert(await page.locator('body.dark').count()===1 && (await last()).data.theme==='dark','Theme not persisted');
    await receive('status',{message:'Đã chọn 4 ảnh. Kiểm tra cấu hình rồi nhập.'});
    await page.screenshot({path:path.join(outputs,'vgd_image_importer_dark.png')});
    await page.setViewportSize({width:540,height:500});
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'Minimum width overflows');
    assert(await page.locator('#import').isVisible(),'Compact import button hidden');
    await page.screenshot({path:path.join(outputs,'vgd_image_importer_compact.png')});
    await page.click('#clear'); assert((await last()).action==='clear','Clear callback wrong');
    await receive('files',[]); assert(await page.locator('#import').isDisabled() && await page.locator('#empty').isVisible(),'Empty state not restored');
    assert.deepStrictEqual(errors,[],'Browser script errors');
    console.log('PASS: real WebP/GIF/SVG to PNG; alpha/dimensions; optional AVIF/ICO/JFIF fixture matrix; corrupt image errors; source callbacks, queue, import options, validation, busy state, theme and compact layout.');
  } finally { await browser.close(); }
})().catch(error=>{console.error(error);process.exitCode=1;});
