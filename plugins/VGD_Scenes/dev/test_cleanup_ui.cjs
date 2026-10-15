const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const {chromium}=require(process.env.VGD_PLAYWRIGHT_MODULE || 'playwright');
const assert=(ok,message)=>{if(!ok)throw Error(message);};
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.VGD_BROWSER_EXECUTABLE});
 try{
  const page=await browser.newPage({viewport:{width:460,height:540}}),errors=[];
  page.on('pageerror',error=>errors.push(error.message));
  await page.addInitScript(()=>{
   window.calls=[];window.resources={timers:[],observers:0};
   const interval=window.setInterval.bind(window);window.setInterval=(callback,delay,...args)=>{resources.timers.push(delay);return interval(callback,delay,...args);};
   window.MutationObserver=new Proxy(window.MutationObserver,{construct(target,args){resources.observers++;return new target(...args);}});
   window.sketchup={ready(){},action(value){calls.push(JSON.parse(value));}};
  });
  await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_scenes/dialog.html')).href);
  const state={model:'A',title:'Cleanup',selection:1,editing:false,busy:false,settings:{views:['ISO']},current_frame:{width:1920,height:1080,margin:10},camera:{perspective:true,fov:45,supported:true,sig:'a',saved_sig:'a'},scenes:Array.from({length:50},(_,i)=>({id:String(i+1),name:'Phòng_'+i,selected:i===0,owned:true,frame:{width:1920,height:1080,margin:10}}))};
  await page.evaluate(value=>VGDScenes.receive('state',value),state);
  await page.click('#presetNone');assert((await page.locator('#generate').textContent()).includes('ít nhất'),'Count stale after preset');
  await page.click('[data-view="TOP"]');assert((await page.locator('#generate').textContent()).includes('1 scene'),'Count stale after view selection');
  await page.click('#preset4');assert((await page.locator('#generate').textContent()).includes('4 scene'),'Count stale after four-view preset');
  await page.click('[data-tab="scenes"]');
  assert(await page.locator('.row-menu,.badge,nav .step-number').count()===0,'Obsolete scene/stepper nodes remain');
  assert((await page.locator('.row-capture').first().innerText())==='Lưu view','Row save name inconsistent');
  const chip=page.locator('.size-chip').first();await chip.click();assert(await chip.getAttribute('aria-expanded')==='true','Frame chip state missing');
  assert(await chip.evaluate(el=>getComputedStyle(el,'::after').content)==='none','Old size arrow remains');
  for(let i=0;i<20;i++)await page.evaluate(value=>VGDScenes.receive('state',value),state);
  const resources=await page.evaluate(()=>window.resources);
  assert(resources.observers<=2&&resources.timers.length<=1,'Presentation creates excessive observers/timers');
  await page.click('[data-tab="compose"]');assert(await page.locator('#updateCurrentView').innerText()==='Lưu view','Primary save name inconsistent');
  await page.click('[data-tab="export"]');await page.click('[data-fmt="jpg"]');
  assert(await page.locator('[data-fmt="jpg"]').getAttribute('aria-pressed')==='true'&&(await page.locator('#outPath').textContent()).includes('JPG'),'Format waits for polling');
  const theme=await page.locator('#theme').boundingBox();assert(theme.width===32&&theme.height===32,'Theme icon regressed');
  const css=fs.readFileSync(path.resolve(__dirname,'../runtime/vgd_scenes/dialog.css'),'utf8');
  assert(!/row-menu|step-number|1\.4|1\.5\.1 fixes/.test(css),'Historical CSS remains');
  assert(css.length<18000,'Consolidated CSS grew past cleanup budget');
  assert(!errors.length,errors.join('\n'));
  console.log('PASS: 50-scene resource budget after 20 refreshes, immediate view/format feedback without polling, uniform Lưu view, obsolete DOM/CSS removed and 1.5.1 theme/frame fixes retained');
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
