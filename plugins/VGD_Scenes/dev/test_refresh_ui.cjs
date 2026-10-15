const path=require('path'),{pathToFileURL}=require('url');
const {chromium}=require(process.env.VGD_PLAYWRIGHT_MODULE || 'playwright');
const assert=(value,message)=>{if(!value)throw Error(message);};
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.VGD_BROWSER_EXECUTABLE});
 try{
  const page=await browser.newPage({viewport:{width:460,height:540},colorScheme:'dark'});
  page.setDefaultTimeout(7000);
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{localStorage.removeItem('VGD.Scenes.Theme');window.calls=[];window.sketchup={ready(){},action(value){calls.push(JSON.parse(value));}};});
  await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_scenes/dialog.html')).href);
  assert(await page.locator('body').evaluate(el=>el.classList.contains('dark')),'First launch ignores system dark theme');
  let state={model:'A',title:'Test',selection:1,editing:false,busy:false,settings:{views:['ISO']},current_frame:{width:1920,height:1080,margin:10},camera:{perspective:true,fov:45,supported:true,sig:'live',saved_sig:'saved'},scenes:[{id:'1',name:'Tủ bếp_ISO',selected:true,owned:true,frame:{width:1920,height:1080,margin:10}},{id:'2',name:'Tủ bếp_TOP',frame:{width:1200,height:1600,margin:10}}]};
  const sync=async(changes={})=>{state={...state,...changes};await page.evaluate(s=>VGDScenes.receive('state',s),state);};
  const result=async(success)=>page.evaluate(success=>VGDScenes.receive('result',{success,message:'Test'}),success);
  const badge=page.locator('#unsavedBadge');
  await sync();await page.click('[data-tab="compose"]');
  assert(await badge.isVisible(),'Opening dialog after Orbit hides unsaved camera');
  await page.click('#updateCurrentView');await result(false);await sync();
  await page.waitForTimeout(1050);
  assert(await badge.isVisible(),'Failed camera save cleared unsaved warning');
  await page.click('#updateCurrentView');await result(true);await sync({camera:{...state.camera,saved_sig:'live'}});
  assert(await badge.isHidden(),'Successful camera save remains dirty');
  await sync({camera:{...state.camera,sig:'orbit'}});assert(await badge.isVisible(),'Orbit not detected');
  await page.selectOption('#composeScene','2');await page.waitForTimeout(1000);
  assert(await badge.isVisible(),'Slow scene visit incorrectly marks old camera as saved');
  await result(true);await sync({scenes:state.scenes.map(s=>({...s,selected:s.id==='2'})),camera:{...state.camera,sig:'top',saved_sig:'top'}});
  assert(await badge.isHidden(),'New scene uses old camera baseline');
  await sync({camera:{...state.camera,sig:'top-orbit'}});
  await page.click('[data-tab="export"]');assert(await badge.isHidden(),'Warning visible outside Compose');
  await page.click('#flowBack');assert(await badge.isVisible(),'Back to Compose hides dirty camera');
  await page.click('[data-tab="scenes"]');
  assert(await page.locator('[data-id="2"] .row-frame').isHidden(),'Row frame starts expanded');
  await page.click('[data-id="2"] .size-chip');await sync();
  assert(await page.locator('[data-id="2"] .row-frame').isVisible(),'Polling collapses open row frame');
  await sync({model:'B',camera:{...state.camera,sig:'new',saved_sig:'new'}});
  assert(await page.locator('[data-id="2"] .row-frame').isHidden(),'Frame expansion leaks between models sharing IDs');
  await page.click('[data-tab="compose"]');assert(await badge.isHidden(),'Camera baseline leaks between models');
  await page.click('[data-tab="export"]');
  for(const fmt of ['jpg','pdf','png']){
   await page.click('[data-fmt="'+fmt+'"]');
   assert(await page.inputValue('#format')===fmt&&await page.locator('[data-fmt="'+fmt+'"]').getAttribute('aria-pressed')==='true','Format segment is out of sync');
   assert(await page.locator('#paperLabel').isVisible()===(fmt==='pdf'),'PDF controls are out of sync');
  }
  await page.check('#date_folder');assert((await page.locator('#outPath').innerText()).includes('YYYY.MM.DD → PNG'),'Dated output path wrong');
  await page.evaluate(()=>VGDScenes.receive('started',{total:4}));
  await page.evaluate(()=>VGDScenes.receive('progress',{current:2,total:4,name:'Test'}));
  assert(await page.locator('#progressText').innerText()==='50%','Export progress percentage wrong');
  await page.evaluate(()=>VGDScenes.receive('exported',{success:false,message:'Test error'}));
  assert(await page.locator('#progressText').isHidden()&&await page.locator('#status').evaluate(el=>getComputedStyle(el).backgroundColor!=='rgba(0, 0, 0, 0)'),'Error feedback or progress cleanup lost');
  assert(!errors.length,errors.join('\n'));
  console.log('PASS: saved camera vs live preview, failed/slow save and visit, model reset, system theme, compact rows, real format segments and progress');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
