const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const {chromium}=require(process.env.VGD_PLAYWRIGHT_MODULE || 'playwright');
const assert=(ok,message)=>{if(!ok)throw Error(message);};
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.VGD_BROWSER_EXECUTABLE});
 try{
  const page=await browser.newPage({viewport:{width:640,height:780}});
  const errors=[];page.on('pageerror',error=>errors.push(error.message));
  await page.addInitScript(()=>{window.calls=[];window.sketchup={ready(){},action(value){calls.push(JSON.parse(value));}};});
  await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_scenes/dialog.html')).href);
  let state={model:'A',title:'Nội thất căn hộ',selection:1,editing:false,busy:false,settings:{views:['ISO','TOP','FRONT','RIGHT']},current_frame:{width:1920,height:1080,margin:10},camera:{perspective:true,fov:45,fov_vertical:true,eye_z_mm:1500,supported:true},frame_cleanup:{count:0,restore:false},presets:{},scenes:[]};
  const sync=async(changes={})=>{state={...state,...changes};await page.evaluate(value=>VGDScenes.receive('state',value),state);};
  const receive=async(data)=>page.evaluate(value=>VGDScenes.receive('result',value),data);
  const mutations=()=>page.evaluate(()=>calls.filter(call=>call.action!=='refresh'));
  const current=()=>page.locator('.tab:not([hidden])').getAttribute('id');
  await sync();assert(await page.locator('nav button').count()===5,'Navigation must have five left tabs');
  assert(await current()==='views'&&await page.locator('#flowNext').isDisabled(),'Empty model starts in wrong step');
  assert(!await page.locator('#sourceOptions').evaluate(el=>el.open),'Advanced source settings start expanded');
  await page.click('[data-tab="sections"]');assert(await current()==='sections'&&await page.locator('nav [data-tab="sections"]').getAttribute('aria-selected')==='true','Sections must have its own left tab');
  await page.click('[data-tab="views"]');await page.click('#generate');assert((await mutations()).at(-1).action==='generate','Create action missing');
  const scenes=['ISO','TOP','FRONT','RIGHT'].map((name,i)=>({id:String(i+1),name:'Tủ bếp_'+name,group:'Tủ bếp',owned:true,selected:i===0,frame:{width:i===1?1200:1920,height:i===1?1600:1080,margin:10}}));
  await receive({success:true,ids:['1','2','3','4'],message:'Đã tạo 4 scene'});await sync({scenes,frame_cleanup:{count:4,restore:false}});
  assert(await current()==='scenes'&&await page.locator('#selectedCount').innerText()==='4 đã chọn','Create must lead to selected generated scenes');
  assert(await page.locator('.row-action:visible').count()===4,'Save camera buttons must be directly visible');
  assert(await page.locator('#scenes details[open]').count()===0,'Scene advanced panels should start collapsed');
  await page.click('#goCompose');assert(await current()==='compose'&&await page.locator('#composeScene').inputValue()==='1','Compose must show current scene');
  assert(await page.locator('#width').isVisible()&&!await page.locator('#cameraFov').isVisible()&&!await page.locator('#export_scale').isVisible(),'Compose mixes camera/advanced/output settings');
  let count=(await mutations()).length;await page.fill('#width','2400');assert((await mutations()).length===count,'Flow changed frame save timing');await page.press('#width','Enter');assert((await mutations()).at(-1).action==='saveFrames','Frame commit lost');
  await receive({success:true,message:'Đã lưu khung'});await sync({current_frame:{width:2400,height:1080,margin:10}});
  await page.click('#cameraOptions > summary');count=(await mutations()).length;await page.click('#cameraOptions > summary');assert((await mutations()).length===count,'Disclosure modified camera');
  await page.selectOption('#composeScene','2');assert((await mutations()).at(-1).action==='visit'&&(await mutations()).at(-1).id==='2','Scene chooser did not visit correct ID');
  await receive({success:true,message:'Đã mở scene'});await sync({scenes:scenes.map(scene=>({...scene,selected:scene.id==='2'})),current_frame:{width:1200,height:1600,margin:10}});
  assert(await page.inputValue('#width')==='1200','Scene chooser did not load that scene frame');
  await page.click('#flowNext');assert(await current()==='export','Compose next must open export');
  assert(await page.locator('#format').isVisible()&&!await page.locator('#width').isVisible()&&!await page.locator('#cameraFov').isVisible(),'Export still contains camera/frame controls');
  assert(await page.locator('#exportSummary').innerText().then(text=>text.includes('Tủ bếp_TOP')&&text.includes('1200 × 1600')),'Export summary lost per-scene frame');
  await page.selectOption('#format','jpg');await page.fill('#export_scale','0.5');assert((await page.locator('#exportSummary').innerText()).includes('600 × 800'),'Summary did not apply export scale');await page.click('#exportButton');const call=(await mutations()).at(-1);assert(call.action==='export'&&call.ids.length===4&&call.settings.format==='jpg'&&call.settings.export_scale===0.5,'Flow changed export payload');
  await receive({success:true,message:'Đã xuất'});await sync();await page.click('#flowBack');assert(await current()==='compose','Back path wrong');await page.click('#flowBack');assert(await current()==='scenes','Back to selection wrong');
  const out=path.resolve(__dirname,'../outputs');fs.mkdirSync(out,{recursive:true});
  for(const dark of [false,true]){
   await page.evaluate(dark=>document.body.classList.toggle('dark',dark),dark);
   const palette=await page.evaluate(()=>({accent:getComputedStyle(document.body).getPropertyValue('--accent').trim(),bg:getComputedStyle(document.body).getPropertyValue('--bg').trim()}));assert(palette.accent==='#b48963'&&palette.bg===(dark?'#121212':'#f7f7f5'),'Existing theme changed');
   for(const viewport of [{width:640,height:780},{width:460,height:540}]){
    await page.setViewportSize(viewport);
    for(const step of ['views','sections','scenes','compose','export']){
     await page.click('[data-tab="'+step+'"]');
     assert(await page.locator('#primarySlot > button:visible').count()===1,'Each step needs one main action');
     const layout=await page.evaluate(()=>{const main=document.querySelector('main'),footer=document.querySelector('footer'),nav=document.querySelector('nav');return nav.getBoundingClientRect().right<=main.getBoundingClientRect().left+1&&main.scrollWidth<=main.clientWidth&&document.documentElement.scrollWidth<=innerWidth&&footer.getBoundingClientRect().bottom<=innerHeight;});assert(layout,'Clipped '+step+'/'+viewport.width);
     await page.screenshot({path:path.join(out,`flow_${step}_${viewport.width}_${dark?'dark':'light'}.png`)});
    }
   }
  }
  assert(!errors.length,errors.join('\n'));console.log('PASS: four-step create/select/compose/export flow, section branch, selected scene chooser, one primary action, collapsible extras, export payload, unchanged theme and 640/460 layouts');
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
