const fs=require('fs'),path=require('path'),assert=require('assert');
const {pathToFileURL}=require('url'),{resolve}=require('./dependencies.cjs');
const {chromium}=require(resolve('playwright'));
(async()=>{
  const root=path.resolve(__dirname,'..'),output=path.join(root,'outputs','manager-preview');
  fs.mkdirSync(output,{recursive:true});
  const browser=await chromium.launch({headless:true,...(process.env.VGD_BROWSER_EXECUTABLE?{executablePath:process.env.VGD_BROWSER_EXECUTABLE}:{channel:'msedge'})});
  try{
    const page=await browser.newPage({viewport:{width:310,height:455},deviceScaleFactor:1}),errors=[];
    page.on('pageerror',error=>errors.push(error.message));
    await page.addInitScript(()=>{window.calls=[];window.sketchup=new Proxy({}, {get:(_target,name)=>(...args)=>window.calls.push({name:String(name),args})});});
    await page.goto(pathToFileURL(path.join(root,'runtime','vgd_reference','ui','web','index.html')).href);
    const thumbnail='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="160" height="90" viewBox="0 0 160 90"><rect width="160" height="90" fill="#d5dfda"/><path d="M0 90V60l45-35 55 50 25-22 35 37" fill="#758a77"/><circle cx="127" cy="20" r="9" fill="#ccab74"/></svg>');
    const mock={toolbar_theme:'light',
      items:[
        {id:'one',name:'Phòng bếp tham khảo.png',thumbnail,width:1600,height:900,visible:true,locked:false,opacity:100,selected:true},
        {id:'two',name:'Phòng khách.jpg',thumbnail,width:1200,height:800,visible:false,locked:true,opacity:75,selected:false}
      ],selected_id:'one',hidden_all:false,opacity_min:10
    };
    const lastCall=()=>page.evaluate(()=>calls.at(-1));
    for(const theme of ['light','dark']){
      await page.emulateMedia({colorScheme:theme});
      await page.evaluate(data=>VGDReference.render(data),mock);
      await page.locator('.brand-mark img').evaluate(img=>img.decode());
      assert.strictEqual(await page.locator('.item').count(),2);
      assert.strictEqual(await page.locator('#selectedControls').isVisible(),true);
      assert.strictEqual(await page.locator('#hideAll').innerText(),'Ẩn tất cả');
      const tokens=await page.evaluate(()=>{
        const style=getComputedStyle(document.documentElement);
        return {accent:style.getPropertyValue('--accent').trim(),outline:style.getPropertyValue('--icon-outline').trim(),glyph:document.querySelector('.brand-mark img').currentSrc,stroke:getComputedStyle(document.querySelector('.tools .ui-icon')).stroke};
      });
      assert.strictEqual(tokens.accent,'#A67C58');
      assert.strictEqual(tokens.outline,theme==='light'?'#292B2D':'#F1EDE6');
      assert(tokens.glyph.endsWith(theme==='light'?'vgd_reference.svg':'vgd_reference_dark.svg'),'Header theme asset mismatch');
      assert.strictEqual(tokens.stroke,theme==='light'?'rgb(41, 43, 45)':'rgb(241, 237, 230)');
      assert.strictEqual(await page.locator('#toolbarTheme').inputValue(),'light','Manager theme incorrectly changed the native toolbar setting');
      assert.strictEqual(await page.locator('.tools button svg').count(),6);
      assert.strictEqual(await page.getByRole('button',{name:'Ẩn ảnh',exact:true}).getAttribute('aria-pressed'),'true');
      assert.strictEqual(await page.getByRole('button',{name:'Khóa ảnh',exact:true}).getAttribute('aria-pressed'),'false');
      await page.mouse.move(1,1);
      await page.screenshot({path:path.join(output,'manager-'+theme+'.png')});
      await page.locator('#appearanceSettings').click();
      assert.strictEqual(await page.locator('#appearancePanel').isVisible(),true);
      await page.locator('#toolbarTheme').selectOption('dark');
      assert.deepStrictEqual(await lastCall(),{name:'setToolbarTheme',args:['dark']});
      await page.evaluate(data=>VGDReference.render({...data,toolbar_theme:'dark'}),mock);
      assert.strictEqual(await page.locator('#toolbarTheme').inputValue(),'dark','Saved setting was not restored by Ruby state');
      await page.mouse.move(1,1);
      await page.screenshot({path:path.join(output,'manager-'+theme+'-settings.png')});
      await page.keyboard.press('Escape');
      assert.strictEqual(await page.locator('#appearancePanel').isVisible(),false);
      const actions=[
        ['#add','addImage',[]],['#paste','pasteImage',[]],['#hideAll','hideAll',[]],['#editSelected','editSelected',[]],
        ['#crop','startCrop',['one']],['.item:nth-child(2)','selectReference',['two']],
        ['.item:first-child .tools button:nth-child(1)','toggleVisible',['one']],
        ['.item:first-child .tools button:nth-child(2)','toggleLock',['one']],
        ['.item:first-child .tools button:nth-child(3)','deleteReference',['one']]
      ];
      for(const [selector,name,args] of actions){await page.locator(selector).click();assert.deepStrictEqual(await lastCall(),{name,args});}
      await page.locator('#opacity').evaluate(element=>{element.value='60';element.dispatchEvent(new Event('input',{bubbles:true}));element.dispatchEvent(new Event('change',{bubbles:true}));});
      assert.deepStrictEqual(await page.evaluate(()=>calls.slice(-2)),[{name:'opacityPreview',args:['one',60]},{name:'commitOpacity',args:['one',60]}]);
      await page.setViewportSize({width:280,height:340});
      const fit=await page.evaluate(()=>Array.from(document.querySelectorAll('.actions button,.tools button,#crop,#opacity')).every(el=>{const r=el.getBoundingClientRect();return r.left>=0&&r.right<=innerWidth&&r.top>=0&&r.bottom<=innerHeight;}));
      assert(fit,'Controls escaped the minimum dialog size');
      await page.screenshot({path:path.join(output,'manager-'+theme+'-minimum.png')});
      await page.setViewportSize({width:310,height:455});
      await page.evaluate(()=>VGDReference.render({items:[],selected_id:null,hidden_all:true,opacity_min:10}));
      assert.strictEqual(await page.locator('#hideAll').innerText(),'Hiện tất cả');
      assert.strictEqual(await page.locator('.empty').innerText(),'Chưa có ảnh tham chiếu nào');
      await page.screenshot({path:path.join(output,'manager-'+theme+'-empty.png')});
    }
    assert.deepStrictEqual(errors,[],'Manager JavaScript errors: '+errors.join('; '));
    console.log('PASS: light/dark palette, runtime header glyph, Vietnamese states, SVG buttons, all existing action callbacks, opacity, and minimum 280×340 layout.');
    console.log('Previews saved: '+output);
  }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
