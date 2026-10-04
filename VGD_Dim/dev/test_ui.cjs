const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const deps=process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES;
if(!deps)throw Error('Set CODEX_PRIMARY_RUNTIME_NODE_MODULES');
const {chromium}=require(path.join(deps,'playwright'));
const assert=(v,m)=>{if(!v)throw Error(m);};
(async()=>{
  const browser=await chromium.launch({headless:true,...(process.env.VGD_BROWSER_PATH?{executablePath:process.env.VGD_BROWSER_PATH}:{channel:'msedge'})});
  try {
    const page=await browser.newPage({viewport:{width:560,height:650}});
    const errors=[];page.on('pageerror',e=>errors.push(e.message));
    await page.addInitScript(()=>{
      window.calls=[];window.alerts=[];
      window.alert=message=>alerts.push(message);
      window.sketchup=new Proxy({},{get:(_,action)=>payload=>calls.push({action,payload})});
    });
    await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/VGD_Dim/dialog.html')).href);
    assert((await page.title()).includes('VGD') && (await page.locator('header').innerText()).includes('ĐANG CHỌN'),'Brand/scope absent');
    const palette=await page.evaluate(()=>({button:getComputedStyle(document.querySelector('#apply')).backgroundColor,body:getComputedStyle(document.body).backgroundColor,header:getComputedStyle(document.querySelector('header')).backgroundColor}));
    assert(palette.button==='rgb(180, 137, 99)' && palette.body==='rgb(247, 247, 245)' && palette.header==='rgb(43, 43, 43)','Cabinet style changed');
    const last=async()=>page.evaluate(()=>calls.at(-1));
    await page.click('#apply');
    let call=await last(),s=JSON.parse(call.payload);
    assert(call.action==='apply' && s.dim_color==='#000000' && s.text_color==='#000000' && s.dim_endpoint==='keep' && s.label_endpoint==='keep','Defaults wrong');
    assert(Object.keys(s).sort().join(',')==='dim_color,dim_endpoint,label_endpoint,text_color','Apply includes unsupported/global fields');
    await page.locator('#dim_color').fill('#112233');await page.locator('#text_color').fill('#aabbcc');
    await page.selectOption('#dim_endpoint','dot');await page.selectOption('#label_endpoint','open');
    await page.click('#apply');s=JSON.parse((await last()).payload);
    assert(s.dim_color==='#112233' && s.text_color==='#aabbcc' && s.dim_endpoint==='dot' && s.label_endpoint==='open','Changed style wrong');
    assert(await page.locator('.tag').allTextContents().then(v=>v.join(',')==='000 DIM,000 TEXT'),'Tag names wrong');
    assert(await page.locator('#size,#size_unit,#unit,#precision,#show_unit,.deep,#open_dim_info,#open_text_info').count()===0,'Fake font/global/deep scan controls remain');
    assert(await page.locator('main').innerText().then(t=>t.includes('Height') && t.includes('Model Info') && t.includes('vùng chọn')),'Model Info route not explained');
    await page.click('#dim_info');assert((await last()).action==='dim_info','Dim Model Info callback wrong');
    await page.click('#text_info');assert((await last()).action==='text_info','Text Model Info callback wrong');
    await page.evaluate(()=>VGDForm.busy(true));
    assert(await page.locator('#apply').isDisabled() && await page.locator('#dim_info').isDisabled() && await page.locator('#text_info').isDisabled(),'Duplicate apply enabled');
    await page.evaluate(()=>VGDForm.busy(false));
    assert(await page.locator('#apply').isEnabled(),'Apply stayed disabled');
    await page.evaluate(()=>VGDForm.error('Hãy chọn Dim hoặc Text trước khi APPLY.'));
    assert(await page.locator('#error').isVisible(),'Error not inline');
    await page.click('#apply');
    assert(await page.locator('#error').isHidden() && await page.evaluate(()=>alerts.length)===0,'Apply retained error or showed alert');
    await page.click('#cancel');assert((await last()).action==='cancel','Cancel wrong');
    const output=path.resolve(__dirname,'../outputs');fs.mkdirSync(output,{recursive:true});
    await page.reload();
    for(const [width,height] of [[560,650],[540,590]]){
      await page.setViewportSize({width,height});
      await page.locator('main').evaluate(e=>e.scrollTop=0);
      const layout=await page.evaluate(()=>({
        overflow:document.documentElement.scrollWidth>innerWidth,
        footer:document.querySelector('footer').getBoundingClientRect().bottom<=innerHeight,
        main:document.querySelector('main').clientHeight>100
      }));
      assert(!layout.overflow && layout.footer && layout.main,'Clipped layout '+width);
      await page.screenshot({path:path.join(output,'vgd_selection_'+width+'.png')});
    }
    assert(errors.length===0,errors.join(';'));
    console.log('PASS: selection-only UI, endpoint/color payload, exact tags, Model Info actions, busy state, no fake size/global units/deep scan, inline errors, no alerts and footer');
  }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
