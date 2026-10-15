const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const {chromium}=require(process.env.VGD_PLAYWRIGHT_MODULE || 'playwright');
const assert=(ok,message)=>{if(!ok)throw Error(message);};
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.VGD_BROWSER_EXECUTABLE});
 try{
  const page=await browser.newPage({viewport:{width:800,height:760}});page.setDefaultTimeout(7000);
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{window.calls=[];window.sketchup={ready(){},action(value){calls.push(JSON.parse(value));}};});
  await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_scenes/dialog.html')).href);
  const scenes=Array.from({length:50},(_,i)=>({id:String(i+1),name:'Phòng ngủ_'+String(i+1).padStart(2,'0'),owned:true,selected:i===0,frame:{width:i%2?1200:1920,height:i%2?1600:1080,margin:10}}));
  let state={model:'A',title:'50 views',selection:1,editing:false,busy:false,native_order_supported:true,native_order_dirty:true,settings:{views:['ISO','TOP','FRONT','RIGHT']},current_frame:scenes[0].frame,camera:{perspective:true,fov:45,supported:true,sig:'a',saved_sig:'a'},scenes};
  const sync=async(changes={})=>{state={...state,...changes};await page.evaluate(value=>VGDScenes.receive('state',value),state);};
  const result=async()=>page.evaluate(()=>VGDScenes.receive('result',{success:true,message:'Test'}));
  const mutations=()=>page.evaluate(()=>calls.filter(c=>c.action!=='refresh'));
  const last=async()=> (await mutations()).at(-1);
  await sync();
  assert(await page.locator('[data-view="ISO"]').innerText()==='ISO','Angle button contains extra text');
  const symbols=await page.locator('[data-view="ISO"]').evaluate(el=>({before:getComputedStyle(el,'::before').display,after:getComputedStyle(el,'::after').display}));assert(symbols.before==='none'&&symbols.after==='none','Angle buttons still show icons or ticks');
  await page.click('[data-tab="scenes"]');
  assert(await page.locator('.scene-row').count()===50&&await page.locator('.row-menu,#update').count()===0,'Old row/source menus remain');
  await page.click('[data-id="1"] .scene-name');assert((await last()).action==='visit'&&(await last()).id==='1','Single click does not visit scene');
  // A state reply arrives between the two clicks; the name node must survive.
  await sync();await page.locator('[data-id="1"] .scene-name').dblclick();
  await page.fill('#renameInput','Phòng ngủ master');await page.click('#modalConfirm');assert((await last()).action==='rename'&&(await last()).id==='1','Double click rename failed after visit reply');await result();await sync();
  await page.click('#selectNone');await page.click('[data-id="1"] input[type=checkbox]');
  const count=(await mutations()).length;
  await page.click('[data-id="10"] input[type=checkbox]',{modifiers:['Shift']});
  assert(await page.locator('.scene-row input[type=checkbox]:checked').count()===10&&(await mutations()).length===count,'Shift range moves camera or misses scenes');
  await page.click('#renameOptions > summary');
  await page.fill('#renamePrefix','PN');await page.fill('#renameBase','Phòng ngủ');await page.fill('#renameSuffix','FINAL');await page.selectOption('#renameSequence','letter');await page.fill('#renameStart','26');
  assert((await page.locator('#renamePreview').innerText()).includes('PN_Phòng ngủ_Z_FINAL')&&(await page.locator('#renamePreview').innerText()).includes('PN_Phòng ngủ_AA_FINAL'),'Alphabetic naming preview incorrect');
  await page.click('#renameMany');let call=await last();assert(call.action==='renameMany'&&call.ids.length===10&&call.start===26&&call.sequence==='letter','Batch naming payload incorrect');await result();await sync();
  await page.click('#renameOptions > summary');
  const grip=page.locator('[data-id="1"] .scene-grip');await grip.scrollIntoViewIfNeeded();
  const source=await grip.boundingBox(),main=await page.locator('main').boundingBox();
  await page.mouse.move(source.x+source.width/2,source.y+source.height/2);await page.mouse.down();
  await page.mouse.move(source.x+source.width/2+15,source.y+source.height/2+15,{steps:5});
  await page.mouse.move(main.x+main.width-30,main.y+main.height-12,{steps:8});
  await page.waitForFunction(()=>{const row=document.querySelector('[data-id="12"]'),main=document.querySelector('main');const r=row.getBoundingClientRect(),m=main.getBoundingClientRect();return r.top>m.top&&r.bottom<m.bottom;});
  const destination=await page.locator('[data-id="12"]').boundingBox();
  await page.mouse.move(destination.x+70,destination.y+2,{steps:5});await page.mouse.up();
  call=await last();assert(call.action==='reorder'&&call.ids.join(',')==='1,2,3,4,5,6,7,8,9,10'&&call.before==='12'&&call.order.length===50,'Group drag lost selection or full-order anchor: '+JSON.stringify(call));await result();await sync();
  await page.click('#syncOrder');call=await last();assert(call.action==='syncOrder'&&call.order.length===50,'Native sync payload incorrect');await result();await sync({native_order_supported:false});assert(await page.locator('#syncOrder').isDisabled()&&(await page.locator('#orderHint').innerText()).includes('SU2022'),'Legacy API restriction not visible');
  await page.locator('[data-id="5"] .row-capture').click();assert((await last()).action==='capture'&&(await last()).id==='5','Direct row camera save wrong ID');await result();await sync();
  await page.locator('[data-id="5"] .row-delete').click();await page.click('#modalCancel');assert((await last()).action==='capture','Cancel row delete changed scene');
  await page.locator('[data-id="5"] .row-delete').click();await page.click('#modalConfirm');assert((await last()).action==='delete'&&(await last()).ids.join(',')==='5','Per-row delete wrong scope');await result();await sync();
  await page.click('[data-tab="sections"]');assert(await page.locator('#section_offset,#customNormal').count()===0&&await page.locator('#section_axis option').count()===3,'Removed cut controls still exist');
  await page.locator('#sectionSlider').evaluate(el=>{el.value='20';el.dispatchEvent(new Event('input',{bubbles:true}));el.value='80';el.dispatchEvent(new Event('input',{bubbles:true}));});
  await page.waitForTimeout(180);call=await last();assert(call.action==='sectionPreview'&&call.settings.section_percent===80&&call.settings.section_offset===0,'Slider does not preview latest cut');
  const previewCount=(await mutations()).filter(c=>c.action==='sectionPreview').length;assert(previewCount===1,'Slider sends unbounded callbacks');
  await page.locator('#sectionSlider').evaluate(el=>{el.value='35';el.dispatchEvent(new Event('input',{bubbles:true}));});await page.click('[data-tab="views"]');await page.waitForTimeout(180);assert((await last()).action==='sectionCancel'&&(await mutations()).filter(c=>c.action==='sectionPreview').length===1,'Leaving cut tab submits stale preview');
  const out=path.resolve(__dirname,'../outputs');fs.mkdirSync(out,{recursive:true});
  for(const dark of [false,true]){
   await page.evaluate(dark=>document.body.classList.toggle('dark',dark),dark);
   await page.setViewportSize({width:800,height:760});await page.click('[data-tab="scenes"]');await page.screenshot({path:path.join(out,`sidebar_50_scenes_${dark?'dark':'light'}.png`)});
  }
  assert(!errors.length,errors.join('\n'));console.log('PASS: 50 scenes, Shift range/block drag, native sync guard, single/double clicks, direct save/delete, bulk numeric/alphabet names and debounced cut preview');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
